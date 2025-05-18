// lib/screens/splash_screen.dart
import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
// import 'package:lottie/lottie.dart'; // Lottie animasyonları için (isteğe bağlı)

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeIn),
    );

    _animationController.forward();

    Timer(const Duration(seconds: 3), () { // Animasyon süresiyle uyumlu hale getirin
      if (FirebaseAuth.instance.currentUser != null) {
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration( // Modern gradient arka plan
          gradient: LinearGradient(
            colors: [Colors.purple.shade300, Colors.purple.shade700],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                // İSTEĞE BAĞLI: Lottie animasyonu
                // SizedBox(
                //   width: 150,
                //   height: 150,
                //   child: Lottie.asset('assets/animations/gavel_animation.json'), // Lottie dosyanızı ekleyin
                // ),
                // VEYA Mevcut İkon (daha büyük ve stilize)
                Icon(
                  Icons.gavel_rounded, // Yuvarlak hatlı bir ikon
                  size: 120,
                  color: Colors.white,
                  shadows: [ // İkona derinlik katmak için gölge
                    Shadow(
                      blurRadius: 10.0,
                      color: Colors.black.withOpacity(0.3),
                      offset: const Offset(2.0, 2.0),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  "Carga", // Uygulama Adı
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 40),
                CircularProgressIndicator(
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white70),
                  strokeWidth: 3,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}