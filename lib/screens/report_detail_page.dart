// lib/screens/report_detail_page.dart (YENİ DOSYA)
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:tutanak/screens/pdf_viewer_page.dart'; // PDF görüntüleyici için
// CrashRegion enum'ını projenizdeki doğru yerden import edin
import 'package:tutanak/models/crash_region.dart';

class ReportDetailPage extends StatelessWidget {
  final String recordId;

  const ReportDetailPage({Key? key, required this.recordId}) : super(key: key);

  String _regionLabel(CrashRegion region) {
    // Bu metodu report_summary_page'den kopyalayabilirsiniz
    switch (region) {
      case CrashRegion.frontLeft: return 'Ön Sol';
      case CrashRegion.frontCenter: return 'Ön Orta';
      // ... diğer durumlar
      default: return region.name;
    }
  }

  Widget _buildSectionTitle(BuildContext context, String title, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: color, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildPhotoDisplay(String? base64Image, List<dynamic>? detections, String partyName) {
    if (base64Image == null || base64Image.isEmpty) {
      return Text("$partyName için işlenmiş fotoğraf bulunmuyor.", style: const TextStyle(fontStyle: FontStyle.italic));
    }
    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(child: Image.memory(imageBytes, height: 250, fit: BoxFit.contain)),
          if (detections != null && detections.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Text("Tespit Edilen Hasarlar:", style: TextStyle(fontWeight: FontWeight.bold)),
            ...detections.map((d) {
              final detectionMap = d as Map<String, dynamic>;
              return Text("  - ${detectionMap['label'] ?? 'Bilinmiyor'} (%${((detectionMap['confidence'] ?? 0.0) * 100).toStringAsFixed(0)})");
            }).toList(),
          ]
        ],
      );
    } catch (e) {
      print("Base64 decode error for $partyName: $e");
      return Text("$partyName için fotoğraf görüntülenirken hata oluştu.", style: const TextStyle(color: Colors.red));
    }
  }

  Widget _buildRegionsDisplay(List<String>? regionNames, String partyName) {
    if (regionNames == null || regionNames.isEmpty) {
      return Text("$partyName için hasar bölgesi seçilmemiş.", style: const TextStyle(fontStyle: FontStyle.italic));
    }
    Set<CrashRegion> regions = regionNames.map((name) {
      try { return CrashRegion.values.byName(name); }
      catch(e) { return null; }
    }).whereType<CrashRegion>().toSet();

    return Wrap(
      spacing: 8, runSpacing: 4,
      children: regions.map((r) => Chip(label: Text(_regionLabel(r)))).toList(),
    );
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Rapor Detayı"),
        backgroundColor: Colors.purple,
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('records').doc(recordId).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Hata: ${snapshot.error}"));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Rapor bulunamadı."));
          }

          final data = snapshot.data!.data() as Map<String, dynamic>;

          // PDF bilgilerini al (eğer varsa)
          final String? pdfTitle = data['title'] as String?; // Firestore'daki PDF başlık alanınız
          final String? pdfUrl = data['pdfUrl'] as String?;   // Firestore'daki PDF URL alanınız

          // Creator bilgileri
          final creatorNotes = data['creatorNotes'] as String?;
          final creatorRegions = List<String>.from(data['creatorDamageRegions'] ?? []);
          final creatorPhotoBase64 = data['creatorProcessedDamageImageBase64'] as String?;
          final creatorDetections = data['creatorDetectionResults'] as List<dynamic>?;

          // Joiner bilgileri
          final joinerNotes = data['joinerNotes'] as String?;
          final joinerRegions = List<String>.from(data['joinerDamageRegions'] ?? []);
          final joinerPhotoBase64 = data['joinerProcessedDamageImageBase64'] as String?;
          final joinerDetections = data['joinerDetectionResults'] as List<dynamic>?;


          return SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Text("Tutanak ID: $recordId", style: Theme.of(context).textTheme.titleMedium)),
                const SizedBox(height: 10),
                if (pdfUrl != null && pdfTitle != null)
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf, color: Colors.red, size: 30),
                    title: Text(pdfTitle, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: const Text("Tutanak PDF'ini Görüntüle"),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PdfViewerPage(pdfUrl: pdfUrl, title: pdfTitle),
                        ),
                      );
                    },
                  ),
                const Divider(height: 30),

                _buildSectionTitle(context, "TUTANAK OLUŞTURANIN BİLGİLERİ", Colors.deepPurple),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Seçilen Hasar Bölgeleri:", style: TextStyle(fontWeight: FontWeight.bold)),
                      _buildRegionsDisplay(creatorRegions, "Oluşturan"),
                      const SizedBox(height: 10),
                      const Text("Notlar:", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(creatorNotes ?? "Eklenmemiş."),
                      const SizedBox(height: 10),
                      const Text("İşlenmiş Hasar Fotoğrafı:", style: TextStyle(fontWeight: FontWeight.bold)),
                      _buildPhotoDisplay(creatorPhotoBase64, creatorDetections, "Oluşturan"),
                    ]),
                  ),
                ),
                const SizedBox(height: 20),

                 _buildSectionTitle(context, "TUTANAĞA KATILANIN BİLGİLERİ", Colors.orange.shade800),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text("Seçilen Hasar Bölgeleri:", style: TextStyle(fontWeight: FontWeight.bold)),
                      _buildRegionsDisplay(joinerRegions, "Katılan"),
                      const SizedBox(height: 10),
                      const Text("Notlar:", style: TextStyle(fontWeight: FontWeight.bold)),
                      Text(joinerNotes ?? "Eklenmemiş."),
                      const SizedBox(height: 10),
                      const Text("İşlenmiş Hasar Fotoğrafı:", style: TextStyle(fontWeight: FontWeight.bold)),
                       _buildPhotoDisplay(joinerPhotoBase64, joinerDetections, "Katılan"),
                    ]),
                  ),
                ),
                 const SizedBox(height: 20),
                 // Ortak bilgiler (konum vs.) buraya eklenebilir.
              ],
            ),
          );
        },
      ),
    );
  }
}