// lib/screens/reports_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:tutanak/screens/report_detail_page.dart';
// PDF görüntüleyici importu gerekirse:
// import 'pdf_viewer_page.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  static void showAddReportDialog(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Manuel rapor ekleme özelliği şu an için aktif değil.')),
    );
  }

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  final String _dateFieldForOrdering = 'createdAt'; // Veya 'reportFinalizedTimestamp'

  String _formatTimestamp(Timestamp? timestamp, BuildContext context) {
    if (timestamp == null) {
      return 'Tarih Bilgisi Yok';
    }
    final locale = Localizations.localeOf(context).toString();
    try {
      return DateFormat('dd MMMM yyyy, HH:mm', locale).format(timestamp.toDate());
    } catch (e) {
      return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
    }
  }

  Future<void> _softDeleteReport(String recordId, String currentUserUid, Map<String, dynamic> reportData) async {
    final String creatorUid = reportData['creatorUid'] as String? ?? '';
    // final String? joinerUid = reportData['joinerUid'] as String?;

    Map<String, dynamic> updateData = {};
    if (currentUserUid == creatorUid) {
      updateData['isDeletedByCreator'] = true;
    } else { 
      updateData['isDeletedByJoiner'] = true;
    }

    if (updateData.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('records').doc(recordId).update(updateData);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Rapor listenizden kaldırıldı.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Rapor kaldırılırken hata: $e')),
          );
        }
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Raporlarınızı görmek için lütfen giriş yapın.', textAlign: TextAlign.center),
        ),
      );
    }

    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('records')
          .where(
            Filter.or(
              Filter.and(
                Filter('creatorUid', isEqualTo: user.uid),
                Filter.or(
                  Filter('isDeletedByCreator', isEqualTo: false),
                  Filter('isDeletedByCreator', isNull: true) 
                )
              ),
              Filter.and(
                Filter('joinerUid', isEqualTo: user.uid),
                 Filter.or(
                  Filter('isDeletedByJoiner', isEqualTo: false),
                  Filter('isDeletedByJoiner', isNull: true) 
                )
              )
            )
          )
          .orderBy(_dateFieldForOrdering, descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          // Hata mesajını ve stack trace'i konsola yazdır
          print("Raporlar sayfasında Firestore sorgu hatası: ${snapshot.error}");
          print("Hata stack trace: ${snapshot.stackTrace}");
          // Kullanıcıya daha genel bir hata mesajı göster
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: theme.colorScheme.error, size: 50),
                  const SizedBox(height: 10),
                  const Text(
                    'Raporlar yüklenirken bir sorun oluştu.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Lütfen daha sonra tekrar deneyin veya internet bağlantınızı kontrol edin.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                  // Geliştirme aşamasında hatayı görmek için:
                  // Text('Detay: ${snapshot.error}', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            )
          );
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.folder_off_outlined, size: 80, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  Text(
                    'Görüntülenecek rapor bulunmuyor.',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                   Text(
                    "Oluşturduğunuz veya katıldığınız tutanaklar burada listelenir.",
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            )
          );
        }

        final reports = snapshot.data!.docs;
        return ListView.builder(
          padding: const EdgeInsets.all(8.0),
          itemCount: reports.length,
          itemBuilder: (context, index) {
            final reportDoc = reports[index];
            final report = reportDoc.data(); 
            
            Timestamp? reportTimestamp = report[_dateFieldForOrdering] as Timestamp? ?? report['reportFinalizedTimestamp'] as Timestamp?;
            String title = _formatTimestamp(reportTimestamp, context);
            String status = report['status'] as String? ?? "Bilinmiyor";
            
            bool hasProcessedPhoto = report.containsKey('creatorProcessedDamageImageBase64') ||
                                     report.containsKey('joinerProcessedDamageImageBase64');

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: ExpansionTile(
                key: PageStorageKey(reportDoc.id),
                leading: Icon(
                  hasProcessedPhoto ? Icons.image_search_rounded : Icons.description_rounded,
                  color: hasProcessedPhoto ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  size: 32,
                ),
                title: Text(
                  title,
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  "Durum: $status\nID: ${reportDoc.id.substring(0, 10)}...",
                  style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    "Tutanak ID: ${reportDoc.id}",
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: Icon(Icons.visibility_outlined, color: theme.colorScheme.primary),
                    title: const Text('Tutanak Detaylarını Görüntüle'),
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
                    leading: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                    title: Text('Bu Tutanağı Listemden Kaldır', style: TextStyle(color: theme.colorScheme.error)),
                    onTap: () async {
                      bool confirm = await showDialog<bool>(
                        context: context,
                        builder: (BuildContext dialogContext) => AlertDialog(
                          title: const Text('Listeden Kaldırma Onayı'),
                          content: Text('Bu tutanağı (${reportDoc.id.substring(0,6)}...) kendi listenizden kaldırmak istediğinize emin misiniz?\n\nBu işlem, diğer kullanıcı için tutanağı silmeyecektir.'),
                          actions: [
                            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('İptal')),
                            TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: Text('Listemden Kaldır', style: TextStyle(color: theme.colorScheme.error))),
                          ],
                        ),
                      ) ?? false;
                      
                      if (confirm) {
                          await _softDeleteReport(reportDoc.id, user.uid, report);
                      }
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}