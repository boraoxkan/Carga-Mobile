// File: lib/screens/location_selection_page.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'location_confirm_page.dart';
import 'report_summary_page.dart';

enum CrashRegion {
  frontLeft,
  frontCenter,
  frontRight,
  left,
  right,
  rearLeft,
  rearCenter,
  rearRight,
}

class LocationSelectionPage extends StatefulWidget {
  final String recordId;
  final bool isCreator;

  const LocationSelectionPage({
    Key? key,
    required this.recordId,
    required this.isCreator,
  }) : super(key: key);

  @override
  _LocationSelectionPageState createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  final Set<CrashRegion> _selectedRegions = {};

  void _toggleRegion(CrashRegion region) {
    setState(() {
      if (_selectedRegions.contains(region))
        _selectedRegions.remove(region);
      else
        _selectedRegions.add(region);
    });
  }

  Offset _offsetForRegion(CrashRegion region, Size size) {
    switch (region) {
      case CrashRegion.frontLeft:
        return Offset(size.width * 0.2, size.height * 0.1);
      case CrashRegion.frontCenter:
        return Offset(size.width * 0.5, size.height * 0.1);
      case CrashRegion.frontRight:
        return Offset(size.width * 0.8, size.height * 0.1);
      case CrashRegion.left:
        return Offset(size.width * 0.1, size.height * 0.5);
      case CrashRegion.right:
        return Offset(size.width * 0.9, size.height * 0.5);
      case CrashRegion.rearLeft:
        return Offset(size.width * 0.2, size.height * 0.9);
      case CrashRegion.rearCenter:
        return Offset(size.width * 0.5, size.height * 0.9);
      case CrashRegion.rearRight:
        return Offset(size.width * 0.8, size.height * 0.9);
    }
  }

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
        title: Text(widget.isCreator
            ? 'Kaza Yeri Seçimi (Oluşturan)'
            : 'Kaza Yeri Seçimi (Katılan)'),
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: Container(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 180,
                      color: Colors.purple,
                    ),
                    for (var region in CrashRegion.values)
                      Positioned(
                        left:
                            _offsetForRegion(region, Size(300, 300)).dx - 16,
                        top:
                            _offsetForRegion(region, Size(300, 300)).dy - 16,
                        child: GestureDetector(
                          onTap: () => _toggleRegion(region),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedRegions.contains(region)
                                  ? Colors.purple
                                  : Colors.white,
                              border: Border.all(color: Colors.purple),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_selectedRegions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Wrap(
                spacing: 8,
                children: _selectedRegions.map((r) {
                  return Chip(
                    label: Text(_regionLabel(r)),
                    backgroundColor: Colors.purple.shade100,
                  );
                }).toList(),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _selectedRegions.isEmpty
                  ? null
                  : () async {
                      // 1) Harita üzerinden konum seçimi
                      final LatLng initialPos =
                          LatLng(41.0082, 28.9784); // örnek başlangıç
                      final LatLng? confirmedPos =
                          await Navigator.push<LatLng>(
                        context,
                        MaterialPageRoute(
                          builder: (_) => LocationConfirmPage(
                            recordId: widget.recordId,
                            initialPosition: initialPos,
                          ),
                        ),
                      );
                      if (confirmedPos == null) return;

                      // 2) Araç bilgilerini fetch edip örnek bir map oluşturun:
                      final vehicleInfo = {
                        'brand': 'Toyota',
                        'model': 'Corolla',
                        'plate': '34ABC12',
                      };

                      // 3) Rapor özetine yönlendirin
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportSummaryPage(
                            selectedRegions: _selectedRegions,
                            vehicleInfo: vehicleInfo,
                            confirmedPosition: confirmedPos,
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('Devam'),
            ),
          ),
        ],
      ),
    );
  }
}
