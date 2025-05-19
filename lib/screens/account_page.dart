// lib/screens/account_page.dart

import 'dart:io'; // File işlemleri için
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart'; // Fotoğraf seçimi için
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage; // Firebase Storage için
import 'package:flutter/services.dart'; // TextInputFormatter için eklendi

class AccountPage extends StatefulWidget {
  final VoidCallback? onProfileUpdated; // Callback fonksiyonu

  const AccountPage({Key? key, this.onProfileUpdated}) : super(key: key); // Constructor'a eklendi

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  Map<String, dynamic>? _userData;
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && mounted) {
      try {
        DocumentSnapshot<Map<String, dynamic>> doc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _userData = doc.data();
            _profileImageUrl = _userData?['profileImageUrl'] as String?;
          });
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kullanıcı bilgileri yüklenirken hata: $e')),
          );
        }
      }
    }
  }

  Future<void> _pickAndUploadImage() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context, // Bu context Builder'dan gelecek
      builder: (BuildContext context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.photo_library_outlined),
                title: const Text('Galeriden Seç'),
                onTap: () {
                  Navigator.pop(context, ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_outlined),
                title: const Text('Kamerayla Çek'),
                onTap: () {
                  Navigator.pop(context, ImageSource.camera);
                },
              ),
            ],
          ),
        );
      },
    );

    if (source == null) return;

    final XFile? pickedFile = await _picker.pickImage(
      source: source,
      imageQuality: 70,
      maxWidth: 800,
    );

    if (pickedFile == null) return;

    File imageFile = File(pickedFile.path);
    User? user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lütfen önce giriş yapın.')),
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    try {
      String fileName = 'profile_pictures/${user.uid}/profile.jpg';
      firebase_storage.Reference storageRef =
          firebase_storage.FirebaseStorage.instance.ref().child(fileName);

      firebase_storage.UploadTask uploadTask = storageRef.putFile(imageFile);
      firebase_storage.TaskSnapshot taskSnapshot = await uploadTask;
      String downloadUrl = await taskSnapshot.ref.getDownloadURL();

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({'profileImageUrl': downloadUrl});

      if (mounted) {
        setState(() {
          _profileImageUrl = downloadUrl;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafınız güncellendi!')),
        );
        widget.onProfileUpdated?.call(); // HomeScreen'i bilgilendir
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Fotoğraf yüklenirken hata oluştu: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> currentUserData) {
    final _editFormKey = GlobalKey<FormState>();
    String currentEmail = currentUserData['email']?.toString() ?? '';
    String currentPhone = currentUserData['telefon']?.toString() ?? '';

    TextEditingController emailEditController = TextEditingController(text: currentEmail);
    TextEditingController phoneEditController = TextEditingController(text: currentPhone);
    bool isLoadingDialog = false;

    showDialog(
      context: context, // Bu context Builder'dan gelecek
      builder: (BuildContext dialogContext) { // Dialog için ayrı bir context
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Bilgileri Düzenle'),
              content: Form(
                key: _editFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: emailEditController,
                      decoration: InputDecoration(
                        labelText: 'E-posta Adresiniz',
                        prefixIcon: Icon(Icons.email_outlined, color: Theme.of(context).colorScheme.primary),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Boş bırakılamaz';
                        if (!value.contains('@') || !value.contains('.')) return 'Geçerli e-posta giriniz';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: phoneEditController,
                      decoration: InputDecoration(
                        labelText: 'Telefon Numaranız',
                        prefixIcon: Icon(Icons.phone_outlined, color: Theme.of(context).colorScheme.primary),
                        hintText: 'Örn: 5xxxxxxxxx', // Kullanıcıya format ipucu
                        counterText: "", // Varsayılan karakter sayacını gizle
                      ),
                      keyboardType: TextInputType.phone,
                      // Sadece rakam girişine izin ver
                      inputFormatters: <TextInputFormatter>[
                        FilteringTextInputFormatter.digitsOnly
                      ],
                      // Maksimum karakter sayısını belirle (örneğin, Türkiye için 10 haneli numara, başındaki 0 olmadan)
                      maxLength: 10,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Boş bırakılamaz';
                        }
                        if (value.length < 10) { // Minimum uzunluk kontrolü
                          return 'Telefon numarası 10 haneli olmalıdır';
                        }
                        // İsteğe bağlı: Daha detaylı format kontrolü (örneğin, ilk hane '5' olmalı gibi)
                        // if (!value.startsWith('5')) {
                        //   return 'Telefon numarası 5 ile başlamalıdır';
                        // }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: isLoadingDialog ? null : () => Navigator.pop(dialogContext),
                  child: const Text('İptal'),
                ),
                ElevatedButton(
                  onPressed: isLoadingDialog ? null : () async {
                    if (_editFormKey.currentState!.validate()) {
                      setDialogState(() => isLoadingDialog = true);
                      try {
                        User? user = FirebaseAuth.instance.currentUser;
                        if (user != null) {
                          await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
                            'email': emailEditController.text.trim(),
                            'telefon': phoneEditController.text.trim(),
                          });
                          Navigator.pop(dialogContext);
                          if (mounted) {
                             ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bilgileriniz güncellendi.')),
                            );
                            _loadUserData(); // AccountPage'deki bilgileri yenile
                            widget.onProfileUpdated?.call(); // HomeScreen'i (ve Drawer'ı) yenile
                          }
                        }
                      } catch (e) {
                         if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Güncelleme hatası: $e')),
                            );
                         }
                      } finally {
                        // Dialog hala aktifse state'i güncelle
                        if(Navigator.of(dialogContext).canPop()){
                           setDialogState(() => isLoadingDialog = false);
                        } else if (mounted) {
                           // Dialog kapandıktan sonra AccountPage state'ini güncellemek gerekirse (nadiren)
                           // Bu genellikle Navigator.pop sonrası mounted kontrolü ile yapılır.
                           // Şimdilik dialog içindeki state yönetimi yeterli.
                        }
                      }
                    }
                  },
                  child: isLoadingDialog ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Text('Kaydet'),
                ),
              ],
            );
          }
        );
      },
    );
  }

  Widget _buildInfoTile(BuildContext context, {required IconData icon, required String title, required String subtitle}) {
    final theme = Theme.of(context);
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 28),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      subtitle: Text(subtitle, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.symmetric(vertical: 8.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    // showModalBottomSheet gibi metodlar için doğru context'i sağlamak amacıyla Builder kullanıyoruz.
    return Builder(builder: (context) {
      final theme = Theme.of(context);

      if (_userData == null) {
        return const Center(child: CircularProgressIndicator());
      }

      final String displayName = '${_userData!['isim'] ?? ''} ${_userData!['soyisim'] ?? ''}'.trim();
      final String displayInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "K";

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: _isUploading ? null : _pickAndUploadImage,
                      child: Stack(
                        alignment: Alignment.bottomRight,
                        children: [
                          CircleAvatar(
                            radius: 60,
                            backgroundColor: theme.colorScheme.primaryContainer,
                            backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                            child: _isUploading
                                ? CircularProgressIndicator(color: theme.colorScheme.onPrimaryContainer)
                                : (_profileImageUrl == null
                                    ? Text(
                                        displayInitial,
                                        style: theme.textTheme.displayLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer),
                                      )
                                    : null),
                          ),
                          if (!_isUploading)
                            Container(
                              padding: const EdgeInsets.all(6), // İkonun etrafındaki boşluk
                              decoration: BoxDecoration(
                                color: theme.colorScheme.primary,
                                shape: BoxShape.circle,
                                border: Border.all(color: theme.cardColor, width: 2) // Kart rengiyle kenarlık
                              ),
                              child: Icon(Icons.edit_outlined, color: theme.colorScheme.onPrimary, size: 18),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      displayName.isNotEmpty ? displayName : "Kullanıcı Adı Yok",
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                      textAlign: TextAlign.center,
                    ),
                    Text(
                      _userData!['email']?.toString() ?? 'E-posta yok',
                      style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    Divider(thickness: 0.8, color: theme.dividerColor.withOpacity(0.5)),
                    const SizedBox(height: 8),
                    _buildInfoTile(
                      context,
                      icon: Icons.badge_outlined,
                      title: 'TC Kimlik Numarası',
                      subtitle: _userData!['tcNo']?.toString() ?? '-',
                    ),
                    _buildInfoTile(
                      context,
                      icon: Icons.phone_iphone_outlined,
                      title: 'Telefon Numaranız',
                      subtitle: _userData!['telefon']?.toString() ?? '-',
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      label: const Text('E-posta/Telefon Düzenle'),
                      onPressed: () {
                        _showEditDialog(_userData!);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    });
  }
}