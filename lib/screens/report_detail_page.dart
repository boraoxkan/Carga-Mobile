// lib/screens/report_detail_page.dart
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tutanak/screens/pdf_viewer_page.dart';
import 'package:tutanak/models/crash_region.dart';
import 'package:geocoding/geocoding.dart';

class ReportDetailPage extends StatefulWidget {
  final String recordId;

  const ReportDetailPage({Key? key, required this.recordId}) : super(key: key);

  @override
  _ReportDetailPageState createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> {
  String? _address;
  bool _isFetchingAddress = false;
  String? _addressError;
  Map<String, dynamic>? _recordData;
  bool _isGeneratingPdf = false;

  final String _pdfServerBaseUrl = "http://100.110.23.124:5001"; // SUNUCU IP ADRESİNİZİ GÜNCELLEYİN
  final String _pdfGenerationEndpoint = "/generate_accident_report_pdf";

  @override
  void initState() {
    super.initState();
  }

  Future<Map<String, dynamic>?> _fetchFullUserDetails(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print("Kullanıcı detayı Firestore'dan çekilirken hata ($userId): $e");
    }
    return null;
  }
  
  Future<Map<String, dynamic>?> _fetchFullVehicleDetails(String? userId, String? vehicleId) async {
    if (userId == null || userId.isEmpty || vehicleId == null || vehicleId.isEmpty) return null;
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(userId).collection('vehicles').doc(vehicleId).get();
      if (doc.exists) {
        return doc.data();
      }
    } catch (e) {
      print("Araç detayı Firestore'dan çekilirken hata (user: $userId, vehicle: $vehicleId): $e");
    }
    return null;
  }


  String _formatTimestamp(Timestamp? timestamp, BuildContext context, {String format = 'dd MMMM yyyy, HH:mm'}) {
    if (timestamp == null) return 'Belirtilmemiş';
    final locale = Localizations.localeOf(context).toString();
    try {
      return DateFormat(format, locale).format(timestamp.toDate());
    } catch (e) {
      return DateFormat(format.contains('HH') ? 'dd.MM.yyyy HH:mm' : 'dd.MM.yyyy').format(timestamp.toDate());
    }
  }

  String _regionLabel(CrashRegion region) {
    switch (region) {
      case CrashRegion.frontLeft: return 'Ön Sol';
      case CrashRegion.frontCenter: return 'Ön Orta';
      case CrashRegion.frontRight:  return 'Ön Sağ';
      case CrashRegion.left: return 'Sol Taraf';
      case CrashRegion.right: return 'Sağ Taraf';
      case CrashRegion.rearLeft: return 'Arka Sol';
      case CrashRegion.rearCenter: return 'Arka Orta';
      case CrashRegion.rearRight: return 'Arka Sağ';
    }
  }

  Future<void> _fetchAddressFromLatLng(double latitude, double longitude) async {
    if (!mounted || _isFetchingAddress) return;
    setState(() => _isFetchingAddress = true);
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      if (mounted && placemarks.isNotEmpty) {
        final Placemark p = placemarks.first;
        _address = [p.thoroughfare, p.subLocality, p.locality, p.administrativeArea, p.postalCode, p.country].where((s) => s != null && s.isNotEmpty).join(', ');
        _address = _address!.isNotEmpty ? _address : "Adres detayı bulunamadı.";
      } else if (mounted) {
        _address = "Adres bilgisi bulunamadı.";
      }
    } catch (e) {
      if (mounted) _addressError = "Adres alınamadı.";
      print("Adres çevirme hatası: $e");
    } finally {
      if (mounted) setState(() => _isFetchingAddress = false);
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

  Widget _buildAddressInfoWidget(Map<String, dynamic> recordData) {
    final LatLng? accidentLocation = (recordData['latitude'] != null && recordData['longitude'] != null)
        ? LatLng(recordData['latitude'] as double, recordData['longitude'] as double)
        : null;
    String? finalAddress = recordData['formattedAddress'] as String? ?? _address;

    if (finalAddress == null && accidentLocation != null && !_isFetchingAddress && _addressError == null && mounted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
           if(mounted) _fetchAddressFromLatLng(accidentLocation.latitude, accidentLocation.longitude);
        });
    }
    
    List<Widget> addressWidgets = [
      _buildTextInfoRow(context, 'İlçe', recordData['kazaIlce'] as String?),
      _buildTextInfoRow(context, 'Semt', recordData['kazaSemt'] as String?),
      _buildTextInfoRow(context, 'Mahalle', recordData['kazaMahalle'] as String?),
      _buildTextInfoRow(context, 'Cadde/Bulvar', recordData['kazaCadde'] as String?),
      _buildTextInfoRow(context, 'Sokak/No', recordData['kazaSokak'] as String?),
    ];

    if (_isFetchingAddress && finalAddress == null) {
      addressWidgets.add(const Center(child: Padding(padding: EdgeInsets.all(8.0), child: Text("Adres yükleniyor..."))));
    } else if (_addressError != null) {
      addressWidgets.add(_buildTextInfoRow(context, 'Adres Hatası', _addressError));
    } else if (finalAddress != null && finalAddress.isNotEmpty) {
      addressWidgets.add(_buildTextInfoRow(context, 'Tam Adres (Otomatik/Kaydedilen)', finalAddress));
    } else if (accidentLocation != null) {
      addressWidgets.add(_buildTextInfoRow(context, 'Kaza Konumu (Enlem/Boylam)', '${accidentLocation.latitude.toStringAsFixed(4)}, ${accidentLocation.longitude.toStringAsFixed(4)}'));
    } else {
      addressWidgets.add(_buildTextInfoRow(context, 'Kaza Adresi', 'Konum ve adres bilgisi bulunamadı.'));
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: addressWidgets);
  }

  Widget _buildPhotoDisplay(BuildContext context, String? base64Image, List<dynamic>? detections, String partyName) {
    final theme = Theme.of(context);
    if (base64Image == null || base64Image.isEmpty) {
      return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text("$partyName için işlenmiş fotoğraf bulunmuyor.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)));
    }
    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          GestureDetector( onTap: () => showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: Image.memory(imageBytes)))),
            child: ClipRRect(borderRadius: BorderRadius.circular(12), child: Image.memory(imageBytes, height: 250, fit: BoxFit.contain, errorBuilder: (c,e,s) => Icon(Icons.broken_image, size: 100, color: theme.colorScheme.outline)))),
          if (detections != null && detections.isNotEmpty) ...[
            const SizedBox(height: 12), Text("Otomatik Tespit Edilen Hasarlar:", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)), const SizedBox(height: 4),
            ...detections.map((d) { final dm = d as Map<String, dynamic>; return Padding(padding: const EdgeInsets.only(left: 8.0, top: 3.0), child: Text("• ${dm['label'] ?? '?'} (%${((dm['confidence'] ?? 0.0) * 100).toStringAsFixed(0)})", style: theme.textTheme.bodyMedium));}).toList(),
          ]
      ]);
    } catch (e) { return Text("$partyName fotoğrafı görüntülenemedi.", style: TextStyle(color: theme.colorScheme.error)); }
  }

  Widget _buildRegionsDisplay(BuildContext context, List<dynamic>? regionNames, String partyName) {
    final theme = Theme.of(context);
    if (regionNames == null || regionNames.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text("$partyName için hasar bölgesi seçilmemiş.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)));
    Set<CrashRegion> regions = regionNames.map((name) { try { return CrashRegion.values.byName(name.toString()); } catch(e) { return null; }}).whereType<CrashRegion>().toSet();
    if (regions.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text("$partyName için geçerli hasar bölgesi yok.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)));
    return Wrap(spacing: 8, runSpacing: 6, children: regions.map((r) => Chip(label: Text(_regionLabel(r)), backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.7), labelStyle: TextStyle(color: theme.colorScheme.onErrorContainer), avatar: Icon(Icons.car_crash_outlined, size: 18, color: theme.colorScheme.onErrorContainer), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)))).toList());
  }
  
  Widget _buildAccidentCircumstancesDisplay(BuildContext context, List<dynamic>? circumstances, String partyName) {
    final theme = Theme.of(context);
    if (circumstances == null || circumstances.isEmpty) return Padding(padding: const EdgeInsets.symmetric(vertical: 8.0), child: Text("$partyName için kaza durumu belirtilmemiş.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)));
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: circumstances.map((c) => Padding(padding: const EdgeInsets.only(top: 2.0), child: Text("• ${c.toString()}", style: theme.textTheme.bodyMedium))).toList());
  }

  Widget _buildPartyInfoSection(BuildContext context, ThemeData theme, Map<String, dynamic> recordData, String rolePrefix, String sectionTitle, IconData sectionIcon) {
    final String? userId = recordData['${rolePrefix}Uid'] as String?;
    final Map<String, dynamic>? vehicleInfo = recordData['${rolePrefix}VehicleInfo'] as Map<String, dynamic>?; // Bu Firestore'dan gelmeli
    final Map<String, dynamic>? userProfileData = recordData['${rolePrefix}UserData'] as Map<String, dynamic>?; // Bu Firestore'dan gelmeli
    
    final String? notes = recordData['${rolePrefix}Notes'] as String?;
    final List<dynamic>? damageRegions = recordData['${rolePrefix}DamageRegions'] as List<dynamic>?;
    final List<dynamic>? kazaDurumlari = recordData['${rolePrefix}KazaDurumlari'] as List<dynamic>?;
    final String? processedPhotoBase64 = recordData['${rolePrefix}ProcessedDamageImageBase64'] as String?;
    final List<dynamic>? detections = recordData['${rolePrefix}DetectionResults'] as List<dynamic>?;
    final Timestamp? submissionTime = recordData['${rolePrefix}LastUpdateTimestamp'] as Timestamp? ?? recordData['${rolePrefix}InfoSubmittedTimestamp'] as Timestamp?;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _buildSectionTitle(context, sectionTitle, sectionIcon, theme.colorScheme.secondary),
        if (userProfileData != null) // Eğer userProfileData recordData içinde varsa doğrudan kullan
             _buildInfoCard( context: context, title: "Sürücü Bilgileri", titleIcon: Icons.person_outline_rounded,
                children: [
                  _buildTextInfoRow(context, "Ad Soyad", '${userProfileData['isim'] ?? ''} ${userProfileData['soyisim'] ?? ''}'.trim(), isBoldValue: true),
                  _buildTextInfoRow(context, "TC Kimlik No", userProfileData['tcNo'] as String?),
                  _buildTextInfoRow(context, "Telefon", userProfileData['telefon'] as String?),
                  _buildTextInfoRow(context, "Sürücü Belge No", userProfileData['driverLicenseNo'] as String?),
                  _buildTextInfoRow(context, "Belge Sınıfı", userProfileData['driverLicenseClass'] as String?),
                  _buildTextInfoRow(context, "Belge Verildiği Yer", userProfileData['driverLicenseIssuePlace'] as String?),
                  _buildTextInfoRow(context, "Adres", userProfileData['address'] as String?),
                ],
              )
        else if (userId != null) // Yoksa Firestore'dan çekmeyi dene
          FutureBuilder<Map<String,dynamic>?>(
            future: _fetchFullUserDetails(userId),
            builder: (context, AsyncSnapshot<Map<String,dynamic>?> userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
              final fetchedUserData = userSnapshot.data;
              return _buildInfoCard( context: context, title: "Sürücü Bilgileri", titleIcon: Icons.person_outline_rounded,
                children: [
                  _buildTextInfoRow(context, "Ad Soyad", '${fetchedUserData?['isim'] ?? ''} ${fetchedUserData?['soyisim'] ?? ''}'.trim(), isBoldValue: true),
                  _buildTextInfoRow(context, "TC Kimlik No", fetchedUserData?['tcNo'] as String?),
                  _buildTextInfoRow(context, "Telefon", fetchedUserData?['telefon'] as String?),
                  _buildTextInfoRow(context, "Sürücü Belge No", fetchedUserData?['driverLicenseNo'] as String?),
                  _buildTextInfoRow(context, "Belge Sınıfı", fetchedUserData?['driverLicenseClass'] as String?),
                  _buildTextInfoRow(context, "Belge Verildiği Yer", fetchedUserData?['driverLicenseIssuePlace'] as String?),
                  _buildTextInfoRow(context, "Adres", fetchedUserData?['address'] as String?),
                ],
              );
            },
          )
        else _buildInfoCard(context: context, title: "Sürücü Bilgileri", children: [const Text("Sürücü bilgisi yok.")]),
        
        const SizedBox(height: 4),
        if (vehicleInfo != null)
            _buildInfoCard( context: context, title: "Araç Bilgileri", titleIcon: Icons.directions_car_outlined,
              children: [
                _buildTextInfoRow(context, "Marka", vehicleInfo['marka']?.toString()),
                _buildTextInfoRow(context, "Model/Seri", vehicleInfo['model']?.toString() ?? vehicleInfo['seri']?.toString()),
                _buildTextInfoRow(context, "Plaka", vehicleInfo['plaka']?.toString(), isBoldValue: true),
                _buildTextInfoRow(context, "Şasi No", vehicleInfo['sasiNo']?.toString()),
                _buildTextInfoRow(context, "Kullanım Şekli", vehicleInfo['kullanim']?.toString()),
                _buildTextInfoRow(context, "Model Yılı", vehicleInfo['modelYili']?.toString()),
                if (vehicleInfo['sigortaSirketi'] != null || vehicleInfo['policeNo'] != null) ...[
                    const Divider(height:16), Text("Trafik Sigortası:", style: theme.textTheme.titleSmall?.copyWith(fontWeight:FontWeight.bold)),
                    _buildTextInfoRow(context, " Sigortalı", vehicleInfo['sigortaliAdiSoyadi']?.toString()),
                    _buildTextInfoRow(context, " Sigortalı TC/Vergi", vehicleInfo['sigortaliTcVergiNo']?.toString()),
                    _buildTextInfoRow(context, " Şirket", vehicleInfo['sigortaSirketi']?.toString()),
                    _buildTextInfoRow(context, " Poliçe No", vehicleInfo['policeNo']?.toString()),
                    _buildTextInfoRow(context, " Acente No", vehicleInfo['acenteNo']?.toString()),
                    _buildTextInfoRow(context, " TRAMER No", vehicleInfo['tramerBelgeNo']?.toString()),
                    _buildTextInfoRow(context, " Başlangıç T.", _formatTimestamp(vehicleInfo['policeBaslangicTarihi'] as Timestamp?, context, format: 'dd.MM.yyyy')),
                    _buildTextInfoRow(context, " Bitiş T.", _formatTimestamp(vehicleInfo['policeBitisTarihi'] as Timestamp?, context, format: 'dd.MM.yyyy')),
                ],
                if (vehicleInfo['yesilKartVar'] == true) ...[
                    const Divider(height:16), Text("Yeşil Kart:", style: theme.textTheme.titleSmall?.copyWith(fontWeight:FontWeight.bold)),
                    _buildTextInfoRow(context, "  No", vehicleInfo['yesilKartNo']?.toString()),
                    _buildTextInfoRow(context, "  Ülke", vehicleInfo['yesilKartUlke']?.toString()),
                    _buildTextInfoRow(context, "  Pasaport No", vehicleInfo['yesilKartPasaportNo']?.toString()),
                ]
              ],
            )
        else
             _buildInfoCard(context: context, title: "Araç Bilgileri", children: [const Text("Bu sürücü için araç bilgisi girilmemiş.", style: TextStyle(fontStyle: FontStyle.italic))]),

        const SizedBox(height: 4),
        _buildInfoCard( context: context, title: "Seçilen Hasar Bölgeleri", titleIcon: Icons.car_crash_outlined, children: [_buildRegionsDisplay(context, damageRegions, sectionTitle)]),
        const SizedBox(height: 4),
        _buildInfoCard( context: context, title: "Kaza Durumları (Beyanı)", titleIcon: Icons.rule_folder_outlined, children: [_buildAccidentCircumstancesDisplay(context, kazaDurumlari, sectionTitle)]),
        const SizedBox(height: 4),
        _buildInfoCard( context: context, title: "Sürücü Notları ve Beyanı", titleIcon: Icons.edit_note_rounded, children: [ Text(notes?.isNotEmpty == true ? notes! : "Eklenmiş bir not/beyan bulunmuyor.", style: theme.textTheme.bodyLarge?.copyWith(fontStyle: notes?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic, height: 1.5))]),
        const SizedBox(height: 4),
        if (processedPhotoBase64 != null) _buildInfoCard( context: context, title: "Hasar Fotoğrafı ve Tespitler", titleIcon: Icons.image_search_rounded, children: [_buildPhotoDisplay(context, processedPhotoBase64, detections, sectionTitle)])
        else _buildInfoCard(context: context, title: "Hasar Fotoğrafı", titleIcon: Icons.image_not_supported_outlined, children: [Text("$sectionTitle için yüklenmiş bir hasar fotoğrafı bulunmuyor.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))]),
        if (submissionTime != null) Padding( padding: const EdgeInsets.only(top: 10.0, right: 8.0, bottom: 8.0), child: Align( alignment: Alignment.centerRight, child: Text("Bilgi Giriş Zamanı: ${_formatTimestamp(submissionTime, context)}", style: theme.textTheme.bodySmall))),
    ]);
  }

  // JSON için veri dönüştürme ve hazırlama
  dynamic _convertValueForJsonRecursive(dynamic value) {
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is LatLng) return {'latitude': value.latitude, 'longitude': value.longitude};
    if (value is CrashRegion) return value.name; // Enum'ı string'e çevir
    if (value is Set) return value.map((e) => _convertValueForJsonRecursive(e)).toList(); // Set'i List'e çevir
    if (value is List) return value.map((item) => _convertValueForJsonRecursive(item)).toList();
    if (value is Map) return value.map((key, val) => MapEntry(key.toString(), _convertValueForJsonRecursive(val)));
    return value;
  }

  Future<Map<String, dynamic>> _prepareDataForPdfGeneration(Map<String, dynamic> currentRecordData) async {
    Map<String, dynamic> dataForPdf = {};

    // Ana recordData'daki tüm alanları dönüştürerek kopyala
    currentRecordData.forEach((key, value) {
      dataForPdf[key] = _convertValueForJsonRecursive(value);
    });

    // Eksik olabilecek veya daha detaylı olması gereken kullanıcı ve araç bilgilerini
    // Firestore'dan çekip `dataForPdf` içine yerleştir.
    // Bu, `ReportSummaryPage`'de Firestore'a ne kadar detaylı veri yazdığınıza bağlıdır.
    // İdealde, `creatorUserData`, `joinerUserData`, `creatorVehicleInfo`, `joinerVehicleInfo`
    // zaten `currentRecordData` içinde tam detaylarıyla bulunmalıdır.

    // Örnek: Creator UserData (Eğer `currentRecordData` içinde yoksa veya eksikse)
    if (currentRecordData['creatorUid'] != null && (dataForPdf['creatorUserData'] == null || !(dataForPdf['creatorUserData'] is Map))) {
      Map<String, dynamic>? creatorDetails = await _fetchFullUserDetails(currentRecordData['creatorUid'] as String?);
      if (creatorDetails != null) {
        dataForPdf['creatorUserData'] = _convertValueForJsonRecursive(creatorDetails);
      }
    }
    // Örnek: Joiner UserData
    if (currentRecordData['joinerUid'] != null && (dataForPdf['joinerUserData'] == null || !(dataForPdf['joinerUserData'] is Map))) {
      Map<String, dynamic>? joinerDetails = await _fetchFullUserDetails(currentRecordData['joinerUid'] as String?);
      if (joinerDetails != null) {
        dataForPdf['joinerUserData'] = _convertValueForJsonRecursive(joinerDetails);
      }
    }
    
    // Örnek: Creator VehicleInfo (Eğer sigorta gibi detaylar eksikse)
    if (currentRecordData['creatorUid'] != null && currentRecordData['creatorVehicleId'] != null && 
        (dataForPdf['creatorVehicleInfo'] == null || !(dataForPdf['creatorVehicleInfo'] is Map) || !(dataForPdf['creatorVehicleInfo'] as Map).containsKey('sigortaSirketi') )) {
        Map<String, dynamic>? creatorVehicleDetails = await _fetchFullVehicleDetails(currentRecordData['creatorUid'] as String?, currentRecordData['creatorVehicleId'] as String?);
        if (creatorVehicleDetails != null) {
            dataForPdf['creatorVehicleInfo'] = _convertValueForJsonRecursive(creatorVehicleDetails);
        }
    }
     // Örnek: Joiner VehicleInfo
    if (currentRecordData['joinerUid'] != null && currentRecordData['joinerVehicleId'] != null && 
        (dataForPdf['joinerVehicleInfo'] == null || !(dataForPdf['joinerVehicleInfo'] is Map) || !(dataForPdf['joinerVehicleInfo'] as Map).containsKey('sigortaSirketi') )) {
        Map<String, dynamic>? joinerVehicleDetails = await _fetchFullVehicleDetails(currentRecordData['joinerUid'] as String?, currentRecordData['joinerVehicleId'] as String?);
        if (joinerVehicleDetails != null) {
            dataForPdf['joinerVehicleInfo'] = _convertValueForJsonRecursive(joinerVehicleDetails);
        }
    }
    return dataForPdf;
  }

  Future<void> _generateAndShowPdf() async {
    if (_recordData == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Rapor verileri henüz yüklenmedi.")));
      return;
    }
    if (!mounted) return;
    setState(() => _isGeneratingPdf = true);

    try {
      Map<String, dynamic> dataToSend = await _prepareDataForPdfGeneration(Map<String, dynamic>.from(_recordData!));
      
      print("Sunucuya gönderilecek PDF verisi (Dönüştürülmüş): ${jsonEncode(dataToSend)}");

      final response = await http.post(
        Uri.parse(_pdfServerBaseUrl + _pdfGenerationEndpoint),
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(dataToSend),
      ).timeout(const Duration(seconds: 120));

      if (!mounted) return;

      if (response.statusCode == 200) {
        final contentType = response.headers['content-type'];
        if (contentType?.startsWith('application/pdf') ?? false) {
            final Uint8List pdfBytes = response.bodyBytes;
            final directory = await getTemporaryDirectory();
            final filePath = '${directory.path}/kaza_raporu_${widget.recordId}.pdf';
            final file = File(filePath);
            await file.writeAsBytes(pdfBytes);

            if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF başarıyla oluşturuldu: $filePath"), duration: const Duration(seconds: 3)));
            Navigator.push(
                context,
                MaterialPageRoute(
                builder: (context) => PdfViewerPage(
                    pdfPath: filePath, 
                    title: "Kaza Tespit Tutanağı"),
                ),
            );
            }
        } else {
            final responseBody = response.body;
            String errorMessage = "Sunucudan PDF yerine beklenmedik bir yanıt alındı ($contentType).";
             try {
                final decodedResponse = json.decode(responseBody);
                if (decodedResponse is Map && decodedResponse.containsKey('pdf_url')) {
                    String pdfUrlFromServer = decodedResponse['pdf_url'];
                     if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("PDF URL'i alındı, görüntüleniyor..."), duration: Duration(seconds: 2)));
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                            builder: (context) => PdfViewerPage(
                                pdfUrl: pdfUrlFromServer, 
                                title: "Kaza Tespit Tutanağı"),
                            ),
                        );
                     }
                     if (mounted) setState(() => _isGeneratingPdf = false);
                     return; 
                } else if (decodedResponse is Map && (decodedResponse.containsKey('error') || decodedResponse.containsKey('message'))) {
                    errorMessage += " Sunucu: ${decodedResponse['error'] ?? decodedResponse['message']}";
                } else {
                    errorMessage += " Yanıt: ${responseBody.characters.take(100)}...";
                }
            } catch (e) {
                 errorMessage += " Yanıt: ${responseBody.characters.take(100)}...";
            }
            throw Exception(errorMessage);
        }
      } else {
        String errorMessage = "PDF oluşturulamadı. Sunucu hatası: ${response.statusCode}";
        try {
            final errorData = json.decode(response.body);
            if (errorData['error'] != null) errorMessage += " - ${errorData['error']}";
            else if (errorData['message'] != null) errorMessage += " - ${errorData['message']}";
        } catch (_) {
             errorMessage += "\nYanıt: ${response.body.characters.take(200)}...";
        }
        print("PDF Oluşturma Hatası: $errorMessage");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorMessage, style: const TextStyle(color: Colors.white)), backgroundColor: Colors.red, duration: const Duration(seconds: 7),));
      }
    } catch (e, s) {
      if (!mounted) return;
      print("PDF oluşturma/gösterme sırasında genel hata: $e\n$s");
      String displayError = e.toString();
      if (displayError.contains("Converting object to an encodable object failed")) {
          displayError = "Veri formatlama hatası. Lütfen geliştiriciye bildirin.";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("PDF oluşturulurken bir hata oluştu: $displayError")));
    } finally {
      if (mounted) setState(() => _isGeneratingPdf = false);
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
               if (!snapshot.hasData || snapshot.data?.data() == null) return const SizedBox.shrink();
               final currentRecordData = snapshot.data!.data()!;
               final String? pdfUrlFromRecord = currentRecordData['pdfUrl'] as String?;
               final String status = currentRecordData['status'] as String? ?? "Bilinmiyor";

               if (status == 'all_data_submitted' || pdfUrlFromRecord != null )
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
          
          final String? pdfUrlFromRecord = _recordData!['pdfUrl'] as String?;
          final String status = _recordData!['status'] as String? ?? "Bilinmiyor";
          final Timestamp? createdAt = _recordData!['createdAt'] as Timestamp?;
          final Timestamp? kazaTimestampForDisplay = _recordData!['kazaTimestamp'] as Timestamp?;
          final Timestamp? finalizedAt = _recordData!['reportFinalizedTimestamp'] as Timestamp?;
          final LatLng? accidentLocation = (_recordData!['latitude'] != null && _recordData!['longitude'] != null)
              ? LatLng(_recordData!['latitude'] as double, _recordData!['longitude'] as double)
              : null;
          
          String? formattedAddressFromFirestore = _recordData!['formattedAddress'] as String?;
          if (formattedAddressFromFirestore == null && accidentLocation != null && _address == null && !_isFetchingAddress && mounted) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                 if(mounted) _fetchAddressFromLatLng(accidentLocation.latitude, accidentLocation.longitude);
             });
          } else if (formattedAddressFromFirestore != null && (_address == null || _address != formattedAddressFromFirestore) && mounted) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if(mounted) setState(() => _address = formattedAddressFromFirestore);
            });
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(
                  context: context, title: "Genel Tutanak Bilgileri", titleIcon: Icons.article_outlined,
                  titleColor: theme.colorScheme.onSurface, cardColor: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                  children: [
                    _buildTextInfoRow(context, "Tutanak ID", widget.recordId, isBoldValue: true),
                    _buildTextInfoRow(context, "Durum", status, isBoldValue: true),
                    _buildTextInfoRow(context, "Kaza Tarihi", _formatTimestamp(kazaTimestampForDisplay, context)),
                    if (createdAt != null) _buildTextInfoRow(context, "Oluşturulma T.", _formatTimestamp(createdAt, context)),
                    if (finalizedAt != null) _buildTextInfoRow(context, "Tamamlanma T.", _formatTimestamp(finalizedAt, context)),
                  ]
                ),

                if (status == 'all_data_submitted' || pdfUrlFromRecord != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      child: ElevatedButton.icon(
                        icon: _isGeneratingPdf 
                            ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2)) 
                            : Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.onPrimary),
                        label: Text(
                            _isGeneratingPdf ? "PDF OLUŞTURULUYOR..." : (pdfUrlFromRecord != null ? "KAYITLI PDF'İ GÖRÜNTÜLE" : "TUTANAK PDF'İNİ OLUŞTUR"),
                            style: TextStyle(color: theme.colorScheme.onPrimary)
                        ),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: pdfUrlFromRecord != null ? theme.colorScheme.secondary : theme.colorScheme.primary,
                            minimumSize: const Size(double.infinity, 48)
                        ),
                        onPressed: _isGeneratingPdf ? null : () {
                           if (pdfUrlFromRecord != null) {
                                Navigator.push(context, MaterialPageRoute(builder: (context) => 
                                PdfViewerPage(pdfUrl: pdfUrlFromRecord, title: "Kaza Tespit Tutanağı")
                                ));
                            } else {
                                _generateAndShowPdf();
                            }
                        },
                      ),
                    ),

                _buildInfoCard(
                    context: context, title: "Kaza Yeri Detayları", titleIcon: Icons.map_rounded,
                    titleColor: theme.colorScheme.onSurface, cardColor: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                    children: [
                      if (accidentLocation != null) SizedBox( height: 220,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(target: accidentLocation, zoom: 16.5),
                          markers: {Marker(markerId: MarkerId(widget.recordId), position: accidentLocation, infoWindow: const InfoWindow(title: "Kaza Yeri"))},
                          scrollGesturesEnabled: true, zoomGesturesEnabled: true, mapToolbarEnabled: true,
                        ),
                      ),
                       const SizedBox(height: 10),
                       _buildAddressInfoWidget(_recordData!),
                    ]
                  ),
                
                if (_recordData!['taniklar'] != null && (_recordData!['taniklar'] as List).isNotEmpty) ...[
                    _buildSectionTitle(context, "Görgü Tanıkları", Icons.visibility_outlined, theme.colorScheme.tertiary),
                    ...(_recordData!['taniklar'] as List).map((tanik) {
                        final tanikMap = tanik as Map<String, dynamic>;
                        return _buildInfoCard(context: context, title: "Tanık: ${tanikMap['adiSoyadi'] ?? 'Bilinmiyor'}", 
                        titleIcon: Icons.person_search_outlined,
                        titleColor: theme.colorScheme.tertiary,
                        children: [
                           _buildTextInfoRow(context, "Adres", tanikMap['adresi']?.toString()),
                           _buildTextInfoRow(context, "Telefon", tanikMap['telefonu']?.toString()),
                        ]);
                    }).toList(),
                ],
                const SizedBox(height: 10),

                _buildPartyInfoSection(context, theme, _recordData!, "creator", "Tutanak Oluşturan Taraf", Icons.person_pin_circle_rounded),
                const SizedBox(height: 10),
                Divider(thickness: 1, color: theme.dividerColor.withOpacity(0.6), height: 30, indent: 20, endIndent: 20),
                const SizedBox(height: 10),
                _buildPartyInfoSection(context, theme, _recordData!, "joiner", "Tutanağa Katılan Taraf", Icons.group_rounded),
                
                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}