// File: lib/screens/report_summary_page.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_selection_page.dart'; // CrashRegion enum için

class ReportSummaryPage extends StatefulWidget {
  final Set<CrashRegion> selectedRegions;
  final Map<String, String> vehicleInfo;
  final LatLng confirmedPosition;

  const ReportSummaryPage({
    Key? key,
    required this.selectedRegions,
    required this.vehicleInfo,
    required this.confirmedPosition,
  }) : super(key: key);

  @override
  _ReportSummaryPageState createState() => _ReportSummaryPageState();
}

class _ReportSummaryPageState extends State<ReportSummaryPage> {
  final TextEditingController _notesController = TextEditingController();

  String _regionLabel(CrashRegion region) {
    switch (region) {
      case CrashRegion.frontLeft:
        return 'Ön Sol';
      case CrashRegion.frontCenter:
        return 'Ön';
      case CrashRegion.frontRight:
        return 'Ön Sağ';
      case CrashRegion.left:
        return 'Sol';
      case CrashRegion.right:
        return 'Sağ';
      case CrashRegion.rearLeft:
        return 'Arka Sol';
      case CrashRegion.rearCenter:
        return 'Arka';
      case CrashRegion.rearRight:
        return 'Arka Sağ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rapor Özeti'),
        backgroundColor: Colors.purple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Seçilen Bölge(ler):', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: widget.selectedRegions
                  .map((r) => Chip(label: Text(_regionLabel(r))))
                  .toList(),
            ),
            const SizedBox(height: 16),
            const Text('Araç Bilgileri:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Marka: ${widget.vehicleInfo['brand']}'),
            Text('Model: ${widget.vehicleInfo['model']}'),
            Text('Plaka: ${widget.vehicleInfo['plate']}'),
            const SizedBox(height: 16),
            const Text('Kaza Konumu:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('(${widget.confirmedPosition.latitude.toStringAsFixed(5)}, '
                '${widget.confirmedPosition.longitude.toStringAsFixed(5)})'),
            const SizedBox(height: 24),
            const Text('Eklemek İstediğiniz Notlar:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: TextField(
                controller: _notesController,
                maxLines: null,
                expands: true,
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'Kendi yorumunuzu buraya yazabilirsiniz…',
                ),
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: () {
                // TODO: Firestore’a kaydetme
                Navigator.popUntil(context, (r) => r.isFirst);
              },
              child: const Text('Raporu Tamamla ve Gönder'),
            ),
          ],
        ),
      ),
    );
  }
}
