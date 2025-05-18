// lib/main.dart
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'firebase_options.dart'; // Firebase yapılandırmanız

// Ekranlarınızın importları
import 'screens/splash_screen.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/home_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await initializeDateFormatting(null, null);

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Carga',
      theme: ThemeData(
        useMaterial3: true, // Material 3'ü etkinleştir
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.purple, // Ana renginiz
          brightness: Brightness.light, // Açık tema için
          primary: Colors.purple,
          secondary: Colors.deepPurpleAccent,
          surface: Colors.white,
          background: Colors.grey.shade100,
          error: Colors.redAccent,
          onPrimary: Colors.white,
          onSecondary: Colors.white,
          onSurface: Colors.black87,
          onBackground: Colors.black87,
          onError: Colors.white,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        fontFamily: 'Roboto', // Örnek bir modern font (pubspec.yaml'a eklenmeli)
        textTheme: TextTheme( // Daha modern metin stilleri
          displayLarge: TextStyle(fontSize: 57.0, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
          displayMedium: TextStyle(fontSize: 45.0, fontWeight: FontWeight.bold, color: Colors.purple.shade700),
          displaySmall: TextStyle(fontSize: 36.0, fontWeight: FontWeight.bold, color: Colors.purple.shade600),
          headlineLarge: TextStyle(fontSize: 32.0, fontWeight: FontWeight.w600, color: Colors.black87),
          headlineMedium: TextStyle(fontSize: 28.0, fontWeight: FontWeight.w600, color: Colors.black87),
          headlineSmall: TextStyle(fontSize: 24.0, fontWeight: FontWeight.w600, color: Colors.black87),
          titleLarge: TextStyle(fontSize: 22.0, fontWeight: FontWeight.w600, color: Colors.black87),
          titleMedium: TextStyle(fontSize: 16.0, fontWeight: FontWeight.w500, letterSpacing: 0.15, color: Colors.black54),
          titleSmall: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, letterSpacing: 0.1, color: Colors.black54),
          bodyLarge: TextStyle(fontSize: 16.0, letterSpacing: 0.5, color: Colors.black87),
          bodyMedium: TextStyle(fontSize: 14.0, letterSpacing: 0.25, color: Colors.black87),
          bodySmall: TextStyle(fontSize: 12.0, letterSpacing: 0.4, color: Colors.black54),
          labelLarge: TextStyle(fontSize: 14.0, fontWeight: FontWeight.w500, letterSpacing: 1.25, color: Colors.purple.shade700),
          labelMedium: TextStyle(fontSize: 12.0, fontWeight: FontWeight.w500, letterSpacing: 1.25, color: Colors.purple.shade600),
          labelSmall: TextStyle(fontSize: 11.0, fontWeight: FontWeight.w500, letterSpacing: 1.5, color: Colors.purple.shade500),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData( // Modern buton stili
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12), // Daha yuvarlak köşeler
            ),
            elevation: 2,
          ),
        ),
        inputDecorationTheme: InputDecorationTheme( // Modern input alanları stili
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.grey.shade400),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.purple, width: 2),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent, width: 1.5),
          ),
          focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.redAccent, width: 2),
          ),
          filled: true,
          fillColor: Colors.grey.shade50,
          contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        ),
        appBarTheme: AppBarTheme( // Modern AppBar stili
            backgroundColor: Colors.purple,
            foregroundColor: Colors.white,
            elevation: 0, // Daha düz bir görünüm için
            titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)
        ),
        cardTheme: CardTheme( // Modern Card stili
            elevation: 2,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)
            ),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4)
        ),
      ),
      locale: Locale('tr', 'TR'),
        supportedLocales: [
        Locale('tr', 'TR'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(), // SplashScreen const yapıldı
        '/login': (context) => LoginScreen(), // LoginScreen const olamaz (controller'lar var)
        '/signup': (context) => const SignupScreen(), // SignupScreen const yapıldı
        '/home': (context) => const HomeScreen(), // HomeScreen const yapıldı
      },
    );
  }
}