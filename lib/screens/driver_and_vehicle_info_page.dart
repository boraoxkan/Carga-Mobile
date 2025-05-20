// lib/screens/driver_and_vehicle_info_page.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'qr_display_page.dart';
import 'qr_scanner_page.dart';
// import 'package:tutanak/screens/vehicles_page.dart'; // Eğer Araçlarım sayfasından hızlıca araç eklemeye yönlendirme yapılacaksa

class DriverAndVehicleInfoPage extends StatefulWidget {
  final bool isJoining;

  const DriverAndVehicleInfoPage({Key? key, required this.isJoining})
      : super(key: key);

  @override
  _DriverAndVehicleInfoPageState createState() =>
      _DriverAndVehicleInfoPageState();
}

class _DriverAndVehicleInfoPageState extends State<DriverAndVehicleInfoPage> {
  // final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  String? selectedVehicleId;
  List<Map<String, dynamic>> vehiclesList = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);

    try {
      await _loadDriverInfo();
      if (!mounted) return; // _loadDriverInfo sonrası widget mount durumunu kontrol et
      await _loadVehicles();
    } catch (e, s) {
      print("HATA: Sürücü/Araç bilgileri yüklenirken hata oluştu (DriverAndVehicleInfoPage): $e");
      print("Stack Trace: $s");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Bilgiler yüklenirken bir hata oluştu.")),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _loadDriverInfo() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        _nameController.text = "Giriş Yapılmamış";
        _phoneController.text = "";
        // _isLoading=false burada yapılabilir veya _loadInitialData'nın finally'sinde
      }
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.serverAndCache));

      if (!mounted) return;

      if (doc.exists && doc.data() != null) {
        final data = doc.data()!;
        final isim = data['isim']?.toString() ?? '';
        final soyisim = data['soyisim']?.toString() ?? '';
        _nameController.text = "$isim $soyisim".trim();
        _phoneController.text = data['telefon']?.toString() ?? '';
      } else {
        _nameController.text = "Profil Bilgisi Yok";
        _phoneController.text = "";
      }
    } catch (e, s) {
      print("HATA: Firestore'dan sürücü bilgisi alınırken (DriverAndVehicleInfoPage): $e");
      print("Stack Trace: $s");
      if (mounted) {
        _nameController.text = "Hata Oluştu";
        _phoneController.text = "";
      }
    }
  }

  Future<void> _loadVehicles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if(mounted) {
        setState(() {
          vehiclesList = [];
          selectedVehicleId = null;
        });
      }
      return;
    }
    try {
      final snap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .get(const GetOptions(source: Source.serverAndCache));

      if (!mounted) return;

      vehiclesList = snap.docs.map((d) {
        final data = d.data();
        data['id'] = d.id;
        return data;
      }).toList();

      if (vehiclesList.isNotEmpty) {
        if (selectedVehicleId == null || !vehiclesList.any((v) => v['id'] == selectedVehicleId)) {
          selectedVehicleId = vehiclesList.first['id'] as String?;
        }
      } else {
        selectedVehicleId = null;
      }
    } catch (e, s) {
      print("HATA: Firestore'dan araç bilgisi alınırken (DriverAndVehicleInfoPage): $e");
      print("Stack Trace: $s");
      if (mounted) {
        vehiclesList = [];
        selectedVehicleId = null;
      }
    }
  }

  void _showAllVehiclesDialog() {
    final theme = Theme.of(context);
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text("Tüm Araçlarınız"),
        content: SizedBox(
          width: double.maxFinite,
          child: vehiclesList.isEmpty
              ? const Text("Gösterilecek araç bulunmuyor.")
              : ListView.builder(
                  shrinkWrap: true,
                  itemCount: vehiclesList.length,
                  itemBuilder: (_, i) {
                    final v = vehiclesList[i];
                    final marka = v['marka']?.toString() ?? 'Bilinmiyor';
                    final seri = v['seri']?.toString() ?? '';
                    final plaka = v['plaka']?.toString() ?? 'Plakasız';
                    final vehicleId = v['id'] as String?;
                    final isSelected = selectedVehicleId == vehicleId;

                    return ListTile(
                      leading: Icon(isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked, color: theme.colorScheme.primary),
                      title: Text("$marka $seri"),
                      subtitle: Text("Plaka: $plaka"),
                      tileColor: isSelected ? theme.colorScheme.primary.withOpacity(0.1) : null,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      onTap: () {
                        if (vehicleId != null && mounted) {
                          setState(() => selectedVehicleId = vehicleId);
                        }
                        Navigator.pop(dialogContext);
                      },
                    );
                  },
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text("Kapat"),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleSelectionBox(ThemeData theme) {
    if (vehiclesList.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.no_transfer_outlined, size: 48, color: theme.colorScheme.onSurfaceVariant.withOpacity(0.7)),
              const SizedBox(height: 12),
              Text(
                "Henüz kayıtlı aracınız bulunmuyor.",
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                "Lütfen önce 'Araçlarım' bölümünden araç ekleyiniz.",
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final displayCount = vehiclesList.length > 2 ? 2 : vehiclesList.length;
    final showMoreButton = vehiclesList.length > 2;

    return SizedBox(
      height: 130,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: showMoreButton ? displayCount + 1 : displayCount,
        itemBuilder: (_, i) {
          if (showMoreButton && i == displayCount) {
            return Padding(
              padding: const EdgeInsets.only(right: 8.0, top: 4, bottom: 4),
              child: InkWell(
                onTap: _showAllVehiclesDialog,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: 130,
                  decoration: BoxDecoration(
                    border: Border.all(color: theme.colorScheme.outline.withOpacity(0.7)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.more_horiz_rounded, size: 32, color: theme.colorScheme.primary),
                      const SizedBox(height: 4),
                      Text("Diğer Araçlar", textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
                    ],
                  ),
                ),
              ),
            );
          }

          final v = vehiclesList[i];
          final vehicleId = v['id'] as String?;
          final isSelected = selectedVehicleId == vehicleId;
          final marka = v['marka']?.toString() ?? '-';
          final seri = v['seri']?.toString() ?? '-';
          final plaka = v['plaka']?.toString() ?? '-';

          return SizedBox(
            width: 150,
            child: Card(
              elevation: isSelected ? 4 : 1,
              color: isSelected ? theme.colorScheme.primaryContainer.withOpacity(0.7) : theme.cardTheme.color,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isSelected ? theme.colorScheme.primary : theme.colorScheme.outline.withOpacity(0.3),
                  width: isSelected ? 2.0 : 1.0,
                ),
              ),
              margin: const EdgeInsets.only(right: 8, top: 4, bottom: 4),
              child: InkWell(
                onTap: vehicleId == null ? null : () {
                  if (mounted) setState(() => selectedVehicleId = vehicleId);
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(marka, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(seri, style: theme.textTheme.bodyMedium, overflow: TextOverflow.ellipsis),
                      const Spacer(),
                      Text(plaka, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant), overflow: TextOverflow.ellipsis),
                      if(isSelected) const SizedBox(height: 4),
                      if(isSelected) Align(alignment: Alignment.centerRight, child: Icon(Icons.check_circle, color: theme.colorScheme.primary, size: 18))
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    bool isActionInProgress = _isLoading && !vehiclesList.isNotEmpty; 

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.isJoining ? "Tutanağa Dahil Ol: Bilgiler" : "Yeni Tutanak: Bilgiler"),
      ),
      body: isActionInProgress 
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadInitialData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Sürücü Bilgileri Kartı
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("Sürücü Bilgileriniz", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _nameController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "Ad Soyad",
                                prefixIcon: Icon(Icons.person_outline, color: theme.colorScheme.primary),
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _phoneController,
                              readOnly: true,
                              decoration: InputDecoration(
                                labelText: "Telefon Numarası",
                                prefixIcon: Icon(Icons.phone_outlined, color: theme.colorScheme.primary),
                              ),
                              keyboardType: TextInputType.phone,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Araç Seçimi Kartı
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text("Araç Seçimi", style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                                IconButton(
                                  icon: Icon(Icons.refresh, color: theme.colorScheme.primary),
                                  onPressed: _loadVehicles, // Sadece araçları yenile
                                  tooltip: "Araç listesini yenile",
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            _buildVehicleSelectionBox(theme),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),

                    // Devam Et Butonu
                    ElevatedButton.icon(
                      icon: _isLoading && !isActionInProgress // Buton işlemdeyse farklı ikon/text
                          ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: theme.colorScheme.onPrimary, strokeWidth: 2))
                          : const Icon(Icons.arrow_forward_ios_rounded, size: 18),
                      label: Text(_isLoading && !isActionInProgress ? "İŞLENİYOR..." : "Devam Et"),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onPressed: (selectedVehicleId == null || (_isLoading && !isActionInProgress)) // Araç seçilmemişse veya işlemdeyse pasif
                          ? null
                          : () async {
                              final currentUser = FirebaseAuth.instance.currentUser;
                              if (currentUser == null) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text("İşleme devam etmek için giriş yapmalısınız.")),
                                );
                                return;
                              }

                              if (widget.isJoining) {
                                // KATILAN KULLANICI AKIŞI
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => QRScannerPage(
                                      joinerVehicleId: selectedVehicleId!,
                                    ),
                                  ),
                                );
                              } else {
                                // OLUŞTURAN KULLANICI AKIŞI (YENİ TUTANAK)
                                if(mounted) setState(() => _isLoading = true); // Buton işlemi için yükleme durumu

                                try {
                                  // 1. Benzersiz bir tutanak ID'si oluştur
                                  final newUniqueRecordId = FirebaseFirestore.instance.collection('records').doc().id;

                                  // 2. Bu benzersiz ID ile Firestore'da başlangıç kaydını oluştur
                                  await FirebaseFirestore.instance.collection('records').doc(newUniqueRecordId).set({
                                    'creatorUid': currentUser.uid,
                                    'creatorVehicleId': selectedVehicleId,
                                    'status': 'pending_scan',
                                    'confirmedByCreator': true,
                                    'confirmedByJoiner': false, 
                                    'createdAt': FieldValue.serverTimestamp(),
                                    'isDeletedByCreator': false, 
                                    'isDeletedByJoiner': false,  
                                    'joinerUid': null, 
                                    'joinerVehicleId': null, 
                                    'latitude': null,
                                    'longitude': null,
                                    'formattedAddress': null,
                                    'creatorDamageRegions': [],
                                    'creatorNotes': null,
                                    'creatorProcessedDamageImageBase64': null,
                                    'creatorDetectionResults': null,
                                    'creatorLastUpdateTimestamp': null,
                                    'joinerDamageRegions': [],
                                    'joinerNotes': null,
                                    'joinerProcessedDamageImageBase64': null,
                                    'joinerDetectionResults': null,
                                    'joinerConfirmationTimestamp': null,
                                    'joinerLastUpdateTimestamp': null,
                                    'reportFinalizedTimestamp': null,
                                  });

                                  if (!mounted) return;
                                  // 3. QRDisplayPage'e bu benzersiz ID'yi gönder
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => QRDisplayPage(recordId: newUniqueRecordId),
                                    ),
                                  );
                                } catch (e) {
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Tutanak başlatılırken hata: $e')),
                                    );
                                  }
                                } finally {
                                  if (mounted) {
                                    setState(() => _isLoading = false); 
                                  }
                                }
                              }
                            },
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}