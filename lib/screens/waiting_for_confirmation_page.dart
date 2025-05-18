// lib/screens/waiting_for_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_selection_page.dart';

class WaitingForConfirmationPage extends StatefulWidget {
  final String recordId;

  const WaitingForConfirmationPage({Key? key, required this.recordId}) : super(key: key);

  @override
  State<WaitingForConfirmationPage> createState() => _WaitingForConfirmationPageState();
}

class _WaitingForConfirmationPageState extends State<WaitingForConfirmationPage> {

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;
        final bool shouldPop = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Onay Beklemeden Çıkılsın mı?'),
            content: const Text(
                'Diğer sürücünün onayı bekleniyor. Bu ekrandan çıkarsanız, tutanak işlemi yarım kalabilir ve diğer sürücü tutanağa katılamayabilir.\n\nYine de çıkmak istiyor musunuz?'),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Beklemeye Devam Et'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text('Evet, Çık', style: TextStyle(color: theme.colorScheme.error)),
              ),
            ],
          ),
        ) ?? false;
        if (shouldPop && mounted) {
          // Opsiyonel: Firestore'daki kaydı iptal et
          // try {
          //   await FirebaseFirestore.instance.collection('records').doc(widget.recordId).update({'status': 'cancelled_by_creator_while_waiting'});
          // } catch (e) { print("İptal etme sırasında hata: $e"); }
          Navigator.popUntil(context, (route) => route.isFirst);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Diğer Sürücünün Onayı Bekleniyor'),
          automaticallyImplyLeading: false,
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: FirebaseFirestore.instance
              .collection('records')
              .doc(widget.recordId)
              .snapshots(),
          builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              print("WaitingForConfirmationPage StreamBuilder Hatası: ${snapshot.error}");
              return Center(
                // ... (Hata UI'ı öncekiyle aynı) ...
                 child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
                      const SizedBox(height: 10),
                      Text('Bir hata oluştu. Lütfen internet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.', textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
                      Text('${snapshot.error}', textAlign: TextAlign.center, style: theme.textTheme.bodySmall),
                    ],
                  ),
                )
              );
            }
            if (!snapshot.hasData || !snapshot.data!.exists) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tutanak kaydı bulunamadı. Ana sayfaya yönlendiriliyorsunuz.')),
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

            // --- DEBUG PRINT ---
            print("WaitingForConfirmationPage - Gelen Veri: $data");
            // --- DEBUG PRINT SONU ---

            // DÜZELTİLMİŞ Onay Kontrolü:
            final bool isJoinerConfirmed = data['confirmedByJoiner'] == true && data['status'] == 'joiner_confirmed';
            // Eğer sadece confirmedByJoiner'a bakmak isterseniz:
            // final bool isJoinerConfirmed = data['confirmedByJoiner'] == true;

            // --- DEBUG PRINT ---
            print('WaitingForConfirmationPage - isJoinerConfirmed: $isJoinerConfirmed');
            // --- DEBUG PRINT SONU ---

            if (isJoinerConfirmed) {
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
                  print("WaitingForConfirmationPage: Yönlendirme tetiklendi!");
                  final parts = widget.recordId.split('|');
                  final String? creatorVehicleId = parts.length == 2 ? parts[1] : null;

                  if (creatorVehicleId == null || creatorVehicleId.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Hata: Geçersiz kayıt ID formatı veya araç ID eksik.')),
                    );
                    Navigator.popUntil(context, (route) => route.isFirst);
                    return;
                  }
                  
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.check_circle_outline_rounded, color: Colors.green.shade300),
                          const SizedBox(width: 8),
                          const Text('Diğer sürücü onayladı!'),
                        ],
                      ),
                      duration: const Duration(milliseconds: 1800), // Biraz daha kısa tutabiliriz
                    ),
                  );

                  Future.delayed(const Duration(milliseconds: 500), () { // SnackBar'ın kapanmasını beklemeden hemen yönlendir
                     if (mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (_) => LocationSelectionPage(
                              recordId: widget.recordId,
                              isCreator: true,
                              currentUserVehicleId: creatorVehicleId,
                            ),
                          ),
                        );
                     }
                  });
                }
              });
              
              return Center(
                // ... (Onay alındı UI'ı öncekiyle aynı) ...
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
            
            // Bekleme ekranı UI
            return Padding(
              // ... (Bekleme ekranı UI'ı öncekiyle aynı) ...
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
                      icon: Icon(Icons.qr_code_rounded, color: theme.colorScheme.secondary),
                      label: Text("QR Kodunu Tekrar Göster", style: TextStyle(color: theme.colorScheme.secondary)),
                      onPressed: (){
                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          } else {
                             ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('QR kodu bir önceki ekranda gösterilmişti.'))
                            );
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