// File: lib/screens/waiting_for_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_selection_page.dart'; // Bu importun olduğundan emin olun

class WaitingForConfirmationPage extends StatelessWidget {
  final String recordId; // recordId creatorUid|creatorVehicleId formatında gelmeli
  const WaitingForConfirmationPage({Key? key, required this.recordId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Onay Bekleniyor'),
        // Geri gitmeyi engellemek veya özel bir işlem yapmak için leading eklenebilir
        // leading: IconButton(
        //   icon: Icon(Icons.arrow_back),
        //   onPressed: () {
        //     // Kullanıcıya bir uyarı gösterip ana sayfaya yönlendirebilirsiniz
        //     Navigator.popUntil(context, (route) => route.isFirst);
        //   },
        // ),
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('records')
            .doc(recordId)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            print("Error in WaitingForConfirmationPage StreamBuilder: ${snap.error}");
            return Center(child: Text('Bir hata oluştu: ${snap.error}'));
          }
          if (!snap.hasData || !snap.data!.exists) {
            // Belge yoksa veya silinmişse, kullanıcıyı bilgilendirip geri yönlendirebiliriz.
             WidgetsBinding.instance.addPostFrameCallback((_) {
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tutanak kaydı bulunamadı veya silinmiş olabilir. Ana sayfaya yönlendiriliyorsunuz.')),
                );
                Navigator.popUntil(context, (route) => route.isFirst);
             });
            return const Center(child: Text('Tutanak kaydı bulunamadı...'));
          }

          final data = snap.data!;
          // 'confirmed' alanı var mı ve true mu diye kontrol et
          if (data.exists && data.data() is Map<String, dynamic> && (data.data() as Map<String, dynamic>)['confirmed'] == true) {
            // Yönlendirme işlemi build metodu içinde doğrudan yapılmamalı,
            // bunun yerine addPostFrameCallback kullanılmalı.
            WidgetsBinding.instance.addPostFrameCallback((_) {
              // recordId'den oluşturanın araç ID'sini çıkar
              final parts = recordId.split('|');
              // Güvenlik için parts uzunluğunu kontrol et
              final String? creatorVehicleId = parts.length == 2 ? parts[1] : null;

              if (creatorVehicleId == null || creatorVehicleId.isEmpty) {
                  // Hata durumu: Geçersiz recordId formatı veya boş vehicleId
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Hata: Geçersiz kayıt ID formatı veya araç ID eksik.')),
                  );
                  // Kullanıcıyı uygun bir sayfaya yönlendirin veya hata gösterin
                  Navigator.popUntil(context, (route) => route.isFirst); // Örn: Ana sayfaya dön
                  return;
              }
              
              // Eğer widget hala ağaca bağlıysa (mounted) yönlendirmeyi yap
              if (ModalRoute.of(context)?.isCurrent ?? false) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (_) => LocationSelectionPage(
                      recordId: recordId,       // creatorUid|creatorVehicleId
                      isCreator: true,          // Oluşturan kullanıcı olduğu için true
                      // DEĞİŞİKLİK BURADA: Oluşturanın araç ID'sini aktar
                      currentUserVehicleId: creatorVehicleId, 
                    ),
                  ),
                );
              }
            });
            // Yönlendirme yapılırken kullanıcıya bilgi mesajı göster
            return const Center(child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Onay alındı, kaza yeri seçimine yönlendiriliyor...'),
              ],
            ));
          }
          
          // Henüz onaylanmamışsa bekleme mesajını göster
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 20),
                  Text(
                    'Diğer sürücünün QR kodu okutup bilgileri onaylaması bekleniyor...',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16),
                  ),
                  SizedBox(height: 20),
                  Text(
                    '(Bu işlem birkaç dakika sürebilir. Lütfen bekleyiniz.)',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ],
              ),
            )
          );
        },
      ),
    );
  }
}