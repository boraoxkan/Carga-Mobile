// File: lib/screens/report_summary_page.dart

import 'dart:io';
import 'dart:convert'; // base64 ve json işlemleri için
import 'dart:typed_data'; // Uint8List için
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage; // Alias eklendi
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:path/path.dart' as path;
import 'package:http/http.dart' as http; // HTTP istekleri için
import 'package:http_parser/http_parser.dart'; // MediaType için

// CrashRegion enum'ını projenizdeki doğru yerden import edin
import 'package:tutanak/models/crash_region.dart'; // Proje adınızı kontrol edin

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
  
  XFile? _selectedImageFile; // Ubuntu sunucusu için seçilen tek fotoğraf
  List<XFile> _selectedImageFiles = []; // Firebase Storage için seçilen fotoğraflar (UI şu an yorumlu)
  
  List<String> _firebaseStorageUploadedImageUrls = []; 
  
  Uint8List? _processedImageBytesFromUbuntu;
  List<dynamic>? _detectionResultsFromUbuntu; 

  bool _isProcessingAndSaving = false;

  Map<String, dynamic>? _otherPartyUserData;
  Map<String, dynamic>? _otherPartyVehicleData;
  Set<CrashRegion> _otherPartySelectedRegions = {};
  List<String> _otherPartyFirebaseStorageImageUrls = [];
  String? _otherPartyProcessedImageBase64;
  List<dynamic>? _otherPartyDetectionResults;
  bool _isLoadingOtherPartyData = true;

  final String _ubuntuServerUrl = "http://100.71.209.113:5001/process_damage_image"; 
  final bool _useFirebaseStorageForOwnPhotos = false; // true: Firebase Storage, false: Ubuntu sunucusu

  @override
  void initState() {
    super.initState();
    _fetchOtherPartyData();
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
      String? otherPartyUid;
      String? otherPartyVehicleId; // Bu değişken doğrudan kullanılmıyor gibi, araç bilgisi _otherPartyVehicleData içinde
      String otherPartyRolePrefix = widget.isCreator ? "joiner" : "creator";

      // Karşı tarafın UID'sini ve Araç ID'sini belirle
      // recordId yapınız (ör: creatorUid|creatorVehiclePlate|joinerUid|joinerVehiclePlate) veya
      // Firestore'daki `creatorUid`, `joinerUid` alanlarına göre
      if (widget.isCreator) {
        otherPartyUid = recordData['joinerUid'] as String?;
        // otherPartyVehicleId = recordData['joinerVehicleId'] as String?; // Eğer böyle bir alan varsa
      } else {
        otherPartyUid = recordData['creatorUid'] as String?;
        // otherPartyVehicleId = recordData['creatorVehicleId'] as String?;
      }
      
      if (otherPartyUid != null) {
        final userDoc = await FirebaseFirestore.instance.collection('users').doc(otherPartyUid).get();
        if (userDoc.exists && mounted) {
           _otherPartyUserData = userDoc.data();
        }
        // Karşı tarafın araç bilgisini doğrudan record'dan almayı deneyebiliriz (eğer orada saklanıyorsa)
        // Ya da users koleksiyonu altından
        if (recordData.containsKey('${otherPartyRolePrefix}VehicleInfo') && mounted) {
            _otherPartyVehicleData = recordData['${otherPartyRolePrefix}VehicleInfo'] as Map<String, dynamic>?;
        } else if (otherPartyUid != null && recordData.containsKey('${otherPartyRolePrefix}VehiclePlate')) { // Örnek bir yapı
            // Bu kısım sizin veri modelinize göre ayarlanmalı
            // Örn: String otherPartyPlate = recordData['${otherPartyRolePrefix}VehiclePlate'];
            // Sonra bu plaka ile users/{uid}/vehicles altından araç aranabilir.
            // Şimdilik yukarıdaki 'VehicleInfo' alanını varsayıyoruz.
        }
      }
      
      final otherPartyRegionsFieldName = '${otherPartyRolePrefix}DamageRegions';
      if (recordData.containsKey(otherPartyRegionsFieldName) && recordData[otherPartyRegionsFieldName] is List) {
        List<dynamic> regionsData = recordData[otherPartyRegionsFieldName];
        if (mounted) {
          _otherPartySelectedRegions = regionsData
              .map((regionString) {
                try { return CrashRegion.values.byName(regionString.toString().split('.').last); }
                catch (e) { return null; }
              })
              .whereType<CrashRegion>().toSet();
        }
      }
      
      final otherPartyFsPhotosFieldName = '${otherPartyRolePrefix}DamagePhotos';
      if (recordData.containsKey(otherPartyFsPhotosFieldName) && recordData[otherPartyFsPhotosFieldName] is List && mounted) {
          _otherPartyFirebaseStorageImageUrls = List<String>.from(recordData[otherPartyFsPhotosFieldName]);
      }

      final otherPartyProcessedBase64FieldName = '${otherPartyRolePrefix}ProcessedDamageImageBase64';
      if (recordData.containsKey(otherPartyProcessedBase64FieldName) && recordData[otherPartyProcessedBase64FieldName] is String && mounted) {
          _otherPartyProcessedImageBase64 = recordData[otherPartyProcessedBase64FieldName] as String?;
      }

      final otherPartyDetectionsFieldName = '${otherPartyRolePrefix}DetectionResults';
       if (recordData.containsKey(otherPartyDetectionsFieldName) && recordData[otherPartyDetectionsFieldName] is List && mounted) {
          _otherPartyDetectionResults = recordData[otherPartyDetectionsFieldName] as List<dynamic>?;
      }

    } catch (e,s) {
      print("Karşı taraf verileri çekilirken hata (report_summary_page): $e \n$s");
      // Hata durumunda kullanıcıya bilgi verilebilir.
    } finally {
      if (mounted) setState(() { _isLoadingOtherPartyData = false; });
    }
  }

  Future<void> _saveReportDataToFirestore({
    List<String>? firebaseStorageUrls,
    String? processedImageBase64,
    List<dynamic>? detections,
  }) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception("Kullanıcı girişi yapılmamış."); // Bu hata _handleReportSubmission'da yakalanmalı
    }

    final String userRolePrefix = widget.isCreator ? "creator" : "joiner";
    Map<String, dynamic> dataToSave = {
      '${userRolePrefix}Notes': _notesController.text.trim(),
      '${userRolePrefix}DamageRegions': widget.selectedRegions.map((r) => r.toString()).toList(),
      '${userRolePrefix}LastUpdateTimestamp': FieldValue.serverTimestamp(),
      '${userRolePrefix}VehicleInfo': widget.vehicleInfo, // Araç bilgisi (marka, model, plaka vb.)
    };

    // UID'yi role göre kaydet
    dataToSave['${userRolePrefix}Uid'] = currentUser.uid;


    if (firebaseStorageUrls != null && firebaseStorageUrls.isNotEmpty) {
      dataToSave['${userRolePrefix}DamagePhotos'] = firebaseStorageUrls;
    }

    if (processedImageBase64 != null) {
      dataToSave['${userRolePrefix}ProcessedDamageImageBase64'] = processedImageBase64;
    }
    if (detections != null) {
      dataToSave['${userRolePrefix}DetectionResults'] = detections;
    }

    // Konum ve başlangıç durumu genellikle creator tarafından ayarlanır
    if (widget.isCreator) {
      final recordDocSnapshot = await FirebaseFirestore.instance.collection('records').doc(widget.recordId).get();
      // Sadece konum bilgisi daha önce eklenmemişse ekle
      if (!recordDocSnapshot.exists || recordDocSnapshot.data()?['latitude'] == null) {
        dataToSave['latitude'] = widget.confirmedPosition.latitude;
        dataToSave['longitude'] = widget.confirmedPosition.longitude;
      }
      // Sadece durum bilgisi daha önce eklenmemişse veya güncellenmesi gerekiyorsa
      if (!recordDocSnapshot.exists || recordDocSnapshot.data()?['status'] == null) {
        dataToSave['status'] = 'pending_joiner_input'; // Örnek başlangıç durumu
      }
    } else {
      // Joiner bilgi girdiğinde durumu güncelle
      dataToSave['status'] = 'all_data_submitted'; // Örnek: Tüm veriler tamamlandı
    }

    // Firestore'a yazma işlemi
    // Hata oluşursa, çağıran metoda (örn: _handleReportSubmission) iletilecektir.
    await FirebaseFirestore.instance
        .collection('records')
        .doc(widget.recordId)
        .set(dataToSave, SetOptions(merge: true));
  }


  String _regionLabel(CrashRegion region) {
    switch (region) {
      case CrashRegion.frontLeft: return 'Ön Sol';
      case CrashRegion.frontCenter: return 'Ön Orta';
      case CrashRegion.frontRight: return 'Ön Sağ';
      case CrashRegion.left: return 'Sol Taraf';
      case CrashRegion.right: return 'Sağ Taraf';
      case CrashRegion.rearLeft: return 'Arka Sol';
      case CrashRegion.rearCenter: return 'Arka Orta';
      case CrashRegion.rearRight: return 'Arka Sağ';
      default: return region.name; 
    }
  }

  Widget _buildInfoCard(String title, List<Widget> children, {Color titleColor = Colors.purple}) {
    return Card(
      elevation: 1, 
      margin: const EdgeInsets.only(bottom: 12), 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), 
      child: Padding(
        padding: const EdgeInsets.all(12.0), 
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: titleColor),
            ),
            const Divider(height: 16, thickness: 0.5),
            ...children,
          ],
        ),
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
     try {
      final XFile? pickedFile = await _picker.pickImage(
        source: source,
        imageQuality: 60, 
        maxWidth: 800, 
      );

      if (pickedFile != null) {
        if (!_useFirebaseStorageForOwnPhotos) { // Ubuntu sunucusu için tek fotoğraf
            if(mounted) {
              setState(() {
                  _selectedImageFile = pickedFile; 
                  _processedImageBytesFromUbuntu = null;
                  _detectionResultsFromUbuntu = null;
              });
            }
        } else { // Firebase Storage için çoklu fotoğraf (UI şu an yorumlu)
            if (_selectedImageFiles.length < 5) { 
                if(mounted) {
                  setState(() {
                      _selectedImageFiles.add(pickedFile);
                  });
                }
            } else {
                if(mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('En fazla 5 fotoğraf yükleyebilirsiniz.')),
                    );
                }
            }
        }
      }
    } catch (e) {
      print("Fotoğraf seçme hatası: $e");
       if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fotoğraf seçilirken bir hata oluştu: $e')),
        );
      }
    }
  }

  void _removeImage(int index) { // Çoklu fotoğraf (Firebase Storage) için
    if (mounted) {
      setState(() {
        _selectedImageFiles.removeAt(index);
      });
    }
  }

  void _removeSingleSelectedImage() { // Tek fotoğraf (Ubuntu) için
    if (mounted) {
      setState(() {
        _selectedImageFile = null;
        _processedImageBytesFromUbuntu = null;
        _detectionResultsFromUbuntu = null;
      });
    }
  }

  Future<void> _uploadToFirebaseStorageAndSave() async {
    // Bu metod _useFirebaseStorageForOwnPhotos = true olduğunda çağrılır.
    // Şu anki mantıkta bu bayrak false olduğu için bu metod doğrudan çağrılmayacak.
    // Eğer bayrak true yapılırsa bu metodun çalışması beklenir.
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın.')));
        return;
    }
     if (_selectedImageFiles.isEmpty && _notesController.text.trim().isEmpty && widget.selectedRegions.isEmpty) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen hasar bölgesi, fotoğraf veya not ekleyin.')));
        return;
    }

    if(mounted) setState(() { _isProcessingAndSaving = true; });
    _firebaseStorageUploadedImageUrls.clear(); 

    try {
      if (_selectedImageFiles.isNotEmpty) {
        for (XFile imageFile in _selectedImageFiles) {
          File file = File(imageFile.path);
          String fileName = '${DateTime.now().millisecondsSinceEpoch}_${path.basename(file.path)}';
          
          firebase_storage.Reference storageRef = firebase_storage.FirebaseStorage.instance
              .ref()
              .child('accident_photos')
              .child(widget.recordId) 
              .child(currentUser.uid)   
              .child(fileName);

          firebase_storage.UploadTask uploadTask = storageRef.putFile(file);
          firebase_storage.TaskSnapshot snapshot = await uploadTask;
          String downloadUrl = await snapshot.ref.getDownloadURL();
          _firebaseStorageUploadedImageUrls.add(downloadUrl);
        }
      }

      await _saveReportDataToFirestore(firebaseStorageUrls: _firebaseStorageUploadedImageUrls);
      
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Tutanak bilgileriniz ve fotoğraflarınız Firebase Storage\'a kaydedildi.')),
        );
        Navigator.popUntil(context, (route) => route.isFirst);
      }

    } catch (e, s) {
      print("Firebase Storage'a yükleme veya rapor kaydetme hatası: $e\n$s");
      if(mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Bilgileriniz gönderilirken hata oluştu: $e')),
        );
      }
    } finally {
      if(mounted) setState(() { _isProcessingAndSaving = false; });
    }
  }

  Future<void> _processWithUbuntuServerAndSave() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın.')));
      return;
    }
    if (_selectedImageFile == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen işlenmek üzere bir hasar fotoğrafı seçin.')));
      return;
    }

    if (mounted) setState(() { _isProcessingAndSaving = true; });

    try {
      File file = File(_selectedImageFile!.path);
      var request = http.MultipartRequest('POST', Uri.parse(_ubuntuServerUrl));
      request.files.add(await http.MultipartFile.fromPath(
        'image', file.path,
        contentType: MediaType('image', path.extension(file.path).replaceAll('.', '')),
      ));
      request.fields['record_id'] = widget.recordId;
      request.fields['user_id'] = currentUser.uid;

      var streamedResponse = await request.send().timeout(const Duration(minutes: 3));
      var response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body); // Sunucudan gelen JSON'ı decode et
        final String? imageBase64 = responseData['processed_image_base64'];
        final List<dynamic>? detections = responseData['detections'] as List<dynamic>?; // Tespitleri al

        if (imageBase64 != null) {
            if (mounted) {
                setState(() {
                    _processedImageBytesFromUbuntu = base64Decode(imageBase64); // base64'ü byte'a çevir
                    _detectionResultsFromUbuntu = detections; // Tespitleri state'e ata
                });
            }
            // İşlenmiş fotoğraf (base64) ve tespitler Firestore'a kaydedilecek
            await _saveReportDataToFirestore(
                processedImageBase64: imageBase64, // Base64 string olarak kaydet
                detections: detections // Tespit listesini kaydet
            );

            if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Fotoğraf işlendi ve tutanak bilgileri kaydedildi!')));
                // Kullanıcıyı Raporlar sayfasına veya ana sayfaya yönlendir
                Navigator.popUntil(context, (route) => route.isFirst); // Örnek: Ana sayfaya (HomeScreen) kadar tüm sayfaları kapat
                // Eğer doğrudan raporlar sayfasına gitmek ve o sayfayı yenilemek gerekiyorsa,
                // HomeScreen'deki currentPage'i 'reports' yapacak bir mekanizma veya
                // Raporlar sayfasına özel bir rota ile gitmek gerekebilir.
            }
        } else {
            throw Exception("Sunucudan işlenmiş fotoğraf (base64) alınamadı.");
        }
    } else {
        // Sunucudan gelen hata mesajını daha iyi göstermek için:
        String errorMessage = "Ubuntu Sunucusundan hata (${response.statusCode}): ${response.reasonPhrase}.";
        try {
            final errorData = json.decode(response.body);
            if (errorData['error'] != null) {
                errorMessage += " Detay: ${errorData['error']}";
                if (errorData['details'] != null) {
                  errorMessage += " (${errorData['details']})";
                }
            }
        } catch (_) {
            // JSON parse edilemezse ham body'i ekle
            errorMessage += " Detay: ${response.body}";
        }
        throw Exception(errorMessage);
    }
    } catch (e, s) {
      print("Ubuntu sunucu ile fotoğraf işleme/kaydetme hatası: $e\n$s");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Fotoğraf işlenirken/kaydedilirken hata: $e')));
    } finally {
      if (mounted) setState(() { _isProcessingAndSaving = false; });
    }
  }

  Future<void> _handleReportSubmission() async {
     final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen giriş yapın.')));
      return;
    }

    if (_selectedImageFile == null && _selectedImageFiles.isEmpty && widget.selectedRegions.isEmpty && _notesController.text.trim().isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lütfen hasar bölgesi, fotoğraf veya not ekleyin.')));
        return;
    }
    
    // setState burada çağrılmalı çünkü _isProcessingAndSaving hemen güncellenmeli
    if(mounted) setState(() { _isProcessingAndSaving = true; });

    try {
      if (_useFirebaseStorageForOwnPhotos) {
          // Eğer Firebase Storage kullanılacaksa (şu an false)
          if (_selectedImageFiles.isNotEmpty || widget.selectedRegions.isNotEmpty || _notesController.text.trim().isNotEmpty) {
              await _uploadToFirebaseStorageAndSave(); // Bu metod kendi içinde _saveReportDataToFirestore'u çağırır
          }
      } else {
          // Ubuntu sunucusu kullanılacaksa
          if (_selectedImageFile != null) { // Ubuntu için tek fotoğraf işleme
              await _processWithUbuntuServerAndSave(); // Bu metod kendi içinde _saveReportDataToFirestore'u çağırır
          } else if (widget.selectedRegions.isNotEmpty || _notesController.text.trim().isNotEmpty) {
              // Fotoğraf yok ama diğer bilgiler var, sadece Firestore'a kaydet
              await _saveReportDataToFirestore(); // Sadece notlar ve bölgeler kaydedilir
              if(mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tutanak bilgileriniz (fotoğrafsız) kaydedildi.')));
                  Navigator.popUntil(context, (route) => route.isFirst);
              }
          }
      }
    } catch (e,s) {
        // _saveReportDataToFirestore veya diğer alt metodlardan gelen hatalar burada yakalanabilir
        // veya zaten o metodlar içinde ScaffoldMessenger gösteriliyor.
        print("Rapor gönderiminde genel hata (_handleReportSubmission): $e\n$s");
        if(mounted && !_isProcessingAndSaving) { // Hata durumunda _isProcessingAndSaving false ise (alt metodlarda zaten ayarlandıysa) tekrar gösterme
             // Alt metodlarda zaten SnackBar gösterildiyse burada tekrar göstermeye gerek yok.
             // Ancak, eğer _saveReportDataToFirestore gibi bir metod doğrudan burada çağrılıp hata verirse SnackBar gerekebilir.
             // Mevcut yapıda _process... ve _upload... metodları kendi SnackBar'larını gösteriyor.
        }
    } finally {
        // _isProcessingAndSaving durumu _uploadToFirebaseStorageAndSave ve _processWithUbuntuServerAndSave içinde
        // zaten false yapılıyor. Eğer bu metodlar çağrılmazsa (örn, sadece not kaydı) burada false yapılmalı.
        // Ancak şu anki akışta her zaman bir alt metod çağrılıyor gibi duruyor.
        // En güvenlisi, eğer bir işlem yapıldıysa (veya hata oluştuysa) burada da false yapmak:
        if(mounted && _isProcessingAndSaving) { // Eğer hala true ise (örn. fotoğrafsız kayıt başarılı olduysa ama pop olmadıysa)
           setState(() { _isProcessingAndSaving = false; });
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutanak Bilgi Girişi'),
        backgroundColor: Colors.purple,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text("SİZİN BİLGİLERİNİZ", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.deepPurple, fontWeight: FontWeight.bold)),
            const Divider(thickness: 1, height: 20),
            _buildInfoCard('Aracınızdaki Hasar Bölgeleri', [
              widget.selectedRegions.isEmpty
                ? const Text('Hasar bölgesi seçilmemiş.', style: TextStyle(fontStyle: FontStyle.italic))
                : Wrap(spacing: 8, runSpacing: 4, children: widget.selectedRegions.map((r) => Chip(
                      label: Text(_regionLabel(r)), backgroundColor: Colors.purple.shade50,
                      labelStyle: const TextStyle(color: Colors.purple), side: BorderSide(color: Colors.purple.shade200),
                  )).toList(),
                ),
            ]),
            _buildInfoCard('Araç Bilgileriniz', [
              Text('Marka: ${widget.vehicleInfo['brand'] ?? 'Belirtilmemiş'}'), const SizedBox(height: 4),
              Text('Model: ${widget.vehicleInfo['model'] ?? 'Belirtilmemiş'}'), const SizedBox(height: 4),
              Text('Plaka: ${widget.vehicleInfo['plate'] ?? 'Belirtilmemiş'}'),
            ]),
            const SizedBox(height: 10),
            Text(
              _useFirebaseStorageForOwnPhotos 
                ? 'Hasarlı Araç Fotoğraflarınız (En fazla 5 adet):' 
                : 'Hasarlı Araç Fotoğrafınız (1 adet, sunucuda işlenecek):', 
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.purple)
            ),
            const SizedBox(height: 10),
            _buildPhotoSelectionAndDisplayUI(),
            const SizedBox(height: 20),
            Text('Ek Notlarınız (İsteğe Bağlı):', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.purple)),
            const SizedBox(height: 10),
            TextField(
              controller: _notesController, maxLines: 4,
              decoration: InputDecoration(
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                hintText: 'Kaza ile ilgili eklemek istediğiniz detaylar...',
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              ),
            ),
            const SizedBox(height: 30),

            Text("KARŞI TARAFIN BİLGİLERİ", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.orange.shade800, fontWeight: FontWeight.bold)),
            const Divider(thickness: 1, height: 20, color: Colors.orange),
             _isLoadingOtherPartyData
              ? const Center(child: Padding(padding: EdgeInsets.symmetric(vertical: 20.0), child: CircularProgressIndicator()))
              : (_otherPartyUserData == null && _otherPartyVehicleData == null && 
                 _otherPartySelectedRegions.isEmpty && 
                 _otherPartyFirebaseStorageImageUrls.isEmpty &&
                 _otherPartyProcessedImageBase64 == null)
                  ? _buildInfoCard('Diğer Sürücü Bilgileri', [const Text('Karşı taraf henüz bilgi girişi yapmamış veya bilgiler alınamadı.', style: TextStyle(fontStyle: FontStyle.italic))], titleColor: Colors.orange.shade700)
                  : Column(children: [
                      if (_otherPartyUserData != null)
                        _buildInfoCard('Diğer Sürücü Bilgileri', [
                            Text('Ad Soyad: ${_otherPartyUserData!['isim'] ?? 'N/A'} ${_otherPartyUserData!['soyisim'] ?? ''}'),
                            const SizedBox(height: 4), Text('Telefon: ${_otherPartyUserData!['telefon'] ?? 'N/A'}'),
                        ], titleColor: Colors.orange.shade700),
                      if (_otherPartyVehicleData != null)
                        _buildInfoCard('Diğer Sürücünün Araç Bilgileri', [
                            // _otherPartyVehicleData'nın Map<String, dynamic> olduğunu varsayıyoruz.
                            Text('Marka: ${_otherPartyVehicleData!['brand'] ?? (_otherPartyVehicleData!['marka'] ?? 'N/A')}'),
                            const SizedBox(height: 4), Text('Model: ${_otherPartyVehicleData!['model'] ?? (_otherPartyVehicleData!['seri'] ?? 'N/A')}'),
                            const SizedBox(height: 4), Text('Plaka: ${_otherPartyVehicleData!['plate'] ?? (_otherPartyVehicleData!['plaka'] ?? 'N/A')}'),
                        ], titleColor: Colors.orange.shade700),
                      _buildInfoCard('Diğer Sürücünün Seçtiği Hasar Bölge(leri)',[
                          _otherPartySelectedRegions.isEmpty
                              ? const Text('Karşı taraf hasar bölgesi seçmemiş.', style: TextStyle(fontStyle: FontStyle.italic))
                              : Wrap(spacing: 8, runSpacing: 4, children: _otherPartySelectedRegions.map((r) => Chip(
                                      label: Text(_regionLabel(r)), backgroundColor: Colors.orange.shade50,
                                      labelStyle: TextStyle(color: Colors.orange.shade700), side: BorderSide(color: Colors.orange.shade200),
                                  )).toList(),
                                ),
                        ], titleColor: Colors.orange.shade700),
                       if (_otherPartyProcessedImageBase64 != null)
                        _buildInfoCard('Diğer Sürücünün İşlenmiş Fotoğrafı (Sunucu)', [
                            Center(child: Image.memory(base64Decode(_otherPartyProcessedImageBase64!), height: 200, fit: BoxFit.contain)),
                            if (_otherPartyDetectionResults != null && _otherPartyDetectionResults!.isNotEmpty) ...[
                                const SizedBox(height: 8),
                                const Text("Tespitler:", style: TextStyle(fontWeight: FontWeight.bold)),
                                ..._otherPartyDetectionResults!.map((d) {
                                  final detectionMap = d as Map<String, dynamic>;
                                  return Text("  - ${detectionMap['label'] ?? 'Bilinmiyor'} (%${((detectionMap['confidence'] ?? 0.0) * 100).toStringAsFixed(0)})");
                                }).toList(),
                            ]
                        ], titleColor: Colors.orange.shade700),
                       if (_otherPartyFirebaseStorageImageUrls.isNotEmpty)
                        _buildInfoCard('Diğer Sürücünün Yüklediği Orijinal Fotoğraflar (Storage)', [
                            GridView.builder(
                                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                                itemCount: _otherPartyFirebaseStorageImageUrls.length,
                                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
                                itemBuilder: (context, index) {
                                    // TODO: onTap ile büyütme eklenebilir.
                                    return InkWell( 
                                      onTap: () { /* Fotoğrafı büyütme implementasyonu */ },
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(8.0),
                                        child: Image.network(
                                          _otherPartyFirebaseStorageImageUrls[index], 
                                          fit: BoxFit.cover,
                                          loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                            if (loadingProgress == null) return child;
                                            return Center(child: CircularProgressIndicator( value: loadingProgress.expectedTotalBytes != null ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes! : null,));
                                          },
                                          errorBuilder: (context, error, stackTrace) => const Icon(Icons.error),
                                        )
                                      )
                                    );
                                },
                            )
                          ], titleColor: Colors.orange.shade700
                        ),
                  ]),
            const SizedBox(height: 30),

            Text("ORTAK BİLGİLER", style: Theme.of(context).textTheme.headlineSmall?.copyWith(color: Colors.blueGrey, fontWeight: FontWeight.bold)),
            const Divider(thickness: 1, height: 20, color: Colors.blueGrey),
            _buildInfoCard('Onaylanan Kaza Konumu', [
                SizedBox(
                  height: 150,
                  child: AbsorbPointer( // Harita etkileşimini engelle
                    child: GoogleMap(
                      initialCameraPosition: CameraPosition(target: widget.confirmedPosition, zoom: 16),
                      markers: {Marker(markerId: const MarkerId('accidentLocation'), position: widget.confirmedPosition)},
                      scrollGesturesEnabled: false, zoomGesturesEnabled: false, rotateGesturesEnabled: false, tiltGesturesEnabled: false,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text('Enlem: ${widget.confirmedPosition.latitude.toStringAsFixed(5)}'),
                Text('Boylam: ${widget.confirmedPosition.longitude.toStringAsFixed(5)}'),
             ], titleColor: Colors.blueGrey.shade700),
            const SizedBox(height: 24),

            _isProcessingAndSaving
            ? const Center(child: CircularProgressIndicator())
            : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green, minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
              ),
              onPressed: (_selectedImageFile == null && _selectedImageFiles.isEmpty && widget.selectedRegions.isEmpty && _notesController.text.trim().isEmpty)
                         ? null // Eğer hiçbir bilgi girilmemişse butonu pasif yap
                         : _handleReportSubmission,
              child: const Text('Tutanak Bilgilerimi Gönder'),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildPhotoSelectionAndDisplayUI() {
    if (!_useFirebaseStorageForOwnPhotos) {
      // --- UBUNTU SUNUCUSU İÇİN TEK FOTOĞRAF MANTIĞI ---
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_processedImageBytesFromUbuntu != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Sunucuda İşlenmiş Fotoğraf:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Center(child: Image.memory(_processedImageBytesFromUbuntu!, fit: BoxFit.contain, height: 250)),
                const SizedBox(height: 8),
                if (_detectionResultsFromUbuntu != null && _detectionResultsFromUbuntu!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Tespit Edilenler:", style: TextStyle(fontWeight: FontWeight.bold)),
                        ..._detectionResultsFromUbuntu!.map((d) {
                          final detectionMap = d as Map<String, dynamic>;
                          return Text("  - ${detectionMap['label'] ?? 'Bilinmiyor'} (%${((detectionMap['confidence'] ?? 0.0) * 100).toStringAsFixed(0)})");
                        }).toList(),
                      ],
                    )
                  ),
                const SizedBox(height: 10),
                Center(child: TextButton.icon(icon: const Icon(Icons.delete_outline, color: Colors.red), label: const Text("Bu Fotoğrafı ve Seçimi Kaldır", style: TextStyle(color: Colors.red)), onPressed: _removeSingleSelectedImage)),
                const Divider(height: 20),
              ],
            ),
          
          if (_processedImageBytesFromUbuntu == null && _selectedImageFile == null)
            Center(
              child: TextButton.icon(
                style: TextButton.styleFrom(foregroundColor: Colors.purple, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.purple.shade300))),
                icon: const Icon(Icons.add_a_photo_outlined, size: 22),
                label: const Text('Hasar Fotoğrafı Seç (1 Adet)', style: TextStyle(fontSize: 16)),
                onPressed: _isProcessingAndSaving ? null : () { 
                  showModalBottomSheet(context: context, builder: (BuildContext bc) {
                      return SafeArea(child: Wrap(children: <Widget>[
                          ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeriden Seç'), onTap: () { _pickImage(ImageSource.gallery); Navigator.of(context).pop(); }),
                          ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Kamerayla Çek'), onTap: () { _pickImage(ImageSource.camera); Navigator.of(context).pop(); }),
                      ]));
                  });
                },
              ),
            ),

          if (_processedImageBytesFromUbuntu == null && _selectedImageFile != null)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Seçilen Fotoğraf (Sunucuya Gönderilecek):", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    Center(child: Image.file(File(_selectedImageFile!.path), fit: BoxFit.contain, height: 250)),
                    Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
                      child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: _removeSingleSelectedImage),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Center(child: Text("Yukarıdaki 'Gönder' butonu ile bu fotoğraf sunucuda işlenecek ve kaydedilecektir.", textAlign: TextAlign.center, style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey.shade700))),
                const Divider(height: 20),
              ],
            ),
        ],
      );
    } 
    // Firebase Storage için çoklu fotoğraf UI'ı (şu an yorumlu)
    // else {
    //   return Column(
    //     crossAxisAlignment: CrossAxisAlignment.start,
    //     children: [
    //       if (_selectedImageFiles.isNotEmpty)
    //         GridView.builder(
    //           shrinkWrap: true,
    //           physics: const NeverScrollableScrollPhysics(),
    //           itemCount: _selectedImageFiles.length,
    //           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
    //           itemBuilder: (context, index) {
    //             return Stack(
    //               alignment: Alignment.topRight,
    //               children: [
    //                 ClipRRect(borderRadius: BorderRadius.circular(8.0), child: Image.file(File(_selectedImageFiles[index].path), fit: BoxFit.cover, width: double.infinity, height: double.infinity)),
    //                 Container(margin: const EdgeInsets.all(2), decoration: BoxDecoration(color: Colors.black.withOpacity(0.6), shape: BoxShape.circle),
    //                   child: IconButton(padding: EdgeInsets.zero, constraints: const BoxConstraints(), icon: const Icon(Icons.close, color: Colors.white, size: 18), onPressed: () => _removeImage(index)),
    //                 ),
    //               ],
    //             );
    //           },
    //         ),
    //       if (_selectedImageFiles.length < 5)
    //         Padding(
    //           padding: EdgeInsets.only(top: _selectedImageFiles.isEmpty ? 0 : 8.0),
    //           child: Center(
    //             child: TextButton.icon(
    //               style: TextButton.styleFrom(foregroundColor: Colors.purple, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.purple.shade300))),
    //               icon: const Icon(Icons.add_a_photo_outlined, size: 22),
    //               label: const Text('Fotoğraf Ekle', style: TextStyle(fontSize: 16)),
    //               onPressed: _isProcessingAndSaving ? null : () { 
    //                  showModalBottomSheet(context: context, builder: (BuildContext bc) {
    //                     return SafeArea(child: Wrap(children: <Widget>[
    //                         ListTile(leading: const Icon(Icons.photo_library), title: const Text('Galeriden Seç'), onTap: () { _pickImage(ImageSource.gallery); Navigator.of(context).pop(); }),
    //                         ListTile(leading: const Icon(Icons.photo_camera), title: const Text('Kamerayla Çek'), onTap: () { _pickImage(ImageSource.camera); Navigator.of(context).pop(); }),
    //                     ]));
    //                   });
    //               },
    //             ),
    //           ),
    //         ),
    //     ],
    //   );
    // }
    // Şimdilik Firebase Storage kısmı yorumlu, sadece Ubuntu akışı aktif:
    return Container(); // Firebase Storage aktif edilince bu kısım doldurulacak veya yukarıdaki blok aktif edilecek.
  }
}