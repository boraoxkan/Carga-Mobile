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
import 'package:path/path.dart' as path; // path.extension için
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // MediaType için
import 'package:geocoding/geocoding.dart';
import 'package:tutanak/models/crash_region.dart';

class ReportSummaryPage extends StatefulWidget {
  final Set<CrashRegion> selectedRegions;
  final Map<String, String> vehicleInfo; // brand, model, plate içermeli
  final LatLng confirmedPosition;
  final String recordId; // Benzersiz tutanak ID'si
  final bool isCreator; // Mevcut kullanıcı tutanağı oluşturan mı?

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
  XFile? _selectedImageFileForUbuntu;
  Uint8List? _processedImageBytesFromUbuntu;
  List<dynamic>? _detectionResultsFromUbuntu;
  bool _isProcessingAndSaving = false;

  Map<String, dynamic>? _otherPartyUserData;
  Map<String, dynamic>? _otherPartyVehicleData;
  Set<CrashRegion> _otherPartySelectedRegions = {};
  String? _otherPartyProcessedImageBase64FromUbuntu;
  List<dynamic>? _otherPartyDetectionResultsFromUbuntu;
  String? _otherPartyNotes;
  bool _isLoadingOtherPartyData = true;

  String? _address;
  bool _isFetchingAddress = true;
  String? _addressError;

  // UBUNTU SUNUCU ADRESİNİZİ BURAYA GİRİN:
  final String _ubuntuServerUrl = "http://100.110.23.124:5001/process_damage_image";
  // final bool _useFirebaseStorageForOwnPhotos = false; // Bu değişken kullanılmıyor gibi, kaldırılabilir.

  @override
  void initState() {
    super.initState();
    _fetchOtherPartyData();
    _getAddressFromLatLng();
  }

  Future<void> _getAddressFromLatLng() async {
    if (!mounted) return;
    setState(() {
      _isFetchingAddress = true;
      _addressError = null;
    });
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.confirmedPosition.latitude,
        widget.confirmedPosition.longitude,
      );
      if (placemarks.isNotEmpty && mounted) {
        final Placemark place = placemarks.first;
        String street = place.street ?? '';
        String thoroughfare = place.thoroughfare ?? '';
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? '';
        String administrativeArea = place.administrativeArea ?? '';
        String postalCode = place.postalCode ?? '';

        List<String> addressParts = [];
        if (street.isNotEmpty) addressParts.add(street);
        if (thoroughfare.isNotEmpty && !street.toLowerCase().contains(thoroughfare.toLowerCase())) {
           addressParts.add(thoroughfare);
        }
        if (subLocality.isNotEmpty) addressParts.add(subLocality);
        if (locality.isNotEmpty) addressParts.add(locality);
        if (administrativeArea.isNotEmpty) addressParts.add(administrativeArea);
        if (postalCode.isNotEmpty) addressParts.add(postalCode);

        String formattedAddress = addressParts.where((part) => part.isNotEmpty).join(', ');
        formattedAddress = formattedAddress.replaceAll(RegExp(r',\s*,'), ', ').replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');
        
        setState(() {
          _address = formattedAddress.isNotEmpty ? formattedAddress : "Adres detayı bulunamadı.";
        });
      } else if (mounted) {
        setState(() {
          _address = "Adres bilgisi bulunamadı.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addressError = "Adres alınamadı: ${e.toString().substring(0, (e.toString().length > 50) ? 50 : e.toString().length)}...";
          _address = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingAddress = false;
        });
      }
    }
  }

  Future<void> _fetchOtherPartyData() async {
    if (!mounted) return;
    setState(() => _isLoadingOtherPartyData = true);
    try {
      final recordDoc = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
      if (!recordDoc.exists || recordDoc.data() == null) {
        if (mounted) setState(() => _isLoadingOtherPartyData = false);
        print("Karşı taraf verisi çekilemedi: Tutanak belgesi bulunamadı (${widget.recordId}).");
        return;
      }
      final recordData = recordDoc.data()!;
      String otherPartyRolePrefix = widget.isCreator ? "joiner" : "creator";

      final String? otherPartyUid = recordData['${otherPartyRolePrefix}Uid'] as String?;
      if (otherPartyUid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherPartyUid).get();
        if (userDoc.exists && mounted) {
           setState(() => _otherPartyUserData = userDoc.data());
        }
        // Araç bilgilerini doğrudan recordData'dan almayı dene (eğer oraya kaydedildiyse)
        if (recordData.containsKey('${otherPartyRolePrefix}VehicleInfo') && recordData['${otherPartyRolePrefix}VehicleInfo'] != null && mounted) {
            setState(()=> _otherPartyVehicleData = recordData['${otherPartyRolePrefix}VehicleInfo'] as Map<String, dynamic>?);
        } else { // Değilse, eski yöntemle (vehicleId ile) çekmeyi dene
            final String? otherPartyVehicleId = recordData['${otherPartyRolePrefix}VehicleId'] as String?;
            if (otherPartyVehicleId != null) {
                final vehicleDoc = await FirebaseFirestore.instance.collection('users').doc(otherPartyUid).collection('vehicles').doc(otherPartyVehicleId).get();
                if(vehicleDoc.exists && mounted) {
                    setState(() => _otherPartyVehicleData = vehicleDoc.data());
                }
            }
        }
      }

      final otherPartyRegionsFieldName = '${otherPartyRolePrefix}DamageRegions';
      if (recordData.containsKey(otherPartyRegionsFieldName) && recordData[otherPartyRegionsFieldName] is List) {
        List<dynamic> regionsData = recordData[otherPartyRegionsFieldName];
        if (mounted) {
          setState(() {
            _otherPartySelectedRegions = regionsData
                .map((regionString) {
                  try { return CrashRegion.values.byName(regionString.toString()); } // .split('.').last kaldırıldı
                  catch (e) { print("Enum parse error for other party: $regionString, $e"); return null; }
                })
                .whereType<CrashRegion>().toSet();
          });
        }
      }
      
      final otherPartyNotesFieldName = '${otherPartyRolePrefix}Notes';
      if(recordData.containsKey(otherPartyNotesFieldName) && mounted){
        setState(() {
          _otherPartyNotes = recordData[otherPartyNotesFieldName] as String?;
        });
      }

      final otherPartyProcessedBase64FieldName = '${otherPartyRolePrefix}ProcessedDamageImageBase64';
      if (recordData.containsKey(otherPartyProcessedBase64FieldName) && recordData[otherPartyProcessedBase64FieldName] is String && mounted) {
          setState(() => _otherPartyProcessedImageBase64FromUbuntu = recordData[otherPartyProcessedBase64FieldName] as String?);
      }
      final otherPartyDetectionsFieldName = '${otherPartyRolePrefix}DetectionResults';
       if (recordData.containsKey(otherPartyDetectionsFieldName) && recordData[otherPartyDetectionsFieldName] is List && mounted) {
          setState(() => _otherPartyDetectionResultsFromUbuntu = recordData[otherPartyDetectionsFieldName] as List<dynamic>?);
      }

    } catch (e,s) {
      print("Karşı taraf verileri çekilirken hata (report_summary_page): $e \n$s");
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Karşı taraf verileri yüklenemedi: $e")));
    } finally {
      if (mounted) setState(() { _isLoadingOtherPartyData = false; });
    }
  }

  Future<void> _saveCurrentUserDataToFirestore({
    String? processedImageBase64, // Ubuntu'dan gelen işlenmiş fotoğraf
    List<dynamic>? detectionResults, // Ubuntu'dan gelen tespitler
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("Kullanıcı girişi yapılmamış.");
    }

    final String userRolePrefix = widget.isCreator ? "creator" : "joiner";
    Map<String, dynamic> dataToUpdate = {
      // '${userRolePrefix}Uid': currentUser.uid, // Bu zaten ilk kayıtta set ediliyor, güncellemeye gerek yok.
      '${userRolePrefix}VehicleInfo': widget.vehicleInfo, // Güncel araç bilgisi
      '${userRolePrefix}Notes': _notesController.text.trim(),
      '${userRolePrefix}DamageRegions': widget.selectedRegions.map((r) => r.name).toList(),
      '${userRolePrefix}LastUpdateTimestamp': FieldValue.serverTimestamp(),
    };

    if (processedImageBase64 != null) {
      dataToUpdate['${userRolePrefix}ProcessedDamageImageBase64'] = processedImageBase64;
    }
    if (detectionResults != null) {
      dataToUpdate['${userRolePrefix}DetectionResults'] = detectionResults;
    }

    // Konum ve adres sadece oluşturan taraf tarafından ilk defa kaydedilir.
    // DriverAndVehicleInfoPage'de ana kayıt oluşturulurken konum için null değerler girilmişti.
    // Bu sayfada oluşturan taraf onayladığında konum ve adres bilgileri eklenir.
    if (widget.isCreator) {
      final recordDocSnapshot = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
      // Eğer belge yoksa (ki olmamalı) veya konum bilgisi henüz set edilmemişse ekle
      if (!recordDocSnapshot.exists || recordDocSnapshot.data()?['latitude'] == null) {
        dataToUpdate['latitude'] = widget.confirmedPosition.latitude;
        dataToUpdate['longitude'] = widget.confirmedPosition.longitude;
        dataToUpdate['locationSetTimestamp'] = FieldValue.serverTimestamp();
        if (_address != null && _address!.isNotEmpty && _addressError == null && _address != "Adres detayı bulunamadı." && _address != "Adres bilgisi bulunamadı.") {
          dataToUpdate['formattedAddress'] = _address;
        }
      } else { // Konum daha önce set edilmişse bile, adres eksikse ve şimdi varsa ekle
        if ((!recordDocSnapshot.data()!.containsKey('formattedAddress') || recordDocSnapshot.data()?['formattedAddress'] == null) &&
            _address != null && _address!.isNotEmpty && _addressError == null &&
            _address != "Adres detayı bulunamadı." && _address != "Adres bilgisi bulunamadı.") {
          dataToUpdate['formattedAddress'] = _address;
        }
      }
    }

    // Status güncellemesi
    String currentStatus = widget.isCreator ? 'creator_info_submitted' : 'joiner_info_submitted';
    dataToUpdate['status'] = currentStatus;
    
    final otherPartyRolePrefix = widget.isCreator ? "joiner" : "creator";
    final recordSnapshot = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
    final recordData = recordSnapshot.data();

    // Diğer tarafın da bilgilerini gönderip göndermediğini kontrol et
    if (recordData != null && recordData['${otherPartyRolePrefix}Uid'] != null &&
        (recordData['status'] == 'creator_info_submitted' || recordData['status'] == 'joiner_info_submitted') &&
         recordData['status'] != currentStatus // Mevcut işlem diğer tarafın gönderdiği status ile aynı değilse (yani farklı taraflar gönderiyorsa)
        ) {
      dataToUpdate['status'] = 'all_data_submitted';
      dataToUpdate['reportFinalizedTimestamp'] = FieldValue.serverTimestamp();
    }
    
    // ÖNEMLİ: `isDeletedByCreator` ve `isDeletedByJoiner` alanları
    // `DriverAndVehicleInfoPage` içinde ilk kayıt oluşturulurken `false` olarak set edilmişti.
    // Bu yüzden burada tekrar set etmeye gerek yok, `SetOptions(merge: true)` sayesinde
    // var olan değerler korunacaktır.
    await FirebaseFirestore.instance
        .collection('records')
        .doc(widget.recordId)
        .set(dataToUpdate, SetOptions(merge: true)); // merge:true çok önemli
  }


  Future<void> _pickImageForUbuntu() async {
     try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery, // Veya ImageSource.camera
        imageQuality: 60, // Kaliteyi düşürerek dosya boyutunu azalt
        maxWidth: 800,    // Genişliği sınırla
      );
      if (pickedFile != null && mounted) {
        setState(() {
            _selectedImageFileForUbuntu = pickedFile;
            _processedImageBytesFromUbuntu = null; // Önceki işlenmiş resmi temizle
            _detectionResultsFromUbuntu = null;  // Önceki tespitleri temizle
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fotoğraf seçilirken bir hata oluştu: $e')));
    }
  }

  Future<void> _processWithUbuntuServerAndSave() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null || _selectedImageFileForUbuntu == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın ve işlenecek bir fotoğraf seçin.')));
      return;
    }

    if (mounted) setState(() => _isProcessingAndSaving = true);

    try {
      File file = File(_selectedImageFileForUbuntu!.path);
      var request = http.MultipartRequest('POST', Uri.parse(_ubuntuServerUrl));
      request.files.add(await http.MultipartFile.fromPath(
        'image', file.path,
        contentType: MediaType('image', path.extension(file.path).replaceAll('.', '')), // path.extension için path importu gerekli
      ));
      // Sunucu tarafında gerekiyorsa bu alanlar eklenebilir
      // request.fields['record_id'] = widget.recordId;
      // request.fields['user_id'] = currentUser.uid;

      var streamedResponse = await request.send().timeout(const Duration(seconds: 90)); // Timeout süresi
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final String? imageBase64 = responseData['processed_image_base64'] as String?;
        final List<dynamic>? detections = responseData['detections'] as List<dynamic>?;

        if (imageBase64 != null && mounted) {
          setState(() {
              _processedImageBytesFromUbuntu = base64Decode(imageBase64);
              _detectionResultsFromUbuntu = detections;
          });
          // Sunucudan gelen işlenmiş fotoğraf ve tespitlerle Firestore'u güncelle
          await _saveCurrentUserDataToFirestore(
              processedImageBase64: imageBase64,
              detectionResults: detections
          );
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf işlendi ve tutanak bilgileri başarıyla kaydedildi!')));
              Navigator.popUntil(context, (route) => route.isFirst); // Ana sayfaya dön
          }
        } else {
            throw Exception("Sunucudan işlenmiş fotoğraf verisi alınamadı.");
        }
    } else {
        // Sunucudan gelen hata mesajını parse etmeye çalış
        String errorMessage = "Sunucu Hatası (${response.statusCode}): ${response.reasonPhrase}.";
        try {
            final errorData = json.decode(response.body);
            if (errorData['error'] != null) errorMessage += " Detay: ${errorData['error']}";
        } catch (_) {
            // JSON parse edilemezse ham body'yi ekle (çok uzun olabilir, dikkat)
            errorMessage += " Detay: ${response.body.substring(0, (response.body.length > 100) ? 100 : response.body.length)}...";
        }
        throw Exception(errorMessage);
    }
    } catch (e, s) {
      print("Ubuntu sunucu ile fotoğraf işleme/kaydetme hatası: $e\n$s");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Sunucu ile iletişimde hata: $e')));
    } finally {
      if (mounted) setState(() => _isProcessingAndSaving = false);
    }
  }

  // Ana kaydetme ve gönderme butonu için
  Future<void> _handleReportSubmission() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın.')));
      return;
    }
    // En az bir bilgi girilmiş olmalı (hasar bölgesi, not veya fotoğraf)
    if (widget.selectedRegions.isEmpty && _notesController.text.trim().isEmpty && _selectedImageFileForUbuntu == null && _processedImageBytesFromUbuntu == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen hasar bölgesi, fotoğraf veya not gibi en az bir bilgi girin.')));
        return;
    }

    if (mounted) setState(() => _isProcessingAndSaving = true);

    try {
      if (_selectedImageFileForUbuntu != null && _processedImageBytesFromUbuntu == null) {
          // Eğer yeni bir fotoğraf seçilmişse ve henüz işlenmemişse, sunucuya gönder ve kaydet
          await _processWithUbuntuServerAndSave();
      } else {
          // Fotoğraf yoksa veya zaten işlenmiş bir fotoğraf varsa, sadece Firestore'a kaydet
          // (işlenmiş fotoğraf ve tespitler _processedImageBytesFromUbuntu ve _detectionResultsFromUbuntu içinde zaten var)
          await _saveCurrentUserDataToFirestore(
            processedImageBase64: _processedImageBytesFromUbuntu != null ? base64Encode(_processedImageBytesFromUbuntu!) : null,
            detectionResults: _detectionResultsFromUbuntu
          );
          if(mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tutanak bilgileriniz başarıyla kaydedildi.')));
              Navigator.popUntil(context, (route) => route.isFirst); // Ana sayfaya dön
          }
      }
    } catch (e,s) {
        print("Rapor gönderiminde genel hata (_handleReportSubmission): $e\n$s");
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapor gönderilirken bir hata oluştu: $e')));
    } finally {
        // _isProcessingAndSaving durumu _processWithUbuntuServerAndSave içinde zaten false yapılıyor.
        // Eğer sadece _saveCurrentUserDataToFirestore çağrıldıysa ve bir hata oluşursa diye burada da kontrol edilebilir.
        if(mounted && _isProcessingAndSaving && (_selectedImageFileForUbuntu == null || _processedImageBytesFromUbuntu != null) ) {
           setState(() => _isProcessingAndSaving = false);
        }
    }
  }

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
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 6),
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
          Expanded(flex: 3, child: Text(value?.isNotEmpty == true ? value! : '-', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildAddressInfoRow() {
    final theme = Theme.of(context);
    if (_isFetchingAddress) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Kaza Adresi:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Expanded(child: Text("Adres yükleniyor...", style: theme.textTheme.bodySmall)),
          ],
        ),
      );
    }
    if (_addressError != null && _addressError!.isNotEmpty) {
      return _buildTextInfoRow('Kaza Adresi', _addressError);
    }
    if (_address != null && _address!.isNotEmpty) {
      return _buildTextInfoRow('Kaza Adresi', _address);
    }
    return _buildTextInfoRow('Kaza Konumu', '${widget.confirmedPosition.latitude.toStringAsFixed(4)}, ${widget.confirmedPosition.longitude.toStringAsFixed(4)}');
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
    switch (region) {
      case CrashRegion.frontLeft:   return 'Ön Sol';
      case CrashRegion.frontCenter: return 'Ön Orta';
      case CrashRegion.frontRight:  return 'Ön Sağ';
      case CrashRegion.left:        return 'Sol Taraf';
      case CrashRegion.right:       return 'Sağ Taraf';
      case CrashRegion.rearLeft:    return 'Arka Sol';
      case CrashRegion.rearCenter:  return 'Arka Orta';
      case CrashRegion.rearRight:   return 'Arka Sağ';
      // default: return region.name; // Bu zaten enum'ın kendi name'i
    }
  }

  Widget _buildPhotoSelectionAndDisplayUI() {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Hasarlı Araç Fotoğrafınız (1 Adet)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Bu fotoğraf, hasar tespiti için sunucuda işlenecektir.', style: theme.textTheme.bodySmall),
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
            title: "Seçilen Fotoğraf (Gönderilecek)",
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
              ),
              onPressed: _isProcessingAndSaving ? null : _pickImageForUbuntu,
            ),
          ),
      ],
    );
  }

  Widget _buildOtherPartyPhotoDisplay(ThemeData theme) {
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
    // Karşı tarafın Firebase Storage'a yüklediği fotoğraflar varsa (eski yöntem), burada listelenebilir.
    // Şimdilik sadece Ubuntu üzerinden işlenmiş fotoğrafı gösteriyoruz.
    // if (_otherPartyFirebaseStorageImageUrls.isNotEmpty) { ... }
    return const Text('Karşı taraf henüz işlenmiş fotoğraf eklememiş.', style: TextStyle(fontStyle: FontStyle.italic));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector( // Klavyeyi kapatmak için
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tutanak Özeti ve Onay'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0), // Alttaki buton için boşluk
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                    decoration: InputDecoration(
                      hintText: 'Kaza ile ilgili eklemek istediğiniz detaylar, beyanınız...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    textInputAction: TextInputAction.done,
                  ),
                ]
              ),

              _buildSectionHeader(context, "KARŞI TARAFIN BİLGİLERİ", Icons.people_alt_rounded),
              _isLoadingOtherPartyData
                ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 30.0), child: CircularProgressIndicator()))
                : (_otherPartyUserData == null && _otherPartyVehicleData == null && _otherPartySelectedRegions.isEmpty && _otherPartyProcessedImageBase64FromUbuntu == null && _otherPartyNotes == null)
                    ? _buildInfoCard(title: "Diğer Sürücü Bilgileri", children: [const Text('Karşı taraf henüz bilgi girişi yapmamış veya bilgiler yüklenemedi.', style: TextStyle(fontStyle: FontStyle.italic))])
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
                          children: [Text(_otherPartyNotes?.isNotEmpty == true ? _otherPartyNotes! : 'Karşı taraf not eklememiş.', style: const TextStyle(fontStyle: FontStyle.italic))],
                        ),
                        const SizedBox(height: 12),
                        if (_otherPartyProcessedImageBase64FromUbuntu != null)
                          _buildInfoCard(
                            title: 'Diğer Sürücünün Hasar Fotoğrafı',
                            titleIcon: Icons.image_search_rounded,
                            children: [_buildOtherPartyPhotoDisplay(theme)],
                          )
                        else
                          _buildInfoCard(
                            title: 'Diğer Sürücünün Hasar Fotoğrafı',
                             titleIcon: Icons.image_not_supported_outlined,
                            children: [const Text("Karşı taraf işlenmiş fotoğraf eklememiş.", style: TextStyle(fontStyle: FontStyle.italic))]
                          ),
                    ]),

              _buildSectionHeader(context, "ORTAK BİLGİLER", Icons.map_rounded),
              _buildInfoCard(
                title: 'Onaylanan Kaza Konumu',
                titleIcon: Icons.location_on_rounded,
                children: [
                    SizedBox(
                      height: 180,
                      child: AbsorbPointer( // Kullanıcının haritayla etkileşimini engelle
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(target: widget.confirmedPosition, zoom: 16.5),
                          markers: {Marker(markerId: const MarkerId('accidentLocation'), position: widget.confirmedPosition, infoWindow: const InfoWindow(title: "Kaza Yeri"))},
                          scrollGesturesEnabled: false, zoomGesturesEnabled: false, rotateGesturesEnabled: false, tiltGesturesEnabled: false, mapToolbarEnabled: false,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),
                    _buildAddressInfoRow(),
               ]),
              const SizedBox(height: 32),
            ],
          ),
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: _isProcessingAndSaving
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded),
                label: const Text('Tutanak Bilgilerimi Gönder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade700, // Daha belirgin bir yeşil
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                onPressed: _handleReportSubmission,
              ),
        ),
      ),
    );
  }
}