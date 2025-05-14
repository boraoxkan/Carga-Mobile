// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'account_page.dart';
import 'vehicles_page.dart';
import 'reports_page.dart';
import 'record_operations_page.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);
  
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // 'account', 'vehicles' veya 'reports' değerlerine göre sayfa geçişi yapılacak.
  String? currentPage;

  String _getAppBarTitle() {
    if (currentPage == 'account') return 'Hesabım';
    if (currentPage == 'vehicles') return 'Araçlarım';
    if (currentPage == 'reports') return 'Raporlar';
    return 'Ana Sayfa';
  }

  Future<Map<String, dynamic>?> _fetchUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      return doc.data();
    }
    return null;
  }

  Widget _buildDrawerHeader() {
    return FutureBuilder<Map<String, dynamic>?>(
      future: _fetchUserData(),
      builder: (context, snapshot) {
        String headerText = 'Kullanıcı';
        if (snapshot.hasData && snapshot.data != null) {
          final userData = snapshot.data!;
          headerText = '${userData['isim'] ?? 'Kullanıcı'} ${userData['soyisim'] ?? ''}';
        }
        return Container(
          color: Colors.purple,
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          height: 80,
          alignment: Alignment.bottomCenter,
          child: Text(
            headerText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
        leading: Builder(
          builder: (context) => IconButton(
            icon: const Icon(Icons.menu),
            onPressed: () {
              Scaffold.of(context).openDrawer();
            },
          ),
        ),
      ),
      drawer: Container(
        width: 250,
        child: Drawer(
          child: Column(
            children: [
              InkWell(
                onTap: () {
                  setState(() {
                    currentPage = null;
                  });
                  Navigator.pop(context);
                },
                child: _buildDrawerHeader(),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle),
                title: const Center(child: Text('Hesabım')),
                onTap: () {
                  setState(() {
                    currentPage = 'account';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.directions_car),
                title: const Center(child: Text('Araçlarım')),
                onTap: () {
                  setState(() {
                    currentPage = 'vehicles';
                  });
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.insert_drive_file),
                title: const Center(child: Text('Raporlar')),
                onTap: () {
                  setState(() {
                    currentPage = 'reports';
                  });
                  Navigator.pop(context);
                },
              ),
              const Spacer(),
              ListTile(
                leading: const Icon(Icons.logout),
                title: const Center(child: Text('Çıkış Yap')),
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  Navigator.pushReplacementNamed(context, '/login');
                },
              ),
            ],
          ),
        ),
      ),
      // currentPage null ise ana sayfada ortalanmış "Tutanak İşlemleri" butonu gösteriliyor.
      body: currentPage == null
          ? Center(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RecordOperationsPage()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(200, 50),
                ),
                child: const Text('Tutanak İşlemleri'),
              ),
            )
          : (currentPage == 'account'
              ? const AccountPage()
              : (currentPage == 'vehicles'
                  ? const VehiclesPage()
                  : const ReportsPage())),
      floatingActionButton: currentPage == 'vehicles'
          ? FloatingActionButton.extended(
              onPressed: () {
                VehiclesPage.showAddVehicleDialog(context);
              },
              label: const Text('Araç Ekle'),
              icon: const Icon(Icons.add),
            )
          : currentPage == 'reports'
              ? FloatingActionButton.extended(
                  onPressed: () {
                    ReportsPage.showAddReportDialog(context);
                  },
                  label: const Text('Rapor Ekle'),
                  icon: const Icon(Icons.add),
                )
              : null,
    );
  }
}
