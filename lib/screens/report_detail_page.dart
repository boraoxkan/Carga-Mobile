// lib/screens/report_detail_page.dart

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tutanak/screens/pdf_viewer_page.dart';

class ReportDetailPage extends StatefulWidget {
  final String recordId;

  const ReportDetailPage({Key? key, required this.recordId}) : super(key: key);

  @override
  _ReportDetailPageState createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  final String _pdfServerBaseUrl = "http://100.71.209.113:6001";
  final String _pdfGenerationEndpoint = "/generate_accident_report_pdf";

  Map<String, dynamic>? _recordData;
  bool _isGeneratingPdf = false;

  /// YARDIMCI FONKSİYON: Her türlü veriyi JSON'a uygun hale getirir.
  /// İç içe geçmiş tüm Map ve List'lerdeki Timestamp gibi özel nesneleri temizler.
  dynamic _convertDataToJsonSerializable(dynamic data) {
    if (data == null) return null;
    if (data is Timestamp) {
      return data.toDate().toIso8601String();
    }
    if (data is LatLng) {
      return {'latitude': data.latitude, 'longitude': data.longitude};
    }
    if (data is Map) {
      return data.map(
        (key, value) => MapEntry(key.toString(), _convertDataToJsonSerializable(value)),
      );
    }
    if (data is List) {
      return data.map((item) => _convertDataToJsonSerializable(item)).toList();
    }
    return data;
  }

  /// VERİ HAZIRLAMA FONKSİYONU: Verileri toplayıp temizleyerek sunucuya hazırlar.
  Future<Map<String, dynamic>> _prepareDataForPdfGeneration(Map<String, dynamic> currentRecordData) async {
    // Başlangıç olarak tüm record verisini temizle
    Map<String, dynamic> dataForPdf = _convertDataToJsonSerializable(Map<String, dynamic>.from(currentRecordData));

    final creatorUid = currentRecordData['creatorUid'] as String?;
    final joinerUid = currentRecordData['joinerUid'] as String?;

    if (creatorUid != null) {
      final creatorDetails = await _fetchFullUserDetails(creatorUid);
      final creatorVehicleDetails = await _fetchFullVehicleDetails(creatorUid, currentRecordData['creatorVehicleId'] as String?);
      
      // Çekilen ek verileri de temizleyerek ana veriye ekle
      dataForPdf['creatorUserData'] = _convertDataToJsonSerializable(creatorDetails);
      dataForPdf['creatorVehicleInfo'] = _convertDataToJsonSerializable(creatorVehicleDetails);
    }
    
    if (joinerUid != null) {
      final joinerDetails = await _fetchFullUserDetails(joinerUid);
      final joinerVehicleDetails = await _fetchFullVehicleDetails(joinerUid, currentRecordData['joinerVehicleId'] as String?);
      
      dataForPdf['joinerUserData'] = _convertDataToJsonSerializable(joinerDetails);
      dataForPdf['joinerVehicleInfo'] = _convertDataToJsonSerializable(joinerVehicleDetails);
    }

    // Şablonda kolay kullanım için tarih ve saati ayrıca formatla
    if (currentRecordData['kazaTimestamp'] is Timestamp) {
      DateTime kazaDT = (currentRecordData['kazaTimestamp'] as Timestamp).toDate();
      dataForPdf['kazaTarihi'] = DateFormat('dd.MM.yyyy', 'tr_TR').format(kazaDT);
      dataForPdf['kazaSaati'] = DateFormat('HH:mm').format(kazaDT);
    }
    
    dataForPdf['recordId'] = widget.recordId;
    return dataForPdf;
  }

  /// PDF OLUŞTURMA FONKSİYONU: Sunucuya istek atıp PDF'i alır.
  Future<void> _generateAndShowPdf() async {
    if (_recordData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rapor verileri henüz yüklenmedi.")));
      return;
    }
    setState(() => _isGeneratingPdf = true);

    try {
      // 1. Veriyi sunucuya göndermek için hazırla ve temizle
      Map<String, dynamic> dataToSend = await _prepareDataForPdfGeneration(Map<String, dynamic>.from(_recordData!));

      // 2. Temizlenmiş veriyi JSON formatına çevir
      final String jsonBody = jsonEncode(dataToSend);

      // 3. Sunucuya isteği gönder
      final response = await http.post(
        Uri.parse("$_pdfServerBaseUrl$_pdfGenerationEndpoint"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonBody,
      ).timeout(const Duration(seconds: 120));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final Uint8List pdfBytes = response.bodyBytes;
        final directory = await getTemporaryDirectory();
        final filePath = '${directory.path}/kaza_raporu_${widget.recordId}.pdf';
        await File(filePath).writeAsBytes(pdfBytes);
        
        Navigator.push(context, MaterialPageRoute(
          builder: (context) => PdfViewerPage(pdfPath: filePath, title: "Kaza Tespit Tutanağı"),
        ));
      } else {
        throw Exception("Sunucu hatası: ${response.statusCode} - ${response.body}");
      }

    } catch (e) {
      print("PDF oluşturma/gösterme sırasında genel hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("PDF oluşturulurken bir hata oluştu: ${e.toString()}"),
          backgroundColor: Colors.red,
        ));
      }
    } finally {
        if(mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  Future<Map<String, dynamic>?> _fetchFullUserDetails(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print("Kullanıcı detayı çekilirken hata ($userId): $e");
      return null;
    }
  }

  Future<Map<String, dynamic>?> _fetchFullVehicleDetails(String? userId, String? vehicleId) async {
    if (userId == null || userId.isEmpty || vehicleId == null || vehicleId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).collection('vehicles').doc(vehicleId).get();
      return doc.exists ? doc.data() : null;
    } catch (e) {
      print("Araç detayı çekilirken hata (user: $userId, vehicle: $vehicleId): $e");
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tutanak Detayı"),
        actions: [
           StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
             stream: FirebaseFirestore.instance.collection('records').doc(widget.recordId).snapshots(),
             builder: (context, snapshot) {
               if (!snapshot.hasData || snapshot.data?.data() == null) {
                 return const SizedBox.shrink();
               }
               final currentRecordData = snapshot.data!.data()!;
               final String? pdfUrlFromRecord = currentRecordData['pdfUrl'] as String?;
               final String status = currentRecordData['status'] as String? ?? "Bilinmiyor";

               if (status == 'all_data_submitted' || pdfUrlFromRecord != null) {
                return IconButton(
                  icon: _isGeneratingPdf 
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) 
                      : const Icon(Icons.picture_as_pdf),
                  tooltip: pdfUrlFromRecord != null ? "Kayıtlı PDF'i Görüntüle" : "Tutanak PDF'ini Oluştur",
                  onPressed: _isGeneratingPdf ? null : () {
                    _recordData = currentRecordData;
                    if (pdfUrlFromRecord != null) {
                       Navigator.push(context, MaterialPageRoute(builder: (context) => 
                        PdfViewerPage(pdfUrl: pdfUrlFromRecord, title: "Kaza Tespit Tutanağı")
                      ));
                    } else {
                      _generateAndShowPdf();
                    }
                  },
                );
               }
               return const SizedBox.shrink();
             }
           ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('records').doc(widget.recordId).snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting && _recordData == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Rapor detayı yüklenirken hata: ${snapshot.error}", style: TextStyle(color: theme.colorScheme.error)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Rapor bulunamadı."));
          }

          _recordData = snapshot.data!.data()!; 
          
          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildPartyInfoSection(context, theme, _recordData!, "creator", "Tutanak Oluşturan Taraf", Icons.person_pin_circle_rounded),
                const SizedBox(height: 10),
                Divider(thickness: 1, color: theme.dividerColor.withOpacity(0.6), height: 30, indent: 20, endIndent: 20),
                const SizedBox(height: 10),
                _buildPartyInfoSection(context, theme, _recordData!, "joiner", "Tutanağa Katılan Taraf", Icons.group_rounded),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
      child: Row(children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(width: 10),
        Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
      ]),
    );
  }

  Widget _buildPartyInfoSection(BuildContext context, ThemeData theme, Map<String, dynamic> recordData, String rolePrefix, String sectionTitle, IconData sectionIcon) {
    final String? userId = recordData['${rolePrefix}Uid'] as String?;
    final String? notes = recordData['${rolePrefix}Notes'] as String?;
    final String? processedPhotoBase64 = recordData['${rolePrefix}ProcessedDamageImageBase64'] as String?;
    
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionTitle(context, sectionTitle, sectionIcon, theme.colorScheme.secondary),
        FutureBuilder<Map<String,dynamic>?>(
          future: _fetchFullUserDetails(userId),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
            final fetchedUserData = userSnapshot.data;
            return Card(
                child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                            Text("Sürücü Bilgileri", style: theme.textTheme.titleLarge),
                            const Divider(),
                            Text('Ad Soyad: ${fetchedUserData?['isim'] ?? 'N/A'} ${fetchedUserData?['soyisim'] ?? ''}'),
                            Text('TC: ${fetchedUserData?['tcNo'] ?? 'N/A'}'),
                        ],
                    ),
                ),
            );
          },
        ),
        if (processedPhotoBase64 != null) Card(child: Padding(padding: const EdgeInsets.all(8.0), child: Image.memory(base64Decode(processedPhotoBase64)))),
        Card(child: Padding(padding: const EdgeInsets.all(16.0), child: Text(notes ?? "Not yok."))),
    ]);
  }
}