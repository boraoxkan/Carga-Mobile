// lib/screens/reports_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pdf_viewer_page.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class ReportsPage extends StatefulWidget {
  const ReportsPage({Key? key}) : super(key: key);

  static void showAddReportDialog(BuildContext context) {
    _ReportsPageState()._showAddReportDialog(context);
  }

  @override
  _ReportsPageState createState() => _ReportsPageState();
}

class _ReportsPageState extends State<ReportsPage> {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Giriş yapılmamış.'));

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('reports')
          .orderBy('date', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Hata: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Rapor bulunamadı.'));
        } else {
          final reports = snapshot.data!.docs;
          return ListView.builder(
            itemCount: reports.length,
            itemBuilder: (context, index) {
              final reportDoc = reports[index];
              final report = reportDoc.data() as Map<String, dynamic>;
              String title = report['title'] ?? 'Rapor';
              String? pdfUrl = report['pdfUrl'];
              DateTime? date;
              if (report['date'] != null) {
                date = (report['date'] as Timestamp).toDate();
              }
              return Slidable(
                key: Key(reportDoc.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (context) async {
                        bool confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Silme Onayı'),
                              content: const Text('Bu raporu silmek istediğinize emin misiniz?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Sil'),
                                ),
                              ],
                            );
                          },
                        ) ?? false;
                        
                        if (confirm) {
                          try {
                            await FirebaseFirestore.instance
                                .collection('users')
                                .doc(user.uid)
                                .collection('reports')
                                .doc(reportDoc.id)
                                .delete();
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Rapor silindi.')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Silme hatası: $e')),
                            );
                          }
                        }
                      },
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Sil',
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.insert_drive_file),
                  title: Text(title),
                  subtitle: date != null ? Text(date.toString()) : null,
                  trailing: pdfUrl != null
                      ? const Icon(Icons.picture_as_pdf, color: Colors.red)
                      : null,
                  onTap: () {
                    if (pdfUrl != null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PdfViewerPage(pdfUrl: pdfUrl, title: title),
                        ),
                      );
                    }
                  },
                ),
              );
            },
          );
        }
      },
    );
  }

  void _showAddReportDialog(BuildContext context) {
    final _formKey = GlobalKey<FormState>();
    TextEditingController titleController = TextEditingController();
    File? selectedFile;

    showDialog(
      context: context,
      builder: (context) {
        bool isUploading = false;
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Rapor Ekle'),
            content: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Rapor Başlığı',
                        border: OutlineInputBorder(),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Lütfen rapor başlığı giriniz';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () async {
                        FilePickerResult? result = await FilePicker.platform.pickFiles(
                          type: FileType.custom,
                          allowedExtensions: ['pdf'],
                        );
                        if (result != null && result.files.single.path != null) {
                          setState(() {
                            selectedFile = File(result.files.single.path!);
                          });
                        }
                      },
                      child: const Text('PDF Seç'),
                    ),
                    const SizedBox(height: 8),
                    Text(selectedFile != null
                        ? 'Seçilen dosya: ${selectedFile!.path.split('/').last}'
                        : 'Hiçbir dosya seçilmedi'),
                    if (isUploading) const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: CircularProgressIndicator(),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                child: const Text('İptal'),
              ),
              ElevatedButton(
                onPressed: () async {
                  if (!_formKey.currentState!.validate() || selectedFile == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Lütfen tüm alanları doldurun ve PDF seçin')),
                    );
                    return;
                  }
                  setState(() {
                    isUploading = true;
                  });
                  try {
                    User? user = FirebaseAuth.instance.currentUser;
                    if (user == null) return;
                    // PDF dosyasını Firebase Storage'a yükle
                    String fileName = '${DateTime.now().millisecondsSinceEpoch}.pdf';
                    Reference storageRef = FirebaseStorage.instance
                        .ref()
                        .child('users')
                        .child(user.uid)
                        .child('reports')
                        .child(fileName);
                    UploadTask uploadTask = storageRef.putFile(selectedFile!);
                    TaskSnapshot snapshot = await uploadTask;
                    String downloadUrl = await snapshot.ref.getDownloadURL();

                    // Firestore'a raporu ekle
                    await FirebaseFirestore.instance
                        .collection('users')
                        .doc(user.uid)
                        .collection('reports')
                        .add({
                      'title': titleController.text.trim(),
                      'pdfUrl': downloadUrl,
                      'date': FieldValue.serverTimestamp(),
                    });

                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Rapor eklendi.')),
                    );
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Rapor eklenirken hata oluştu: $e')),
                    );
                  }
                },
                child: const Text('Kaydet'),
              ),
            ],
          );
        });
      },
    );
  }
}
