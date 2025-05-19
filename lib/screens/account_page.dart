// lib/screens/account_page.dart

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:flutter/services.dart';

class AccountPage extends StatefulWidget {
  final VoidCallback? onProfileUpdated;

  const AccountPage({Key? key, this.onProfileUpdated}) : super(key: key);

  @override
  _AccountPageState createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  final ImagePicker _picker = ImagePicker();
  bool _isUploading = false;
  Map<String, dynamic>? _userData;
  String? _profileImageUrl;
  bool _isLoadingUserData = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    if (!mounted) return;
    setState(() => _isLoadingUserData = true);
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        DocumentSnapshot<Map<String, dynamic>> doc =
            await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (mounted && doc.exists) {
          setState(() {
            _userData = doc.data();
            _profileImageUrl = _userData?['profileImageUrl'] as String?;
            _isLoadingUserData = false;
          });
        } else if (mounted) {
          setState(() => _isLoadingUserData = false);
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isLoadingUserData = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kullanıcı bilgileri yüklenirken hata: $e')),
          );
        }
      }
    } else if (mounted) {
      setState(() => _isLoadingUserData = false);
    }
  }

  Future<void> _pickAndUploadImage() async {
    // ... (Bu fonksiyon öncekiyle aynı kalabilir) ...
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
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
      if(context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen önce giriş yapın.')),
        );
      }
      return;
    }

    if (mounted) {
      setState(() {
        _isUploading = true;
      });
    }

    try {
      String fileName = 'profile_pictures/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg'; // Daha benzersiz dosya adı
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
           _userData?['profileImageUrl'] = downloadUrl; // Yerel state'i de güncelle
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profil fotoğrafınız güncellendi!')),
        );
        widget.onProfileUpdated?.call();
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
    
    // Controller'ları dialog içinde tanımlayıp ilk değerlerini atayalım
    final TextEditingController emailEditController = TextEditingController(text: currentUserData['email']?.toString() ?? '');
    final TextEditingController phoneEditController = TextEditingController(text: currentUserData['telefon']?.toString() ?? '');
    final TextEditingController driverLicenseNoController = TextEditingController(text: currentUserData['driverLicenseNo']?.toString() ?? '');
    final TextEditingController driverLicenseClassController = TextEditingController(text: currentUserData['driverLicenseClass']?.toString() ?? '');
    final TextEditingController driverLicenseIssuePlaceController = TextEditingController(text: currentUserData['driverLicenseIssuePlace']?.toString() ?? '');
    final TextEditingController addressController = TextEditingController(text: currentUserData['address']?.toString() ?? '');
    
    bool isLoadingDialog = false;

    InputDecoration _dialogInputDecoration(String labelText, IconData prefixIcon) {
        final theme = Theme.of(context);
        return InputDecoration(
            labelText: labelText,
            prefixIcon: Icon(prefixIcon, color: theme.colorScheme.primary),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12)
        );
    }

    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Kişisel Bilgileri Düzenle'),
              content: Form(
                key: _editFormKey,
                child: SingleChildScrollView( // İçerik sığmazsa kaydırma için
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: emailEditController,
                        decoration: _dialogInputDecoration('E-posta Adresiniz', Icons.email_outlined),
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
                        decoration: _dialogInputDecoration('Telefon (5xxxxxxxxx)', Icons.phone_outlined),
                        keyboardType: TextInputType.phone,
                        inputFormatters: <TextInputFormatter>[FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Boş bırakılamaz';
                           if (value.length != 10) return 'Telefon 10 haneli olmalıdır.';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                       TextFormField(
                        controller: addressController,
                        decoration: _dialogInputDecoration('Adresiniz', Icons.home_outlined),
                        keyboardType: TextInputType.multiline,
                        maxLines: 3,
                        minLines: 1,
                         // validator: (value) => (value == null || value.trim().isEmpty) ? 'Adres boş bırakılamaz' : null, // Zorunluysa
                      ),
                      const SizedBox(height: 20),
                      Text("Sürücü Belgesi Bilgileri", style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: driverLicenseNoController,
                        decoration: _dialogInputDecoration('Sürücü Belge No', Icons.card_membership_outlined),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: driverLicenseClassController,
                        decoration: _dialogInputDecoration('Belge Sınıfı', Icons.category_outlined),
                        textCapitalization: TextCapitalization.characters,
                      ),
                       const SizedBox(height: 16),
                      TextFormField(
                        controller: driverLicenseIssuePlaceController,
                        decoration: _dialogInputDecoration('Belge Verildiği Yer (İl/İlçe)', Icons.location_city_outlined),
                      ),
                    ],
                  ),
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
                          Map<String, dynamic> updatedData = {
                            'email': emailEditController.text.trim(),
                            'telefon': phoneEditController.text.trim(),
                            'address': addressController.text.trim().isNotEmpty ? addressController.text.trim() : null,
                            'driverLicenseNo': driverLicenseNoController.text.trim().isNotEmpty ? driverLicenseNoController.text.trim() : null,
                            'driverLicenseClass': driverLicenseClassController.text.trim().isNotEmpty ? driverLicenseClassController.text.trim() : null,
                            'driverLicenseIssuePlace': driverLicenseIssuePlaceController.text.trim().isNotEmpty ? driverLicenseIssuePlaceController.text.trim() : null,
                            'lastProfileUpdate': FieldValue.serverTimestamp(),
                          };
                          // Sadece e-posta değişiyorsa Firebase Auth'u güncelle (re-authentication gerekebilir)
                          if (user.email != emailEditController.text.trim()) {
                            // await user.updateEmail(emailEditController.text.trim()); // Bu işlem hassas olduğu için re-authentication ister.
                            // Şimdilik sadece Firestore'u güncelleyelim. E-posta değişikliği daha karmaşık bir akış gerektirir.
                            // E-posta değişikliğini ayrı bir özellik olarak ele almak daha iyi olabilir.
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('E-posta değişikliği için ayrı bir doğrulama adımı gerekebilir. Şimdilik sadece profil bilgileri güncellendi.')),
                            );
                          }

                          await FirebaseFirestore.instance.collection('users').doc(user.uid).update(updatedData);
                          
                          Navigator.pop(dialogContext); // Önce dialogu kapat
                          if (mounted) { // Sonra mounted kontrolü yap
                             ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Bilgileriniz güncellendi.')),
                            );
                            _loadUserData(); 
                            widget.onProfileUpdated?.call();
                          }
                        }
                      } catch (e) {
                         if (mounted) { // Hata durumunda da mounted kontrolü
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Güncelleme hatası: $e')),
                            );
                         }
                      } finally {
                         // Dialog hala aktifse (hata durumunda kapanmadıysa) veya mounted ise state'i güncelle
                         if (Navigator.of(dialogContext, rootNavigator: true).canPop() && mounted) {
                            setDialogState(() => isLoadingDialog = false);
                         } else if (mounted) {
                            // Eğer dialog kapandıysa ve burası hala çalışıyorsa, sadece ana sayfa state'i güncellenir
                            setState(() {
                                // Gerekirse ana sayfada bir state güncellemesi
                            });
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

  Widget _buildInfoTile(BuildContext context, {required IconData icon, required String title, required String? subtitle, bool isSensitive = false}) {
    final theme = Theme.of(context);
    final displaySubtitle = (subtitle == null || subtitle.trim().isEmpty) ? '-' : subtitle;
    return ListTile(
      leading: Icon(icon, color: theme.colorScheme.primary, size: 28),
      title: Text(title, style: theme.textTheme.titleSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
      subtitle: Text(displaySubtitle, style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      contentPadding: const EdgeInsets.symmetric(vertical: 6.0),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Builder(builder: (context) {
      final theme = Theme.of(context);

      if (_isLoadingUserData) {
        return const Center(child: CircularProgressIndicator());
      }
      if (_userData == null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: theme.colorScheme.error),
                const SizedBox(height: 16),
                Text('Kullanıcı bilgileri yüklenemedi.', style: theme.textTheme.titleLarge),
                const SizedBox(height: 8),
                Text('Lütfen internet bağlantınızı kontrol edin veya daha sonra tekrar deneyin.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: Icon(Icons.refresh),
                  label: Text('Tekrar Dene'),
                  onPressed: _loadUserData,
                )
              ],
            ),
          )
        );
      }

      final String displayName = '${_userData!['isim'] ?? ''} ${_userData!['soyisim'] ?? ''}'.trim();
      final String displayInitial = displayName.isNotEmpty ? displayName[0].toUpperCase() : "K";

      return SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: GestureDetector(
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
                                          style: theme.textTheme.displayMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer, fontWeight: FontWeight.bold),
                                        )
                                      : null),
                            ),
                            if (!_isUploading)
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primary,
                                  shape: BoxShape.circle,
                                  border: Border.all(color: theme.cardColor, width: 2)
                                ),
                                child: Icon(Icons.edit_outlined, color: theme.colorScheme.onPrimary, size: 18),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Center(
                      child: Text(
                        displayName.isNotEmpty ? displayName : "Kullanıcı Adı Yok",
                        style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    Center(
                      child: Text(
                        _userData!['email']?.toString() ?? 'E-posta yok',
                        style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Divider(thickness: 0.5),
                    _buildInfoTile(context, icon: Icons.badge_outlined, title: 'TC Kimlik Numarası', subtitle: _userData!['tcNo']?.toString()),
                    _buildInfoTile(context, icon: Icons.phone_iphone_outlined, title: 'Telefon Numaranız', subtitle: _userData!['telefon']?.toString()),
                    _buildInfoTile(context, icon: Icons.home_work_outlined, title: 'Adresiniz', subtitle: _userData!['address']?.toString()),
                    
                    Padding(
                      padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
                      child: Text("Sürücü Belgesi Detayları", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold, color: theme.colorScheme.primary)),
                    ),
                    _buildInfoTile(context, icon: Icons.card_membership_outlined, title: 'Belge Numarası', subtitle: _userData!['driverLicenseNo']?.toString()),
                    _buildInfoTile(context, icon: Icons.category_outlined, title: 'Belge Sınıfı', subtitle: _userData!['driverLicenseClass']?.toString()),
                    _buildInfoTile(context, icon: Icons.location_city_outlined, title: 'Verildiği Yer', subtitle: _userData!['driverLicenseIssuePlace']?.toString()),
                    
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.edit_note_outlined, size: 20),
                      label: const Text('Kişisel Bilgileri Düzenle'),
                      onPressed: () {
                        _showEditDialog(_userData!);
                      },
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