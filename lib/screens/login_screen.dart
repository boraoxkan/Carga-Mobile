// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginScreen extends StatefulWidget {
  LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  Future<void> _login(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });
      try {
        await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: emailController.text.trim(),
          password: passwordController.text.trim(),
        );
        if (mounted) { // Async işlem sonrası widget'ın hala mount edilmiş olup olmadığını kontrol et
          Navigator.pushReplacementNamed(context, '/home');
        }
      } on FirebaseAuthException catch (e) {
        if (mounted) {
          String message = 'Giriş sırasında bir hata oluştu.';
          if (e.code == 'user-not-found') {
            message = 'Bu e-posta ile kayıtlı kullanıcı bulunamadı.';
          } else if (e.code == 'wrong-password') {
            message = 'Yanlış şifre girdiniz.';
          } else if (e.code == 'invalid-email') {
            message = 'Geçersiz e-posta formatı.';
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(message),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Beklenmedik bir hata oluştu: $e'),
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      // AppBar isteğe bağlı, daha modern bir görünüm için kaldırılabilir veya transparan yapılabilir
      // appBar: AppBar(
      //   title: Text('Giriş Yap'),
      //   elevation: 0,
      //   backgroundColor: Colors.transparent, // Ya da tema rengi
      // ),
      body: SafeArea( // Ekran çentikleri vb. için
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0), // Daha fazla padding
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch, // Butonları genişletmek için
                children: [
                  Icon(
                    Icons.gavel_rounded, // Splash ile tutarlı ikon
                    size: 80,
                    color: colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Hoş Geldiniz!',
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium?.copyWith(color: colorScheme.primary),
                  ),
                  Text(
                    'Devam etmek için giriş yapın.',
                    textAlign: TextAlign.center,
                    style: textTheme.titleMedium,
                  ),
                  const SizedBox(height: 32),
                  // E-mail alanı
                  TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'E-posta Adresiniz',
                      prefixIcon: Icon(Icons.email_outlined, color: colorScheme.primary),
                      // hintText: 'ornek@eposta.com', // main.dart'taki fillColor ile daha iyi görünür
                    ),
                    keyboardType: TextInputType.emailAddress,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'E-posta adresinizi giriniz.';
                      }
                      if (!value.contains('@') || !value.contains('.')) { // Daha basit bir @ ve . kontrolü
                        return 'Geçerli bir e-posta adresi giriniz.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  // Şifre alanı
                  TextFormField(
                    controller: passwordController,
                    decoration: InputDecoration(
                      labelText: 'Şifreniz',
                      prefixIcon: Icon(Icons.lock_outline, color: colorScheme.primary),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _isPasswordVisible ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                          color: colorScheme.primary,
                        ),
                        onPressed: () {
                          setState(() {
                            _isPasswordVisible = !_isPasswordVisible;
                          });
                        },
                      ),
                    ),
                    obscureText: !_isPasswordVisible,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Şifrenizi giriniz.';
                      }
                      // if (value.length < 6) { // İsteğe bağlı: minimum şifre uzunluğu
                      //   return 'Şifre en az 6 karakter olmalıdır.';
                      // }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  // Şifremi Unuttum
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () {
                        // TODO: Şifremi unuttum akışını implemente et
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Şifremi Unuttum özelliği henüz aktif değil.')),
                        );
                      },
                      child: Text('Şifrenizi mi unuttunuz?', style: TextStyle(color: colorScheme.secondary)),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Giriş Yap butonu
                  _isLoading
                      ? Center(child: CircularProgressIndicator(color: colorScheme.primary))
                      : ElevatedButton(
                          onPressed: () => _login(context),
                          child: const Text('GİRİŞ YAP'),
                        ),
                  const SizedBox(height: 20),
                  // Kayıt Ol butonu
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text("Hesabınız yok mu?", style: textTheme.bodyMedium),
                      TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, '/signup');
                        },
                        child: Text(
                          'Hemen Kayıt Olun',
                          style: TextStyle(fontWeight: FontWeight.bold, color: colorScheme.secondary),
                        ),
                      ),
                    ],
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