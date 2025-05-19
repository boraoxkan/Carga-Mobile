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
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart'; // MediaType için
import 'package:geocoding/geocoding.dart'; // Adres çevirme için eklendi
import 'package:tutanak/models/crash_region.dart';

class ReportSummaryPage extends StatefulWidget {
  final Set<CrashRegion> selectedRegions;
  final Map<String, String> vehicleInfo;
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
  XFile? _selectedImageFileForUbuntu;
  Uint8List? _processedImageBytesFromUbuntu;
  List<dynamic>? _detectionResultsFromUbuntu;
  bool _isProcessingAndSaving = false;

  Map<String, dynamic>? _otherPartyUserData;
  Map<String, dynamic>? _otherPartyVehicleData;
  Set<CrashRegion> _otherPartySelectedRegions = {};
  List<String> _otherPartyFirebaseStorageImageUrls = [];
  String? _otherPartyProcessedImageBase64FromUbuntu;
  List<dynamic>? _otherPartyDetectionResultsFromUbuntu;
  bool _isLoadingOtherPartyData = true;

  // Adres için state değişkenleri
  String? _address;
  bool _isFetchingAddress = true;
  String? _addressError;

  final String _ubuntuServerUrl = "http://100.110.23.124:5001/process_damage_image";
  final bool _useFirebaseStorageForOwnPhotos = false;

  @override
  void initState() {
    super.initState();
    _fetchOtherPartyData();
    _getAddressFromLatLng(); // Adresi çekmek için initState'te çağır
  }

  // Enlem ve boylamdan adres bilgisini getiren fonksiyon
  Future<void> _getAddressFromLatLng() async {
    if (!mounted) return;
    print("Adres çekme işlemi başlıyor... Enlem: ${widget.confirmedPosition.latitude}, Boylam: ${widget.confirmedPosition.longitude}"); // Debug
    setState(() {
      _isFetchingAddress = true;
      _addressError = null;
    });
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.confirmedPosition.latitude,
        widget.confirmedPosition.longitude,
        // localeIdentifier parametresi kaldırıldı. Paket cihazın yerel ayarlarını kullanır.
      );
      print("Placemarks alındı: ${placemarks.length} adet"); // Debug

      if (placemarks.isNotEmpty && mounted) {
        final Placemark place = placemarks.first;
        print("İlk placemark: ${place.toJson()}"); // Debug - Gelen tüm veriyi görmek için

        String street = place.street ?? ''; // Sokak adı ve numarası birleşik olabilir.
        String thoroughfare = place.thoroughfare ?? ''; // Cadde/Yol adı
        String subLocality = place.subLocality ?? ''; // Mahalle
        String locality = place.locality ?? ''; // İlçe/Semt
        String administrativeArea = place.administrativeArea ?? ''; // İl
        String postalCode = place.postalCode ?? '';
        String country = place.country ?? '';

        // Adres formatlama (Örnek, ihtiyaca göre düzenlenebilir)
        // Bazı durumlarda place.street hem caddeyi hem de sokak adını içerebilir.
        // place.thoroughfare ise sadece cadde/yol adını verebilir.
        // Bu yüzden tekrarları önlemek için kontrol eklenebilir.

        List<String> addressParts = [];
        if (street.isNotEmpty) {
          addressParts.add(street);
        }
        // Eğer thoroughfare caddesi street içinde geçmiyorsa ve farklıysa ekle
        if (thoroughfare.isNotEmpty && !street.toLowerCase().contains(thoroughfare.toLowerCase())) {
           addressParts.add(thoroughfare);
        }
        if (subLocality.isNotEmpty) {
          addressParts.add(subLocality);
        }
        if (locality.isNotEmpty) {
          addressParts.add(locality);
        }
        if (administrativeArea.isNotEmpty) {
          addressParts.add(administrativeArea);
        }
        if (postalCode.isNotEmpty) {
          addressParts.add(postalCode);
        }
        if (country.isNotEmpty) {
          // addressParts.add(country); // Ülke genellikle gerekmeyebilir
        }

        String formattedAddress = addressParts.where((part) => part.isNotEmpty).join(', ');
        // Çift virgül veya başlangıç/sondaki virgülleri temizle
        formattedAddress = formattedAddress.replaceAll(RegExp(r',\s*,'), ', ').replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');


        print("Formatlanmış Adres: $formattedAddress"); // Debug
        setState(() {
          _address = formattedAddress.isNotEmpty ? formattedAddress : "Adres detayı bulunamadı.";
        });
      } else if (mounted) {
        print("Placemark bulunamadı."); // Debug
        setState(() {
          _address = "Adres bilgisi bulunamadı.";
        });
      }
    } catch (e) {
      if (mounted) {
        print("Adres çevirme hatası (catch bloğu): $e"); // Debug
        setState(() {
          _addressError = "Adres alınamadı: ${e.toString().substring(0, (e.toString().length > 50) ? 50 : e.toString().length)}..."; // Hatayı kısaltarak göster
          _address = null;
        });
      }
    } finally {
      if (mounted) {
        print("Adres çekme işlemi tamamlandı. _isFetchingAddress: false, Adres: $_address, Hata: $_addressError"); // Debug
        setState(() {
          _isFetchingAddress = false;
        });
      }
    }
  }


  Future<void> _fetchOtherPartyData() async {
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

      final String? otherPartyUid = recordData['${otherPartyRolePrefix}Uid'] as String?;
      if (otherPartyUid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherPartyUid).get();
        if (userDoc.exists && mounted) {
           setState(() => _otherPartyUserData = userDoc.data());
        }
        if (recordData.containsKey('${otherPartyRolePrefix}VehicleInfo') && mounted) {
            setState(()=> _otherPartyVehicleData = recordData['${otherPartyRolePrefix}VehicleInfo'] as Map<String, dynamic>?);
        } else {
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
                  try { return CrashRegion.values.byName(regionString.toString().split('.').last); }
                  catch (e) { print("Enum parse error: $regionString, $e"); return null; }
                })
                .whereType<CrashRegion>().toSet();
          });
        }
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

  Future<void> _saveReportDataToFirestore({
    String? processedImageBase64ForUbuntu,
    List<dynamic>? detectionsForUbuntu,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("Kullanıcı girişi yapılmamış.");
    }

    final String userRolePrefix = widget.isCreator ? "creator" : "joiner";
    Map<String, dynamic> dataToSave = {
      '${userRolePrefix}Uid': currentUser.uid,
      '${userRolePrefix}VehicleInfo': widget.vehicleInfo,
      '${userRolePrefix}Notes': _notesController.text.trim(),
      '${userRolePrefix}DamageRegions': widget.selectedRegions.map((r) => r.name).toList(),
      '${userRolePrefix}LastUpdateTimestamp': FieldValue.serverTimestamp(),
    };

    if (processedImageBase64ForUbuntu != null) {
      dataToSave['${userRolePrefix}ProcessedDamageImageBase64'] = processedImageBase64ForUbuntu;
    }
    if (detectionsForUbuntu != null) {
      dataToSave['${userRolePrefix}DetectionResults'] = detectionsForUbuntu;
    }

    if (widget.isCreator) {
      final recordDocSnapshot = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
      if (!recordDocSnapshot.exists || recordDocSnapshot.data()?['latitude'] == null) {
        dataToSave['latitude'] = widget.confirmedPosition.latitude;
        dataToSave['longitude'] = widget.confirmedPosition.longitude;
        dataToSave['locationSetTimestamp'] = FieldValue.serverTimestamp();
        // Adresi sadece oluşturan taraf kaydederken ekleyelim (eğer başarılı bir şekilde alındıysa)
        if (_address != null && _address!.isNotEmpty && _addressError == null && _address != "Adres detayı bulunamadı." && _address != "Adres bilgisi bulunamadı.") {
          dataToSave['formattedAddress'] = _address;
        }
      } else {
        // Eğer konum daha önce kaydedilmişse ve formatlanmış adres yoksa, yine de eklemeyi deneyebiliriz.
        // Bu, oluşturan tarafın bilgileri daha sonra güncellemesi durumunda faydalı olabilir.
        if ((!recordDocSnapshot.data()!.containsKey('formattedAddress') || recordDocSnapshot.data()?['formattedAddress'] == null) &&
            _address != null && _address!.isNotEmpty && _addressError == null &&
            _address != "Adres detayı bulunamadı." && _address != "Adres bilgisi bulunamadı.") {
          dataToSave['formattedAddress'] = _address;
        }
      }
    }

    dataToSave['status'] = widget.isCreator ? 'creator_info_submitted' : 'joiner_info_submitted';

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

  Future<void> _pickImageForUbuntu() async {
     try {
      final XFile? pickedFile = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 60,
        maxWidth: 800,
      );
      if (pickedFile != null && mounted) {
        setState(() {
            _selectedImageFileForUbuntu = pickedFile;
            _processedImageBytesFromUbuntu = null;
            _detectionResultsFromUbuntu = null;
        });
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fotoğraf seçilirken bir hata oluştu: $e')));
    }
  }

  Future<void> _processWithUbuntuServerAndSave() async {
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

      var streamedResponse = await request.send().timeout(const Duration(seconds: 90));
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
              Navigator.popUntil(context, (route) => route.isFirst);
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

  Future<void> _handleReportSubmission() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın.')));
      return;
    }
    if (widget.selectedRegions.isEmpty && _notesController.text.trim().isEmpty && _selectedImageFileForUbuntu == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen hasar bölgesi, fotoğraf veya not gibi en az bir bilgi girin.')));
        return;
    }

    if (mounted) setState(() => _isProcessingAndSaving = true);

    try {
      if (!_useFirebaseStorageForOwnPhotos) {
          if (_selectedImageFileForUbuntu != null) {
              await _processWithUbuntuServerAndSave();
          } else {
              await _saveReportDataToFirestore();
              if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tutanak bilgileriniz (fotoğrafsız) kaydedildi.')));
                  Navigator.popUntil(context, (route) => route.isFirst);
              }
          }
      } else {
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
        if(mounted && _isProcessingAndSaving) {
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
      Color? cardColor,
  }) {
    final theme = Theme.of(context);
    return Card(
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
    print("_buildAddressInfoRow çağrıldı. _isFetchingAddress: $_isFetchingAddress, _address: $_address, _addressError: $_addressError"); // Debug
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
    // Herhangi bir adres veya hata yoksa, enlem/boylam gösterilebilir veya "Belirtilmemiş" denebilir.
    // Şimdilik varsayılan enlem/boylamı gösterelim, ama bu durum _getAddressFromLatLng'in mantığıyla çelişebilir.
    // Bu satıra normalde gelinmemesi lazım.
    return _buildTextInfoRow('Kaza Adresi (Enlem/Boylam)', '${widget.confirmedPosition.latitude.toStringAsFixed(4)}, ${widget.confirmedPosition.longitude.toStringAsFixed(4)}');
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
      default: return region.name;
    }
  }

  Widget _buildPhotoSelectionAndDisplayUI() {
    final theme = Theme.of(context);
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
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tutanak Özeti ve Onay'),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
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
                    ),
                  ),
                ]
              ),

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

              _buildSectionHeader(context, "ORTAK BİLGİLER", Icons.map_rounded),
              _buildInfoCard(
                title: 'Onaylanan Kaza Konumu',
                titleIcon: Icons.location_on_rounded,
                children: [
                    SizedBox(
                      height: 180,
                      child: AbsorbPointer(
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
                label: const Text('Tutanak Bilgilerimi Gönder ve Tamamla'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green.shade600,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _handleReportSubmission,
              ),
        ),
      ),
    );
  }
}