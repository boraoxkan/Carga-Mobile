// lib/screens/reports_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart'; // Tarih formatlama için eklendi
import 'package:tutanak/screens/report_detail_page.dart';
// PDF görüntüleyici için pdf_viewer_page.dart importu gerekiyorsa ekleyin
// import 'pdf_viewer_page.dart';
// flutter_slidable importu kaldırılabilir, çünkü ExpansionTile ile farklı bir yaklaşım kullanacağız
// import 'package:flutter_slidable/flutter_slidable.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  static void showAddReportDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manuel rapor ekleme şimdilik devre dışı.')),
    );
  }

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  // Raporun hangi tarihe göre sıralanacağını belirleyen alan adı
  // Firestore belgenizde 'creatorLastUpdateTimestamp', 'joinerLastUpdateTimestamp',
  // 'confirmedTimestamp' veya genel bir 'createdAt' gibi bir alan olmalı.
  // Örnek olarak 'creatorLastUpdateTimestamp' kullanalım.
  // Eğer bu alan yoksa veya farklı bir isimdeyse, aşağıdaki sorguyu ve
  // tarih alma kısmını kendi alan adınıza göre güncelleyin.
  final String _dateFieldForOrdering = 'creatorLastUpdateTimestamp'; // VEYA 'confirmedTimestamp' veya 'createdAt'

  // Tarihi formatlamak için bir yardımcı fonksiyon
  String _formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) {
      return 'Tarih Bilgisi Yok';
    }
    // Türkçe lokasyon ile formatlama
    final DateFormat formatter = DateFormat('dd MMMM yyyy, HH:mm', 'tr_TR');
    return formatter.format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Giriş yapılmamış.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('records')
          .where(
            Filter.or(
              Filter('creatorUid', isEqualTo: user.uid),
              Filter('joinerUid', isEqualTo: user.uid)
            )
          )
          // Tarihe göre sıralama (en yeni en üstte)
          // Firestore'da bu alan için bir indeks oluşturmanız gerekebilir.
          .orderBy(_dateFieldForOrdering, descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          print("Raporlar sayfasında hata: ${snapshot.error}");
          print("Hata stack trace: ${snapshot.stackTrace}");
          return Center(child: Text('Raporlar yüklenirken bir hata oluştu.\nDetay: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Henüz bir tutanak kaydınız bulunmuyor.'));
        } else {
          final reports = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final reportDoc = reports[index];
              final report = reportDoc.data() as Map<String, dynamic>;
              
              // Rapor başlığı için tarihi alalım
              // Örnek olarak creator'ın son güncelleme zamanını veya joiner'ınkini alabiliriz
              // Ya da 'confirmedTimestamp' gibi genel bir onaylanma zamanı
              Timestamp? reportTimestamp;
              if (report.containsKey(_dateFieldForOrdering) && report[_dateFieldForOrdering] is Timestamp) {
                reportTimestamp = report[_dateFieldForOrdering] as Timestamp?;
              } else if (report.containsKey('joinerLastUpdateTimestamp') && report['joinerLastUpdateTimestamp'] is Timestamp) {
                // Fallback olarak joiner'ın zamanını da kontrol edebiliriz
                reportTimestamp = report['joinerLastUpdateTimestamp'] as Timestamp?;
              }
              // Veya genel bir 'createdAt' alanı varsa:
              // else if (report.containsKey('createdAt') && report['createdAt'] is Timestamp) {
              //   reportTimestamp = report['createdAt'] as Timestamp?;
              // }

              String title = _formatTimestamp(reportTimestamp);
              String status = report['status'] as String? ?? "Bilinmiyor";
              bool hasProcessedPhoto = report.containsKey('creatorProcessedDamageImageBase64') ||
                                       report.containsKey('joinerProcessedDamageImageBase64');

              return Card( // Her bir ExpansionTile'ı bir Card içine alarak daha belirgin hale getirebiliriz
                margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                child: ExpansionTile(
                  key: PageStorageKey(reportDoc.id), // Scroll pozisyonunu korumak için
                  leading: Icon(
                    hasProcessedPhoto ? Icons.image_search_outlined : Icons.description_outlined,
                    color: hasProcessedPhoto ? Colors.green.shade700 : Colors.blueGrey.shade700,
                    size: 30,
                  ),
                  title: Text(
                    title, // Başlık olarak formatlanmış tarih
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text("Durum: $status\nTutanak ID: ${reportDoc.id.substring(0,10)}..."), // ID'nin bir kısmını göster
                  childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      "Tutanak ID: ${reportDoc.id}", // Tam ID'yi burada gösterebiliriz
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    const SizedBox(height: 10),
                    ListTile(
                      leading: const Icon(Icons.visibility_outlined, color: Colors.deepPurple),
                      title: const Text('İşlenmiş Raporu Görüntüle'),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReportDetailPage(recordId: reportDoc.id),
                          ),
                        );
                      },
                    ),
                    ListTile(
                      leading: const Icon(Icons.picture_as_pdf_outlined, color: Colors.redAccent),
                      title: const Text('PDF Raporu Oluştur/Görüntüle'),
                      onTap: () {
                        // TODO: PDF oluşturma ve görüntüleme fonksiyonunu buraya ekleyin
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('PDF Raporu özelliği yakında eklenecektir.')),
                        );
                        // Örnek: Eğer PDF URL'si Firestore'da saklanıyorsa:
                        // final String? pdfUrl = report['pdfUrl'] as String?;
                        // final String? pdfTitle = report['pdfTitle'] as String? ?? "Tutanak PDF";
                        // if (pdfUrl != null) {
                        //   Navigator.push(
                        //     context,
                        //     MaterialPageRoute(
                        //       builder: (context) => PdfViewerPage(pdfUrl: pdfUrl, title: pdfTitle),
                        //     ),
                        //   );
                        // } else {
                        //   ScaffoldMessenger.of(context).showSnackBar(
                        //     const SnackBar(content: Text('Bu rapor için PDF bulunamadı.')),
                        //   );
                        // }
                      },
                    ),
                     // İsteğe bağlı: Silme butonu eklenebilir
                    ListTile(
                      leading: Icon(Icons.delete_outline, color: Colors.red.shade700),
                      title: Text('Bu Tutanağı Sil', style: TextStyle(color: Colors.red.shade700)),
                      onTap: () async {
                        bool confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Silme Onayı'),
                            content: Text('Bu tutanağı (${reportDoc.id.substring(0,6)}...) silmek istediğinize emin misiniz?'),
                            actions: [
                              TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('İptal')),
                              TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Sil', style: TextStyle(color: Colors.red))),
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
                    ),
                  ],
                ),
              );
            },
          );
        }
      },
    );
  }
}