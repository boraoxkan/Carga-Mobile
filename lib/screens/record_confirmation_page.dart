// File: lib/screens/record_confirmation_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_selection_page.dart';

class RecordConfirmationPage extends StatefulWidget {
  final String qrData;           // Okunan ham veri: creatorUid|creatorVehicleId
  final String joinerVehicleId;  // Katılanın kendi seçtiği AraçID

  const RecordConfirmationPage({
    Key? key,
    required this.qrData,
    required this.joinerVehicleId,
  }) : super(key: key);

  @override
  _RecordConfirmationPageState createState() => _RecordConfirmationPageState();
}

class _RecordConfirmationPageState extends State<RecordConfirmationPage> {
  Future<Map<String, dynamic>>? _infoFuture;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    setState(() {
      _infoFuture = _fetchAllInfo();
    });
  }

  Future<Map<String, dynamic>> _fetchAllInfo() async {
    final firestore = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      throw Exception('İşlem için kullanıcı girişi gerekli.');
    }
    final joinerUid = currentUser.uid;

    final parts = widget.qrData.split('|');
    if (parts.length != 2) {
      throw Exception('Geçersiz QR verisi formatı: ${widget.qrData}');
    }
    final creatorUid = parts[0];
    final creatorVehicleId = parts[1];

    // 1) Oluşturan kullanıcı verisi
    final creatorSnap = await firestore.collection('users').doc(creatorUid).get();
    if (!creatorSnap.exists) {
      throw Exception('QR koduna sahip sürücü bilgisi bulunamadı (ID: $creatorUid).');
    }
    final creatorData = creatorSnap.data()!;

    // 2) Oluşturanın araç verisi
    final creatorVehicleSnap = await firestore
        .collection('users')
        .doc(creatorUid)
        .collection('vehicles')
        .doc(creatorVehicleId)
        .get();
    if (!creatorVehicleSnap.exists) {
      throw Exception('QR koduna sahip sürücünün aracı bulunamadı (Araç ID: $creatorVehicleId).');
    }
    final creatorVehicleData = creatorVehicleSnap.data()!;

    // 3) Katılan kullanıcı verisi
    final joinerSnap = await firestore.collection('users').doc(joinerUid).get();
    if (!joinerSnap.exists) {
      throw Exception('Kendi sürücü bilginiz bulunamadı (ID: $joinerUid).');
    }
    final joinerData = joinerSnap.data()!;

    // 4) Katılanın araç verisi
    final joinerVehicleSnap = await firestore
        .collection('users')
        .doc(joinerUid)
        .collection('vehicles')
        .doc(widget.joinerVehicleId)
        .get();
    if (!joinerVehicleSnap.exists) {
      throw Exception('Seçtiğiniz araç bulunamadı (Araç ID: ${widget.joinerVehicleId}).');
    }
    final joinerVehicleData = joinerVehicleSnap.data()!;

    return {
      'creatorData': creatorData,
      'creatorVehicleData': creatorVehicleData,
      'joinerData': joinerData,
      'joinerVehicleData': joinerVehicleData,
    };
  }

  String _getString(Map<String, dynamic> data, String key, [String defaultValue = 'Bilgi Yok']) {
    return data[key]?.toString() ?? defaultValue;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tutanak Bilgileri Onayı')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            _errorMessage = snapshot.error.toString();
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, color: Colors.red, size: 50),
                    const SizedBox(height: 10),
                    const Text(
                      'Bilgiler yüklenirken bir hata oluştu:',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _errorMessage!.replaceFirst("Exception: ", ""),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.red),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Geri Dön'),
                    ),
                    ElevatedButton(
                      onPressed: _loadData,
                      child: const Text('Tekrar Dene'),
                    ),
                  ],
                ),
              ),
            );
          }
          if (!snapshot.hasData) {
            return const Center(child: Text('Beklenmeyen bir durum oluştu.'));
          }

          final info = snapshot.data!;
          final creator = info['creatorData'] as Map<String, dynamic>;
          final cv = info['creatorVehicleData'] as Map<String, dynamic>;
          final joiner = info['joinerData'] as Map<String, dynamic>;
          final jv = info['joinerVehicleData'] as Map<String, dynamic>;

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Diğer Sürücü (QR Sahibi):',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Ad Soyad: ${_getString(creator, 'isim')} ${_getString(creator, 'soyisim')}'),
                        Text('Telefon: ${_getString(creator, 'telefon', 'Telefon Yok')}'),
                        const SizedBox(height: 8),
                        Text('Araç: ${_getString(cv, 'marka')} ${_getString(cv, 'seri')}'),
                        Text('Plaka: ${_getString(cv, 'plaka')}'),
                      ],
                    ),
                  ),
                ),
                Card(
                  elevation: 2,
                  margin: const EdgeInsets.only(bottom: 16),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Siz (QR Okutan):',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 8),
                        Text('Ad Soyad: ${_getString(joiner, 'isim')} ${_getString(joiner, 'soyisim')}'),
                        Text('Telefon: ${_getString(joiner, 'telefon', 'Telefon Yok')}'),
                        const SizedBox(height: 8),
                        Text('Seçili Araç: ${_getString(jv, 'marka')} ${_getString(jv, 'seri')}'),
                        Text('Plaka: ${_getString(jv, 'plaka')}'),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () async {
                    try {
                      // 1) Firestore kaydını güncelle
                      await FirebaseFirestore.instance
                        .collection('records')
                        .doc(widget.qrData)
                        .update({
                          'joinerUid': FirebaseAuth.instance.currentUser!.uid,
                          'joinerVehicleId': widget.joinerVehicleId,
                          'confirmed': true,
                        });
                      
                      // 2) Kaza yeri seçimine yönlendir
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationSelectionPage(
                            recordId: widget.qrData,
                            isCreator: false,
                          ),
                        ),
                      );
                    } catch (e) {
                      // Hata durumunda geri dönüp yeniden denemenizi sağlar
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Onaylama sırasında hata: $e')),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50)
                  ),
                  child: const Text('Bilgileri Onayla ve Devam Et'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    side: BorderSide(color: Theme.of(context).colorScheme.primary),
                  ),
                  child: const Text('Vazgeç'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
