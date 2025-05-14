// lib/models/register_user.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> register( // _register yerine register olarak değiştirdik
  String emailController,
  String passwordController,
  String nameController,
  String surnameController,
  String tcNoController,
  String phoneController,
  GlobalKey<FormState> formKey,
  BuildContext context
) async {
  if (formKey.currentState!.validate()) {
    try {
      // Firebase Authentication ile kullanıcı oluşturma
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController,
        password: passwordController,
      );
      
      // Ek kullanıcı bilgilerini Firestore'da saklama
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'isim': nameController,
        'soyisim': surnameController,
        'tcNo': tcNoController,
        'telefon': phoneController,
        'email': emailController,
      });
      
      // Başarılı kayıt sonrası giriş ekranına yönlendirme
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      String message = 'Bir hata oluştu';
      if (e.code == 'weak-password') {
        message = 'Şifre çok zayıf.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Bu e-mail ile zaten kayıt var.';
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message))
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Bir hata oluştu: $e'))
      );
    }
  }
}
