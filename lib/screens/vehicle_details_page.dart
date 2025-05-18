// lib/screens/vehicle_details_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
// image_picker da kullanılabilir, file_picker daha genel dosya seçimine izin verir.
// Mevcut kodunuzda file_picker kullanıldığı için onu koruyorum.

class VehicleDetailsPage extends StatefulWidget {
  final String vehicleId;
  final Map<String, dynamic> vehicleData; // Başlangıç verisi

  const VehicleDetailsPage({
    Key? key,
    required this.vehicleId,
    required this.vehicleData,
  }) : super(key: key);

  @override
  _VehicleDetailsPageState createState() => _VehicleDetailsPageState();
}

class _VehicleDetailsPageState extends State<VehicleDetailsPage> {
  // Fotoğrafları doğrudan Firestore'dan stream ile almak daha güncel olmasını sağlar
  // Ancak başlangıç verisiyle gelip, yeni eklenenleri setState ile yönetmek de bir yöntem.
  // Daha dinamik bir yapı için StreamBuilder kullanılabilir.
  // Şimdilik mevcut yapıyı koruyarak UI iyileştirmeleri yapalım.
  late List<String> _photos; // String listesi olarak tanımlandı
  bool _isUploading = false;

  @override
  void initState() {
    super.initState();
    // Gelen verideki 'photos' alanını güvenli bir şekilde List<String>'e çevirelim
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
            _photos.add(downloadUrl); // Yerel listeyi de güncelle
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

  // İsteğe bağlı: Fotoğraf silme fonksiyonu
  Future<void> _deletePhoto(String photoUrl, int index) async {
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

    try {
      // Firebase Storage'dan sil
      firebase_storage.Reference photoRef = firebase_storage.FirebaseStorage.instance.refFromURL(photoUrl);
      await photoRef.delete();

      // Firestore'dan URL'yi kaldır
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
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Fotoğraf silindi.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf silinirken hata: $e')),
        );
      }
    }
  }


  Widget _buildDetailRow({required BuildContext context, required IconData icon, required String label, required String value}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0), // Dikey boşluk artırıldı
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary, size: 24), // Tema rengi ve standart boyut
          const SizedBox(width: 16),
          Expanded(
            flex: 2, // Etiket için biraz daha fazla yer
            child: Text(
              '$label:',
              style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(
            flex: 3, // Değer için daha fazla yer
            child: Text(
              value.isNotEmpty ? value : '-', // Boş değer için '-'
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
    final vehicleData = widget.vehicleData; // Başlangıç verisini kullan

    return Scaffold(
      appBar: AppBar(
        title: Text(vehicleData['plaka']?.toString() ?? 'Araç Detayları'), // Başlıkta plaka
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch, // Butonların tam genişlik alması için
          children: [
            Card(
              // Card stili temadan gelecek
              elevation: 4, // Temadan gelen stili geçersiz kılmak için gerekirse
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
              'Araç Fotoğrafları (${_photos.length})', // Fotoğraf sayısı
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            if (_isUploading)
              const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator())),
            if (!_isUploading && _photos.isEmpty)
              Center( // Ortala
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
                  crossAxisCount: 3, // Daha büyük önizlemeler için 2 veya 3
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: _photos.length + 1, // Son hücre "Ekle" butonu için
                itemBuilder: (context, index) {
                  if (index == _photos.length) {
                    // "Fotoğraf Ekle" butonu
                    return InkWell( // Tıklanabilir alan
                      onTap: _uploadPhoto,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: theme.colorScheme.primary.withOpacity(0.5),
                            width: 1.5,
                            // style: BorderStyle.dashed // Kesikli çizgi için
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
                    // Mevcut fotoğraflar
                    String photoUrl = _photos[index];
                    return GestureDetector(
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (_) => Dialog(
                            backgroundColor: Colors.transparent,
                            insetPadding: const EdgeInsets.all(10),
                            child: Column( // Kapat butonu için
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Expanded(
                                  child: InteractiveViewer( // Zoom için
                                    panEnabled: false,
                                    boundaryMargin: const EdgeInsets.all(80),
                                    minScale: 0.5,
                                    maxScale: 4,
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(12.0),
                                      child: Image.network(photoUrl, fit: BoxFit.contain),
                                    ),
                                  ),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(),
                                  child: const Text("Kapat", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
                                )
                              ],
                            ),
                          ),
                        );
                      },
                      onLongPress: () { // Uzun basıldığında silme seçeneği
                        _deletePhoto(photoUrl, index);
                      },
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12), // Daha yuvarlak köşeler
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
                           Positioned( // Silme ikonu için ipucu (uzun basış)
                            top: 4,
                            right: 4,
                            child: Icon(Icons.delete_sweep_outlined, color: Colors.white.withOpacity(0.2), size: 16),
                          )
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