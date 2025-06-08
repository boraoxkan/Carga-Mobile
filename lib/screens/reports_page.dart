// lib/screens/reports_page.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:tutanak/screens/pdf_viewer_page.dart';
import 'package:tutanak/screens/report_detail_page.dart';

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
  final String _dateFieldForOrdering = 'createdAt';

  // --- Yardımcı Fonksiyonlar ---

  String _formatTimestamp(Timestamp? timestamp, BuildContext context) {
    if (timestamp == null) return 'Tarih Bilgisi Yok';
    final locale = Localizations.localeOf(context).toString();
    try {
      return DateFormat('dd MMMM yyyy, HH:mm', locale).format(timestamp.toDate());
    } catch (e) {
      return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
    }
  }

  Future<void> _softDeleteReport(String recordId, String currentUserUid, Map<String, dynamic> reportData) async {
    final String creatorUid = reportData['creatorUid'] as String? ?? '';
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

  // --- Ana Build Metodu ---
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(child: Text('Raporlarınızı görmek için lütfen giriş yapın.'));
    }

    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('records')
          .where(
            Filter.or(
              Filter.and(
                Filter('creatorUid', isEqualTo: user.uid),
                Filter.or(Filter('isDeletedByCreator', isEqualTo: false), Filter('isDeletedByCreator', isNull: true))
              ),
              Filter.and(
                Filter('joinerUid', isEqualTo: user.uid),
                 Filter.or(Filter('isDeletedByJoiner', isEqualTo: false), Filter('isDeletedByJoiner', isNull: true))
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
          return Center(child: Text('Hata: ${snapshot.error}'));
        }
        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Görüntülenecek rapor bulunmuyor.'));
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
            bool hasProcessedPhoto = report.containsKey('creatorProcessedDamageImageBase64') || report.containsKey('joinerProcessedDamageImageBase64');

            // ---------- YENİ BUTON MANTIĞI BAŞLANGICI ----------
            final String? aiPdfUrl = report['aiReportPdfUrl'] as String?;
            final String? aiReportStatus = report['aiReportStatus'] as String?;

            Widget aiButtonLeading;
            String aiButtonTitle = "AI Sigorta Raporu";
            String? aiButtonSubtitle;
            VoidCallback? aiButtonOnTap;

            // Durum 1: PDF hazır ve görüntülenebilir.
            if (aiPdfUrl != null && aiPdfUrl.isNotEmpty) {
                aiButtonLeading = Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.secondary);
                aiButtonTitle = "AI Raporunu Görüntüle";
                aiButtonOnTap = () {
                    Navigator.push(context, MaterialPageRoute(
                        builder: (context) => PdfViewerPage(pdfUrl: aiPdfUrl, title: "AI Sigorta Raporu"),
                    ));
                };
            } 
            // Durum 2: Rapor tamamlanmış ama PDF henüz hazır değil (veya hata oluşmuş).
            else if (status == 'all_data_submitted') {
                if (aiReportStatus == 'Failed') {
                    aiButtonLeading = Icon(Icons.error_outline, color: theme.colorScheme.error);
                    aiButtonTitle = "AI Raporu Oluşturulamadı";
                    aiButtonSubtitle = "Bir hata oluştu. Detaylar için tıklayın."; // Opsiyonel
                    aiButtonOnTap = () {
                      showDialog(context: context, builder: (context) => AlertDialog(
                        title: Text("Oluşturma Hatası"),
                        content: Text("Rapor oluşturulurken bir sunucu hatası meydana geldi. Lütfen daha sonra tekrar deneyin veya geliştirici ile iletişime geçin.\n\nHata Detayı: ${report['aiReportError'] ?? 'Bilinmiyor'}"),
                        actions: [TextButton(onPressed: ()=>Navigator.pop(context), child: Text("Tamam"))],
                      ));
                    };
                } else {
                    aiButtonLeading = SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2, color: theme.colorScheme.secondary,));
                    aiButtonTitle = "AI Raporu Oluşturuluyor";
                    aiButtonSubtitle = "Bu işlem birkaç dakika sürebilir...";
                    aiButtonOnTap = null; // Oluşturulurken tıklanamaz.
                }
            } 
            // Durum 3: Rapor henüz tamamlanmamış.
            else {
                aiButtonLeading = Icon(Icons.hourglass_empty_rounded, color: Colors.grey);
                aiButtonTitle = "AI Sigorta Raporu";
                aiButtonSubtitle = "Tüm taraflar bilgilerini tamamladığında oluşturulacak.";
                aiButtonOnTap = null; // Henüz hazır değilken tıklanamaz.
            }
            // ---------- YENİ BUTON MANTIĞI SONU ----------

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
              child: ExpansionTile(
                key: PageStorageKey(reportDoc.id),
                leading: Icon(
                  hasProcessedPhoto ? Icons.image_search_rounded : Icons.description_rounded,
                  color: hasProcessedPhoto ? theme.colorScheme.primary : theme.colorScheme.secondary,
                  size: 32,
                ),
                title: Text(title, style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text("Durum: $status\nID: ${reportDoc.id.substring(0, 10)}..."),
                childrenPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                expandedCrossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text("Tutanak ID: ${reportDoc.id}", style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  const SizedBox(height: 10),
                  ListTile(
                    leading: Icon(Icons.visibility_outlined, color: theme.colorScheme.primary),
                    title: const Text('Tutanak Detaylarını Görüntüle'),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => ReportDetailPage(recordId: reportDoc.id))),
                  ),

                  // --- GÜNCELLENMİŞ BUTON KULLANIMI ---
                  ListTile(
                    leading: aiButtonLeading,
                    title: Text(aiButtonTitle),
                    subtitle: aiButtonSubtitle != null ? Text(aiButtonSubtitle) : null,
                    enabled: aiButtonOnTap != null,
                    onTap: aiButtonOnTap,
                  ),
                  // --- BİTİŞ ---

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