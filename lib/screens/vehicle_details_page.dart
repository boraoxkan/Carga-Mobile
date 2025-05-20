// lib/screens/vehicle_details_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;

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
  late List<String> _photos;
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    var photoData = widget.vehicleData['photos'];
    if (photoData is List) {
      _photos = List<String>.from(photoData.whereType<String>());
    } else {
      _photos = [];
    }
  }

  Future<void> _uploadPhoto() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.image,
    );

    if (result != null && result.files.single.path != null) {
      File file = File(result.files.single.path!);
      User? user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Lütfen giriş yapın.")));
        return;
      }

      if (mounted) setState(() => _isUploading = true);

      try {
        String fileName = '${DateTime.now().millisecondsSinceEpoch}_${file.path.split('/').last}';
        firebase_storage.Reference storageRef = firebase_storage.FirebaseStorage.instance
            .ref()
            .child('users/${user.uid}/vehicles/${widget.vehicleId}/photos/$fileName');

        firebase_storage.UploadTask uploadTask = storageRef.putFile(file);
        firebase_storage.TaskSnapshot snapshot = await uploadTask;
        String downloadUrl = await snapshot.ref.getDownloadURL();

        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('vehicles')
            .doc(widget.vehicleId)
            .update({
          'photos': FieldValue.arrayUnion([downloadUrl]),
        });

        if (mounted) {
          setState(() {
            _photos.add(downloadUrl);
            _isUploading = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fotoğraf başarıyla yüklendi.')),
          );
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isUploading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Fotoğraf yüklenirken hata: $e')),
          );
        }
      }
    }
  }

  Future<void> _deletePhoto(String photoUrl, int index, {bool closeDialogAfterDelete = false}) async {
    bool confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Fotoğrafı Sil'),
          content: const Text('Bu fotoğrafı silmek istediğinize emin misiniz? Bu işlem geri alınamaz.'),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('İptal')),
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: Text('Sil', style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          ],
        );
      },
    ) ?? false;

    if (!confirm) return;

    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // Yükleme göstergesini aktif et (opsiyonel, ama iyi bir UX için)
    // if(mounted) setState(() => _isDeleting = true); // _isDeleting diye bir state tanımlamanız gerekir

    try {
      firebase_storage.Reference photoRef = firebase_storage.FirebaseStorage.instance.refFromURL(photoUrl);
      await photoRef.delete();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .doc(widget.vehicleId)
          .update({
        'photos': FieldValue.arrayRemove([photoUrl]),
      });

      if (mounted) {
        setState(() {
          _photos.removeAt(index);
          // _isDeleting = false; // Yükleme göstergesini kapat
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf silindi.')),
        );
        if (closeDialogAfterDelete && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
      }
    } catch (e) {
      if (mounted) {
        // setState(() => _isDeleting = false); // Yükleme göstergesini kapat
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf silinirken hata: $e')),
        );
      }
    }
  }

  Widget _buildDetailRow({required BuildContext context, required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              '$label:',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value.isNotEmpty ? value : '-',
              style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vehicleData = widget.vehicleData;

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicleData['plaka']?.toString() ?? 'Araç Detayları'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Araç Bilgileri", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    const Divider(),
                    _buildDetailRow(context: context, icon: Icons.label_outline, label: 'Marka', value: vehicleData['marka']?.toString() ?? '-'),
                    _buildDetailRow(context: context, icon: Icons.category_outlined, label: 'Seri', value: vehicleData['seri']?.toString() ?? '-'),
                    _buildDetailRow(context: context, icon: Icons.directions_car_filled_outlined, label: 'Model', value: vehicleData['model']?.toString() ?? '-'),
                    _buildDetailRow(context: context, icon: Icons.calendar_today_outlined, label: 'Model Yılı', value: vehicleData['modelYili']?.toString() ?? '-'),
                    _buildDetailRow(context: context, icon: Icons.work_outline, label: 'Kullanım Şekli', value: vehicleData['kullanim']?.toString() ?? '-'),
                    _buildDetailRow(context: context, icon: Icons.pin_outlined, label: 'Plaka', value: vehicleData['plaka']?.toString() ?? '-'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Araç Fotoğrafları (${_photos.length})',
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_isUploading)
              const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
            if (!_isUploading && _photos.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 32.0),
                  child: Column(
                    children: [
                      Icon(Icons.photo_library_outlined, size: 60, color: theme.colorScheme.secondary.withOpacity(0.7)),
                      const SizedBox(height: 16),
                      Text("Bu araç için henüz fotoğraf eklenmemiş.", style: theme.textTheme.titleMedium),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.add_a_photo_outlined),
                        label: const Text('İlk Fotoğrafı Ekle'),
                        onPressed: _uploadPhoto,
                      ),
                    ],
                  ),
                ),
              ),
            if (!_isUploading && _photos.isNotEmpty)
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photos.length + 1,
                itemBuilder: (context, index) {
                  if (index == _photos.length) {
                    return InkWell(
                      onTap: _uploadPhoto,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate_outlined, size: 40, color: theme.colorScheme.primary),
                              const SizedBox(height: 4),
                              Text("Ekle", style: TextStyle(color: theme.colorScheme.primary))
                            ],
                          ),
                        ),
                      ),
                    );
                  } else {
                    String photoUrl = _photos[index];
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (BuildContext dialogContext) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(10),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: InteractiveViewer(
                                    panEnabled: false,
                                    boundaryMargin: const EdgeInsets.all(20), 
                                    minScale: 0.5,
                                    maxScale: 4,
                                    child: ClipRRect( 
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: Image.network(photoUrl, fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                                Padding( 
                                  padding: const EdgeInsets.only(top: 8.0, bottom: 4.0),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      TextButton.icon(
                                        icon: Icon(Icons.close_rounded, color: Colors.white.withOpacity(0.9)),
                                        label: Text("Kapat", style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.bold)),
                                        onPressed: () => Navigator.of(dialogContext).pop(),
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.black.withOpacity(0.4),
                                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                        ),
                                      ),
                                      TextButton.icon(
                                        icon: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                                        label: Text("Sil", style: TextStyle(color: theme.colorScheme.error, fontWeight: FontWeight.bold)),
                                        onPressed: () async {
                                          // Dialog içinden silme işlemi çağırılacak
                                          // Bu fonksiyon, kendi içinde onay dialogu gösterir.
                                          // Silme sonrası büyük fotoğraf dialogunun kapanması için closeDialogAfterDelete: true
                                          await _deletePhoto(photoUrl, index, closeDialogAfterDelete: true);
                                          // _deletePhoto zaten Navigator.pop(context) yapacak (eğer closeDialogAfterDelete true ise)
                                          // Bu yüzden burada ekstradan Navigator.pop(dialogContext) yapmaya gerek yok,
                                          // çünkü _deletePhoto başarılı olursa bu dialog zaten kapanmış olacak.
                                          // Eğer _deletePhoto'dan sonra bu dialog hala açıksa (örneğin silme iptal edildiyse)
                                          // o zaman manuel kapatmak gerekebilir, ama mevcut durumda _deletePhoto'nun
                                          // yönetimi yeterli olmalı.
                                        },
                                        style: TextButton.styleFrom(
                                          backgroundColor: Colors.black.withOpacity(0.4),
                                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        );
                      },
                      // Uzun basarak silme hala aktif kalabilir, isteğe bağlı.
                      // onLongPress: () {
                      //   _deletePhoto(photoUrl, index);
                      // },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              photoUrl,
                              fit: BoxFit.cover,
                              loadingBuilder: (BuildContext context, Widget child, ImageChunkEvent? loadingProgress) {
                                if (loadingProgress == null) return child;
                                return Center(
                                  child: CircularProgressIndicator(
                                    value: loadingProgress.expectedTotalBytes != null
                                        ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                        : null,
                                  ),
                                );
                              },
                              errorBuilder: (context, error, stackTrace) => Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade400, size: 40),
                              ),
                            ),
                          ),
                        ],
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