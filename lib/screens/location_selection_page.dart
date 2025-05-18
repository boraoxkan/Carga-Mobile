// File: lib/screens/location_selection_page.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart'; // Firebase Auth için
import 'package:cloud_firestore/cloud_firestore.dart'; // Firestore için
import 'location_confirm_page.dart';
import 'report_summary_page.dart';
import 'package:tutanak/models/crash_region.dart';

class LocationSelectionPage extends StatefulWidget {
  final String recordId; // creatorUid|creatorVehicleId formatında
  final bool isCreator;
  final String? currentUserVehicleId;

  const LocationSelectionPage({
    Key? key,
    required this.recordId,
    required this.isCreator,
    required this.currentUserVehicleId,
  }) : super(key: key);

  @override
  _LocationSelectionPageState createState() => _LocationSelectionPageState();
}

class _LocationSelectionPageState extends State<LocationSelectionPage> {
  final Set<CrashRegion> _selectedRegions = {};

  void _toggleRegion(CrashRegion region) {
    setState(() {
      if (_selectedRegions.contains(region)) {
        _selectedRegions.remove(region);
      } else {
        _selectedRegions.add(region);
      }
    });
  }

  Offset _offsetForRegion(CrashRegion region, Size size) {
    // Kullanıcının sağladığı offset değerleri kullanılıyor
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
    // Kullanıcının sağladığı label'lar kullanılıyor
    switch (region) {
      case CrashRegion.frontLeft:
        return 'Ön Sol';
      case CrashRegion.frontCenter:
        return 'Ön'; // "Ön Orta" olarak da düşünebilirsiniz.
      case CrashRegion.frontRight:
        return 'Ön Sağ';
      case CrashRegion.left:
        return 'Sol'; // "Sol Taraf" olarak da düşünebilirsiniz.
      case CrashRegion.right:
        return 'Sağ'; // "Sağ Taraf" olarak da düşünebilirsiniz.
      case CrashRegion.rearLeft:
        return 'Arka Sol';
      case CrashRegion.rearCenter:
        return 'Arka'; // "Arka Orta" olarak da düşünebilirsiniz.
      case CrashRegion.rearRight:
        return 'Arka Sağ';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreator
            ? 'Aracınızdaki Hasar Bölgeleri' // Başlık güncellendi
            : 'Aracınızdaki Hasar Bölgeleri'),// Başlık güncellendi
        backgroundColor: Colors.purple,
      ),
      body: Column(
        children: [
           Padding( // Kullanıcıya yönelik bir açıklama eklendi
            padding: const EdgeInsets.all(16.0),
            child: Text(
              "Lütfen aracınızın hasar alan/alanlarını aşağıdaki şemadan seçiniz.",
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          Expanded(
            child: Center(
              child: SizedBox( // Container yerine SizedBox kullanılabilir
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Icon(
                      Icons.directions_car,
                      size: 180,
                      color: Colors.purple.shade200, // Renk biraz açıldı
                    ),
                    for (var region in CrashRegion.values)
                      Positioned(
                        // Düğme boyutunu (40x40) göz önüne alarak merkezlemek için -20
                        left: _offsetForRegion(region, const Size(300, 300)).dx - 20,
                        top: _offsetForRegion(region, const Size(300, 300)).dy - 20,
                        child: GestureDetector(
                          onTap: () => _toggleRegion(region),
                          child: Container(
                            width: 40, // Düğme boyutu artırıldı
                            height: 40, // Düğme boyutu artırıldı
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _selectedRegions.contains(region)
                                  ? Colors.red.shade400 // Seçiliyse kırmızı
                                  : Colors.deepPurple.withOpacity(0.3), // Seçili değilse mor ve transparan
                              border: Border.all(
                                color: _selectedRegions.contains(region) ? Colors.red.shade700 : Colors.deepPurple, 
                                width: 2
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  spreadRadius: 1,
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                )
                              ]
                            ),
                            child: _selectedRegions.contains(region) // Seçiliyse check ikonu
                                ? const Icon(Icons.check, color: Colors.white, size: 24)
                                : null,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          if (_selectedRegions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16,8,16,16), // Alt boşluk artırıldı
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Seçilen Bölgeler:", style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Colors.black54)),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: _selectedRegions.map((r) {
                      return Chip(
                        label: Text(_regionLabel(r), style: TextStyle(color: Colors.red.shade900)),
                        backgroundColor: Colors.red.shade100,
                        avatar: Icon(Icons.warning_amber_rounded, color: Colors.red.shade700, size: 18),
                        deleteIcon: Icon(Icons.close, size: 16, color: Colors.red.shade700),
                        onDeleted: () {
                          _toggleRegion(r);
                        },
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          const SizedBox(height:10), 
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: ElevatedButton(
              onPressed: _selectedRegions.isEmpty
                  ? null
                  : () async {
                      // currentUserVehicleId kontrolü
                      if (widget.currentUserVehicleId == null || widget.currentUserVehicleId!.isEmpty) {
                          if(mounted) { // mounted kontrolü eklendi
                            ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Araç ID bilgisi bulunamadı. Lütfen önceki adıma dönüp araç seçiminizi kontrol edin.')),
                            );
                          }
                          return;
                      }

                      final LatLng initialPos = const LatLng(41.0082, 28.9784); 
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
                      if (!mounted) return; // Async işlem sonrası context kontrolü

                      Map<String, String> actualVehicleInfo = {
                        'brand': 'Bilinmiyor',
                        'model': 'Bilinmiyor',
                        'plate': 'Bilinmiyor',
                      };

                      final currentUser = FirebaseAuth.instance.currentUser;
                      
                      if (currentUser != null) { // currentUser null kontrolü
                        try {
                          print("LocationSelectionPage: Fetching vehicle info for user: ${currentUser.uid}, vehicle ID: ${widget.currentUserVehicleId}");
                          
                          String vehicleOwnerUid = currentUser.uid;

                          final vehicleDoc = await FirebaseFirestore.instance
                              .collection('users')
                              .doc(vehicleOwnerUid) 
                              .collection('vehicles')
                              .doc(widget.currentUserVehicleId)
                              .get();

                          if (vehicleDoc.exists && vehicleDoc.data() != null) {
                            final data = vehicleDoc.data()!;
                            actualVehicleInfo = {
                              'brand': data['marka']?.toString() ?? 'Belirtilmemiş',
                              'model': data['model']?.toString() ?? (data['seri']?.toString() ?? 'Belirtilmemiş'),
                              'plate': data['plaka']?.toString() ?? 'Belirtilmemiş',
                            };
                            print("LocationSelectionPage: Vehicle info fetched: $actualVehicleInfo");
                          } else {
                            print("LocationSelectionPage: Error - Vehicle document not found for user ${vehicleOwnerUid} and vehicle ID ${widget.currentUserVehicleId}");
                            if(mounted) { // mounted kontrolü eklendi
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Seçilen araç bilgileri bulunamadı.')),
                              );
                            }
                          }
                        } catch (e, s) {
                          print("LocationSelectionPage: Error fetching vehicle info: $e");
                          print("Stack trace: $s");
                          if(mounted) { // mounted kontrolü eklendi
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Araç bilgileri çekilirken bir hata oluştu: $e')),
                            );
                          }
                        }
                      } else {
                         print("LocationSelectionPage: Error - Current user is null.");
                         if(mounted) { // mounted kontrolü eklendi
                          ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Kullanıcı bilgisi alınamadı. Araç detayları çekilemedi.')),
                          );
                        }
                      }
                      
                      if (!mounted) return; // Son bir context kontrolü
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ReportSummaryPage(
                            selectedRegions: _selectedRegions,
                            vehicleInfo: actualVehicleInfo,
                            confirmedPosition: confirmedPos,
                            recordId: widget.recordId,      // << BU SATIR EKLENDİ/GÜNCELLENDİ
                            isCreator: widget.isCreator,    // << BU SATIR EKLENDİ
                          ),
                        ),
                      );
                    },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
              ),
              child: const Text('Konum Seçimi ve Devam'),
            ),
          ),
        ],
      ),
    );
  }
}