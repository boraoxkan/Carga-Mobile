// lib/screens/report_summary_page.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path; // path.basename için
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // MediaType için
import 'package:tutanak/models/crash_region.dart';

class ReportSummaryPage extends StatefulWidget {
  final Set<CrashRegion> selectedRegions;
  final Map<String, String> vehicleInfo; // Kendi aracının bilgileri
  final LatLng confirmedPosition;
  final String recordId;
  final bool isCreator;

  const ReportSummaryPage({
    Key? key,
    required this.selectedRegions,
    required this.vehicleInfo,
    required this.confirmedPosition,
    required this.recordId,
    required this.isCreator,
  }) : super(key: key);

  @override
  _ReportSummaryPageState createState() => _ReportSummaryPageState();
}

class _ReportSummaryPageState extends State<ReportSummaryPage> {
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  
  XFile? _selectedImageFileForUbuntu; // Ubuntu sunucusu için seçilen tek fotoğraf
  // List<XFile> _selectedImageFilesForFirebase = []; // Firebase Storage için (şimdilik kullanılmıyor)
  
  // List<String> _firebaseStorageUploadedImageUrls = []; // Firebase için (şimdilik kullanılmıyor)
  
  Uint8List? _processedImageBytesFromUbuntu;
  List<dynamic>? _detectionResultsFromUbuntu; 

  bool _isProcessingAndSaving = false; // Genel kaydetme/işleme durumu

  // Karşı taraf verileri
  Map<String, dynamic>? _otherPartyUserData;
  Map<String, dynamic>? _otherPartyVehicleData;
  Set<CrashRegion> _otherPartySelectedRegions = {};
  List<String> _otherPartyFirebaseStorageImageUrls = []; // Karşı taraf Firebase Storage kullandıysa
  String? _otherPartyProcessedImageBase64FromUbuntu; // Karşı taraf Ubuntu sunucusu kullandıysa
  List<dynamic>? _otherPartyDetectionResultsFromUbuntu;
  bool _isLoadingOtherPartyData = true;

  // Ubuntu sunucu adresi (güvenlik için bu tür adresler konfigürasyon dosyasında tutulmalı)
  final String _ubuntuServerUrl = "http://100.71.209.113:5001/process_damage_image"; 
  // Mevcut kodunuzda bu false, yani Ubuntu sunucusu kullanılıyor.
  final bool _useFirebaseStorageForOwnPhotos = false; 

  @override
  void initState() {
    super.initState();
    _fetchOtherPartyData();
  }

  Future<void> _fetchOtherPartyData() async {
    // ... (Bu metot öncekiyle aynı kalabilir, sadece alan adlarını kontrol edin) ...
    // Önemli: Firestore'dan veri çekerken kullanılan alan adlarının
    // (örn: 'joinerDamageRegions', 'creatorProcessedDamageImageBase64')
    // _saveReportDataToFirestore metodunda kullanılanlarla tutarlı olduğundan emin olun.
     if (!mounted) return;
    setState(() { _isLoadingOtherPartyData = true; });
    try {
      final recordDoc = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
      if (!recordDoc.exists || recordDoc.data() == null) {
        if (mounted) setState(() => _isLoadingOtherPartyData = false);
        return;
      }
      final recordData = recordDoc.data()!;
      String otherPartyRolePrefix = widget.isCreator ? "joiner" : "creator";
      String ownRolePrefix = widget.isCreator ? "creator" : "joiner"; // Kendi rolümüzü de bilelim

      // Karşı tarafın kullanıcı ve araç bilgileri (RecordConfirmationPage'de eklendiğini varsayıyoruz)
      final String? otherPartyUid = recordData['${otherPartyRolePrefix}Uid'] as String?;
      if (otherPartyUid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherPartyUid).get();
        if (userDoc.exists && mounted) {
           setState(() => _otherPartyUserData = userDoc.data());
        }
        // Karşı tarafın araç bilgisi genellikle 'records' dokümanına doğrudan yazılır.
        if (recordData.containsKey('${otherPartyRolePrefix}VehicleInfo') && mounted) {
            setState(()=> _otherPartyVehicleData = recordData['${otherPartyRolePrefix}VehicleInfo'] as Map<String, dynamic>?);
        } else { // Eğer vehicleId üzerinden çekmek gerekirse (daha karmaşık)
            final String? otherPartyVehicleId = recordData['${otherPartyRolePrefix}VehicleId'] as String?;
            if (otherPartyVehicleId != null) {
                final vehicleDoc = await FirebaseFirestore.instance.collection('users').doc(otherPartyUid).collection('vehicles').doc(otherPartyVehicleId).get();
                if(vehicleDoc.exists && mounted) {
                    setState(() => _otherPartyVehicleData = vehicleDoc.data());
                }
            }
        }
      }
      
      // Karşı tarafın hasar bölgeleri
      final otherPartyRegionsFieldName = '${otherPartyRolePrefix}DamageRegions';
      if (recordData.containsKey(otherPartyRegionsFieldName) && recordData[otherPartyRegionsFieldName] is List) {
        List<dynamic> regionsData = recordData[otherPartyRegionsFieldName];
        if (mounted) {
          setState(() {
            _otherPartySelectedRegions = regionsData
                .map((regionString) {
                  try { return CrashRegion.values.byName(regionString.toString().split('.').last); } // Enum adını doğru parse et
                  catch (e) { print("Enum parse error: $regionString, $e"); return null; }
                })
                .whereType<CrashRegion>().toSet();
          });
        }
      }
      
      // Karşı tarafın Ubuntu ile işlenmiş fotoğrafı ve tespitleri
      final otherPartyProcessedBase64FieldName = '${otherPartyRolePrefix}ProcessedDamageImageBase64';
      if (recordData.containsKey(otherPartyProcessedBase64FieldName) && recordData[otherPartyProcessedBase64FieldName] is String && mounted) {
          setState(() => _otherPartyProcessedImageBase64FromUbuntu = recordData[otherPartyProcessedBase64FieldName] as String?);
      }
      final otherPartyDetectionsFieldName = '${otherPartyRolePrefix}DetectionResults';
       if (recordData.containsKey(otherPartyDetectionsFieldName) && recordData[otherPartyDetectionsFieldName] is List && mounted) {
          setState(() => _otherPartyDetectionResultsFromUbuntu = recordData[otherPartyDetectionsFieldName] as List<dynamic>?);
      }

      // Karşı tarafın Firebase Storage'a yüklediği fotoğraflar (eğer bu senaryo varsa)
      // final otherPartyFsPhotosFieldName = '${otherPartyRolePrefix}DamagePhotos'; // Eğer Firebase Storage da kullanılıyorsa
      // if (recordData.containsKey(otherPartyFsPhotosFieldName) && recordData[otherPartyFsPhotosFieldName] is List && mounted) {
      //     setState(() => _otherPartyFirebaseStorageImageUrls = List<String>.from(recordData[otherPartyFsPhotosFieldName]));
      // }

    } catch (e,s) {
      print("Karşı taraf verileri çekilirken hata (report_summary_page): $e \n$s");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Karşı taraf verileri yüklenemedi: $e")));
    } finally {
      if (mounted) setState(() { _isLoadingOtherPartyData = false; });
    }
  }


  Future<void> _saveReportDataToFirestore({
    // List<String>? firebaseStorageUrls, // Şimdilik kullanılmıyor
    String? processedImageBase64ForUbuntu,
    List<dynamic>? detectionsForUbuntu,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("Kullanıcı girişi yapılmamış.");
    }

    final String userRolePrefix = widget.isCreator ? "creator" : "joiner";
    Map<String, dynamic> dataToSave = {
      '${userRolePrefix}Uid': currentUser.uid, // Kimin bilgi girdiğini belirt
      '${userRolePrefix}VehicleInfo': widget.vehicleInfo, // Kendi aracının bilgileri (marka, model, plaka vb.)
      '${userRolePrefix}Notes': _notesController.text.trim(),
      '${userRolePrefix}DamageRegions': widget.selectedRegions.map((r) => r.name).toList(), // Enum'ın adını kaydet
      '${userRolePrefix}LastUpdateTimestamp': FieldValue.serverTimestamp(),
    };

    // if (firebaseStorageUrls != null && firebaseStorageUrls.isNotEmpty) {
    //   dataToSave['${userRolePrefix}DamagePhotos'] = firebaseStorageUrls;
    // }

    if (processedImageBase64ForUbuntu != null) {
      dataToSave['${userRolePrefix}ProcessedDamageImageBase64'] = processedImageBase64ForUbuntu;
    }
    if (detectionsForUbuntu != null) {
      dataToSave['${userRolePrefix}DetectionResults'] = detectionsForUbuntu;
    }

    // Konum bilgisi genellikle bir kez, oluşturan tarafından veya her iki tarafın onayıyla eklenir.
    // Şimdilik, oluşturan tarafın eklediğini varsayıyoruz.
    if (widget.isCreator) {
      final recordDocSnapshot = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
      if (!recordDocSnapshot.exists || recordDocSnapshot.data()?['latitude'] == null) { // Sadece daha önce eklenmemişse
        dataToSave['latitude'] = widget.confirmedPosition.latitude;
        dataToSave['longitude'] = widget.confirmedPosition.longitude;
        dataToSave['locationSetTimestamp'] = FieldValue.serverTimestamp();
      }
    }
    
    // Durum güncellemesi: Her iki taraf da kendi bilgilerini gönderdiğinde
    // tutanağın durumu "tamamlandı" veya "PDF oluşturuluyor" gibi bir şeye güncellenebilir.
    // Bu mantık, her iki tarafın da bilgi gönderip göndermediğini kontrol ederek yapılmalı.
    // Şimdilik, her kullanıcının kendi bilgilerini gönderdiğini belirten bir durum ekleyelim.
    dataToSave['status'] = widget.isCreator ? 'creator_info_submitted' : 'joiner_info_submitted';
    
    // Eğer bu işlem sonrası her iki taraf da bilgi göndermişse, durumu 'all_data_submitted' yap
    final currentRecordData = (await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get()).data();
    bool creatorSubmitted = widget.isCreator || (currentRecordData?['status'] == 'creator_info_submitted' || currentRecordData?['status'] == 'all_data_submitted');
    bool joinerSubmitted = !widget.isCreator || (currentRecordData?['status'] == 'joiner_info_submitted' || currentRecordData?['status'] == 'all_data_submitted');

    if(creatorSubmitted && joinerSubmitted){
        dataToSave['status'] = 'all_data_submitted';
        dataToSave['reportFinalizedTimestamp'] = FieldValue.serverTimestamp();
    }


    await FirebaseFirestore.instance
        .collection('records')
        .doc(widget.recordId)
        .set(dataToSave, SetOptions(merge: true));
  }

  // Fotoğraf seçme (Ubuntu için tek, Firebase için çoklu olabilir)
  Future<void> _pickImageForUbuntu() async {
     // ... (Önceki _pickImage metodu ile benzer, sadece _selectedImageFileForUbuntu'yu set eder) ...
     try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, // Veya kameradan seçenek sun
        imageQuality: 60, 
        maxWidth: 800, 
      );
      if (pickedFile != null && mounted) {
        setState(() {
            _selectedImageFileForUbuntu = pickedFile; 
            _processedImageBytesFromUbuntu = null; // Önceki işlenmiş resmi temizle
            _detectionResultsFromUbuntu = null;   // Önceki tespitleri temizle
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fotoğraf seçilirken bir hata oluştu: $e')));
    }
  }

  // Ubuntu sunucusuna gönderme ve Firestore'a kaydetme
  Future<void> _processWithUbuntuServerAndSave() async {
    // ... (Bu metot öncekiyle aynı, sadece _selectedImageFileForUbuntu'yu kullanır) ...
    // ... ve başarılı olursa _saveReportDataToFirestore'u çağırır ...
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _selectedImageFileForUbuntu == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın ve fotoğraf seçin.')));
      return;
    }
    if (mounted) setState(() => _isProcessingAndSaving = true);
    try {
      File file = File(_selectedImageFileForUbuntu!.path);
      var request = http.MultipartRequest('POST', Uri.parse(_ubuntuServerUrl));
      request.files.add(await http.MultipartFile.fromPath(
        'image', file.path,
        contentType: MediaType('image', path.extension(file.path).replaceAll('.', '')),
      ));
      request.fields['record_id'] = widget.recordId;
      request.fields['user_id'] = currentUser.uid;

      var streamedResponse = await request.send().timeout(const Duration(seconds: 90)); // Timeout artırıldı
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final String? imageBase64 = responseData['processed_image_base64'];
        final List<dynamic>? detections = responseData['detections'] as List<dynamic>?;

        if (imageBase64 != null && mounted) {
          setState(() {
              _processedImageBytesFromUbuntu = base64Decode(imageBase64);
              _detectionResultsFromUbuntu = detections;
          });
          await _saveReportDataToFirestore(
              processedImageBase64ForUbuntu: imageBase64,
              detectionsForUbuntu: detections
          );
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf işlendi ve tutanak bilgileri kaydedildi!')));
              Navigator.popUntil(context, (route) => route.isFirst); // Ana sayfaya dön
          }
        } else {
            throw Exception("Sunucudan işlenmiş fotoğraf alınamadı.");
        }
    } else {
        String errorMessage = "Sunucu Hatası (${response.statusCode}): ${response.reasonPhrase}.";
        try {
            final errorData = json.decode(response.body);
            if (errorData['error'] != null) errorMessage += " Detay: ${errorData['error']}";
        } catch (_) { errorMessage += " Detay: ${response.body}";}
        throw Exception(errorMessage);
    }
    } catch (e, s) {
      print("Ubuntu sunucu ile fotoğraf işleme/kaydetme hatası: $e\n$s");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Hata: $e')));
    } finally {
      if (mounted) setState(() => _isProcessingAndSaving = false);
    }
  }

  // Genel gönderme butonu işlevi
  Future<void> _handleReportSubmission() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın.')));
      return;
    }
    // En az bir bilgi girilmiş olmalı (hasar bölgesi, not veya fotoğraf)
    if (widget.selectedRegions.isEmpty && _notesController.text.trim().isEmpty && _selectedImageFileForUbuntu == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen hasar bölgesi, fotoğraf veya not gibi en az bir bilgi girin.')));
        return;
    }
    
    if (mounted) setState(() => _isProcessingAndSaving = true);

    try {
      if (!_useFirebaseStorageForOwnPhotos) { // Ubuntu sunucusu akışı
          if (_selectedImageFileForUbuntu != null) { // Fotoğraf varsa işle ve kaydet
              await _processWithUbuntuServerAndSave(); 
          } else { // Sadece notlar ve bölgeler varsa doğrudan kaydet
              await _saveReportDataToFirestore(); 
              if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tutanak bilgileriniz (fotoğrafsız) kaydedildi.')));
                  Navigator.popUntil(context, (route) => route.isFirst);
              }
          }
      } else {
          // Firebase Storage akışı (şimdilik aktif değil)
          // await _uploadToFirebaseStorageAndSave(); 
          // Bu metodun da içinde _saveReportDataToFirestore çağrısı olmalı.
          // Şimdilik sadece notları ve bölgeleri kaydedelim (fotoğrafsız Firebase akışı)
          await _saveReportDataToFirestore();
           if(mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tutanak bilgileriniz (Firebase - fotoğrafsız) kaydedildi.')));
              Navigator.popUntil(context, (route) => route.isFirst);
          }
      }
    } catch (e,s) {
        print("Rapor gönderiminde genel hata (_handleReportSubmission): $e\n$s");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapor gönderilirken bir hata oluştu: $e')));
    } finally {
        if(mounted && _isProcessingAndSaving) { // Hata olsa bile veya işlem bitince
           setState(() => _isProcessingAndSaving = false);
        }
    }
  }
  
  // --- UI Yardımcı Metotları ---
  Widget _buildSectionHeader(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Text(title, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
      required String title,
      IconData? titleIcon,
      required List<Widget> children,
      EdgeInsetsGeometry? padding,
      Color? cardColor,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2, // Temadan gelecek ama gerekirse ayarlanabilir
      color: cardColor, // Varsayılan olarak tema kart rengi
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)), // Temadan gelecek
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, color: theme.colorScheme.secondary, size: 22),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 0.5),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextInfoRow(String label, String? value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text('$label:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Expanded(flex: 3, child: Text(value ?? '-', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildRegionsDisplay(Set<CrashRegion> regions, {bool isOwn = true}) {
    final theme = Theme.of(context);
    if (regions.isEmpty) {
      return Text(isOwn ? 'Hasar bölgesi seçilmedi.' : 'Karşı taraf hasar bölgesi belirtmemiş.', style: const TextStyle(fontStyle: FontStyle.italic));
    }
    return Wrap(
      spacing: 8,
      runSpacing: 6,
      children: regions.map((r) => Chip(
        label: Text(_regionLabel(r)),
        backgroundColor: isOwn ? theme.colorScheme.errorContainer.withOpacity(0.7) : theme.colorScheme.tertiaryContainer.withOpacity(0.7),
        labelStyle: TextStyle(color: isOwn ? theme.colorScheme.onErrorContainer : theme.colorScheme.onTertiaryContainer),
        avatar: Icon(Icons.car_crash_outlined, size: 18, color: isOwn ? theme.colorScheme.onErrorContainer : theme.colorScheme.onTertiaryContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )).toList(),
    );
  }

  String _regionLabel(CrashRegion region) {
    // ... (öncekiyle aynı) ...
    switch (region) {
      case CrashRegion.frontLeft:   return 'Ön Sol';
      case CrashRegion.frontCenter: return 'Ön Orta';
      case CrashRegion.frontRight:  return 'Ön Sağ';
      case CrashRegion.left:        return 'Sol Taraf';
      case CrashRegion.right:       return 'Sağ Taraf';
      case CrashRegion.rearLeft:    return 'Arka Sol';
      case CrashRegion.rearCenter:  return 'Arka Orta';
      case CrashRegion.rearRight:   return 'Arka Sağ';
      default: return region.name;
    }
  }

  Widget _buildPhotoSelectionAndDisplayUI() {
    final theme = Theme.of(context);
    // Sadece Ubuntu sunucusu akışını ele alıyoruz (_useFirebaseStorageForOwnPhotos = false varsayımıyla)
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hasarlı Araç Fotoğrafınız (1 Adet)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Bu fotoğraf sunucuda işlenerek hasar tespiti yapılmaya çalışılacaktır.', style: theme.textTheme.bodySmall),
        const SizedBox(height: 12),

        if (_processedImageBytesFromUbuntu != null)
          _buildInfoCard(
            title: "İşlenmiş Hasar Fotoğrafı",
            titleIcon: Icons.auto_fix_high_rounded,
            children: [
              Center(child: Image.memory(_processedImageBytesFromUbuntu!, fit: BoxFit.contain, height: 200)),
              if (_detectionResultsFromUbuntu != null && _detectionResultsFromUbuntu!.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text("Tespit Edilenler:", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ..._detectionResultsFromUbuntu!.map((d) {
                  final detectionMap = d as Map<String, dynamic>;
                  return Padding(
                    padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                    child: Text("• ${detectionMap['label'] ?? 'Bilinmiyor'} (%${((detectionMap['confidence'] ?? 0.0) * 100).toStringAsFixed(0)})"),
                  );
                }).toList(),
              ],
              const SizedBox(height: 12),
              Center(
                child: TextButton.icon(
                  icon: Icon(Icons.change_circle_outlined, color: theme.colorScheme.secondary),
                  label: Text("Farklı Fotoğraf Seç", style: TextStyle(color: theme.colorScheme.secondary)),
                  onPressed: _isProcessingAndSaving ? null : _pickImageForUbuntu,
                ),
              ),
            ]
          ),
        
        if (_processedImageBytesFromUbuntu == null && _selectedImageFileForUbuntu != null)
          _buildInfoCard(
            title: "Seçilen Fotoğraf (İşlenecek)",
            titleIcon: Icons.photo_camera_back_outlined,
            children: [
              Stack(
                alignment: Alignment.topRight,
                children: [
                  Center(child: Image.file(File(_selectedImageFileForUbuntu!.path), fit: BoxFit.contain, height: 200)),
                  IconButton(
                    icon: Icon(Icons.cancel_rounded, color: theme.colorScheme.error.withOpacity(0.8)),
                    onPressed: () => setState(() => _selectedImageFileForUbuntu = null),
                    tooltip: "Seçimi Kaldır",
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Center(child: Text("Bu fotoğraf, gönderildiğinde sunucuda işlenecektir.", textAlign: TextAlign.center, style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic))),
            ]
          ),

        if (_processedImageBytesFromUbuntu == null && _selectedImageFileForUbuntu == null)
          Center(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.add_a_photo_outlined),
              label: const Text('Hasar Fotoğrafı Yükle'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                // side: BorderSide(color: theme.colorScheme.primary), // Tema'dan gelecek
              ),
              onPressed: _isProcessingAndSaving ? null : _pickImageForUbuntu,
            ),
          ),
      ],
    );
  }

  Widget _buildOtherPartyPhotoDisplay(ThemeData theme) {
    // Karşı tarafın Ubuntu ile işlenmiş fotoğrafı
    if (_otherPartyProcessedImageBase64FromUbuntu != null) {
      try {
        final Uint8List imageBytes = base64Decode(_otherPartyProcessedImageBase64FromUbuntu!);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Image.memory(imageBytes, height: 180, fit: BoxFit.contain)),
            if (_otherPartyDetectionResultsFromUbuntu != null && _otherPartyDetectionResultsFromUbuntu!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text("Tespitler:", style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
              ..._otherPartyDetectionResultsFromUbuntu!.map((d) {
                final detectionMap = d as Map<String, dynamic>;
                return Padding(
                  padding: const EdgeInsets.only(left: 8.0, top: 2.0),
                  child: Text("• ${detectionMap['label'] ?? 'Bilinmiyor'} (%${((detectionMap['confidence'] ?? 0.0) * 100).toStringAsFixed(0)})")
                );
              }).toList(),
            ]
          ],
        );
      } catch (e) {
        print("Karşı taraf fotoğrafını decode etme hatası: $e");
        return const Text("Fotoğraf görüntülenemedi.", style: TextStyle(color: Colors.red));
      }
    }
    // Karşı tarafın Firebase'e yüklediği orijinal fotoğraflar (eğer bu akış varsa)
    if (_otherPartyFirebaseStorageImageUrls.isNotEmpty) {
      return GridView.builder(
          shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
          itemCount: _otherPartyFirebaseStorageImageUrls.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 6, mainAxisSpacing: 6),
          itemBuilder: (context, index) {
              return InkWell( 
                onTap: () { /* TODO: Fotoğrafı büyütme implementasyonu */ },
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8.0),
                  child: Image.network(
                    _otherPartyFirebaseStorageImageUrls[index], 
                    fit: BoxFit.cover,
                    loadingBuilder: (context, child, progress) => progress == null ? child : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                    errorBuilder: (context, error, stack) => const Icon(Icons.broken_image_outlined, size: 40),
                  )
                )
              );
          },
      );
    }
    return const Text('Karşı taraf henüz fotoğraf eklememiş veya fotoğraf türü desteklenmiyor.', style: TextStyle(fontStyle: FontStyle.italic));
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutanak Özeti ve Onay'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // Buton için altta boşluk
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // --- SİZİN BİLGİLERİNİZ BÖLÜMÜ ---
            _buildSectionHeader(context, "SİZİN BİLGİLERİNİZ", Icons.person_pin_rounded),
            _buildInfoCard(
              title: "Araç Bilgileriniz",
              titleIcon: Icons.directions_car_filled_rounded,
              children: [
                _buildTextInfoRow('Marka', widget.vehicleInfo['brand']),
                _buildTextInfoRow('Model', widget.vehicleInfo['model']),
                _buildTextInfoRow('Plaka', widget.vehicleInfo['plate']),
              ]
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: "Seçtiğiniz Hasar Bölgeleri",
              titleIcon: Icons.car_crash_rounded,
              children: [_buildRegionsDisplay(widget.selectedRegions, isOwn: true)]
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              title: "Hasar Fotoğrafı ve Notlar",
              titleIcon: Icons.camera_alt_rounded,
              children: [
                _buildPhotoSelectionAndDisplayUI(),
                const SizedBox(height: 20),
                Text('Ek Notlarınız:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                TextField(
                  controller: _notesController,
                  maxLines: 4,
                  minLines: 2,
                  decoration: InputDecoration( // Stil temadan gelecek
                    hintText: 'Kaza ile ilgili eklemek istediğiniz detaylar, beyanınız...',
                  ),
                ),
              ]
            ),

            // --- KARŞI TARAFIN BİLGİLERİ BÖLÜMÜ ---
            _buildSectionHeader(context, "KARŞI TARAFIN BİLGİLERİ", Icons.people_alt_rounded),
            _isLoadingOtherPartyData
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator()))
              : (_otherPartyUserData == null && _otherPartyVehicleData == null && _otherPartySelectedRegions.isEmpty && _otherPartyProcessedImageBase64FromUbuntu == null && _otherPartyFirebaseStorageImageUrls.isEmpty)
                  ? _buildInfoCard(title: "Diğer Sürücü Bilgileri", children: [const Text('Karşı taraf henüz bilgi girişi yapmamış veya bilgiler alınamadı.', style: TextStyle(fontStyle: FontStyle.italic))])
                  : Column(children: [
                      if (_otherPartyUserData != null)
                        _buildInfoCard(
                          title: 'Diğer Sürücü',
                          titleIcon: Icons.person_outline_rounded,
                          children: [
                            _buildTextInfoRow('Ad Soyad', '${_otherPartyUserData!['isim'] ?? ''} ${_otherPartyUserData!['soyisim'] ?? ''}'.trim()),
                            _buildTextInfoRow('Telefon', _otherPartyUserData!['telefon'] as String?),
                        ]),
                      const SizedBox(height: 12),
                      if (_otherPartyVehicleData != null)
                        _buildInfoCard(
                          title: 'Diğer Sürücünün Aracı',
                          titleIcon: Icons.directions_car_outlined,
                          children: [
                            _buildTextInfoRow('Marka', _otherPartyVehicleData!['brand'] ?? _otherPartyVehicleData!['marka'] as String?),
                            _buildTextInfoRow('Model', _otherPartyVehicleData!['model'] ?? _otherPartyVehicleData!['seri'] as String?),
                            _buildTextInfoRow('Plaka', _otherPartyVehicleData!['plate'] ?? _otherPartyVehicleData!['plaka'] as String?),
                        ]),
                      const SizedBox(height: 12),
                      _buildInfoCard(
                        title: 'Diğer Sürücünün Seçtiği Hasar Bölge(leri)',
                        titleIcon: Icons.car_crash_outlined,
                        children: [_buildRegionsDisplay(_otherPartySelectedRegions, isOwn: false)],
                      ),
                      const SizedBox(height: 12),
                       _buildInfoCard(
                        title: 'Diğer Sürücünün Notları',
                        titleIcon: Icons.notes_rounded,
                        children: [Text(_otherPartyUserData?['${widget.isCreator ? "joiner" : "creator"}Notes']?.toString() ?? 'Karşı taraf not eklememiş.', style: const TextStyle(fontStyle: FontStyle.italic))],
                      ),
                      const SizedBox(height: 12),
                      if (_otherPartyProcessedImageBase64FromUbuntu != null || _otherPartyFirebaseStorageImageUrls.isNotEmpty)
                        _buildInfoCard(
                          title: 'Diğer Sürücünün Hasar Fotoğraf(lar)ı',
                          titleIcon: Icons.image_search_rounded,
                          children: [_buildOtherPartyPhotoDisplay(theme)],
                        ),
                  ]),
            
            // --- ORTAK BİLGİLER BÖLÜMÜ ---
            _buildSectionHeader(context, "ORTAK BİLGİLER", Icons.map_rounded),
            _buildInfoCard(
              title: 'Onaylanan Kaza Konumu',
              titleIcon: Icons.location_on_rounded,
              children: [
                  SizedBox(
                    height: 180, // Harita yüksekliği artırıldı
                    child: AbsorbPointer(
                      child: GoogleMap(
                        initialCameraPosition: CameraPosition(target: widget.confirmedPosition, zoom: 16.5),
                        markers: {Marker(markerId: const MarkerId('accidentLocation'), position: widget.confirmedPosition, infoWindow: const InfoWindow(title: "Kaza Yeri"))},
                        scrollGesturesEnabled: false, zoomGesturesEnabled: false, rotateGesturesEnabled: false, tiltGesturesEnabled: false, mapToolbarEnabled: false,
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildTextInfoRow('Enlem', widget.confirmedPosition.latitude.toStringAsFixed(6)),
                  _buildTextInfoRow('Boylam', widget.confirmedPosition.longitude.toStringAsFixed(6)),
             ]),
            const SizedBox(height: 32),
          ],
        ),
      ),
      // Sayfanın altına sabitlenmiş gönderme butonu
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: _isProcessingAndSaving
          ? const Center(child: CircularProgressIndicator())
          : ElevatedButton.icon(
              icon: const Icon(Icons.send_rounded),
              label: const Text('Tutanak Bilgilerimi Gönder ve Tamamla'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green.shade600, // Onay ve gönderme için yeşil renk
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              onPressed: _handleReportSubmission,
            ),
      ),
    );
  }
}