// lib/screens/waiting_for_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_selection_page.dart'; // Yönlendirilecek sayfa

class WaitingForConfirmationPage extends StatefulWidget {
  final String recordId; // Bu, Firestore'daki benzersiz belge ID'si

  const WaitingForConfirmationPage({Key? key, required this.recordId}) : super(key: key);

  @override
  State<WaitingForConfirmationPage> createState() => _WaitingForConfirmationPageState();
}

class _WaitingForConfirmationPageState extends State<WaitingForConfirmationPage> {
  // Bu sayfada ek bir state'e (şimdilik) ihtiyaç yok gibi duruyor.
  // StreamBuilder veriyi yönetecek.

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false, // Geri tuşuyla çıkışı engelle
      onPopInvoked: (bool didPop) async {
        if (didPop) return; // Zaten pop olduysa bir şey yapma

        final bool shouldPop = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) => AlertDialog(
            title: const Text('Onay Beklemeden Çıkılsın mı?'),
            content: const Text(
                'Diğer sürücünün onayı bekleniyor. Bu ekrandan çıkarsanız, tutanak işlemi yarım kalabilir ve diğer sürücü tutanağa katılamayabilir.\n\nYine de çıkmak istiyor musunuz?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false), // Hayır, bekle
                child: const Text('Beklemeye Devam Et'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(true), // Evet, çık
                child: Text('Evet, Çık', style: TextStyle(color: theme.colorScheme.error)),
              ),
            ],
          ),
        ) ?? false; // Kullanıcı bir seçim yapmazsa false döner

        if (shouldPop && mounted) {
          // Opsiyonel: Kullanıcı çıkarsa Firestore'daki kaydın durumunu 'cancelled_by_creator_while_waiting' gibi bir değere güncelleyebilirsiniz.
          // Bu, diğer kullanıcının boşuna beklememesini sağlar veya size analiz için veri sunar.
          // Örnek:
          // try {
          //   await FirebaseFirestore.instance.collection('records').doc(widget.recordId).update({'status': 'creator_cancelled_waiting'});
          // } catch (e) { print("Tutanak iptal edilirken hata: $e"); }

          // Ana sayfaya kadar tüm sayfaları kapat
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diğer Sürücünün Onayı Bekleniyor'),
          automaticallyImplyLeading: false, // Geri tuşunu AppBar'da gösterme
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('records')
              .doc(widget.recordId) // Dinlenecek belge benzersiz ID ile belirtiliyor
              .snapshots(),
          builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              // Veri henüz gelmediyse ve bekliyorsa
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              print("WaitingForConfirmationPage StreamBuilder Hatası: ${snapshot.error}");
              return Center(
                 child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline_rounded, color: theme.colorScheme.error, size: 50),
                      const SizedBox(height: 10),
                      Text(
                        'Veri akışında bir hata oluştu. Lütfen internet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium
                      ),
                      const SizedBox(height: 5),
                      Text('Hata: ${snapshot.error}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              // Belge bulunamadı veya silindi. Bu durumda kullanıcıyı ana sayfaya yönlendirmek mantıklı.
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tutanak kaydı bulunamadı veya silinmiş. Ana sayfaya yönlendiriliyorsunuz.')),
                  );
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              });
              return const Center(child: Text('Tutanak kaydı bulunamadı...'));
            }

            final data = snapshot.data!.data();
            if (data == null) {
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Tutanak verisi okunamadı. Ana sayfaya yönlendiriliyorsunuz.')),
                        );
                        Navigator.popUntil(context, (route) => route.isFirst);
                    }
                });
                return const Center(child: Text('Tutanak verisi boş...'));
            }

            print("WaitingForConfirmationPage - Gelen Veri: $data");

            // Katılan kullanıcının onay durumunu ve genel durumu kontrol et
            final bool isJoinerConfirmed = data['confirmedByJoiner'] == true && data['status'] == 'joiner_confirmed';
            print('WaitingForConfirmationPage - isJoinerConfirmed: $isJoinerConfirmed (confirmedByJoiner: ${data['confirmedByJoiner']}, status: ${data['status']})');


            if (isJoinerConfirmed) {
              // Katılan kullanıcı onayladıysa, bu sayfa (oluşturan kullanıcı için) bir sonraki adıma geçmeli.
              WidgetsBinding.instance.addPostFrameCallback((_) async {
                if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
                  print("WaitingForConfirmationPage: Katılan onayladı, LocationSelectionPage'e yönlendirme tetiklendi!");

                  // Yönlendirme yapmadan önce creatorVehicleId'yi Firestore'dan çek
                  final String? creatorVehicleIdFromDoc = data['creatorVehicleId'] as String?;

                  if (creatorVehicleIdFromDoc == null || creatorVehicleIdFromDoc.isEmpty) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Hata: Oluşturanın araç ID bilgisi alınamadı.')),
                      );
                      Navigator.popUntil(context, (route) => route.isFirst); // Ana sayfaya dön
                    }
                    return;
                  }
                  
                  if (mounted) { // SnackBar ve yönlendirme öncesi son bir kontrol
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade300),
                            const SizedBox(width: 8),
                            const Text('Diğer sürücü onayladı!'),
                          ],
                        ),
                        duration: const Duration(milliseconds: 1800),
                      ),
                    );

                    // Gecikmeli yönlendirme (UI'ın güncellenmesi için)
                    Future.delayed(const Duration(milliseconds: 500), () {
                       if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
                          Navigator.pushReplacement( // Geri tuşuyla bu sayfaya gelinmemesi için
                            context,
                            MaterialPageRoute(
                              builder: (_) => LocationSelectionPage(
                                recordId: widget.recordId, // Benzersiz tutanak ID'si
                                isCreator: true, // Bu sayfa oluşturan tarafından görülüyor
                                currentUserVehicleId: creatorVehicleIdFromDoc, // Firestore'dan çekilen
                              ),
                            ),
                          );
                       }
                    });
                  }
                }
              });
              
              // Yönlendirme yapılırken gösterilecek UI
              return Center(
                 child: Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.how_to_reg_rounded, size: 100, color: Colors.green.shade500),
                      const SizedBox(height: 24),
                      Text('Onay Alındı!', style: theme.textTheme.headlineMedium?.copyWith(color: Colors.green.shade700, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 12),
                      Text('Kaza yeri ve hasar bilgileri adımına yönlendiriliyorsunuz...', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                      const SizedBox(height: 30),
                      const CircularProgressIndicator(),
                    ],
                  ),
                )
              );
            }
            
            // Katılan kullanıcı henüz onaylamadıysa bekleme ekranı UI'ı
            return Padding(
               padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 1500),
                    curve: Curves.easeInOut,
                    builder: (context, value, child) {
                      return Opacity(
                        opacity: value,
                        child: Transform.scale(
                          scale: 0.8 + (value * 0.2),
                          child: child,
                        ),
                      );
                    },
                    child: Icon(Icons.hourglass_empty_rounded, size: 90, color: theme.colorScheme.primary),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Diğer Sürücünün Onayı Bekleniyor...',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Lütfen diğer sürücünün QR kodunuzu okutup kendi bilgilerini onaylamasını bekleyin. Bu işlem birkaç dakika sürebilir. Bu ekrandan ayrılmayın.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(height: 1.4, color: theme.colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 32),
                  LinearProgressIndicator(
                    backgroundColor: theme.colorScheme.primary.withOpacity(0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                    minHeight: 6,
                    borderRadius: BorderRadius.circular(3),
                  ),
                  const SizedBox(height: 30),
                   TextButton.icon(
                      icon: Icon(Icons.qr_code_scanner_rounded, color: theme.colorScheme.secondary), // İkon güncellendi
                      label: Text("QR Kodunu Tekrar Göster", style: TextStyle(color: theme.colorScheme.secondary)),
                      onPressed: (){
                          // Kullanıcı QR kodunu tekrar göstermek için bir önceki sayfaya (QRDisplayPage) dönebilir.
                          // pushReplacement ile gelindiyse, bu pop işlemi bir önceki (DriverAndVehicleInfoPage) sayfaya atar.
                          // Bu akışın doğru yönetilmesi için QRDisplayPage'den push ile gelinmesi daha iyi olabilir
                          // veya burada QRDisplayPage'e push ile yönlendirme yapılabilir.
                          // Şimdilik basitçe pop yapıyoruz, bu QRDisplayPage'i tekrar açmaz,
                          // DriverAndVehicleInfoPage'e döner. Bu istenen davranış olmayabilir.
                          // Doğru davranış: QRDisplayPage'e geri dönmek.
                          // Bu, QRDisplayPage'den pushReplacement yerine push ile gelinmesini gerektirir.
                          // Veya buradan QRDisplayPage'e push edilebilir.
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context); // Bu, QRDisplayPage'e geri döner (eğer oradan push ile gelindiyse)
                          } else {
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('QR kodu bir önceki ekranda gösterilmişti. Ana sayfaya dönülüyor.'))
                            );
                            Navigator.popUntil(context, (route) => route.isFirst);
                          }
                      },
                  )
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}