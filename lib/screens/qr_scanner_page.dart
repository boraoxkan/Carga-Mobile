// lib/screens/qr_scanner_page.dart
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:qr_code_scanner/qr_code_scanner.dart';
import 'record_confirmation_page.dart'; 

class QRScannerPage extends StatefulWidget {
  final String joinerVehicleId; 

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
    // Hot reload durumunda kamerayı yeniden başlatmak için
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
    controller.scannedDataStream.listen((scanData) {
      // Eğer zaten bir QR işleniyorsa veya okunan kod boşsa/null ise bir şey yapma
      if (_isProcessing || scanData.code == null || scanData.code!.isEmpty) {
        return;
      }

      setState(() {
        _isProcessing = true;
        _result = scanData; 
      });

      _controller!.pauseCamera(); 

      final String uniqueRecordId = scanData.code!;
      print("Okunan Benzersiz Record ID (QRScannerPage): $uniqueRecordId");

      // Artık QR verisinin formatını (örn: 'uid|vehicleId') kontrol etmeye GEREK YOK.
      // Çünkü QR verisi doğrudan benzersiz bir Firestore belge ID'si olmalı.
      // Sadece boş olup olmadığını kontrol etmek yeterli (yukarıda yapıldı).

      if (mounted) {
        // SnackBar ile kullanıcıya geri bildirim verilebilir (opsiyonel)
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('QR Kod Okundu: ${uniqueRecordId.substring(0, (uniqueRecordId.length > 10 ? 10 : uniqueRecordId.length))}... Yönlendiriliyor.')),
        // );

        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => RecordConfirmationPage(
              qrData: uniqueRecordId, 
              joinerVehicleId: widget.joinerVehicleId,
            ),
          ),
        ).then((_) {
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
        : 280.0; 

    return Scaffold(
      appBar: AppBar(
        title: const Text('QR Kodu Tara'),
        actions: [
          IconButton(
            icon: Icon(_flashOn ? Icons.flash_on_rounded : Icons.flash_off_rounded),
            tooltip: "Flaş ${_flashOn ? 'Kapat' : 'Aç'}",
            onPressed: () async {
              await _controller?.toggleFlash();
              if(mounted){
                setState(() {
                  _flashOn = !_flashOn;
                });
              }
            },
          ),
          // Kamera değiştirme butonu genellikle gerekli olmaz, arka kamera varsayılandır.
          // Eğer ön kamera da desteklenmek isteniyorsa eklenebilir:
          // IconButton(
          //   icon: Icon(Icons.flip_camera_ios_outlined),
          //   tooltip: "Kamera Değiştir",
          //   onPressed: () async {
          //     await _controller?.flipCamera();
          //     // Hangi kameranın aktif olduğunu takip etmek için ek bir state gerekebilir.
          //   },
          // ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            flex: 5, 
            child: QRView(
              key: qrKey,
              onQRViewCreated: _onQRViewCreated,
              overlay: QrScannerOverlayShape(
                borderColor: theme.colorScheme.primary, 
                borderRadius: 12, 
                borderLength: 30, 
                borderWidth: 8,
                cutOutSize: scanArea, 
                // cutOutBottomOffset: 50, // Tarama alanını dikeyde kaydırmak için (opsiyonel)
              ),
              onPermissionSet: (ctrl, p) => _onPermissionSet(context, ctrl, p),
            ),
          ),
          Expanded(
            flex: 1, 
            child: Container(
              width: double.infinity, 
              color: theme.scaffoldBackgroundColor.withOpacity(0.95), 
              padding: const EdgeInsets.all(12.0),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      _isProcessing ? Icons.document_scanner_outlined : Icons.center_focus_strong_outlined,
                      size: 30,
                      color: theme.colorScheme.onSurfaceVariant
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _isProcessing ? 'QR Kod İşleniyor...' : 'Kamerayı QR koduna doğrultun',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium,
                    ),
                    // Okunan kodu debug için göstermek isterseniz (kullanıcıya göstermek gerekmeyebilir):
                    // if (_result != null && !_isProcessing && _result!.code != null)
                    //   Padding(
                    //     padding: const EdgeInsets.only(top: 8.0),
                    //     child: Text(
                    //       'Okunan: ${_result!.code!.substring(0, (_result!.code!.length > 15 ? 15 : _result!.code!.length))}...',
                    //       style: theme.textTheme.bodySmall,
                    //       overflow: TextOverflow.ellipsis,
                    //     ),
                    //   ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}