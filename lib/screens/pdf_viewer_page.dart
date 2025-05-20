// lib/screens/pdf_viewer_page.dart
import 'dart:io'; 
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfViewerPage extends StatelessWidget {
  final String? pdfUrl; 
  final String? pdfPath; 
  final String title;

  const PdfViewerPage({
    Key? key,
    this.pdfUrl,
    this.pdfPath,
    required this.title,
  }) : assert(pdfUrl != null || pdfPath != null, "pdfUrl veya pdfPath sağlanmalıdır"), 
       super(key: key);

  @override
  Widget build(BuildContext context) {
    Widget pdfViewerWidget;

    if (pdfUrl != null && pdfUrl!.isNotEmpty) {
      pdfViewerWidget = SfPdfViewer.network(pdfUrl!);
    } else if (pdfPath != null && pdfPath!.isNotEmpty) {
      pdfViewerWidget = SfPdfViewer.file(File(pdfPath!));
    } else {
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