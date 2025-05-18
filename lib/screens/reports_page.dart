// lib/screens/reports_page.dart
import 'dart:io'; // FilePicker için gerekli olabilir, şimdilik yorumda
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:tutanak/screens/report_detail_page.dart'; // YENİ EKLENDİ
// import 'pdf_viewer_page.dart'; // Artık ReportDetailPage içinde yönetilecek
import 'package:flutter_slidable/flutter_slidable.dart';
// import 'package:file_picker/file_picker.dart'; // PDF yükleme için kalabilir
// import 'package:firebase_storage/firebase_storage.dart'; // PDF yükleme için kalabilir

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  static void showAddReportDialog(BuildContext context) {
    // _ReportsPageState()._showAddReportDialog(context); // PDF ekleme dialogu hala çalışabilir
    // Veya bu butonu kaldırıp, raporların sadece uygulama akışıyla oluşmasını sağlayabilirsiniz.
     ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manuel rapor ekleme şimdilik devre dışı.')),
      );
  }

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Giriş yapılmamış.'));

    // Kullanıcının dahil olduğu (creatorUid veya joinerUid) raporları çek
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('records') // 'records' koleksiyonunu dinle
          .where(Filter.or( // Kullanıcının ya oluşturan ya da katılan olduğu kayıtları filtrele
                Filter('creatorUid', isEqualTo: user.uid),
                Filter('joinerUid', isEqualTo: user.uid)
            ))
          // .orderBy('date', descending: true) // 'date' alanı varsa sıralama için kullanın
          .orderBy(FieldPath.documentId) // Veya ID'ye göre sırala
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Henüz bir tutanak kaydınız bulunmuyor.'));
        } else {
          final reports = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final reportDoc = reports[index];
              final report = reportDoc.data() as Map<String, dynamic>;
              
              // Rapor başlığı (PDF başlığı veya recordId olabilir)
              String title = report['title'] ?? "Tutanak: ${reportDoc.id.substring(0,10)}..."; // Firestore'dan gelen PDF başlığı
              
              // Rapor tarihi (Firestore'da uygun bir tarih alanı varsa)
              DateTime? reportDate;
              // Örneğin 'createdAt', 'lastUpdated_creator', 'lastUpdated_joiner' gibi bir alan varsa:
              if (report['lastUpdated_creator'] != null) {
                reportDate = (report['lastUpdated_creator'] as Timestamp).toDate();
              } else if (report['lastUpdated_joiner'] != null) {
                 reportDate = (report['lastUpdated_joiner'] as Timestamp).toDate();
              }
              // else if (report['createdAt'] != null) { // Veya oluşturulma tarihi
              //   reportDate = (report['createdAt'] as Timestamp).toDate();
              // }

              // İşlenmiş fotoğraf var mı kontrolü (basit bir örnek)
              bool hasProcessedPhoto = report.containsKey('creatorProcessedDamageImageBase64') ||
                                       report.containsKey('joinerProcessedDamageImageBase64');
              String status = report['status'] as String? ?? "Bilinmiyor";


              return Slidable(
                key: Key(reportDoc.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (context) async {
                        // Silme onayı ve işlemi (Bu kısım aynı kalabilir)
                         bool confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Silme Onayı'),
                            content: Text('Bu tutanağı (${reportDoc.id.substring(0,6)}...) silmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('İptal')),
                              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sil')),
                            ],
                          ),
                        ) ?? false;
                        
                        if (confirm) {
                          try {
                            await FirebaseFirestore.instance.collection('records').doc(reportDoc.id).delete();
                            if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Tutanak silindi.')));
                          } catch (e) {
                            if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Silme hatası: $e')));
                          }
                        }
                      },
                      backgroundColor: Colors.red,foregroundColor: Colors.white,
                      icon: Icons.delete, label: 'Sil',
                    ),
                  ],
                ),
                child: ListTile(
                  leading: Icon(
                    hasProcessedPhoto ? Icons.image_search : Icons.description_outlined, // İşlenmiş fotoğraf varsa farklı ikon
                    color: hasProcessedPhoto ? Colors.green : Colors.blueGrey,
                    size: 30,
                  ),
                  title: Text(title),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (reportDate != null) Text("Tarih: ${reportDate.day}.${reportDate.month}.${reportDate.year}"),
                      Text("Durum: $status"),
                    ],
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ReportDetailPage(recordId: reportDoc.id),
                      ),
                    );
                  },
                ),
              );
            },
          );
        }
      },
    );
  }

  // _showAddReportDialog PDF ekleme metodu (isteğe bağlı olarak kalabilir veya kaldırılabilir)
  // void _showAddReportDialog(BuildContext context) { ... }
}