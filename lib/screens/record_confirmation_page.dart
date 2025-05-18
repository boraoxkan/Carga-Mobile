// lib/screens/record_confirmation_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'location_selection_page.dart';

class RecordConfirmationPage extends StatefulWidget {
  final String qrData;
  final String joinerVehicleId;

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
  bool _isConfirming = false; // Onaylama işlemi sırasında yükleme göstergesi için

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (mounted) { // mounted kontrolü eklendi
      setState(() {
        _infoFuture = _fetchAllInfo();
      });
    }
  }

  Future<Map<String, dynamic>> _fetchAllInfo() async {
    // ... (_fetchAllInfo metodu içeriği öncekiyle aynı kalabilir) ...
    // Önceki cevaptaki _fetchAllInfo metodu doğruydu.
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

    final creatorSnap = await firestore.collection('users').doc(creatorUid).get();
    if (!creatorSnap.exists) {
      throw Exception('QR koduna sahip sürücü bilgisi bulunamadı (ID: $creatorUid).');
    }
    final creatorData = creatorSnap.data()!;

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

    final joinerSnap = await firestore.collection('users').doc(joinerUid).get();
    if (!joinerSnap.exists) {
      throw Exception('Kendi sürücü bilginiz bulunamadı (ID: $joinerUid).');
    }
    final joinerData = joinerSnap.data()!;

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

  Future<void> _confirmAndProceed() async {
    if (!mounted) return;
    setState(() => _isConfirming = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('İşlem için giriş yapmalısınız.')),
      );
      if (mounted) setState(() => _isConfirming = false);
      return;
    }

    try {
      // Firestore kaydını DÜZGÜN ALANLARLA güncelle
      await FirebaseFirestore.instance
          .collection('records')
          .doc(widget.qrData) // qrData = creatorUid|creatorVehicleId
          .update({
        'joinerUid': currentUser.uid,
        'joinerVehicleId': widget.joinerVehicleId,
        'confirmedByJoiner': true, // <<< BU ALAN ÖNEMLİ
        'status': 'joiner_confirmed', // <<< BU ALAN DA ÖNEMLİ
        'joinerConfirmationTimestamp': FieldValue.serverTimestamp(),
        // 'confirmed' alanını artık kullanmıyoruz, gerekirse kaldırılabilir veya
        // eski veriyle uyumluluk için o da true yapılabilir ama kafa karıştırır.
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilgiler onaylandı. Kaza yeri seçimine yönlendiriliyorsunuz.')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LocationSelectionPage(
            recordId: widget.qrData,
            isCreator: false, // Bu sayfayı gören QR okutan (katılan) kullanıcıdır.
            currentUserVehicleId: widget.joinerVehicleId,
          ),
        ),
      );
    } catch (e) {
      print("RecordConfirmationPage: Onaylama sırasında hata: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Onaylama sırasında bir hata oluştu: $e')),
        );
        setState(() => _isConfirming = false);
      }
    }
    // pushReplacement sonrası setState çağırmaya gerek yok.
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context); // Tema eklendi
    return Scaffold(
      appBar: AppBar(title: const Text('Tutanak Bilgileri Onayı')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) { // Hata ve veri yoksa durumu birleştirildi
            _errorMessage = snapshot.hasError ? snapshot.error.toString() : 'Bilgiler yüklenemedi.';
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Bilgiler Yüklenirken Bir Hata Oluştu',
                       textAlign: TextAlign.center,
                       style: theme.textTheme.titleLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _errorMessage!.replaceFirst("Exception: ", ""),
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon( // İkonlu buton
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar Dene'),
                      onPressed: _loadData,
                    ),
                     const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context), // Bir önceki sayfaya döner (QRScannerPage)
                      child: const Text('Vazgeç ve Geri Dön'),
                    ),
                  ],
                ),
              ),
            );
          }

          final info = snapshot.data!;
          final creator = info['creatorData'] as Map<String, dynamic>;
          final cv = info['creatorVehicleData'] as Map<String, dynamic>;
          final joiner = info['joinerData'] as Map<String, dynamic>;
          final jv = info['joinerVehicleData'] as Map<String, dynamic>;

          return SingleChildScrollView( // İçerik taşabilir diye SingleChildScrollView eklendi
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Card'lar için ortak bir stil fonksiyonu (opsiyonel)
                _buildInfoCard(
                  context: context,
                  title: 'Diğer Sürücü (QR Sahibi)',
                  icon: Icons.qr_code_scanner_rounded,
                  children: [
                    Text('Ad Soyad: ${_getString(creator, 'isim')} ${_getString(creator, 'soyisim')}'),
                    Text('Telefon: ${_getString(creator, 'telefon', 'Telefon Yok')}'),
                    const SizedBox(height: 8),
                    Text('Araç: ${_getString(cv, 'marka')} ${_getString(cv, 'seri')}'),
                    Text('Plaka: ${_getString(cv, 'plaka')}'),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoCard(
                  context: context,
                  title: 'Siz (QR Okutan)',
                  icon: Icons.person_pin_circle_outlined,
                  children: [
                    Text('Ad Soyad: ${_getString(joiner, 'isim')} ${_getString(joiner, 'soyisim')}'),
                    Text('Telefon: ${_getString(joiner, 'telefon', 'Telefon Yok')}'),
                    const SizedBox(height: 8),
                    Text('Seçili Araç: ${_getString(jv, 'marka')} ${_getString(jv, 'seri')}'),
                    Text('Plaka: ${_getString(jv, 'plaka')}'),
                  ],
                ),
                const SizedBox(height: 32), // Butonlar için daha fazla boşluk
                ElevatedButton.icon(
                  icon: _isConfirming 
                      ? Container(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2,))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_isConfirming ? 'ONAYLANIYOR...' : 'Bilgileri Onayla ve Devam Et'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: _isConfirming ? null : _confirmAndProceed,
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isConfirming ? null : () => Navigator.pop(context),
                   style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
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

  // Bilgi kartları için yardımcı widget (daha modern bir görünüm için)
  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children
  }) {
    final theme = Theme.of(context);
    return Card(
      // elevation: 2, // Temadan gelecek
      // margin: const EdgeInsets.only(bottom: 16), // Temadan gelecek
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
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
}