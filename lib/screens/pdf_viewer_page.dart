// lib/screens/pdf_viewer_page.dart
import 'dart:io'; // File işlemleri için eklendi
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerPage extends StatelessWidget {
  final String? pdfUrl; // Artık opsiyonel, null olabilir
  final String? pdfPath; // Yerel dosya yolu için yeni opsiyonel parametre
  final String title;

  const PdfViewerPage({
    Key? key,
    this.pdfUrl,
    this.pdfPath,
    required this.title,
  }) : assert(pdfUrl != null || pdfPath != null, "pdfUrl veya pdfPath sağlanmalıdır"), // En az birisi dolu olmalı
       super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget pdfViewerWidget;

    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      pdfViewerWidget = SfPdfViewer.network(pdfUrl!);
    } else if (pdfPath != null && pdfPath!.isNotEmpty) {
      // Yerel dosyanın var olup olmadığını kontrol etmek iyi bir pratik olabilir
      // if (await File(pdfPath!).exists()) { ... }
      pdfViewerWidget = SfPdfViewer.file(File(pdfPath!));
    } else {
      // Bu durum assert nedeniyle normalde oluşmamalı, ama bir fallback olarak eklenebilir
      pdfViewerWidget = const Center(
        child: Text("Görüntülenecek PDF kaynağı bulunamadı."),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: pdfViewerWidget,
    );
  }
}