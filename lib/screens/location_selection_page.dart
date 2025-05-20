// lib/screens/location_selection_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'location_confirm_page.dart';
import 'report_summary_page.dart';
import 'package:tutanak/models/crash_region.dart'; // CrashRegion enum'ı

class LocationSelectionPage extends StatefulWidget {
  final String recordId;
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
  Map<String, String>? _currentVehicleInfo;
  bool _isLoadingVehicleInfo = true;

  @override
  void initState() {
    super.initState();
    _fetchCurrentVehicleInfo();
  }

  Future<void> _fetchCurrentVehicleInfo() async {
    // ... (Bu metot bir önceki cevapta olduğu gibi kalacak) ...
    if (widget.currentUserVehicleId == null || widget.currentUserVehicleId!.isEmpty) {
      if (mounted) {
        setState(() {
          _isLoadingVehicleInfo = false;
          _currentVehicleInfo = {
            'brand': 'Bilinmiyor', 'model': 'Bilinmiyor', 'plate': 'Plakasız',
          };
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Araç ID bilgisi bulunamadı.')),
        );
      }
      return;
    }

    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) {
       if (mounted) {
        setState(() => _isLoadingVehicleInfo = false);
         ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Kullanıcı girişi yapılmamış.')),
        );
      }
      return;
    }
    try {
      final vehicleDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser.uid)
          .collection('vehicles')
          .doc(widget.currentUserVehicleId)
          .get();
      if (mounted) {
        if (vehicleDoc.exists && vehicleDoc.data() != null) {
          final data = vehicleDoc.data()!;
          setState(() {
            _currentVehicleInfo = {
              'brand': data['marka']?.toString() ?? 'Belirtilmemiş',
              'model': data['model']?.toString() ?? (data['seri']?.toString() ?? 'Belirtilmemiş'),
              'plate': data['plaka']?.toString() ?? 'Belirtilmemiş',
            };
            _isLoadingVehicleInfo = false;
          });
        } else {
          setState(() => _isLoadingVehicleInfo = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Seçilen araç bilgileri bulunamadı.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingVehicleInfo = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Araç bilgileri çekilirken hata: $e')),
        );
      }
    }
  }

  void _toggleRegion(CrashRegion region) {
    setState(() {
      if (_selectedRegions.contains(region)) {
        _selectedRegions.remove(region);
      } else {
        _selectedRegions.add(region);
      }
    });
  }

  // Araç üzerindeki hasar noktalarının konumlarını yüzdesel olarak tanımlar
  Offset _getRelativeOffsetForRegion(CrashRegion region) {
    switch (region) {
      case CrashRegion.frontLeft:   return const Offset(0.25, 0.15); // Sol ön
      case CrashRegion.frontCenter: return const Offset(0.50, 0.10); // Ön orta
      case CrashRegion.frontRight:  return const Offset(0.75, 0.15); // Sağ ön
      case CrashRegion.left:        return const Offset(0.15, 0.50); // Sol orta
      case CrashRegion.right:       return const Offset(0.85, 0.50); // Sağ orta
      case CrashRegion.rearLeft:    return const Offset(0.25, 0.85); // Sol arka
      case CrashRegion.rearCenter:  return const Offset(0.50, 0.90); // Arka orta
      case CrashRegion.rearRight:   return const Offset(0.75, 0.85); // Sağ arka
    }
  }

  String _regionLabel(CrashRegion region) {
    switch (region) {
      case CrashRegion.frontLeft:   return 'Ön Sol';
      case CrashRegion.frontCenter: return 'Ön Orta';
      case CrashRegion.frontRight:  return 'Ön Sağ';
      case CrashRegion.left:        return 'Sol Taraf';
      case CrashRegion.right:       return 'Sağ Taraf';
      case CrashRegion.rearLeft:    return 'Arka Sol';
      case CrashRegion.rearCenter:  return 'Arka Orta';
      case CrashRegion.rearRight:   return 'Arka Sağ';
      default: return region.name;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const double selectionButtonRadius = 22.0; 

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isCreator
            ? 'Aracınızdaki Hasar Bölgeleri'
            : 'Diğer Araçtaki Hasar Bölgeleri'),
      ),
      body: _isLoadingVehicleInfo
          ? const Center(child: CircularProgressIndicator())
          : _currentVehicleInfo == null
              ? Center( /* ... (Hata durumu öncekiyle aynı) ... */ )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20.0, 20.0, 20.0, 12.0),
                      child: Text(
                        "Lütfen aracınızın hasar gören bölgelerini aşağıdaki şemadan işaretleyiniz.",
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleMedium?.copyWith(height: 1.4),
                      ),
                    ),
                    Expanded(
                      // Hasar seçim alanı için LayoutBuilder kullanarak esnek boyutlandırma
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final double carAreaSize = constraints.maxWidth * 0.75 < constraints.maxHeight * 0.75
                              ? constraints.maxWidth * 0.75
                              : constraints.maxHeight * 0.75;
                          
                          final double carIconSize = carAreaSize * 0.7;


                          return Center(
                            child: Container(
                              width: carAreaSize,
                              height: carAreaSize,
                              // decoration: BoxDecoration(border: Border.all(color: Colors.grey)), // Alanı görmek için
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  // Araç İkonu (veya Image.asset ile kendi görseliniz)
                                  Icon(
                                    Icons.directions_car_filled_rounded,
                                    size: carIconSize,
                                    color: theme.colorScheme.primary.withOpacity(0.15),
                                  ),
                                  // Tıklanabilir hasar bölgeleri
                                  for (var region in CrashRegion.values)
                                    Builder( 
                                      builder: (context) {
                                        Offset relativeOffset = _getRelativeOffsetForRegion(region);
                                        // Butonun merkezi, hesaplanan göreceli konumda olacak
                                        double left = (relativeOffset.dx * carAreaSize) - selectionButtonRadius;
                                        double top = (relativeOffset.dy * carAreaSize) - selectionButtonRadius;

                                        return Positioned(
                                          left: left,
                                          top: top,
                                          child: InkWell(
                                            onTap: () => _toggleRegion(region),
                                            borderRadius: BorderRadius.circular(selectionButtonRadius),
                                            splashColor: _selectedRegions.contains(region)
                                                ? theme.colorScheme.error.withOpacity(0.3)
                                                : theme.colorScheme.primary.withOpacity(0.3),
                                            child: Container(
                                              width: selectionButtonRadius * 2,
                                              height: selectionButtonRadius * 2,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _selectedRegions.contains(region)
                                                    ? theme.colorScheme.error.withOpacity(0.7)
                                                    : theme.colorScheme.secondary.withOpacity(0.25),
                                                border: Border.all(
                                                  color: _selectedRegions.contains(region)
                                                      ? theme.colorScheme.error
                                                      : theme.colorScheme.secondary.withOpacity(0.5),
                                                  width: 1.5,
                                                ),
                                                boxShadow: [
                                                   if (_selectedRegions.contains(region))
                                                    BoxShadow(
                                                      color: theme.colorScheme.error.withOpacity(0.3),
                                                      blurRadius: 5,
                                                      spreadRadius: 1
                                                    )
                                                ]
                                              ),
                                              child: _selectedRegions.contains(region)
                                                  ? Icon(Icons.priority_high_rounded, 
                                                      color: theme.colorScheme.onError,
                                                      size: selectionButtonRadius * 1.2)
                                                  : Center(
                                                      child: Text(
                                                        _regionLabel(region)[0], 
                                                        style: TextStyle(
                                                          color: theme.colorScheme.onSecondaryContainer.withOpacity(0.7),
                                                          fontWeight: FontWeight.bold,
                                                          fontSize: selectionButtonRadius * 0.7,
                                                        ),
                                                      ),
                                                    ),
                                            ),
                                          ),
                                        );
                                      }
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    if (_selectedRegions.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Seçilen Hasar Bölgeleri:", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              children: _selectedRegions.map((r) {
                                return Chip(
                                  label: Text(_regionLabel(r), style: TextStyle(color: theme.colorScheme.onError)),
                                  backgroundColor: theme.colorScheme.error,
                                  avatar: Icon(Icons.report_gmailerrorred_rounded, color: theme.colorScheme.onError, size: 20),
                                  deleteIcon: Icon(Icons.cancel_rounded, size: 18, color: theme.colorScheme.onError.withOpacity(0.7)),
                                  onDeleted: () {
                                    _toggleRegion(r);
                                  },
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)), 
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 20.0), 
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.location_on_rounded, size: 20),
                        label: const Text('Konum Seçimi ve Devam'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: _selectedRegions.isEmpty || _currentVehicleInfo == null
                            ? null
                            : () async {
                               // ... (LocationConfirmPage ve ReportSummaryPage'e yönlendirme kodu) 
                                final LatLng initialPos = const LatLng(41.0082, 28.9784);
                                if (!mounted) return;
                                final LatLng? confirmedPos = await Navigator.push<LatLng>(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LocationConfirmPage(
                                      recordId: widget.recordId,
                                      initialPosition: initialPos,
                                    ),
                                  ),
                                );
                                if (confirmedPos == null || !mounted) return;
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ReportSummaryPage(
                                      selectedRegions: _selectedRegions,
                                      vehicleInfo: _currentVehicleInfo!,
                                      confirmedPosition: confirmedPos,
                                      recordId: widget.recordId,
                                      isCreator: widget.isCreator,
                                    ),
                                  ),
                                );
                              },
                      ),
                    ),
                  ],
                ),
    );
  }
}