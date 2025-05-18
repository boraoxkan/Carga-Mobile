// lib/screens/qr_display_page.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'waiting_for_confirmation_page.dart';

class QRDisplayPage extends StatefulWidget {
  final String recordId; // UID|VehicleID formatında gelmeli

  const QRDisplayPage({Key? key, required this.recordId}) : super(key: key);

  @override
  State<QRDisplayPage> createState() => _QRDisplayPageState();
}

class _QRDisplayPageState extends State<QRDisplayPage> {
  bool _isLoading = false;

  Future<void> _prepareForScanning() async {
    if (mounted) setState(() => _isLoading = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen önce giriş yapın.')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    final parts = widget.recordId.split('|');
    if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Geçersiz kayıt ID formatı.')),
        );
        setState(() => _isLoading = false);
      }
      return;
    }

    try {
      await FirebaseFirestore.instance
          .collection('records')
          .doc(widget.recordId)
          .set({
        'creatorUid': user.uid,
        'creatorVehicleId': parts[1],
        'joinerUid': null,
        'joinerVehicleId': null,
        'status': 'pending_scan',
        'confirmedByCreator': true,
        'confirmedByJoiner': false,
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) =>
                WaitingForConfirmationPage(recordId: widget.recordId),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Tutanak başlatılırken hata: $e')),
        );
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = widget.recordId.split('|');
    final bool isValidQrData = parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty;

    if (!isValidQrData) {
      return Scaffold(
        appBar: AppBar(title: const Text("Hata")),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.error, size: 60),
                const SizedBox(height: 20),
                Text("QR Kodu Oluşturulamadı", style: theme.textTheme.headlineSmall),
                const SizedBox(height: 10),
                Text(
                  "Geçersiz veya eksik bilgi nedeniyle QR kodu gösterilemiyor. Lütfen önceki adıma dönüp tekrar deneyin.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Geri Dön"),
                )
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Tutanak Başlatma QR Kodu")),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(
              Icons.qr_code_2_rounded, // Daha modern bir QR ikonu
              size: 70,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              "Diğer Sürücüyle Paylaşın",
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              "Bu QR kodu, kazaya karışan diğer sürücünün tutanağınıza güvenli bir şekilde dahil olmasını sağlar. Lütfen diğer sürücünün bu kodu kendi telefon kamerası veya QR okuyucu uygulaması ile okutmasını isteyin.",
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(height: 1.4), // Satır yüksekliği artırıldı
            ),
            const SizedBox(height: 32),
            Center(
              child: Card(
                elevation: 6, // QR kodunu daha belirgin yapmak için gölge artırıldı
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), // Daha yuvarlak köşeler
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: QrImageView(
                    data: widget.recordId,
                    version: QrVersions.auto,
                    size: 230.0, // Boyut biraz daha büyük olabilir
                    gapless: false,
                    // embeddedImage: AssetImage('assets/images/app_logo_small.png'), // Eğer küçük bir logonuz varsa
                    // embeddedImageStyle: QrEmbeddedImageStyle(size: Size(40, 40)),
                    errorStateBuilder: (cxt, err) {
                      return Container(
                        alignment: Alignment.center,
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 40),
                            const SizedBox(height: 8),
                            const Text(
                              "Hata: QR Kodu oluşturulamadı.",
                              textAlign: TextAlign.center,
                            ),
                          ],
                        )
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            // "Kodlanan Tutanak Kimliği" bölümü kaldırıldı.
            _isLoading
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0), // Yükleme göstergesi için boşluk
                    child: CircularProgressIndicator(),
                  ))
                : ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_circle_right_outlined),
                    label: const Text('Onay Bekleme Ekranına Geç'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _prepareForScanning,
                  ),
            const SizedBox(height: 12),
            TextButton(
                onPressed: _isLoading ? null : () => Navigator.pop(context),
                child: const Text("Önceki Adıma Dön")
            )
          ],
        ),
      ),
    );
  }
}