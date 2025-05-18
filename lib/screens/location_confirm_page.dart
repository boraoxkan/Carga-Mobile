// lib/screens/location_confirm_page.dart
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationConfirmPage extends StatefulWidget {
  final String recordId; // Bu parametre kullanılmıyor gibi, ama constructor'da kalmış
  final LatLng initialPosition;

  const LocationConfirmPage({
    Key? key,
    required this.recordId, // Kullanılmıyorsa kaldırılabilir
    required this.initialPosition,
  }) : super(key: key);

  @override
  _LocationConfirmPageState createState() => _LocationConfirmPageState();
}

class _LocationConfirmPageState extends State<LocationConfirmPage> {
  GoogleMapController? _mapController;
  late LatLng _markerPosition;
  bool _loadingRealPosition = true;
  bool _permissionDenied = false; // İzin reddedilme durumunu takip etmek için

  @override
  void initState() {
    super.initState();
    _markerPosition = widget.initialPosition;
    _fetchRealPosition();
  }

  Future<void> _fetchRealPosition() async {
    if (!mounted) return;
    setState(() {
      _loadingRealPosition = true;
      _permissionDenied = false;
    });

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
        if (mounted) {
          setState(() {
            _loadingRealPosition = false;
            _permissionDenied = true;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni verilmedi. Lütfen marker\'ı manuel olarak ayarlayın.')),
          );
        }
        return;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
         if (mounted) {
          setState(() {
            _loadingRealPosition = false;
            _permissionDenied = true;
          });
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Konum izni kalıcı olarak reddedildi. Ayarlardan izin vermeniz gerekir.')),
          );
        }
        return;
    }


    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 10)); // Timeout süresi artırıldı
      if (mounted) {
        setState(() {
          _markerPosition = LatLng(pos.latitude, pos.longitude);
          _loadingRealPosition = false;
        });
        _mapController?.animateCamera(
          CameraUpdate.newLatLngZoom(_markerPosition, 16.5), // Daha yakın bir zoom seviyesi
        );
      }
    } catch (e) {
      print("Gerçek konum alınırken hata: $e");
      if (mounted) {
        setState(() => _loadingRealPosition = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Gerçek konumunuz alınamadı. Lütfen marker\'ı manuel olarak ayarlayın.')),
        );
      }
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    // Eğer gerçek konum zaten alındıysa veya izin reddedildiyse, haritayı mevcut marker pozisyonuna animasyonla getir
    if (!_loadingRealPosition) {
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_markerPosition, _permissionDenied ? 14.0 : 16.5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kaza Konumunu Doğrulayın'),
      ),
      body: Stack(
        alignment: Alignment.center,
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: CameraPosition(target: _markerPosition, zoom: 14), // Başlangıç zoom'u
            myLocationEnabled: !_permissionDenied, // İzin varsa kendi konumunu göster
            myLocationButtonEnabled: !_permissionDenied, // İzin varsa butonu göster
            markers: {
              Marker(
                markerId: const MarkerId('selectedAccidentLocation'),
                position: _markerPosition,
                draggable: true,
                onDragEnd: (newPosition) {
                  if (mounted) {
                    setState(() => _markerPosition = newPosition);
                  }
                },
                icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed), // Kırmızı marker
                infoWindow: const InfoWindow(title: "Kaza Yeri", snippet: "Konumu sürükleyerek ayarlayabilirsiniz."),
              )
            },
            onTap: (newPosition) {
               if (mounted) {
                setState(() => _markerPosition = newPosition);
                 _mapController?.animateCamera(CameraUpdate.newLatLng(newPosition));
              }
            },
            zoomControlsEnabled: true, // Harita üzerinde +/- butonları
            mapToolbarEnabled: false, // Google Haritalar uygulamasını açma butonunu gizle
            // mapType: MapType.hybrid, // İsteğe bağlı: Uydu görünümü için
          ),
          // Yükleme göstergesi ekranın ortasında ve haritanın üzerinde
          if (_loadingRealPosition)
            Container(
              color: Colors.black.withOpacity(0.3), // Hafif karartma
              child: Center(
                child: Card( // Daha şık bir yükleme göstergesi
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(color: theme.colorScheme.primary),
                        const SizedBox(height: 16),
                        Text("Mevcut konumunuz alınıyor...", style: theme.textTheme.titleMedium),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          // "Bu Konumu Onayla" butonu ekranın altında
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container( // Butonun etrafına gölge ve padding için
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), // Alt boşluk artırıldı
              decoration: BoxDecoration(
                gradient: LinearGradient( // Hafif bir gradient
                  colors: [
                    theme.scaffoldBackgroundColor.withOpacity(0.0),
                    theme.scaffoldBackgroundColor.withOpacity(0.8),
                    theme.scaffoldBackgroundColor,
                  ],
                  stops: const [0.0, 0.3, 0.6],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: ElevatedButton.icon(
                icon: const Icon(Icons.check_circle_outline_rounded),
                label: const Text('Bu Konumu Onayla'),
                style: ElevatedButton.styleFrom( // Tema'dan gelecek ama padding ayarlanabilir
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _loadingRealPosition // Konum hala yükleniyorsa butonu pasif yap
                    ? null
                    : () => Navigator.pop(context, _markerPosition),
              ),
            ),
          ),
           // Kullanıcıya ipucu (isteğe bağlı)
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Card(
              color: theme.colorScheme.surfaceVariant.withOpacity(0.9),
              child: Padding(
                padding: const EdgeInsets.all(10.0),
                child: Text(
                  "Kaza yerini tam olarak işaretlemek için marker'ı sürükleyebilir veya haritaya dokunabilirsiniz.",
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}