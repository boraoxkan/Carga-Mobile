// lib/screens/qr_display_page.dart
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
// import 'package:cloud_firestore/cloud_firestore.dart'; // Artık bu sayfada doğrudan Firestore işlemi yapılmıyor
// import 'package:firebase_auth/firebase_auth.dart'; // Artık bu sayfada doğrudan Auth işlemi yapılmıyor
import 'waiting_for_confirmation_page.dart';

class QRDisplayPage extends StatefulWidget {
  final String recordId; 

  const QRDisplayPage({Key? key, required this.recordId}) : super(key: key);

  @override
  State<QRDisplayPage> createState() => _QRDisplayPageState();
}

class _QRDisplayPageState extends State<QRDisplayPage> {
  // _isLoading durumu, "Onay Bekleme Ekranına Geç" butonu için bir yükleme göstergesi
  // sağlamak amacıyla tutulabilir, ancak artık Firestore'a yazma işlemi yapmadığı için
  // anlık bir yönlendirme olacak. İsteğe bağlı olarak kaldırılabilir veya kısa bir gecikme
  // ile UX iyileştirmesi için kullanılabilir.
  bool _isLoading = false;

  Future<void> _navigateToWaitingPage() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    // Bu sayfada artık Firestore'a bir yazma işlemi yapılmıyor.
    // Firestore'daki başlangıç kaydı bir önceki sayfada (DriverAndVehicleInfoPage) oluşturuldu.
    // Bu sayfanın tek görevi QR'ı göstermek ve sonraki sayfaya (WaitingForConfirmationPage) yönlendirmek.

    // Yönlendirme öncesi küçük bir gecikme (opsiyonel, UX için)
    // await Future.delayed(const Duration(milliseconds: 300));

    if (mounted) {
      // Geri dönüldüğünde tekrar QR oluşturma ekranına gelinmemesi için pushReplacement kullanılabilir.
      // Ancak kullanıcı QR'ı tekrar görmek isteyebilir, bu durumda push daha uygun olabilir.
      // Şimdilik, akışta ilerlemeyi varsayarak pushReplacement kullanalım.
      // Eğer kullanıcı QR'ı tekrar görmek isterse, WaitingForConfirmationPage'den
      // geri gelme senaryosu ayrıca düşünülmelidir.
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) =>
              WaitingForConfirmationPage(recordId: widget.recordId), 
        ),
      );
    }
    // Yönlendirme sonrası _isLoading'i false yapmaya genellikle gerek kalmaz, sayfa değişecektir.
    // Ancak bir hata durumunda veya state'i korumak isteniyorsa `finally` bloğu eklenebilir.
    // if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool isValidQrData = widget.recordId.isNotEmpty;

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
              Icons.qr_code_2_rounded,
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
              style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
            ),
            const SizedBox(height: 32),
            Center(
              child: Card(
                elevation: 6,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: QrImageView(
                    data: widget.recordId, 
                    version: QrVersions.auto,
                    size: 230.0,
                    gapless: false,
                    // embeddedImage: AssetImage('assets/images/app_logo_small.png'), // Opsiyonel logo
                    // embeddedImageStyle: QrEmbeddedImageStyle(size: Size(40, 40)),
                    errorStateBuilder: (cxt, err) {
                      print("QR Oluşturma Hatası (QRDisplayPage): $err");
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
            const SizedBox(height: 20),
            // Kodlanan Tutanak Kimliği (Debug için gösterilebilir, son kullanıcı için gereksiz olabilir)
            // Text(
            //   "Tutanak Kimliği (Test): ${widget.recordId}",
            //   textAlign: TextAlign.center,
            //   style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
            // ),
            const SizedBox(height: 32),
            _isLoading
                ? const Center(child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 16.0),
                    child: CircularProgressIndicator(),
                  ))
                : ElevatedButton.icon(
                    icon: const Icon(Icons.arrow_circle_right_outlined),
                    label: const Text('Onay Bekleme Ekranına Geç'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                    onPressed: _navigateToWaitingPage, 
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