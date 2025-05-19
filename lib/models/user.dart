// lib/models/user.dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

Future<void> register(
  BuildContext context, // Context'i başa almak daha yaygın bir kullanım
  GlobalKey<FormState> formKey,
  String emailController,
  String passwordController,
  String nameController,
  String surnameController,
  String tcNoController,
  String phoneController,
  // YENİ EKLENEN PARAMETRELER
  String driverLicenseNo,
  String driverLicenseClass,
  String driverLicenseIssuePlace,
  String address,
) async {
  if (formKey.currentState!.validate()) {
    // Burada bir yükleme göstergesi yönetimi (isLoading state'i) ekleyebilirsiniz
    try {
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController,
        password: passwordController,
      );
      
      await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
        'isim': nameController,
        'soyisim': surnameController,
        'tcNo': tcNoController,
        'telefon': phoneController,
        'email': emailController, // Firebase Auth'dan da alınabilir: userCredential.user?.email
        'driverLicenseNo': driverLicenseNo.isNotEmpty ? driverLicenseNo : null,
        'driverLicenseClass': driverLicenseClass.isNotEmpty ? driverLicenseClass : null,
        'driverLicenseIssuePlace': driverLicenseIssuePlace.isNotEmpty ? driverLicenseIssuePlace : null,
        'address': address.isNotEmpty ? address : null,
        'createdAt': FieldValue.serverTimestamp(), // Kayıt oluşturma tarihi
        'profileImageUrl': null, // Başlangıçta profil resmi yok
      });
      
      if (context.mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Bir hata oluştu';
      if (e.code == 'weak-password') {
        message = 'Şifre çok zayıf.';
      } else if (e.code == 'email-already-in-use') {
        message = 'Bu e-mail ile zaten kayıt var.';
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Bir hata oluştu: $e'), backgroundColor: Theme.of(context).colorScheme.error),
        );
      }
    } finally {
      // Yükleme göstergesini kapat
    }
  }
}