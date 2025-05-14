// lib/screens/signup_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tutanak/models/user.dart'; // register fonksiyonunun bulunduğu dosya

class SignupScreen extends StatefulWidget {
  const SignupScreen({Key? key}) : super(key: key);

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form alanları için controller'lar
  final TextEditingController nameController = TextEditingController();
  final TextEditingController surnameController = TextEditingController();
  final TextEditingController tcNoController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController confirmPasswordController = TextEditingController();

  // E-mail doğrulaması
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

  // Oval kenarlı input dekorasyonu sağlayan fonksiyon
  InputDecoration _inputDecoration(String labelText) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      enabledBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.grey),
        borderRadius: BorderRadius.circular(20.0),
      ),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.purple),
        borderRadius: BorderRadius.circular(20.0),
      ),
      errorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red),
        borderRadius: BorderRadius.circular(20.0),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderSide: BorderSide(color: Colors.red, width: 2),
        borderRadius: BorderRadius.circular(20.0),
      ),
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
              // İsim
              TextFormField(
                controller: nameController,
                decoration: _inputDecoration('İsim'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Boş bırakıldı';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // Soyisim
              TextFormField(
                controller: surnameController,
                decoration: _inputDecoration('Soyisim'),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Boş bırakıldı';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // TC No (sadece rakam)
              TextFormField(
                controller: tcNoController,
                decoration: _inputDecoration('TC No'),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Boş bırakıldı';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // Telefon No (sadece rakam)
              TextFormField(
                controller: phoneController,
                decoration: _inputDecoration('Telefon No'),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Boş bırakıldı';
                  }
                  return null;
                },
              ),
              SizedBox(height: 16),
              // E-mail
              TextFormField(
                controller: emailController,
                decoration: _inputDecoration('E-mail'),
                keyboardType: TextInputType.emailAddress,
                validator: validateEmail,
              ),
              SizedBox(height: 16),
              // Şifre
              TextFormField(
                controller: passwordController,
                decoration: _inputDecoration('Şifre'),
                obscureText: true,
                validator: validatePassword,
              ),
              SizedBox(height: 16),
              // Şifre Tekrar
              TextFormField(
                controller: confirmPasswordController,
                decoration: _inputDecoration('Şifre Tekrar'),
                obscureText: true,
                validator: validateConfirmPassword,
              ),
              SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // register fonksiyonunu import ettiğiniz dosyadan çağırıyoruz.
                  register(
                    emailController.text,
                    passwordController.text,
                    nameController.text,
                    surnameController.text,
                    tcNoController.text,
                    phoneController.text,
                    _formKey,
                    context,
                  );
                },
                child: Text('Kayıt Ol'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
