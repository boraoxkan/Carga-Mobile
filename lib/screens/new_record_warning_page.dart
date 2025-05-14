// lib/screens/new_record_warning_page.dart
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'driver_and_vehicle_info_page.dart';

class NewRecordWarningPage extends StatelessWidget {
  final bool isJoining;
  const NewRecordWarningPage({Key? key, required this.isJoining}) : super(key: key);

  Future<void> _call112(BuildContext context) async {
    final Uri launchUri = Uri(scheme: 'tel', path: '112');
    if (await canLaunchUrl(launchUri)) {
      bool? confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text("112 Acil Yardımı"),
          content: const Text("112'yi aramak ister misiniz?"),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("İptal"),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Ara"),
            ),
          ],
        ),
      );
      if (confirmed ?? false) {
        await launchUrl(launchUri);
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Telefon araması yapılamıyor.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Yeni Tutanak Oluştur"),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.yellow.shade100,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                children: [
                  const Text(
                    "KVKK kapsamında:\n"
                    "• Alkol veya uyuşturucu kullanımı yok ise\n"
                    "• Ölüm/yaralanma bulunmuyor ise\n"
                    "Trafik sigortanız bulunuyor ise\n"
                    "• Araç kamu kurum ve kuruluşlarına ait değil ise\n"
                    "• Kamu malına veya 3. kişiye zarar verilmemiş ise\n"
                    "Araç sayısı 1'den fazla ise\n"
                    "• Sürücü belgeniz var ve araç cinsine uygun ise",
                    style: TextStyle(fontSize: 16, color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () => _call112(context),
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                    child: const Text("112 Acil Yardımı Ara"),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // “Şartları Sağlıyorum” butonuna tıklandığında flow tipini koruyarak DriverAndVehicleInfoPage'e yönlendiriyoruz.
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => DriverAndVehicleInfoPage(isJoining: isJoining),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Şartları Sağlıyorum"),
            ),
          ],
        ),
      ),
    );
  }
}
