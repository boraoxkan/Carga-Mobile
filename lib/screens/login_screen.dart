// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // Form kontrolü için GlobalKey oluşturuyoruz.
  final _formKey = GlobalKey<FormState>();

  // TextEditingController'lar
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  // Giriş işlemi yapan metot
  Future<void> _login(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        // Giriş başarılı ise ana sayfaya yönlendir
        Navigator.pushReplacementNamed(context, '/home');
      } on FirebaseAuthException catch (e) {
        String message = 'Bir hata oluştu';
        if (e.code == 'user-not-found') {
          message = 'Kullanıcı bulunamadı';
        } else if (e.code == 'wrong-password') {
          message = 'Yanlış şifre';
        }
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  // InputDecoration fonksiyonu: Oval kenarlı metin kutuları
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
        title: Text('Giriş Yap'),
      ),
      body: Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Form(
              key: _formKey, // Form anahtarımız
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Splash ekranındaki gavel simgesi login ekranında da üstte gösterilsin
                  Icon(
                    Icons.gavel,
                    size: 100,
                    color: Colors.purple,
                  ),
                  SizedBox(height: 20),
                  // E-mail alanı
                  TextFormField(
                    controller: emailController,
                    decoration: _inputDecoration('E-mail'),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Boş bırakıldı';
                      }
                      if (!value.contains('@') || !value.endsWith('.com')) {
                        return 'Geçerli bir e-mail giriniz (@domain.com formatında)';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  // Şifre alanı
                  TextFormField(
                    controller: passwordController,
                    decoration: _inputDecoration('Şifre'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Boş bırakıldı';
                      }
                      return null;
                    },
                  ),
                  SizedBox(height: 16),
                  // Giriş Yap butonu
                  ElevatedButton(
                    onPressed: () => _login(context),
                    child: Text('Giriş Yap'),
                  ),
                  SizedBox(height: 8),
                  // Kayıt Ol butonu
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/signup');
                    },
                    child: Text('Kayıt Ol'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}