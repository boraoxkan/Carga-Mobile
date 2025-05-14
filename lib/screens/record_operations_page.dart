// lib/screens/record_operations_page.dart
import 'package:flutter/material.dart';
import 'new_record_warning_page.dart';

class RecordOperationsPage extends StatelessWidget {
  const RecordOperationsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tutanak İşlemleri'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // “Yeni Tutanak Oluştur” akışı – isJoining: false
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewRecordWarningPage(isJoining: false),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Yeni Tutanak Oluştur"),
            ),
            const SizedBox(height: 20),
            // “Yeni Tutanak’a Dahil Ol” akışı – isJoining: true
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NewRecordWarningPage(isJoining: true),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text("Yeni Tutanak'a Dahil Ol"),
            ),
          ],
        ),
      ),
    );
  }
}
