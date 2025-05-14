// lib/screens/vehicle_details_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class VehicleDetailsPage extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicleData;

  const VehicleDetailsPage({
    Key? key,
    required this.vehicleId,
    required this.vehicleData,
  }) : super(key: key);

  @override
  _VehicleDetailsPageState createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  List<dynamic> photos = [];

  @override
  void initState() {
    super.initState();
    // Eğer "photos" alanı varsa, onu listeye aktar; yoksa boş liste kullan.
    if (widget.vehicleData.containsKey('photos')) {
      photos = List<dynamic>.from(widget.vehicleData['photos']);
    }
  }

  Future<void> _uploadPhoto() async {
    // FilePicker ile resim seçimi yapılıyor.
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );
    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) return;
      String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      Reference storageRef = FirebaseStorage.instance
          .ref()
          .child('users')
          .child(user.uid)
          .child('vehicles')
          .child(widget.vehicleId)
          .child('photos')
          .child(fileName);
      UploadTask uploadTask = storageRef.putFile(file);
      TaskSnapshot snapshot = await uploadTask;
      String downloadUrl = await snapshot.ref.getDownloadURL();

      // Firestore'da aracın belgesindeki "photos" alanına yeni URL ekleniyor.
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .doc(widget.vehicleId)
          .update({
        'photos': FieldValue.arrayUnion([downloadUrl]),
      });

      setState(() {
        photos.add(downloadUrl);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fotoğraf yüklendi.')),
      );
    }
  }

  Widget _buildDetailRow({required IconData icon, required String label, required String value}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.blueAccent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$label:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Ana sayfa, araç bilgileri ve fotoğraf galerisini içeriyor.
    return Scaffold(
      appBar: AppBar(
        title: const Text('Araç Detayları'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Aracın detay bilgilerini gösteren modern görünümlü Card.
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
                child: Column(
                  children: [
                    _buildDetailRow(
                      icon: Icons.directions_car,
                      label: 'Marka',
                      value: widget.vehicleData['marka'] ?? '-',
                    ),
                    const Divider(),
                    _buildDetailRow(
                      icon: Icons.category,
                      label: 'Seri',
                      value: widget.vehicleData['seri'] ?? '-',
                    ),
                    const Divider(),
                    _buildDetailRow(
                      icon: Icons.directions,
                      label: 'Model',
                      value: widget.vehicleData['model'] ?? '-',
                    ),
                    const Divider(),
                    _buildDetailRow(
                      icon: Icons.date_range,
                      label: 'Model Yılı',
                      value: widget.vehicleData['modelYili'] ?? '-',
                    ),
                    const Divider(),
                    _buildDetailRow(
                      icon: Icons.business_center,
                      label: 'Kullanım Şekli',
                      value: widget.vehicleData['kullanim'] ?? '-',
                    ),
                    const Divider(),
                    _buildDetailRow(
                      icon: Icons.confirmation_number,
                      label: 'Plaka',
                      value: widget.vehicleData['plaka'] ?? '-',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            // Fotoğraf başlığı
            Text(
              'Araç Fotoğrafları',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            // Eğer hiç fotoğraf yüklenmediyse; placeholder görünümü, fotoğraf varsa grid görünümü.
            photos.isEmpty
                ? Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade400),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Center(
                      child: TextButton.icon(
                        onPressed: _uploadPhoto,
                        icon: const Icon(Icons.add_a_photo, color: Colors.blue),
                        label: const Text(
                          'Fotoğraf Ekle',
                          style: TextStyle(color: Colors.blue),
                        ),
                      ),
                    ),
                  )
                : GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                    ),
                    itemCount: photos.length + 1, // Son hücre ek fotoğraf ekleme butonu için
                    itemBuilder: (context, index) {
                      if (index == photos.length) {
                        return GestureDetector(
                          onTap: _uploadPhoto,
                          child: Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Center(
                              child: Icon(Icons.add, color: Colors.blue),
                            ),
                          ),
                        );
                      } else {
                        String photoUrl = photos[index];
                        return GestureDetector(
                          onTap: () {
                            // Fotoğrafa tıklandığında tam ekran görüntülemek için
                            showDialog(
                              context: context,
                              builder: (_) => Dialog(
                                child: Image.network(photoUrl),
                              ),
                            );
                          },
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(photoUrl, fit: BoxFit.cover),
                          ),
                        );
                      }
                    },
                  ),
          ],
        ),
      ),
    );
  }
}
