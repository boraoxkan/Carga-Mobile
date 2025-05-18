// lib/screens/qr_scanner_page.dart
import 'dart:io'; // Platform kontrolü için
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'record_confirmation_page.dart';

class QRScannerPage extends StatefulWidget {
  final String joinerVehicleId; // Katılanın kendi seçtiği araç ID'si

  const QRScannerPage({
    Key? key,
    required this.joinerVehicleId,
  }) : super(key: key);

  @override
  State<QRScannerPage> createState() => _QRScannerPageState();
}

class _QRScannerPageState extends State<QRScannerPage> {
  final GlobalKey qrKey = GlobalKey(debugLabel: 'QR');
  QRViewController? _controller;
  Barcode? _result;
  bool _isProcessing = false;
  bool _flashOn = false;

  @override
  void reassemble() {
    super.reassemble();
    if (_controller != null) {
      if (Platform.isAndroid) {
        _controller!.pauseCamera();
      }
      _controller!.resumeCamera();
    }
  }

  void _onQRViewCreated(QRViewController controller) {
    setState(() {
      _controller = controller;
    });
    _controller!.scannedDataStream.listen((scanData) {
      if (_isProcessing || scanData.code == null || scanData.code!.isEmpty) return;

      setState(() {
        _isProcessing = true;
        _result = scanData; // Sonucu anlık göstermek için (opsiyonel)
      });

      _controller!.pauseCamera(); // Kamerayı duraklat

      final qrData = scanData.code!;
      print("Okunan QR Verisi (QRScannerPage): $qrData");

      // QR verisinin formatını basitçe kontrol et (UID|VehicleID)
      final parts = qrData.split('|');
      if (parts.length != 2 || parts[0].isEmpty || parts[1].isEmpty) {
        print("Geçersiz QR formatı!");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Okunan QR kodu geçersiz veya beklenen formatta değil.")),
          );
          // Kamerayı tekrar başlat ve işlemi bitir
          _controller?.resumeCamera();
          setState(() {
            _isProcessing = false;
            _result = null;
          });
        }
        return;
      }

      // Geçerli QR kodu okundu, onay sayfasına yönlendir
      if (mounted) {
        // Kısa bir gecikme ile "okundu" mesajı gösterilebilir
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('QR Kod Okundu: ${qrData.substring(0, min(qrData.length, 10))}... Yönlendiriliyor.')),
        // );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecordConfirmationPage(
              qrData: qrData,
              joinerVehicleId: widget.joinerVehicleId,
            ),
          ),
        ).then((_) {
          // RecordConfirmationPage kapatıldıktan sonra burası çalışır.
          // Kamerayı tekrar aktifleştir ve işlem durumunu sıfırla.
          if (mounted) {
            print("Confirmation page kapatıldı, kamera devam ettiriliyor.");
            _controller?.resumeCamera();
            setState(() {
              _isProcessing = false;
              _result = null;
            });
          }
        });
      }
    });
  }

  void _onPermissionSet(BuildContext context, QRViewController ctrl, bool p) {
    print('${DateTime.now().toIso8601String()}_onPermissionSet $p');
    if (!p && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Kamera izni verilmedi. QR kod okutmak için izin vermelisiniz.')),
      );
      // Kullanıcıyı uygulama ayarlarına yönlendirme butonu eklenebilir.
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    var scanArea = (MediaQuery.of(context).size.width < 400 ||
            MediaQuery.of(context).size.height < 400)
        ? 200.0
        : 280.0; // Tarama alanını biraz büyüttüm

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kodu Tara'),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: "Flaş ${_flashOn ? 'Kapat' : 'Aç'}",
            onPressed: () async {
              await _controller?.toggleFlash();
              setState(() {
                _flashOn = !_flashOn;
              });
            },
          ),
          // Kamera değiştirme butonu (genellikle arka kamera yeterli olur)
          // IconButton(
          //   icon: Icon(Icons.flip_camera_ios_outlined),
          //   tooltip: "Kamera Değiştir",
          //   onPressed: () async {
          //     await _controller?.flipCamera();
          //     // Hangi kameranın aktif olduğunu takip etmek için ek state gerekebilir.
          //   },
          // ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5, // Kamera görüntüsüne daha fazla alan
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: theme.colorScheme.primary, // Tema rengi
                borderRadius: 12, // Daha yuvarlak köşeler
                borderLength: 30,
                borderWidth: 8, // Daha belirgin kenarlık
                cutOutSize: scanArea,
                // cutOutBottomOffset: 50, // Tarama alanını biraz yukarı kaydırmak için
              ),
              onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
            ),
          ),
          Expanded(
            flex: 1, // Alt bilgi alanına daha az alan
            child: Container(
              color: Colors.black.withOpacity(0.03), // Hafif bir arka plan
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.center_focus_weak, size: 30, color: theme.colorScheme.onSurfaceVariant),
                      const SizedBox(height: 8),
                      Text(
                        _isProcessing ? 'QR Kod İşleniyor...' : 'Kamerayı QR koduna doğrultun',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium,
                      ),
                      // if (_result != null && !_isProcessing) // Debug için okunan kodu göstermek isterseniz
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 8.0),
                      //     child: Text(
                      //       'Bulunan Kod: ${_result!.code?.substring(0, (_result!.code?.length ?? 0) > 10 ? 10 : _result!.code?.length ?? 0)}...',
                      //       style: theme.textTheme.bodySmall,
                      //       overflow: TextOverflow.ellipsis,
                      //     ),
                      //   ),
                    ],
                  ),
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}