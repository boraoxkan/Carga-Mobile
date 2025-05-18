// lib/main.dart
// GEÇİCİ DEĞİŞİKLİK: firebase_options kullanımı kaldırıldı.

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart'; // <-- BU SATIRI YORUM SATIRI YAPIN VEYA SİLİN

// Ekranlarınızın importları
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

/*
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Firebase'i options parametresi OLMADAN başlatın
  await Firebase.initializeApp(); // <-- DEĞİŞİKLİK BURADA (options kaldırıldı)
  runApp(const MyApp());
}
*/

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // <-- Düzeltilmiş satır
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Mor Temalı Uygulama',
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => SplashScreen(),
        '/login': (context) => LoginScreen(),
        '/signup': (context) => SignupScreen(),
        '/home': (context) => HomeScreen(),
      },
    );
  }
}