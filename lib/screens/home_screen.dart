// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'account_page.dart'; // Güncellenmiş AccountPage'i import ediyoruz
import 'vehicles_page.dart';
import 'reports_page.dart';
import 'new_record_warning_page.dart';
// import 'record_operations_page.dart'; // Eğer kullanıyorsanız

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _currentPageKey = 'home';
  User? _currentUser;
  Map<String, dynamic>? _userData;
  bool _isUserDataLoading = true;

  @override
  void initState() {
    super.initState();
    _currentUser = FirebaseAuth.instance.currentUser;
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    if (!mounted) return;
    setState(() {
      _isUserDataLoading = true;
    });
    if (_currentUser != null) {
      try {
        // Veri çekme sırasında gecikme ekleyerek anlık güncellemeyi daha iyi görmek için (opsiyonel, sadece test için)
        // await Future.delayed(Duration(milliseconds: 500));
        DocumentSnapshot<Map<String, dynamic>> doc = await FirebaseFirestore
            .instance
            .collection('users')
            .doc(_currentUser!.uid)
            .get();
        if (mounted) {
          setState(() {
            _userData = doc.data();
            _isUserDataLoading = false;
          });
        }
      } catch (e) {
        if (mounted) {
          setState(() {
            _isUserDataLoading = false;
          });
          print("Kullanıcı verisi çekilirken hata (HomeScreen): $e");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Kullanıcı bilgileri yüklenemedi: $e')),
          );
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isUserDataLoading = false;
        });
      }
    }
  }

  String _getAppBarTitle() {
    switch (_currentPageKey) {
      case 'account':
        return 'Hesabım';
      case 'vehicles':
        return 'Araçlarım';
      case 'reports':
        return 'Raporlar';
      case 'home':
      default:
        return 'Ana Sayfa';
    }
  }

  Widget _buildDrawerHeader(ThemeData theme) {
    if (_isUserDataLoading || _currentUser == null) { 
      return DrawerHeader(
        decoration: BoxDecoration(
          color: theme.colorScheme.primaryContainer,
        ),
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    String displayName = "Kullanıcı";
    String displayEmail = _currentUser!.email ?? "E-posta bulunamadı";
    String? profileImageUrl;

    if (_userData != null) {
      displayName =
          '${_userData!['isim'] ?? ''} ${_userData!['soyisim'] ?? ''}'.trim();
      if (displayName.isEmpty) displayName = "Kullanıcı";
      profileImageUrl = _userData!['profileImageUrl'] as String?;
    }

    return UserAccountsDrawerHeader(
      accountName: Text(
        displayName,
        style: theme.textTheme.titleLarge?.copyWith(color: theme.colorScheme.onPrimaryContainer),
      ),
      accountEmail: Text(
        displayEmail,
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onPrimaryContainer.withOpacity(0.8)),
      ),
      currentAccountPicture: CircleAvatar(
        radius: 30, 
        backgroundColor: theme.colorScheme.secondary,
        foregroundColor: theme.colorScheme.onSecondary,
        backgroundImage: profileImageUrl != null ? NetworkImage(profileImageUrl) : null,
        child: (profileImageUrl == null && displayName.isNotEmpty)
            ? Text(
                displayName[0].toUpperCase(),
                style: theme.textTheme.headlineMedium?.copyWith(color: theme.colorScheme.onSecondary),
              )
            : (profileImageUrl == null ? Icon(Icons.person_outline, size: 36, color: theme.colorScheme.onSecondary) : null),
      ),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
      ),
    );
  }


  Widget _buildContent() {
    switch (_currentPageKey) {
      case 'account':
        // AccountPage'e onProfileUpdated callback'ini iletiyoruz.
        // Bu callback, AccountPage'de profil güncellendiğinde HomeScreen'deki _fetchUserData'yı tetikler.
        return AccountPage(onProfileUpdated: () {
          _fetchUserData(); 
        });
      case 'vehicles':
        return const VehiclesPage();
      case 'reports':
        return const ReportsPage();
      case 'home':
      default:
        return _buildHomePageContent(Theme.of(context));
    }
  }

  Widget _buildHomePageContent(ThemeData theme) {
    String userName = _userData?['isim'] ?? 'Kullanıcı';
     return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            Icons.shield_outlined, 
            size: 80,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 24),
          Text(
            'Merhaba, $userName!',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            'Tutanak işlemlerine hızlıca başlayın veya geçmiş kayıtlarınızı inceleyin.',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 40),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_circle_outline),
            label: const Text('Yeni Tutanak Oluştur'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewRecordWarningPage(isJoining: false)),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            icon: const Icon(Icons.group_add_outlined),
            label: const Text('Mevcut Tutanağa Katıl'),
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.secondaryContainer,
              foregroundColor: theme.colorScheme.onSecondaryContainer,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewRecordWarningPage(isJoining: true)),
              );
            },
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            icon: const Icon(Icons.history_outlined),
            label: const Text('Geçmiş Tutanaklarım'),
            style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: BorderSide(color: theme.colorScheme.primary),
                foregroundColor: theme.colorScheme.primary
            ),
            onPressed: () {
              setState(() {
                _currentPageKey = 'reports';
              });
            },
          )
        ],
      ),
    );
  }

  Widget _buildDrawerListItem({
    required IconData icon,
    required String title,
    required String pageKey,
    required ThemeData theme,
  }) {
    final bool isSelected = _currentPageKey == pageKey;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? theme.colorScheme.primary.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant),
        title: Text(
          title,
          style: theme.textTheme.titleMedium?.copyWith(
            color: isSelected ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
        onTap: () {
          if (pageKey == 'logout') {
            _logout();
          } else {
            if (mounted) { 
              setState(() {
                _currentPageKey = pageKey;
              });
            }
          }
          Navigator.pop(context);
        },
        selected: isSelected,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if(mounted) { 
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(_getAppBarTitle()),
      ),
      drawer: Drawer(
        child: Column(
          children: [
            _buildDrawerHeader(theme),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                children: [
                  _buildDrawerListItem(icon: Icons.home_outlined, title: 'Ana Sayfa', pageKey: 'home', theme: theme),
                  _buildDrawerListItem(icon: Icons.account_circle_outlined, title: 'Hesabım', pageKey: 'account', theme: theme),
                  _buildDrawerListItem(icon: Icons.directions_car_outlined, title: 'Araçlarım', pageKey: 'vehicles', theme: theme),
                  _buildDrawerListItem(icon: Icons.insert_drive_file_outlined, title: 'Raporlar', pageKey: 'reports', theme: theme),
                ],
              ),
            ),
            const Spacer(),
            const Divider(height: 1, indent: 16, endIndent: 16),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: _buildDrawerListItem(icon: Icons.logout_outlined, title: 'Çıkış Yap', pageKey: 'logout', theme: theme),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
      body: _buildContent(),
      floatingActionButton: _currentPageKey == 'vehicles'
          ? FloatingActionButton.extended(
              onPressed: () {
                VehiclesPage.showAddVehicleDialog(context);
              },
              label: const Text('Araç Ekle'),
              icon: const Icon(Icons.add),
            )
          : _currentPageKey == 'reports' && ReportsPage.showAddReportDialog != null
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