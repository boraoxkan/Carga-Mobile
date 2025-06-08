// lib/screens/report_summary_page.dart
import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; 
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart'; 
import 'package:tutanak/models/crash_region.dart';

// PDF Alanı 7 için Kaza Durumları Listesi (Bu listeyi kendi PDF'inize göre güncelleyin)
const List<String> kazaDurumlariListesi = [
  "Kırmızı ışıkta geçmek",
  "Hız limitini aşmak",
  "Takip mesafesini korumamak",
  "Şerit ihlali yapmak",
  "Yanlış park etmek",
  "Duraklama kurallarına uymamak",
  "Geçme yasağı olan yerde geçmek (sollama)",
  "Kavşakta geçiş önceliğine uymamak",
  "Sağa dönüş kurallarına uymamak",
  "Sola dönüş kurallarına uymamak",
  "Geri manevra kurallarına uymamak",
  "Yetkili memurun dur işaretinde geçmek",
  "Park etmiş araca çarpmak",
  "Karşı yönden gelen trafiğin kullandığı yola girmek",
  "Taşıt giremez işareti bulunan yola girmek",
];

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
  // --- STATE ve CONTROLLER'LAR ---
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _notesController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  XFile? _selectedImageFileForUbuntu;
  Uint8List? _processedImageBytesFromUbuntu;
  List<dynamic>? _detectionResultsFromUbuntu;
  bool _isProcessingAndSaving = false;
  String _loadingMessage = "Tutanak bilgileri gönderiliyor..."; // Yeni loading mesajı

  // Diğer tarafa ait veriler
  Map<String, dynamic>? _otherPartyUserData;
  Map<String, dynamic>? _otherPartyVehicleData;
  Set<CrashRegion> _otherPartySelectedRegions = {};
  List<String> _otherPartySecilenKazaDurumlari = [];
  String? _otherPartyProcessedImageBase64FromUbuntu;
  List<dynamic>? _otherPartyDetectionResultsFromUbuntu;
  String? _otherPartyNotes;
  bool _isLoadingOtherPartyData = true;

  // Adres ve tarih bilgileri
  String? _address;
  bool _isFetchingAddress = true;
  String? _addressError;
  DateTime _kazaTarihi = DateTime.now();
  TimeOfDay _kazaSaati = TimeOfDay.now();

  // Diğer Form controller'ları...
  final TextEditingController _ilceController = TextEditingController();
  final TextEditingController _semtController = TextEditingController();
  final TextEditingController _mahalleController = TextEditingController();
  final TextEditingController _caddeController = TextEditingController();
  final TextEditingController _sokakController = TextEditingController();
  final TextEditingController _tanik1AdiSoyadiController = TextEditingController();
  final TextEditingController _tanik1AdresController = TextEditingController();
  final TextEditingController _tanik1TelController = TextEditingController();
  final List<String> _secilenKazaDurumlari = [];

  // --- SUNUCU ADRESLERİ ---
  final String _damageDetectionServerUrl = "http://100.71.209.113:5001/process_damage_image";
  final String _aiPdfServerUrl = "http://100.71.209.113:6001/generate_ai_pdf_report";


  @override
  void initState() {
    super.initState();
    _loadInitialRecordData();
    _fetchOtherPartyData();
  }

  dynamic _convertDataToJsonSerializable(dynamic data) {
    if (data == null) return null;
    if (data is Timestamp) return data.toDate().toIso8601String();
    if (data is GeoPoint) return {'latitude': data.latitude, 'longitude': data.longitude};
    if (data is LatLng) return {'latitude': data.latitude, 'longitude': data.longitude};
    if (data is Map) return data.map((key, value) => MapEntry(key.toString(), _convertDataToJsonSerializable(value)));
    if (data is List) return data.map((item) => _convertDataToJsonSerializable(item)).toList();
    return data;
  }

  Future<Map<String, dynamic>?> _fetchFullUserDetails(String? userId) async {
    if (userId == null || userId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<Map<String, dynamic>?> _fetchFullVehicleDetails(String? userId, String? vehicleId) async {
    if (userId == null || userId.isEmpty || vehicleId == null || vehicleId.isEmpty) return null;
    final doc = await FirebaseFirestore.instance.collection('users').doc(userId).collection('vehicles').doc(vehicleId).get();
    return doc.exists ? doc.data() : null;
  }

  Future<Map<String, dynamic>> _prepareDataForAi(Map<String, dynamic> currentRecordData) async {
    Map<String, dynamic> dataForAi = _convertDataToJsonSerializable(Map<String, dynamic>.from(currentRecordData));
    final creatorUid = currentRecordData['creatorUid'] as String?;
    final joinerUid = currentRecordData['joinerUid'] as String?;

    if (creatorUid != null) {
      dataForAi['creatorUserData'] = _convertDataToJsonSerializable(await _fetchFullUserDetails(creatorUid));
      dataForAi['creatorVehicleInfo'] = _convertDataToJsonSerializable(await _fetchFullVehicleDetails(creatorUid, currentRecordData['creatorVehicleId'] as String?));
    }
    if (joinerUid != null) {
      dataForAi['joinerUserData'] = _convertDataToJsonSerializable(await _fetchFullUserDetails(joinerUid));
      dataForAi['joinerVehicleInfo'] = _convertDataToJsonSerializable(await _fetchFullVehicleDetails(joinerUid, currentRecordData['joinerVehicleId'] as String?));
    }
    if (currentRecordData['kazaTimestamp'] is Timestamp) {
      DateTime kazaDT = (currentRecordData['kazaTimestamp'] as Timestamp).toDate();
      dataForAi['kazaTarihi'] = DateFormat('dd.MM.yyyy', 'tr_TR').format(kazaDT);
      dataForAi['kazaSaati'] = DateFormat('HH:mm').format(kazaDT);
    }
    dataForAi['recordId'] = widget.recordId;
    return dataForAi;
  }

  Future<void> _loadInitialRecordData() async {
    if (!mounted) return;
    try {
      DocumentSnapshot recordDoc = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
      if (mounted && recordDoc.exists && recordDoc.data() != null) {
        Map<String, dynamic> data = recordDoc.data() as Map<String, dynamic>;
        final String userRolePrefix = widget.isCreator ? "creator" : "joiner";

        setState(() {
          // Kaza Tarihi ve Saati (Sadece creator ise yükle veya her iki taraf için de ortaksa)
          if (data['kazaTimestamp'] != null && data['kazaTimestamp'] is Timestamp) {
            _kazaTarihi = (data['kazaTimestamp'] as Timestamp).toDate();
            _kazaSaati = TimeOfDay.fromDateTime(_kazaTarihi);
          }
          // Adres Bileşenleri (Sadece creator ise yükle veya her iki taraf için de ortaksa)
          _ilceController.text = data['kazaIlce'] ?? '';
          _semtController.text = data['kazaSemt'] ?? '';
          _mahalleController.text = data['kazaMahalle'] ?? '';
          _caddeController.text = data['kazaCadde'] ?? '';
          _sokakController.text = data['kazaSokak'] ?? '';
          _address = data['formattedAddress'] ?? _address; 

          // Tanık Bilgileri (Sadece creator ise yükle)
          if (widget.isCreator && data['taniklar'] != null && data['taniklar'] is List && (data['taniklar'] as List).isNotEmpty) {
            var tanikData = (data['taniklar'] as List).first as Map<String, dynamic>;
            _tanik1AdiSoyadiController.text = tanikData['adiSoyadi'] ?? '';
            _tanik1AdresController.text = tanikData['adresi'] ?? '';
            _tanik1TelController.text = tanikData['telefonu'] ?? '';
          }
          
          // Kullanıcının kendi notları
          _notesController.text = data['${userRolePrefix}Notes'] ?? '';

          // Kullanıcının kendi kaza durumları
          if (data['${userRolePrefix}KazaDurumlari'] != null && data['${userRolePrefix}KazaDurumlari'] is List) {
            _secilenKazaDurumlari.clear();
            _secilenKazaDurumlari.addAll(List<String>.from(data['${userRolePrefix}KazaDurumlari']));
          }
           // Kullanıcının kendi işlenmiş fotoğrafı ve tespitleri
          if (data['${userRolePrefix}ProcessedDamageImageBase64'] != null) {
            _processedImageBytesFromUbuntu = base64Decode(data['${userRolePrefix}ProcessedDamageImageBase64'] as String);
          }
          if (data['${userRolePrefix}DetectionResults'] != null) {
            _detectionResultsFromUbuntu = data['${userRolePrefix}DetectionResults'] as List<dynamic>?;
          }

        });
      }
    } catch (e) {
      print("Başlangıç kaza verileri yüklenirken hata: $e");
      // Hata durumunda adres çekme işlemini yine de başlatabiliriz
    } finally {
        if (mounted) {
             // Adres çekme işlemini, Firestore'dan adres bilgisi yüklenemese bile veya yüklendikten sonra başlat
            _getAddressFromLatLngThenPopulate();
        }
    }
  }
  
  Future<void> _getAddressFromLatLngThenPopulate() async {
    if (!mounted) return;
    bool shouldFetch = _ilceController.text.isEmpty || _mahalleController.text.isEmpty || _caddeController.text.isEmpty || _address == null;

    if (!shouldFetch && _isFetchingAddress) { 
        if(mounted) setState(() => _isFetchingAddress = false);
        return;
    }
    if (!shouldFetch && !_isFetchingAddress) {
        return;
    }

    setState(() {
      _isFetchingAddress = true;
      _addressError = null;
    });
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(
        widget.confirmedPosition.latitude,
        widget.confirmedPosition.longitude,
      );
      if (mounted && placemarks.isNotEmpty) {
        final Placemark place = placemarks.first;
        setState(() {
          // Sadece boşsa otomatik doldur, kullanıcı önceden girdiyse üzerine yazma
          if(_ilceController.text.isEmpty) _ilceController.text = place.subAdministrativeArea ?? place.locality ?? '';
          if(_mahalleController.text.isEmpty) _mahalleController.text = place.subLocality ?? '';
          if(_caddeController.text.isEmpty) _caddeController.text = place.thoroughfare ?? '';
          if(_sokakController.text.isEmpty) _sokakController.text = place.street?.replaceFirst(place.thoroughfare ?? '', '').trim() ?? '';
          
          List<String> addressParts = [];
          if (place.street != null && place.street!.isNotEmpty) addressParts.add(place.street!);
          if (place.thoroughfare != null && place.thoroughfare!.isNotEmpty && (place.street == null || !place.street!.toLowerCase().contains(place.thoroughfare!.toLowerCase()))) {
              addressParts.add(place.thoroughfare!);
          }
          if (place.subLocality != null && place.subLocality!.isNotEmpty) addressParts.add(place.subLocality!);
          if (place.locality != null && place.locality!.isNotEmpty) addressParts.add(place.locality!);
          if (place.administrativeArea != null && place.administrativeArea!.isNotEmpty) addressParts.add(place.administrativeArea!);
          if (place.postalCode != null && place.postalCode!.isNotEmpty) addressParts.add(place.postalCode!);
          String formattedAddress = addressParts.where((part) => part.isNotEmpty).join(', ');
          _address = formattedAddress.replaceAll(RegExp(r',\s*,'), ', ').replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');
          _address = _address!.isNotEmpty ? _address : "Adres detayı bulunamadı.";
        });
      } else if (mounted) {
        setState(() {
          _address = "Adres bilgisi bulunamadı.";
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _addressError = "Adres alınamadı: ${e.toString().characters.take(50)}...";
          _address = null;
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isFetchingAddress = false);
      }
    }
  }

  Future<void> _selectKazaTarihi(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _kazaTarihi,
      firstDate: DateTime(DateTime.now().year - 2), // Son 2 yıl
      lastDate: DateTime.now(),
      locale: const Locale('tr', 'TR'),
      helpText: 'KAZA TARİHİNİ SEÇİN',
      confirmText: 'TAMAM',
      cancelText: 'İPTAL',
    );
    if (picked != null && picked != _kazaTarihi && mounted) {
      setState(() => _kazaTarihi = picked);
    }
  }

  Future<void> _selectKazaSaati(BuildContext context) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: _kazaSaati,
      helpText: 'KAZA SAATİNİ SEÇİN',
      confirmText: 'TAMAM',
      cancelText: 'İPTAL',
      builder: (BuildContext context, Widget? child) {
        return Localizations.override(
          context: context,
          locale: const Locale('tr', 'TR'),
          child: child,
        );
      },
    );
    if (picked != null && picked != _kazaSaati && mounted) {
      setState(() => _kazaSaati = picked);
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
        if (recordData.containsKey('${otherPartyRolePrefix}VehicleInfo') && recordData['${otherPartyRolePrefix}VehicleInfo'] != null && mounted) {
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
                  try { return CrashRegion.values.byName(regionString.toString()); }
                  catch (e) { print("Enum parse error for other party: $regionString, $e"); return null; }
                })
                .whereType<CrashRegion>().toSet();
          });
        }
      }
      
      final otherPartyNotesFieldName = '${otherPartyRolePrefix}Notes';
      if(recordData.containsKey(otherPartyNotesFieldName) && mounted){
        setState(() => _otherPartyNotes = recordData[otherPartyNotesFieldName] as String?);
      }

      final otherPartyKazaDurumlariFieldName = '${otherPartyRolePrefix}KazaDurumlari';
       if (recordData.containsKey(otherPartyKazaDurumlariFieldName) && recordData[otherPartyKazaDurumlariFieldName] is List && mounted) {
         setState(() {
           _otherPartySecilenKazaDurumlari = List<String>.from(recordData[otherPartyKazaDurumlariFieldName]);
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
      if (mounted) setState(() => _isLoadingOtherPartyData = false);
    }
  }

  Future<void> _saveCurrentUserDataToFirestore({
    String? processedImageBase64,
    List<dynamic>? detectionResults,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) throw Exception("Kullanıcı girişi yapılmamış.");

    final String userRolePrefix = widget.isCreator ? "creator" : "joiner";
    final DateTime kazaTamTarihSaat = DateTime(_kazaTarihi.year, _kazaTarihi.month, _kazaTarihi.day, _kazaSaati.hour, _kazaSaati.minute);
    final Timestamp kazaTimestamp = Timestamp.fromDate(kazaTamTarihSaat);

    Map<String, dynamic> dataToUpdate = {
      '${userRolePrefix}VehicleInfo': widget.vehicleInfo,
      '${userRolePrefix}Notes': _notesController.text.trim(),
      '${userRolePrefix}DamageRegions': widget.selectedRegions.map((r) => r.name).toList(),
      '${userRolePrefix}LastUpdateTimestamp': FieldValue.serverTimestamp(),
      '${userRolePrefix}KazaDurumlari': _secilenKazaDurumlari,
    };

    if (processedImageBase64 != null) dataToUpdate['${userRolePrefix}ProcessedDamageImageBase64'] = processedImageBase64;
    if (detectionResults != null) dataToUpdate['${userRolePrefix}DetectionResults'] = detectionResults;

    if (widget.isCreator) {
      dataToUpdate['kazaTimestamp'] = kazaTimestamp;
      dataToUpdate['kazaIlce'] = _ilceController.text.trim().isNotEmpty ? _ilceController.text.trim() : null;
      dataToUpdate['kazaSemt'] = _semtController.text.trim().isNotEmpty ? _semtController.text.trim() : null;
      dataToUpdate['kazaMahalle'] = _mahalleController.text.trim().isNotEmpty ? _mahalleController.text.trim() : null;
      dataToUpdate['kazaCadde'] = _caddeController.text.trim().isNotEmpty ? _caddeController.text.trim() : null;
      dataToUpdate['kazaSokak'] = _sokakController.text.trim().isNotEmpty ? _sokakController.text.trim() : null;
      dataToUpdate['latitude'] = widget.confirmedPosition.latitude;
      dataToUpdate['longitude'] = widget.confirmedPosition.longitude;
      dataToUpdate['formattedAddress'] = _address?.isNotEmpty == true ? _address : null;

      List<Map<String, String>> tanikListesi = [];
      if (_tanik1AdiSoyadiController.text.trim().isNotEmpty) {
        tanikListesi.add({
          'adiSoyadi': _tanik1AdiSoyadiController.text.trim(),
          'adresi': _tanik1AdresController.text.trim(),
          'telefonu': _tanik1TelController.text.trim(),
        });
      }
      if (tanikListesi.isNotEmpty) {
        dataToUpdate['taniklar'] = tanikListesi;
      } else {
        dataToUpdate['taniklar'] = FieldValue.delete(); 
      }
    }

    String currentStatus = widget.isCreator ? 'creator_info_submitted' : 'joiner_info_submitted';
    dataToUpdate['status'] = currentStatus;
    
    final otherPartyRolePrefix = widget.isCreator ? "joiner" : "creator";
    final recordSnapshot = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
    final recordData = recordSnapshot.data();

    if (recordData != null && recordData['${otherPartyRolePrefix}Uid'] != null &&
        (recordData['status'] == 'creator_info_submitted' || recordData['status'] == 'joiner_info_submitted') &&
         recordData['status'] != currentStatus) {
      dataToUpdate['status'] = 'all_data_submitted';
      dataToUpdate['reportFinalizedTimestamp'] = FieldValue.serverTimestamp();
    }
    
    await FirebaseFirestore.instance.collection('records').doc(widget.recordId).set(dataToUpdate, SetOptions(merge: true));
  }

  Future<void> _pickImageForUbuntu() async {
     try {
      final XFile? pickedFile = await _picker.pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 800);
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
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın ve işlenecek bir fotoğraf seçin.')));
      return;
    }
    if (mounted) setState(() => _isProcessingAndSaving = true);
    try {
      File file = File(_selectedImageFileForUbuntu!.path);
      var request = http.MultipartRequest('POST', Uri.parse(_damageDetectionServerUrl));
      request.files.add(await http.MultipartFile.fromPath(
        'image', file.path,
        contentType: MediaType('image', path.extension(file.path).replaceAll('.', '')),
      ));
      var streamedResponse = await request.send().timeout(const Duration(seconds: 90));
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
          await _saveCurrentUserDataToFirestore(processedImageBase64: imageBase64, detectionResults: detections);
          if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf işlendi ve tutanak bilgileri başarıyla kaydedildi!')));
              Navigator.popUntil(context, (route) => route.isFirst);
          }
        } else {
            throw Exception("Sunucudan işlenmiş fotoğraf verisi alınamadı.");
        }
    } else {
        String errorMessage = "Sunucu Hatası (${response.statusCode}): ${response.reasonPhrase}.";
        try {
            final errorData = json.decode(response.body);
            if (errorData['error'] != null) errorMessage += " Detay: ${errorData['error']}";
        } catch (_) {
            errorMessage += " Detay: ${response.body.characters.take(100)}...";
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

  Future<void> _handleReportSubmission() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın.')));
      return;
    }
    if (_formKey.currentState == null || !_formKey.currentState!.validate()) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen * ile işaretli zorunlu alanları doldurun.')));
       return;
    }
    if (widget.selectedRegions.isEmpty && _notesController.text.trim().isEmpty && _selectedImageFileForUbuntu == null && _processedImageBytesFromUbuntu == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen hasar bölgesi, fotoğraf veya not gibi en az bir bilgi girin.')));
        return;
    }

    setState(() {
      _isProcessingAndSaving = true;
      _loadingMessage = "Bilgileriniz kaydediliyor...";
    });
    
    try {
      // ADIM 1: Önce kullanıcının kendi bilgilerini kaydet.
      // Bu mantık if/else bloğundan çıkarılıp birleştirildi.
      if (_selectedImageFileForUbuntu != null && _processedImageBytesFromUbuntu == null) {
          await _processWithUbuntuServerAndSave();
      } else {
          await _saveCurrentUserDataToFirestore(
              processedImageBase64: _processedImageBytesFromUbuntu != null ? base64Encode(_processedImageBytesFromUbuntu!) : null,
              detectionResults: _detectionResultsFromUbuntu
          );
      }

      // ADIM 2: Kaydetme sonrası Firestore'dan belgenin güncel halini tekrar çek.
      print("Kullanıcı verisi kaydedildi, raporun son durumu kontrol ediliyor...");
      final recordDoc = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
      
      // ADIM 3: Raporun durumunu kontrol et ve gerekirse AI sürecini başlat.
      final currentStatus = recordDoc.data()?['status'] as String?;
      print("RAPORUN GÜNCEL DURUMU: $currentStatus"); // DEBUG İÇİN KONSOL ÇIKTISI

      if (mounted && recordDoc.exists && currentStatus == 'all_data_submitted') {
          print("Tüm taraflar onayladı. AI raporu oluşturma süreci başlıyor: ${widget.recordId}");
          
          // Kullanıcıya bilgi ver.
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Tüm bilgiler tamamlandı. AI raporu arka planda oluşturuluyor...'),
              duration: Duration(seconds: 4),
          ));

          // AI raporu oluşturma ve kaydetme işlemini "fire-and-forget" olarak başlat.
          // Bu fonksiyonun bitmesini BEKLEMİYORUZ, böylece kullanıcı ana sayfaya hemen dönebilir.
          _initiateAndFinalizeAiReport(widget.recordId);
      }
      
      // ADIM 4: Kullanıcıyı ana sayfaya yönlendir.
      if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tutanak bilgileriniz başarıyla kaydedildi.')));
          Navigator.popUntil(context, (route) => route.isFirst);
      }

    } catch (e, s) {
        print("Rapor gönderiminde genel hata (_handleReportSubmission): $e\n$s");
        if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Rapor gönderilirken bir hata oluştu: $e')));
        }
    } finally {
        if (mounted) {
            setState(() => _isProcessingAndSaving = false);
        }
    }
  }

  Future<void> _initiateAndFinalizeAiReport(String recordId) async {
    if (!mounted) return;
    
    try {
      print("AI Süreci: Firestore'dan tam veri çekiliyor...");
      final doc = await FirebaseFirestore.instance.collection('records').doc(recordId).get();
      if (!doc.exists) throw Exception("AI Raporu oluşturulacak kayıt bulunamadı.");
      
      print("AI Süreci: Veri hazırlanıyor ve sunucuya gönderiliyor...");
      Map<String, dynamic> dataToSend = await _prepareDataForAi(doc.data()!);
      final String jsonBody = jsonEncode(dataToSend);

      final response = await http.post(
          Uri.parse(_aiPdfServerUrl),
          headers: {'Content-Type': 'application/json; charset=UTF-8'},
          body: jsonBody,
      ).timeout(const Duration(seconds: 120));

      if (response.statusCode != 200) {
          throw Exception("AI PDF sunucusu hatası: ${response.statusCode}. Detay: ${response.body}");
      }
      
      final Uint8List pdfBytes = response.bodyBytes;
      print("AI Süreci: PDF verisi sunucudan alındı. Firebase Storage'a yükleniyor...");

      final storageRef = firebase_storage.FirebaseStorage.instance.ref('ai_reports/$recordId.pdf');
      await storageRef.putData(pdfBytes, firebase_storage.SettableMetadata(contentType: 'application/pdf'));

      final String downloadUrl = await storageRef.getDownloadURL();
      print("AI Süreci: PDF yüklendi. URL Firestore'a kaydediliyor: $downloadUrl");
      
      await FirebaseFirestore.instance.collection('records').doc(recordId).update({
          'aiReportPdfUrl': downloadUrl,
          'aiReportStatus': 'Completed',
      });

      print("AI Raporu başarıyla oluşturuldu ve Firestore'a kaydedildi.");

    } catch(e) {
      print("AI raporunu sonlandırma sürecinde hata: $e");
      try {
        await FirebaseFirestore.instance.collection('records').doc(recordId).update({
            'aiReportStatus': 'Failed',
            'aiReportError': e.toString().substring(0, 200),
        });
      } catch (firestoreError) {
        print("AI hata durumunu Firestore'a yazarken ek hata oluştu: $firestoreError");
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
    return const Text('Karşı taraf henüz işlenmiş fotoğraf eklememiş.', style: TextStyle(fontStyle: FontStyle.italic));
  }

  Widget _buildDateTimePickerRow(ThemeData theme) {
    final DateFormat dateFormat = DateFormat('dd MMMM yyyy, EEEE', 'tr'); 
    final TimeOfDayFormat timeFormat = MediaQuery.of(context).alwaysUse24HourFormat ? TimeOfDayFormat.HH_colon_mm : TimeOfDayFormat.h_colon_mm_space_a;

    return Row(
      children: [
        Expanded(
          child: InkWell(
            onTap: () => _selectKazaTarihi(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Kaza Tarihi',
                prefixIcon: Icon(Icons.calendar_today, color: theme.colorScheme.primary),
              ),
              child: Text(dateFormat.format(_kazaTarihi)),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: InkWell(
            onTap: () => _selectKazaSaati(context),
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Kaza Saati',
                prefixIcon: Icon(Icons.access_time, color: theme.colorScheme.primary),
              ),
              child: Text(_kazaSaati.format(context)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddressDetailFields() {
    return Column(
      children: [
        TextFormField(
            controller: _ilceController,
            decoration: const InputDecoration(labelText: 'İlçe*', prefixIcon: Icon(Icons.location_city)),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'İlçe boş bırakılamaz' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _semtController, decoration: const InputDecoration(labelText: 'Semt/Bucak', prefixIcon: Icon(Icons.holiday_village_outlined))),
        const SizedBox(height: 12),
        TextFormField(
            controller: _mahalleController,
            decoration: const InputDecoration(labelText: 'Mahalle*', prefixIcon: Icon(Icons.signpost_outlined)),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Mahalle boş bırakılamaz' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(
            controller: _caddeController,
            decoration: const InputDecoration(labelText: 'Cadde/Bulvar*', prefixIcon: Icon(Icons.add_road_outlined)),
            validator: (value) => (value == null || value.trim().isEmpty) ? 'Cadde/Bulvar boş bırakılamaz' : null,
        ),
        const SizedBox(height: 12),
        TextFormField(controller: _sokakController, decoration: const InputDecoration(labelText: 'Sokak/Site/No', prefixIcon: Icon(Icons.home_work_outlined))),
      ],
    );
  }

  Widget _buildWitnessFields(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Görgü Tanığı 1 (varsa)", style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(controller: _tanik1AdiSoyadiController, decoration: const InputDecoration(labelText: 'Tanık Adı Soyadı', prefixIcon: Icon(Icons.person_search_outlined))),
        const SizedBox(height: 12),
        TextFormField(controller: _tanik1AdresController, decoration: const InputDecoration(labelText: 'Tanık Adresi', prefixIcon: Icon(Icons.location_on_outlined)), maxLines: 2),
        const SizedBox(height: 12),
        TextFormField(
            controller: _tanik1TelController,
            decoration: const InputDecoration(labelText: 'Tanık Telefonu (5xxxxxxxxx)', prefixIcon: Icon(Icons.phone_outlined)),
            keyboardType: TextInputType.phone,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)]
        ),
      ],
    );
  }

  Widget _buildAccidentCircumstances(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Sizin İçin Geçerli Kaza Durumları (PDF Alan 7)", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Text("Lütfen aşağıdaki maddelerden size uyanları işaretleyiniz.", style: theme.textTheme.bodySmall),
        const SizedBox(height: 8),
        Container(
          constraints: BoxConstraints(maxHeight: 250), 
          decoration: BoxDecoration(
            border: Border.all(color: theme.dividerColor),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Scrollbar(
            thumbVisibility: true,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: kazaDurumlariListesi.length,
              itemBuilder: (context, index) {
                final durum = kazaDurumlariListesi[index];
                return CheckboxListTile(
                  title: Text(durum, style: theme.textTheme.bodyMedium),
                  value: _secilenKazaDurumlari.contains(durum),
                  onChanged: (bool? value) {
                    setState(() {
                      if (value == true) {
                        _secilenKazaDurumlari.add(durum);
                      } else {
                        _secilenKazaDurumlari.remove(durum);
                      }
                    });
                  },
                  controlAffinity: ListTileControlAffinity.leading,
                  activeColor: theme.colorScheme.primary,
                  dense: true, // Daha kompakt görünüm
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildOtherPartyKazaDurumlari(ThemeData theme) {
    if (_isLoadingOtherPartyData) return const SizedBox.shrink();
    if (_otherPartySecilenKazaDurumlari.isEmpty) {
      return const Text('Karşı taraf kaza durumu belirtmemiş.', style: TextStyle(fontStyle: FontStyle.italic));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _otherPartySecilenKazaDurumlari.map((durum) => Padding(
        padding: const EdgeInsets.only(top: 2.0),
        child: Text("• $durum", style: theme.textTheme.bodyMedium),
      )).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Tutanak Özeti ve Onay'),
        ),
        body: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 80.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader(context, "KAZA DETAYLARI", Icons.event_note_outlined),
                _buildInfoCard(
                  title: "Kaza Tarihi ve Saati*",
                  titleIcon: Icons.access_alarm_outlined,
                  children: [ _buildDateTimePickerRow(theme) ]
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: "Detaylı Kaza Yeri*",
                  titleIcon: Icons.map_outlined,
                  children: [
                    if (_isFetchingAddress && _address == null) const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                    if (_addressError != null) Text(_addressError!, style: TextStyle(color: theme.colorScheme.error)),
                    if (_address != null && !_isFetchingAddress) Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Text("Otomatik Alınan Adres: $_address", style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic)),
                    ),
                    _buildAddressDetailFields(),
                    const SizedBox(height: 8),
                     Text("* ile işaretli alanların (İlçe, Mahalle, Cadde) doldurulması zorunludur.", style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
                  ]
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: "Görgü Tanıkları (varsa)",
                  titleIcon: Icons.people_alt_outlined,
                  children: [ _buildWitnessFields(theme) ]
                ),
                
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
                  title: "Kaza Durumları (Beyanınız)",
                  titleIcon: Icons.rule_folder_outlined,
                  children: [ _buildAccidentCircumstances(theme) ],
                ),
                const SizedBox(height: 12),
                _buildInfoCard(
                  title: "Hasar Fotoğrafı ve Notlar",
                  titleIcon: Icons.camera_alt_rounded,
                  children: [
                    _buildPhotoSelectionAndDisplayUI(),
                    const SizedBox(height: 20),
                    Text('Ek Notlarınız/Beyanınız:', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    TextFormField(
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
                : (_otherPartyUserData == null && _otherPartyVehicleData == null && _otherPartySelectedRegions.isEmpty && _otherPartySecilenKazaDurumlari.isEmpty && _otherPartyProcessedImageBase64FromUbuntu == null && _otherPartyNotes == null)
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
                        if (_otherPartyVehicleData != null) const SizedBox(height: 12),
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
                          title: 'Diğer Sürücünün Hasar Bölge(leri)',
                          titleIcon: Icons.car_crash_outlined,
                          children: [_buildRegionsDisplay(_otherPartySelectedRegions, isOwn: false)],
                        ),
                         const SizedBox(height: 12),
                         _buildInfoCard(
                          title: 'Diğer Sürücünün Kaza Durumları Beyanı',
                          titleIcon: Icons.rule_folder_outlined,
                          children: [_buildOtherPartyKazaDurumlari(theme)],
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
                        else if (!_isLoadingOtherPartyData) 
                          _buildInfoCard(
                            title: 'Diğer Sürücünün Hasar Fotoğrafı',
                             titleIcon: Icons.image_not_supported_outlined,
                            children: [const Text("Karşı taraf işlenmiş fotoğraf eklememiş.", style: TextStyle(fontStyle: FontStyle.italic))]
                          ),
                    ]),

                _buildSectionHeader(context, "ORTAK BİLGİLER (Konum)", Icons.map_rounded),
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
                        _buildTextInfoRow('Enlem', widget.confirmedPosition.latitude.toStringAsFixed(5)),
                        _buildTextInfoRow('Boylam', widget.confirmedPosition.longitude.toStringAsFixed(5)),
                        if (_address != null && !_isFetchingAddress) _buildTextInfoRow('Otomatik Adres', _address),
                        if (_isFetchingAddress) const Padding(padding: EdgeInsets.all(8.0), child: Text("Adres yükleniyor...")),
                        if (_addressError != null) Text(_addressError!, style: TextStyle(color: Colors.red)),
                ]),
                const SizedBox(height: 32),
              ],
            ),
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
                  backgroundColor: Colors.green.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
                ),
                onPressed: (){
                  if (_formKey.currentState!.validate()) {
                    _handleReportSubmission();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen * ile işaretli zorunlu alanları ve hatalı girişleri kontrol edin.')),
                    );
                  }
                },
              ),
        ),
      ),
    );
  }
}