/// File: lib/screens/waiting_for_confirmation_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_selection_page.dart';

class WaitingForConfirmationPage extends StatelessWidget {
  final String recordId;
  const WaitingForConfirmationPage({Key? key, required this.recordId}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Onay Bekleniyor')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('records')
            .doc(recordId)
            .snapshots(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data!;
          if (data.exists && data.get('confirmed') == true) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => LocationSelectionPage(
                    recordId: recordId,
                    isCreator: true,
                  ),
                ),
              );
            });
            return const Center(child: Text('Yönlendiriliyor...'));
          }
          return const Center(child: Text('Diğer sürücünün onayı bekleniyor...'));
        },
      ),
    );
  }
}