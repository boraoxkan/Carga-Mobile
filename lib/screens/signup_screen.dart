// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tutanak/models/user.dart'; 
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController tcNoController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();
  final TextEditingController driverLicenseNoController = TextEditingController();
  final TextEditingController driverLicenseClassController = TextEditingController();
  final TextEditingController driverLicenseIssuePlaceController = TextEditingController();
  final TextEditingController addressController = TextEditingController(); 

  String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Boş bırakıldı';
    }
    if (!value.contains('@') || !value.endsWith('.com')) {
      return 'Geçerli bir e-mail giriniz (@domain.com formatında)';
    }
    return null;
  }

  String? validatePassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Boş bırakıldı';
    }
    if (value.length < 6) {
        return 'Şifre en az 6 karakter olmalıdır.';
    }
    return null;
  }

  String? validateConfirmPassword(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Boş bırakıldı';
    }
    if (value != passwordController.text) {
      return 'Şifreler eşleşmiyor';
    }
    return null;
  }

  InputDecoration _inputDecoration(String labelText, {IconData? prefixIcon}) {
    final theme = Theme.of(context);
    return InputDecoration(
      labelText: labelText,
      prefixIcon: prefixIcon != null ? Icon(prefixIcon, color: theme.colorScheme.primary) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Kayıt Ol'),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              TextFormField(
                controller: nameController,
                decoration: _inputDecoration('İsim', prefixIcon: Icons.person_outline),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Boş bırakıldı' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: surnameController,
                decoration: _inputDecoration('Soyisim', prefixIcon: Icons.person_outline),
                validator: (value) => (value == null || value.trim().isEmpty) ? 'Boş bırakıldı' : null,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: tcNoController,
                decoration: _inputDecoration('TC Kimlik Numarası', prefixIcon: Icons.badge_outlined),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(11)],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Boş bırakıldı';
                  if (value.length != 11) return 'TC Kimlik No 11 haneli olmalıdır.';
                  return null;
                },
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: phoneController,
                decoration: _inputDecoration('Telefon Numarası (5xxxxxxxxx)', prefixIcon: Icons.phone_outlined),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
                 validator: (value) {
                    if (value == null || value.trim().isEmpty) return 'Boş bırakıldı';
                    if (value.length != 10) return 'Telefon numarası 10 haneli olmalıdır (başında 0 olmadan).';
                    return null;
                }
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: emailController,
                decoration: _inputDecoration('E-posta Adresi', prefixIcon: Icons.email_outlined),
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: passwordController,
                decoration: _inputDecoration('Şifre', prefixIcon: Icons.lock_outline),
                obscureText: true,
                validator: validatePassword,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: confirmPasswordController,
                decoration: _inputDecoration('Şifre Tekrar', prefixIcon: Icons.lock_outline),
                obscureText: true,
                validator: validateConfirmPassword,
              ),
              SizedBox(height: 20),
              Divider(),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12.0),
                child: Text("Sürücü ve Adres Bilgileri (Opsiyonel)", style: Theme.of(context).textTheme.titleMedium),
              ),
              TextFormField(
                controller: driverLicenseNoController,
                decoration: _inputDecoration('Sürücü Belge No', prefixIcon: Icons.card_membership_outlined),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: driverLicenseClassController,
                decoration: _inputDecoration('Sürücü Belge Sınıfı (örn: B)', prefixIcon: Icons.category_outlined),
                textCapitalization: TextCapitalization.characters,
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: driverLicenseIssuePlaceController,
                decoration: _inputDecoration('Sürücü Belgesi Verildiği Yer (İl/İlçe)', prefixIcon: Icons.location_city_outlined),
              ),
              SizedBox(height: 16),
              TextFormField(
                controller: addressController,
                decoration: _inputDecoration('Adresiniz', prefixIcon: Icons.home_outlined),
                keyboardType: TextInputType.multiline,
                maxLines: 3,
                minLines: 1,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  if (_formKey.currentState!.validate()) {
                    registerWithAdditionalInfo(
                      context,
                      _formKey,
                      emailController.text.trim(),
                      passwordController.text.trim(),
                      nameController.text.trim(),
                      surnameController.text.trim(),
                      tcNoController.text.trim(),
                      phoneController.text.trim(),
                      driverLicenseNoController.text.trim(),
                      driverLicenseClassController.text.trim(),
                      driverLicenseIssuePlaceController.text.trim(),
                      addressController.text.trim(),
                    );
                  }
                },
                child: Text('Kayıt Ol'),
                style: ElevatedButton.styleFrom(minimumSize: Size(double.infinity, 50)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<void> registerWithAdditionalInfo(
  BuildContext context,
  GlobalKey<FormState> formKey,
  String email,
  String password,
  String name,
  String surname,
  String tcNo,
  String phone,
  String driverLicenseNo,
  String driverLicenseClass,
  String driverLicenseIssuePlace,
  String address,
) async {
  try {
    UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
      'isim': name,
      'soyisim': surname,
      'tcNo': tcNo,
      'telefon': phone,
      'email': email,
      'driverLicenseNo': driverLicenseNo.isNotEmpty ? driverLicenseNo : null,
      'driverLicenseClass': driverLicenseClass.isNotEmpty ? driverLicenseClass : null,
      'driverLicenseIssuePlace': driverLicenseIssuePlace.isNotEmpty ? driverLicenseIssuePlace : null,
      'address': address.isNotEmpty ? address : null,
      'createdAt': FieldValue.serverTimestamp(),
    });
    
    if (context.mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  } on FirebaseAuthException catch (e) {
    String message = 'Bir hata oluştu';
    if (e.code == 'weak-password') {
      message = 'Şifre çok zayıf.';
    } else if (e.code == 'email-already-in-use') {
      message = 'Bu e-posta ile zaten kayıt var.';
    }
    if(context.mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  } catch (e) {
    if(context.mounted){
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e'), backgroundColor: Theme.of(context).colorScheme.error),
      );
    }
  } finally {
  }
}