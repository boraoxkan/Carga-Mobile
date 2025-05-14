// File: lib/screens/qr_display_page.dart

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'waiting_for_confirmation_page.dart';  // <— ekledik

class QRDisplayPage extends StatelessWidget {
  final String recordId; // UID|VehicleID formatında gelmeli

  const QRDisplayPage({Key? key, required this.recordId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Basit format kontrolü (opsiyonel)
    final parts = recordId.split('|');
    final isValid = parts.length == 2 && parts[0].isNotEmpty && parts[1].isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text("Tutanak QR Kodu")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isValid)
              QrImageView(
                data: recordId,
                version: QrVersions.auto,
                size: 250.0,
              )
            else
              Container(
                width: 250,
                height: 250,
                alignment: Alignment.center,
                color: Colors.grey.shade200,
                child: const Text(
                  "Geçersiz QR verisi!",
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.red),
                ),
              ),

            const SizedBox(height: 20),
            Text(
              "Kodlanan Veri:\n$recordId",
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 40),

            // DÜZELTME: Karşı taraf okutması için buton ekledik
            ElevatedButton(
              onPressed: () async {
                final user = FirebaseAuth.instance.currentUser;
                if (user == null) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Lütfen giriş yapın.')),
                  );
                  return;
                }

                // 1) Firestore'da yeni record oluştur
                await FirebaseFirestore.instance
                    .collection('records')
                    .doc(recordId)
                    .set({
                  'creatorUid': user.uid,
                  'creatorVehicleId': parts[1],
                  'joinerUid': null,
                  'joinerVehicleId': null,
                  'confirmed': false,
                });

                // 2) Onay bekleme sayfasına geç
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        WaitingForConfirmationPage(recordId: recordId),
                  ),
                );
              },
              child: const Text('Karşı taraf okutmaya hazır ol'),
            ),
          ],
        ),
      ),
    );
  }
}
