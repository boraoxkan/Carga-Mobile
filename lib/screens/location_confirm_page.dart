// File: lib/screens/location_confirm_page.dart

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';

class LocationConfirmPage extends StatefulWidget {
  final String recordId;
  final LatLng initialPosition;

  const LocationConfirmPage({
    Key? key,
    required this.recordId,
    required this.initialPosition,
  }) : super(key: key);

  @override
  _LocationConfirmPageState createState() => _LocationConfirmPageState();
}

class _LocationConfirmPageState extends State<LocationConfirmPage> {
  GoogleMapController? _mapController;
  late LatLng _markerPosition;
  bool _loadingRealPosition = true;

  @override
  void initState() {
    super.initState();
    _markerPosition = widget.initialPosition;
    _fetchRealPosition();
  }

  Future<void> _fetchRealPosition() async {
    LocationPermission perm = await Geolocator.requestPermission();
    if (perm != LocationPermission.always &&
        perm != LocationPermission.whileInUse) {
      setState(() => _loadingRealPosition = false);
      return;
    }
    try {
      Position pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high,
          timeLimit: const Duration(seconds: 5));
      setState(() {
        _markerPosition = LatLng(pos.latitude, pos.longitude);
        _loadingRealPosition = false;
      });
      _mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(_markerPosition, 16.5),
      );
    } catch (_) {
      setState(() => _loadingRealPosition = false);
    }
  }

  void _onMapCreated(GoogleMapController controller) {
    _mapController = controller;
    if (!_loadingRealPosition) {
      _mapController!.animateCamera(
        CameraUpdate.newLatLngZoom(_markerPosition, 16.5),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Konum Doğrulama'),
        backgroundColor: Colors.purple,
      ),
      body: Stack(
        children: [
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition:
                CameraPosition(target: _markerPosition, zoom: 14),
            myLocationEnabled: true,
            markers: {
              Marker(
                markerId: const MarkerId('selected'),
                position: _markerPosition,
                draggable: true,
                onDragEnd: (pos) => setState(() => _markerPosition = pos),
              )
            },
            onTap: (pos) => setState(() => _markerPosition = pos),
            zoomControlsEnabled: true,
          ),
          if (_loadingRealPosition)
            const Center(child: CircularProgressIndicator()),
          Positioned(
            bottom: 24,
            left: 24,
            right: 24,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                minimumSize: const Size.fromHeight(50),
              ),
              onPressed: _loadingRealPosition
                  ? null
                  : () => Navigator.pop(context, _markerPosition),
              child: const Text('Bu Konumu Onayla'),
            ),
          ),
        ],
      ),
    );
  }
}
