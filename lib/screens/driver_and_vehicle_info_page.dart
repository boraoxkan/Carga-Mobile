// lib/screens/driver_and_vehicle_info_page.dart
// Hata Düzeltmeleri ve Print Eklentileri:
// 1. VehicleAddPage referansları kaldırıldı.
// 2. QRDisplayPage çağrısındaki parametre adı 'qrData' -> 'recordId' olarak düzeltildi.
// 3. QR verisi oluşturma öncesi ve sonrası için print eklendi.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

// Diğer sayfaların importları
import 'qr_display_page.dart';
import 'qr_scanner_page.dart';
// import 'vehicle_add_page.dart'; // Kaldırıldı

class DriverAndVehicleInfoPage extends StatefulWidget {
  /// isJoining: true ise “Yeni Tutanak’a Dahil Ol” akışı,
  /// false ise “Yeni Tutanak Oluştur” akışı.
  final bool isJoining;

  const DriverAndVehicleInfoPage({Key? key, required this.isJoining})
      : super(key: key);

  @override
  _DriverAndVehicleInfoPageState createState() =>
      _DriverAndVehicleInfoPageState();
}

class _DriverAndVehicleInfoPageState extends State<DriverAndVehicleInfoPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? selectedVehicleId;
  List<Map<String, dynamic>> vehiclesList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    // Widget ağaca bağlı değilse veya zaten yükleniyorsa işlem yapma
    if (!_isLoading && mounted) {
       setState(() => _isLoading = true);
    } else if (!mounted) {
        print("_loadInitialData çağrıldı ama widget mount edilmemiş.");
        return;
    } else {
        // print("_loadInitialData zaten çalışıyor, tekrar tetiklenmedi.");
        // return; // Yükleme sırasında tekrar tetiklemeyi engellemek için
    }


    try {
      print("_loadInitialData: Sürücü bilgileri yükleniyor...");
      await _loadDriverInfo();
      // Widget hala ağaca bağlı mı?
      if (!mounted) {
         print("_loadInitialData: Sürücü bilgileri yüklendikten sonra widget mount edilmemiş.");
         return;
      }
      print("_loadInitialData: Araç bilgileri yükleniyor...");
      await _loadVehicles();
      print("_loadInitialData: Yükleme tamamlandı.");
    } catch (e, s) {
      print("HATA: Sürücü/Araç bilgileri yüklenirken hata oluştu: $e");
      print("Stack Trace: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bilgiler yüklenirken bir hata oluştu.")),
        );
      }
    } finally {
       // Sonunda isLoading durumunu güncelle (eğer widget hala bağlıysa)
       if (mounted) {
          print("_loadInitialData: isLoading false olarak ayarlanıyor.");
          setState(() => _isLoading = false);
       } else {
          print("_loadInitialData: finally bloğu çalıştı ama widget mount edilmemiş.");
       }
    }
  }

  Future<void> _loadDriverInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      print("_loadDriverInfo: Kullanıcı girişi yapılmamış.");
      if (mounted) {
         _nameController.text = "Giriş Yapılmamış";
         _phoneController.text = "";
      }
      return;
    }
    print("_loadDriverInfo: Firestore'dan ${user.uid} için veri çekiliyor...");
    try {
       final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!mounted) {
         print("_loadDriverInfo: Veri çekildikten sonra widget mount edilmemiş.");
         return; // Widget ağaçtan kaldırıldıysa işlem yapma
      }

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        print("_loadDriverInfo: Sürücü verisi bulundu: $data");
        final isim = data['isim']?.toString() ?? '';
        final soyisim = data['soyisim']?.toString() ?? '';
        _nameController.text = "$isim $soyisim".trim();
        _phoneController.text = data['telefon']?.toString() ?? '';
      } else {
        print("_loadDriverInfo: Sürücü bilgisi Firestore'da bulunamadı: ${user.uid}");
        _nameController.text = "Profil Bilgisi Yok";
        _phoneController.text = "";
      }
    } catch (e, s) {
       print("HATA: Firestore'dan sürücü bilgisi alınırken: $e");
       print("Stack Trace: $s");
       if (mounted) {
          _nameController.text = "Hata Oluştu";
          _phoneController.text = "";
       }
    }
  }

  Future<void> _loadVehicles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
       print("_loadVehicles: Kullanıcı null, işlem iptal.");
       return;
    }
    print("_loadVehicles: Firestore'dan ${user.uid} için araçlar çekiliyor...");
    try {
       final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .get(const GetOptions(source: Source.serverAndCache));

       if (!mounted) {
          print("_loadVehicles: Veri çekildikten sonra widget mount edilmemiş.");
          return; // Widget ağaçtan kaldırıldıysa işlem yapma
       }

        print("_loadVehicles: ${snap.docs.length} adet araç bulundu.");
        vehiclesList = snap.docs.map((d) {
           final data = d.data();
           data['id'] = d.id;
           return data;
        }).toList();

        if (vehiclesList.isNotEmpty) {
           // Seçili araç ID'sini güncelle veya ilk aracı seç
           if (selectedVehicleId == null || !vehiclesList.any((v) => v['id'] == selectedVehicleId)) {
              selectedVehicleId = vehiclesList.first['id'] as String?;
              print("_loadVehicles: İlk araç seçildi: $selectedVehicleId");
           } else {
               print("_loadVehicles: Mevcut seçili araç korundu: $selectedVehicleId");
           }
        } else {
           print("_loadVehicles: Kullanıcının aracı bulunamadı.");
           selectedVehicleId = null;
        }

    } catch (e, s) {
       print("HATA: Firestore'dan araç bilgisi alınırken: $e");
       print("Stack Trace: $s");
       if (mounted) {
          vehiclesList = [];
          selectedVehicleId = null;
       }
    }
  }

  // Tüm araçları gösteren dialog
  void _showAllVehiclesDialog() {
     print("_showAllVehiclesDialog açılıyor...");
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Araç Seçimi"),
        content: SizedBox(
          width: double.maxFinite,
          child: vehiclesList.isEmpty
              ? const Text("Gösterilecek başka araç yok.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: vehiclesList.length,
                  itemBuilder: (_, i) {
                    final v = vehiclesList[i];
                    final marka = v['marka']?.toString() ?? 'Bilinmiyor';
                    final seri = v['seri']?.toString() ?? '';
                    final plaka = v['plaka']?.toString() ?? 'Plaka Yok';
                    final vehicleId = v['id'] as String?;
                    final isSelected = selectedVehicleId == vehicleId;

                    return ListTile(
                      title: Text("$marka - $seri - $plaka"),
                      tileColor: isSelected ? Colors.green.shade50 : null,
                      onTap: () {
                        print("Dialog: Araç seçildi - ID: $vehicleId");
                        if (vehicleId != null && mounted) {
                           setState(() => selectedVehicleId = vehicleId);
                        }
                        Navigator.pop(context); // Dialog'u kapat
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () {
               print("Dialog: Kapat butonuna basıldı.");
               Navigator.pop(context);
            },
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  // Araç seçim kutularını oluşturan widget
  Widget _buildVehicleSelectionBox() {
    // Araç listesi boşsa sadece mesaj göster
    if (vehiclesList.isEmpty) {
       print("_buildVehicleSelectionBox: Araç listesi boş.");
      return const Center(
        child: Padding( // Biraz dolgu ekleyelim
           padding: EdgeInsets.symmetric(vertical: 20.0),
           child: Text("Henüz araç eklenmemiş."),
        )
      );
    }

    print("_buildVehicleSelectionBox: ${vehiclesList.length} araç için kutular oluşturuluyor.");
    final itemCount = vehiclesList.length;
    final displayCount = itemCount > 3 ? 3 : itemCount;
    final showMoreButton = itemCount > 3;

    return SizedBox(
      height: 120,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: showMoreButton ? displayCount + 1 : displayCount,
        itemBuilder: (_, i) {
          // "Diğer" butonu
          if (showMoreButton && i == displayCount) {
            return GestureDetector(
              onTap: _showAllVehiclesDialog,
              child: Container(
                width: 120,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.blueAccent),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Center(
                  child: Text( "Diğer Araçlar", textAlign: TextAlign.center, style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold), ),
                ),
              ),
            );
          }

          // Normal araç kartı
          final v = vehiclesList[i];
          final vehicleId = v['id'] as String?;
          final isSelected = selectedVehicleId == vehicleId;
          final marka = v['marka']?.toString() ?? '-';
          final seri = v['seri']?.toString() ?? '-';
          final plaka = v['plaka']?.toString() ?? '-';

          return GestureDetector(
            onTap: vehicleId == null ? null : () {
               print("Araç kutusuna tıklandı: ID $vehicleId");
               if (mounted) {
                  setState(() => selectedVehicleId = vehicleId);
               }
            } ,
            child: Container(
              width: 120,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                border: Border.all( color: isSelected ? Colors.green.shade600 : Colors.grey.shade400, width: isSelected ? 2.0 : 1.0),
                borderRadius: BorderRadius.circular(8),
                color: isSelected ? Colors.green.shade50 : Colors.white,
              ),
              padding: const EdgeInsets.all(8),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(marka, style: const TextStyle(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(seri, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Text(plaka, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
     print("DriverAndVehicleInfoPage: Build metodu çalıştı. isLoading: $_isLoading");
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isJoining ? "Tutanağa Katıl" : "Yeni Tutanak Oluştur"),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData, // Aşağı çekince yenileme
              child: SingleChildScrollView(
                  // RefreshIndicator ile kaydırma çakışmaması için
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(16),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Sürücü bilgileri kartı
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12)),
                          child: Padding( padding: const EdgeInsets.all(16), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                const Text("Sürücü Bilgileri", style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold)),
                                const SizedBox(height: 16),
                                TextFormField( controller: _nameController, readOnly: true, decoration: InputDecoration( labelText: "İsim Soyisim", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade100, ), ),
                                const SizedBox(height: 16),
                                TextFormField( controller: _phoneController, readOnly: true, decoration: InputDecoration( labelText: "Telefon Numarası", border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), filled: true, fillColor: Colors.grey.shade100, ), keyboardType: TextInputType.phone, ),
                              ], ), ), ),
                        const SizedBox(height: 24),

                        // Araç seçimi kartı
                        Card(
                          elevation: 2,
                          shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(12)),
                          child: Padding( padding: const EdgeInsets.all(16), child: Column( crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Row( mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                                    const Text("Araç Seçimi", style: TextStyle( fontSize: 18, fontWeight: FontWeight.bold)),
                                    IconButton( icon: const Icon(Icons.refresh), onPressed: _loadInitialData, tooltip: "Araç listesini yenile", ), ], ),
                                const SizedBox(height: 8),
                                _buildVehicleSelectionBox(),
                              ], ), ), ),
                        const SizedBox(height: 24),

                        // Devam Et butonu
                        ElevatedButton(
                          style: ElevatedButton.styleFrom( minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder( borderRadius: BorderRadius.circular(8), ), ),
                          // Araç seçili değilse buton pasif
                          onPressed: selectedVehicleId == null ? null : () {
                              print("Devam Et butonuna basıldı.");
                              // selectedVehicleId null kontrolü (buton zaten pasif olmalı ama garanti)
                              if (selectedVehicleId == null) {
                                 print("HATA: selectedVehicleId null olduğu halde butona basıldı!");
                                 return;
                              }

                              final currentUser = FirebaseAuth.instance.currentUser;
                              if (currentUser == null) {
                                 print("HATA: Devam Et'e basıldı ama currentUser null!");
                                 ScaffoldMessenger.of(context).showSnackBar( const SnackBar(content: Text("İşleme devam etmek için giriş yapmalısınız.")), );
                                 return;
                              }

                              if (widget.isJoining) {
                                print("Yönlendirme: QRScannerPage'e gidiliyor...");
                                // Katılan kullanıcı → QR okuma
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QRScannerPage(
                                      joinerVehicleId: selectedVehicleId!,
                                    ),
                                  ),
                                );
                              } else {
                                print("Yönlendirme: QRDisplayPage'e gidiliyor...");
                                // Oluşturan kullanıcı → QR görüntüleme

                                // --- PRINT EKLEMESİ BAŞLANGICI ---
                                print("--- QR Verisi Oluşturuluyor ---");
                                print("Kullanıcı UID: ${currentUser.uid}");
                                print("Seçili Araç ID: $selectedVehicleId");
                                // --- PRINT EKLEMESİ SONU ---

                                final qrData = "${currentUser.uid}|$selectedVehicleId";

                                // --- PRINT EKLEMESİ BAŞLANGICI ---
                                print("Oluşturulan QR Verisi (recordId için): $qrData");
                                // --- PRINT EKLEMESİ SONU ---

                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QRDisplayPage(recordId: qrData), // Parametre adı 'recordId'
                                  ),
                                );
                              }
                            },
                          child: const Text("Devam Et"),
                        ),
                      ],
                    ),
                  ),
                ),
            ),
    );
  }
}