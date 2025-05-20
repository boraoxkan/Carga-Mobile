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
  bool _isConfirming = false; 

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() {
    if (mounted) {
      setState(() {
        _infoFuture = _fetchAllInfo();
      });
    }
  }

  Future<Map<String, dynamic>> _fetchAllInfo() async {
    final firestore = FirebaseFirestore.instance;
    final currentUser = FirebaseAuth.instance.currentUser;

    if (currentUser == null) {
      throw Exception('İşlem için kullanıcı girişi gerekli.');
    }
    final joinerUid = currentUser.uid;

    // widget.qrData artık benzersiz recordId'dir.
    final String uniqueRecordId = widget.qrData;
    print('RecordConfirmationPage: Alınan uniqueRecordId: $uniqueRecordId');

    // 1. Benzersiz recordId ile ana tutanak belgesini Firestore'dan çek
    final recordDocSnap = await firestore.collection('records').doc(uniqueRecordId).get();
    if (!recordDocSnap.exists || recordDocSnap.data() == null) {
      print('HATA: Tutanak kaydı bulunamadı! ID: $uniqueRecordId');
      throw Exception('Geçersiz QR kodu veya böyle bir tutanak kaydı bulunamadı.');
    }
    final recordData = recordDocSnap.data()!;
    final String? creatorUid = recordData['creatorUid'] as String?;
    final String? creatorVehicleId = recordData['creatorVehicleId'] as String?;

    if (creatorUid == null || creatorVehicleId == null) {
      print('HATA: Tutanak belgesinde oluşturan kullanıcı veya araç bilgileri eksik!');
      throw Exception('Tutanak bilgileri okunamadı (oluşturan detayları eksik).');
    }

    print('RecordConfirmationPage: Tutanaktan çekilen creatorUid: $creatorUid, creatorVehicleId: $creatorVehicleId');

    // 2. Oluşturan kullanıcı verisini (creatorUid ile) Firestore'dan çek
    final creatorUserSnap = await firestore.collection('users').doc(creatorUid).get();
    if (!creatorUserSnap.exists || creatorUserSnap.data() == null) {
      throw Exception('QR koduna sahip sürücünün kullanıcı bilgisi bulunamadı (ID: $creatorUid).');
    }
    final creatorUserData = creatorUserSnap.data()!;

    // 3. Oluşturanın araç verisini (creatorVehicleId ile) Firestore'dan çek
    final creatorVehicleSnap = await firestore
        .collection('users')
        .doc(creatorUid)
        .collection('vehicles')
        .doc(creatorVehicleId)
        .get();
    if (!creatorVehicleSnap.exists || creatorVehicleSnap.data() == null) {
      throw Exception('QR koduna sahip sürücünün aracı bulunamadı (Araç ID: $creatorVehicleId).');
    }
    final creatorVehicleData = creatorVehicleSnap.data()!;

    // 4. Katılan kullanıcı (zaten oturum açmış olan) verisini Firestore'dan çek
    final joinerUserSnap = await firestore.collection('users').doc(joinerUid).get();
    if (!joinerUserSnap.exists || joinerUserSnap.data() == null) {
      throw Exception('Kendi sürücü bilginiz bulunamadı (ID: $joinerUid).');
    }
    final joinerUserData = joinerUserSnap.data()!;

    final joinerVehicleSnap = await firestore
        .collection('users')
        .doc(joinerUid)
        .collection('vehicles')
        .doc(widget.joinerVehicleId)
        .get();
    if (!joinerVehicleSnap.exists || joinerVehicleSnap.data() == null) {
      throw Exception('Seçtiğiniz araç bulunamadı (Araç ID: ${widget.joinerVehicleId}).');
    }
    final joinerVehicleData = joinerVehicleSnap.data()!;

    return {
      'creatorData': creatorUserData,
      'creatorVehicleData': creatorVehicleData,
      'joinerData': joinerUserData,
      'joinerVehicleData': joinerVehicleData,
      'uniqueRecordId': uniqueRecordId, 
    };
  }

  String _getString(Map<String, dynamic> data, String key, [String defaultValue = 'Bilgi Yok']) {
    return data[key]?.toString() ?? defaultValue;
  }

  Future<void> _confirmAndProceed(String uniqueRecordId) async {
    if (!mounted) return;
    setState(() => _isConfirming = true);

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
      if(mounted){
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('İşlem için giriş yapmalısınız.')),
        );
        setState(() => _isConfirming = false);
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('records')
          .doc(uniqueRecordId) 
          .update({
        'joinerUid': currentUser.uid,
        'joinerVehicleId': widget.joinerVehicleId, 
        'confirmedByJoiner': true,
        'status': 'joiner_confirmed',
        'joinerConfirmationTimestamp': FieldValue.serverTimestamp(),
        
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bilgiler onaylandı. Kaza yeri seçimine yönlendiriliyorsunuz.')),
      );

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => LocationSelectionPage(
            recordId: uniqueRecordId, 
            isCreator: false, 
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
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Tutanak Bilgileri Onayı')),
      body: FutureBuilder<Map<String, dynamic>>(
        future: _infoFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData || snapshot.data == null) {
            _errorMessage = snapshot.hasError ? snapshot.error.toString() : 'Bilgiler yüklenemedi.';
            String displayError = _errorMessage!;
            if (displayError.contains("Exception: ")) {
              displayError = displayError.substring(displayError.indexOf("Exception: ") + 11);
            }

            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 60),
                    const SizedBox(height: 16),
                    Text(
                      'Bilgiler Yüklenemedi',
                       textAlign: TextAlign.center,
                       style: theme.textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      displayError,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Tekrar Dene'),
                      onPressed: _loadData, 
                    ),
                     const SizedBox(height: 12),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
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
          final uniqueRecordId = info['uniqueRecordId'] as String; 

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildInfoCard(
                  context: context,
                  title: 'Diğer Sürücü (QR Sahibi)',
                  icon: Icons.qr_code_2_rounded,
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
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  icon: _isConfirming
                      ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2,))
                      : const Icon(Icons.check_circle_outline_rounded),
                  label: Text(_isConfirming ? 'ONAYLANIYOR...' : 'Bilgileri Onayla ve Devam Et'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),

                  ),
                  onPressed: _isConfirming ? null : () => _confirmAndProceed(uniqueRecordId),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: _isConfirming ? null : () => Navigator.pop(context),
                   style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: BorderSide(color: theme.colorScheme.outline), 
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

  // Bilgi kartları için yardımcı widget 
  Widget _buildInfoCard({
    required BuildContext context,
    required String title,
    required IconData icon,
    required List<Widget> children
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2, 
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)), 
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24, thickness: 0.5), 
            ...children,
          ],
        ),
      ),
    );
  }
}