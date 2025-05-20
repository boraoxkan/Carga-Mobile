// lib/screens/new_record_warning_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_and_vehicle_info_page.dart';

class NewRecordWarningPage extends StatelessWidget {
  final bool isJoining;
  const NewRecordWarningPage({Key? key, required this.isJoining}) : super(key: key);

  Future<void> _call112(BuildContext context) async {
    final Uri launchUri = Uri(scheme: 'tel', path: '112');
    // canLaunchUrl yerine launchUrl doğrudan kullanılabilir, hata durumunda exception fırlatır.
    try {
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (BuildContext dialogContext) => AlertDialog(
          title: const Text("112 Acil Yardım Çağrısı"),
          content: const Text("112 Acil Yardım'ı aramak istediğinize emin misiniz?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text("İptal"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: Text("Ara", style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        ),
      );
      if (confirmed == true) { 
        if (await canLaunchUrl(launchUri)) { 
            await launchUrl(launchUri);
        } else {
            if (context.mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Arama başlatılamadı: ${launchUri.toString()}")),
                );
            }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Telefon araması yapılırken hata oluştu: $e")),
        );
      }
    }
  }

  Widget _buildWarningItem(BuildContext context, String text) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle_outline, size: 20, color: theme.colorScheme.primary.withOpacity(0.8)),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(isJoining ? "Tutanağa Dahil Ol" : "Yeni Tutanak Oluştur"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 0, 
              color: theme.colorScheme.surfaceVariant.withOpacity(0.5), 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    Icon(Icons.gavel_rounded, size: 60, color: theme.colorScheme.primary),
                    const SizedBox(height: 16),
                    Text(
                      "Kaza Tespit Tutanağı Şartları",
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      "Aşağıdaki durumlar sizin için geçerliyse ve karşı tarafla anlaştıysanız, polis çağırmadan anlaşmalı kaza tespit tutanağı düzenleyebilirsiniz:",
                      style: theme.textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    _buildWarningItem(context, "Alkol veya uyuşturucu madde etkisi altında değilseniz,"),
                    _buildWarningItem(context, "Kazada ölüm veya yaralanma durumu yoksa,"),
                    _buildWarningItem(context, "Geçerli trafik sigortanız bulunuyorsa,"),
                    _buildWarningItem(context, "Araçlar kamu kurum ve kuruluşlarına ait değilse,"),
                    _buildWarningItem(context, "Kamu malına veya 3. kişilere zarar verilmemişse,"),
                    _buildWarningItem(context, "Kazaya karışan araç sayısı birden fazlaysa (karşılıklı anlaşma için),"),
                    _buildWarningItem(context, "Sürücü belgeniz geçerli ve kullandığınız araç türüne uygunsa,"),
                    const SizedBox(height: 24),
                    Text(
                      "Yukarıdaki şartlar sağlanmıyorsa veya anlaşmazlık varsa, lütfen trafik polisini (155) veya jandarmayı (156) arayın. Yaralanma durumunda ise 112 Acil Yardımı arayın.",
                      style: theme.textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.call_outlined),
                      label: const Text("112 Acil Yardımı Ara"),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        foregroundColor: theme.colorScheme.error,
                        side: BorderSide(color: theme.colorScheme.error.withOpacity(0.7)),
                      ),
                      onPressed: () => _call112(context),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverAndVehicleInfoPage(isJoining: isJoining),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50), 
                padding: const EdgeInsets.symmetric(vertical: 16)
              ),
              child: Text(isJoining ? "Şartları Anladım, Devam Et" : "Şartları Sağlıyorum, Devam Et"),
            ),
            const SizedBox(height: 16),
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text("Geri Dön", style: TextStyle(color: theme.colorScheme.primary))
            )
          ],
        ),
      ),
    );
  }
}