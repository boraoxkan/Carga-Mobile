import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tutanak/models/crash_region.dart'; // Model dosyanızın yolu doğru olmalı
import 'package:tutanak/screens/pdf_viewer_page.dart'; // Ekran dosyanızın yolu doğru olmalı
import 'package:geocoding/geocoding.dart';

class ReportDetailPage extends StatefulWidget {
  final String recordId;

  const ReportDetailPage({Key? key, required this.recordId}) : super(key: key);

  @override
  _ReportDetailPageState createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  // DİKKAT: Sunucu IP adresiniz ve portunuzu buraya girin.
  final String _pdfServerBaseUrl = "http://100.71.209.113:6001";
  final String _pdfGenerationEndpoint = "/generate_accident_report_pdf";

  Map<String, dynamic>? _recordData;
  bool _isGeneratingPdf = false;
  String? _address;
  bool _isFetchingAddress = false;
  String? _addressError;

  // --- VERİ ÇEKME VE HAZIRLAMA FONKSİYONLARI ---

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

  /// BU YARDIMCI FONKSİYON, HER TÜRLÜ VERİYİ JSON'A UYGUN HALE GETİRİR.
  /// İç içe geçmiş (nested) tüm Map ve List'lerdeki Timestamp gibi özel nesneleri temizler.
  dynamic _convertDataToJsonSerializable(dynamic data) {
    if (data is Timestamp) {
      // Timestamp nesnesini standart bir tarih formatına çevir
      return data.toDate().toIso8601String(); 
    }
    if (data is LatLng) {
      return {'latitude': data.latitude, 'longitude': data.longitude};
    }
    if (data is Map) {
      // Map'in her bir elemanı için fonksiyonu tekrar çağır (recursive)
      return data.map(
        (key, value) => MapEntry(key.toString(), _convertDataToJsonSerializable(value)),
      );
    }
    if (data is List) {
      // Listenin her bir elemanı için fonksiyonu tekrar çağır (recursive)
      return data.map((item) => _convertDataToJsonSerializable(item)).toList();
    }
    // Diğer tüm veri tipleri (String, int, bool vb.) olduğu gibi kalır.
    return data;
  }

  /// BU FONKSİYON, VERİLERİ TOPLAYIP TEMİZLEYEREK SUNUCUYA HAZIRLAR
  Future<Map<String, dynamic>> _prepareDataForPdfGeneration(Map<String, dynamic> currentRecordData) async {
    // 1. Ana veriyi al ve içindeki Timestamp gibi özel nesneleri temizle.
    Map<String, dynamic> dataForPdf = _convertDataToJsonSerializable(Map<String, dynamic>.from(currentRecordData));

    // 2. Creator ve Joiner için detaylı verileri Firestore'dan çek.
    final creatorUid = currentRecordData['creatorUid'] as String?;
    final joinerUid = currentRecordData['joinerUid'] as String?;

    if (creatorUid != null) {
      final creatorDetails = await _fetchFullUserDetails(creatorUid);
      final creatorVehicleDetails = await _fetchFullVehicleDetails(creatorUid, currentRecordData['creatorVehicleId'] as String?);
      // Çekilen bu verileri de JSON'a çevrilebilir hale getir ve ana haritaya ekle.
      dataForPdf['creatorUserData'] = _convertDataToJsonSerializable(creatorDetails);
      dataForPdf['creatorVehicleInfo'] = _convertDataToJsonSerializable(creatorVehicleDetails);
    }
    
    if (joinerUid != null) {
      final joinerDetails = await _fetchFullUserDetails(joinerUid);
      final joinerVehicleDetails = await _fetchFullVehicleDetails(joinerUid, currentRecordData['joinerVehicleId'] as String?);
      dataForPdf['joinerUserData'] = _convertDataToJsonSerializable(joinerDetails);
      dataForPdf['joinerVehicleInfo'] = _convertDataToJsonSerializable(joinerVehicleDetails);
    }

    // 3. Şablonda kolay kullanım için tarih ve saati ayrı ayrı ekle.
    if (currentRecordData['kazaTimestamp'] is Timestamp) {
      DateTime kazaDT = (currentRecordData['kazaTimestamp'] as Timestamp).toDate();
      dataForPdf['kazaTarihi'] = DateFormat('dd.MM.yyyy', 'tr_TR').format(kazaDT);
      dataForPdf['kazaSaati'] = DateFormat('HH:mm').format(kazaDT);
    }
    
    dataForPdf['recordId'] = widget.recordId;
    return dataForPdf;
  }

  /// BU FONKSİYON, SUNUCUYA İSTEK ATIP PDF'İ ALIR
  Future<void> _generateAndShowPdf() async {
    if (_recordData == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rapor verileri henüz yüklenmedi.")));
      return;
    }
    setState(() => _isGeneratingPdf = true);

    // 1. Veriyi sunucuya göndermeye hazırla
    // Bu fonksiyonun önceki cevaplardaki gibi doğru olduğundan emin olun.
    // Her ihtimale karşı bu fonksiyonun da doğru halini aşağıya ekleyeceğim.
    Map<String, dynamic> dataToSend = await _prepareDataForPdfGeneration(Map<String, dynamic>.from(_recordData!));

    // 2. HATA AYIKLAMA VE KONTROL
    print("--- HATA AYIKLAMA BAŞLADI ---");
    try {
      // Veriyi JSON'a çevirmeyi dene
      jsonEncode(dataToSend);
      
      // Eğer bu satıra kadar geldiyse ve hata almadıysanız, sorun çözülmüş demektir.
      // Bu durumda normal API isteğini gönderebiliriz.
      print("✓ Veri JSON formatına başarıyla çevrildi. Hata bulunamadı. Sunucuya gönderiliyor...");

      // ---- API İSTEĞİ BURADA ----
      final response = await http.post(
        Uri.parse("$_pdfServerBaseUrl$_pdfGenerationEndpoint"),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(dataToSend),
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
      // ---- API İSTEĞİ BİTİŞİ ----

    } catch (e) {
      // BURASI ÇOK ÖNEMLİ: HATA ALIRSANIZ KONSOL BU KISMI YAZDIRACAK
      print("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
      print("!!! JSON ÇEVİRME HATASI TESPİT EDİLDİ !!!");
      print("Hatanın tam metni: $e");
      print("Sorunlu anahtarı bulmak için veri kontrol ediliyor...");
      print("--------------------------------------------");

      // Hangi anahtarın sorun çıkardığını bulmak için veriyi tek tek kontrol et
      dataToSend.forEach((key, value) {
        try {
          jsonEncode({key: value});
        } catch (err) {
          print(">>>> SORUNLU ANAHTAR (KEY): '$key' <<<<");
          print(">>>> DEĞERİN TİPİ: ${value.runtimeType} <<<<");
          print("--------------------------------------------");
        }
      });
      print("Hata ayıklama tamamlandı. Lütfen yukarıdaki 'SORUNLU ANAHTAR' çıktısını kontrol edin.");
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("Veri formatlama hatası! Lütfen konsolu kontrol edin."),
          backgroundColor: Colors.red,
        ));
      }

    } finally {
        if(mounted) setState(() => _isGeneratingPdf = false);
    }
  }

  // --- ARAYÜZ (UI) WIDGET'LARI ---
  
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
               if (!snapshot.hasData || snapshot.data?.data() == null) return const SizedBox.shrink();
               final currentRecordData = snapshot.data!.data()!;
               final String? pdfUrlFromRecord = currentRecordData['pdfUrl'] as String?;
               final String status = currentRecordData['status'] as String? ?? "Bilinmiyor";

               if (status == 'all_data_submitted' || pdfUrlFromRecord != null) {
                return IconButton(
                  icon: _isGeneratingPdf ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,)) : const Icon(Icons.picture_as_pdf),
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
                 // Burada sizin mevcut UI kodunuz yer alacak.
                 // Örnek olarak birkaçı eklendi.
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

  // Buradan sonraki tüm _build... fonksiyonları sizin kodunuzdaki gibi kalacak
  String _formatTimestamp(Timestamp? timestamp, BuildContext context, {String format = 'dd MMMM yyyy, HH:mm'}) {
    if (timestamp == null) return 'Belirtilmemiş';
    final locale = Localizations.localeOf(context).toString();
    try {
      return DateFormat(format, locale).format(timestamp.toDate());
    } catch (e) {
      return DateFormat(format.contains('HH') ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy').format(timestamp.toDate());
    }
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

  Widget _buildInfoCard({ required BuildContext context, String? title, IconData? titleIcon, required List<Widget> children, EdgeInsetsGeometry? padding, Color? cardColor, Color? titleColor}) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2, color: cardColor ?? theme.cardTheme.color,
      shape: theme.cardTheme.shape ?? RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding( padding: padding ?? const EdgeInsets.all(16.0),
        child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
            if (title != null) ...[
              Row(children: [
                  if (titleIcon != null) ...[ Icon(titleIcon, color: titleColor ?? theme.colorScheme.primary, size: 22), const SizedBox(width: 8)],
                  Expanded(child: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: titleColor ?? theme.colorScheme.primary))),
              ]),
              const Divider(height: 20, thickness: 0.5),
            ],
            ...children,
        ]),
      ),
    );
  }

  Widget _buildTextInfoRow(BuildContext context, String label, String? value, {bool isBoldValue = false, int flexLabel = 2, int flexValue = 3}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row( crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(flex: flexLabel, child: Text('$label:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Expanded(flex: flexValue, child: SelectableText(value?.isNotEmpty == true ? value! : '-', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: isBoldValue ? FontWeight.w600 : FontWeight.normal))),
        ],
      ),
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
            return _buildInfoCard( context: context, title: "Sürücü Bilgileri", titleIcon: Icons.person_outline_rounded,
              children: [
                _buildTextInfoRow(context, "Ad Soyad", '${fetchedUserData?['isim'] ?? ''} ${fetchedUserData?['soyisim'] ?? ''}'.trim(), isBoldValue: true),
                _buildTextInfoRow(context, "TC Kimlik No", fetchedUserData?['tcNo'] as String?),
              ],
            );
          },
        ),
        if (processedPhotoBase64 != null) _buildInfoCard( context: context, title: "Hasar Fotoğrafı", children: [ Image.memory(base64Decode(processedPhotoBase64)) ]),
        _buildInfoCard( context: context, title: "Sürücü Notları", children: [ Text(notes ?? "Not yok.") ]),
    ]);
  }
}