// lib/screens/qr_scanner_page.dart
import 'dart:io'; // Platform kontrolü için
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'record_confirmation_page.dart';

class QRScannerPage extends StatefulWidget {
  // isJoining flag'i RecordConfirmationPage'e taşındığı için burada gereksiz olabilir.
  // final bool isJoining;
  final String joinerVehicleId; // Katılanın kendi seçtiği araç ID'si

  const QRScannerPage({
    Key? key,
    // required this.isJoining, // Kaldırıldı veya isteğe bağlı hale getirilebilir
    required this.joinerVehicleId,
  }) : super(key: key);

  @override
  _QRScannerPageState createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? controller;
  Barcode? result;
  bool _isProcessing = false; // Tekrar tekrar yönlendirmeyi önlemek için

  // Hot reload için kamera yaşam döngüsü yönetimi
  @override
  void reassemble() {
    super.reassemble();
    if (Platform.isAndroid) {
      controller!.pauseCamera();
    }
    controller!.resumeCamera();
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR Kodu Tara')),
      body: Column(
        children: <Widget>[
          Expanded(flex: 4, child: _buildQrView(context)),
          Expanded(
            flex: 1,
            child: Center(
              child: (result != null)
                  ? Text('Bulunan Kod: ${result!.code}') // Debug için
                  : const Text('Kamerayı QR koduna doğrultun'),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQrView(BuildContext context) {
    // Ekran boyutuna göre tarama alanını ayarlama
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 200.0
        : 300.0;
    return QRView(
      key: qrKey,
      onQRViewCreated: _onQRViewCreated,
      overlay: QrScannerOverlayShape(
          borderColor: Colors.red,
          borderRadius: 10,
          borderLength: 30,
          borderWidth: 10,
          cutOutSize: scanArea),
      onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
    );
  }


  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      this.controller = controller;
    });
    controller.scannedDataStream.listen((scanData) {
      // Eğer zaten bir işlem yapılıyorsa veya kod geçerli değilse dinlemeyi bırak
      if (_isProcessing || scanData.code == null) return;

       setState(() {
         _isProcessing = true; // İşleme başla
         result = scanData; // Sonucu göster (opsiyonel)
       });

      controller.pauseCamera(); // Kamerayı duraklat

      final qrData = scanData.code!;
      print("Okunan QR Verisi: $qrData"); // Debug için

      // QR verisinin formatını basitçe kontrol et
      if (!qrData.contains('|')) {
         print("Geçersiz QR formatı!");
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Okunan QR kodu geçersiz formatta.")),
         );
         // Kamerayı tekrar başlat ve işlemi bitir
         controller.resumeCamera();
         setState(() {
            _isProcessing = false;
            result = null;
         });
         return; // Fonksiyondan çık
      }


      // pushReplacement yerine push kullanmak daha iyi olabilir
      // Kullanıcı geri dönebilmeli
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecordConfirmationPage(
            // isJoining: widget.isJoining, // Bu bilgi RecordConfirmationPage içinde belirlenebilir veya gereksizse kaldırılabilir.
            qrData: qrData, // Okunan ham veri: creatorUid|creatorVehicleId
            joinerVehicleId: widget.joinerVehicleId, // Katılanın seçtiği araç ID'si
          ),
        ),
      ).then((_) {
         // RecordConfirmationPage kapatıldıktan sonra burası çalışır.
         // Kamerayı tekrar aktifleştir ve işlem durumunu sıfırla.
          print("Confirmation page kapatıldı, kamera devam ettiriliyor.");
          controller.resumeCamera();
          setState(() {
            _isProcessing = false;
            result = null;
          });
      });
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    print('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera izni verilmedi')),
      );
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }
}