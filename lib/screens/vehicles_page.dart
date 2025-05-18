// lib/screens/vehicles_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart'; // FilteringTextInputFormatter için
import 'package:tutanak/services/car_service.dart'; // CarService importu
// CupertinoPickerDialog yerine Material Dropdown kullanacağız
// import '../widgets/cupertino_picker_dialog.dart';
import 'vehicle_details_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({Key? key}) : super(key: key);

  // showAddVehicleDialog'u static yapmak yerine, HomeScreen'den çağrıldığında
  // bir GlobalKey<VehiclesPageState> üzerinden erişmek daha iyi bir pratik olabilir
  // ya da bu metodu bir helper sınıfına taşımak.
  // Şimdilik mevcut static yapıyı koruyarak içini güncelleyeceğiz.
  static void showAddVehicleDialog(BuildContext context) {
    // Bu static metodun doğrudan state'e erişimi olmadığı için,
    // dialog gösterme işlevini VehiclesPage widget'ının state'ine taşıyıp,
    // FAB tıklandığında o state üzerinden çağırmak daha doğru olur.
    // Alternatif olarak, VehiclesPage'e bir GlobalKey verip HomeScreen'den
    // bu key üzerinden state'e ulaşıp metodu çağırabiliriz.
    // Şimdilik en basit haliyle, dialog'un stateful olmasını sağlayacak şekilde güncelleyelim.
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AddVehicleDialog(); // Ayrı bir StatefulWidget olarak tanımladık
      },
    );
  }

  @override
  _VehiclesPageState createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Araçlarınızı görmek için lütfen giriş yapın.', textAlign: TextAlign.center),
        ),
      );
    }

    final theme = Theme.of(context);

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('vehicles')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        } else if (snapshot.hasError) {
          return Center(child: Text('Araçlar yüklenirken bir hata oluştu: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.directions_car_filled_outlined, size: 80, color: theme.colorScheme.secondary.withOpacity(0.7)),
                  const SizedBox(height: 20),
                  Text(
                    'Henüz aracınız yok.',
                    style: theme.textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Yeni bir araç eklemek için aşağıdaki (+) butonuna dokunun.',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        } else {
          final vehicles = snapshot.data!.docs;
          return ListView.builder(
            padding: const EdgeInsets.all(8.0), // Liste için genel padding
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final doc = vehicles[index];
              final vehicleData = doc.data() as Map<String, dynamic>;
              final String marka = vehicleData['marka'] ?? 'Bilinmiyor';
              final String seri = vehicleData['seri'] ?? 'Bilinmiyor';
              final String model = vehicleData['model'] ?? 'Bilinmiyor';
              final String plaka = vehicleData['plaka'] ?? 'Plakasız';

              return Card(
                // Card stili tema'dan gelecek
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                child: Slidable(
                  key: Key(doc.id),
                  startActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (context) async {
                          // Silme onayı ve işlemi (öncekiyle aynı)
                           bool confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext dialogContext) { // Dialog context'i
                              return AlertDialog(
                                title: const Text('Silme Onayı'),
                                content: Text('"${marka} ${seri} (${plaka})" aracını silmek istediğinize emin misiniz?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(false),
                                    child: const Text('İptal'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.of(dialogContext).pop(true),
                                    child: Text('Sil', style: TextStyle(color: theme.colorScheme.error)),
                                  ),
                                ],
                              );
                            },
                          ) ?? false;

                          if (confirm) {
                            try {
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('vehicles')
                                  .doc(doc.id)
                                  .delete();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Araç (${plaka}) silindi.')),
                                );
                              }
                            } catch (e) {
                               if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Silme hatası: $e')),
                                );
                              }
                            }
                          }
                        },
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        icon: Icons.delete_outline,
                        label: 'Sil',
                        borderRadius: BorderRadius.circular(12), // Card ile uyumlu
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    leading: CircleAvatar( // İkon yerine daha şık bir avatar
                      backgroundColor: theme.colorScheme.primaryContainer,
                      foregroundColor: theme.colorScheme.onPrimaryContainer,
                      child: const Icon(Icons.directions_car_filled_outlined),
                    ),
                    title: Text(
                      '$marka $seri',
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '$model\nPlaka: $plaka',
                      style: theme.textTheme.bodyMedium,
                    ),
                    isThreeLine: true, // Subtitle'da iki satır varsa
                    trailing: IconButton(
                      icon: Icon(Icons.arrow_forward_ios_rounded, color: theme.colorScheme.secondary),
                      tooltip: "Detayları Gör",
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VehicleDetailsPage(
                              vehicleId: doc.id,
                              vehicleData: vehicleData,
                            ),
                          ),
                        );
                      },
                    ),
                    onTap: () { // ListTile'a tıklanınca da detaylara git
                       Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => VehicleDetailsPage(
                              vehicleId: doc.id,
                              vehicleData: vehicleData,
                            ),
                          ),
                        );
                    },
                  ),
                ),
              );
            },
          );
        }
      },
    );
  }
}

// Araç Ekleme Dialog'u için ayrı bir StatefulWidget
class _AddVehicleDialog extends StatefulWidget {
  @override
  __AddVehicleDialogState createState() => __AddVehicleDialogState();
}

class __AddVehicleDialogState extends State<_AddVehicleDialog> {
  final _vehicleFormKey = GlobalKey<FormState>();
  final CarService _carService = CarService();

  List<String> _brands = [];
  List<String> _series = [];
  List<String> _models = [];
  final List<String> _usageOptions = ['Bireysel', 'Ticari'];

  String? _selectedBrand;
  String? _selectedSeries;
  String? _selectedModel;
  String? _selectedUsage;

  bool _isLoadingBrands = true;
  bool _isLoadingSeries = false;
  bool _isLoadingModels = false;

  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchBrands();
  }

  Future<void> _fetchBrands() async {
    if (!mounted) return;
    setState(() => _isLoadingBrands = true);
    try {
      _brands = await _carService.fetchCarMakes();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Markalar yüklenemedi: $e')));
    }
    if (mounted) setState(() => _isLoadingBrands = false);
  }

  Future<void> _fetchSeries(String brand) async {
    if (!mounted) return;
    setState(() {
      _isLoadingSeries = true;
      _series = [];
      _selectedSeries = null;
      _models = [];
      _selectedModel = null;
    });
    try {
      _series = await _carService.fetchCarSeries(brand);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Seriler yüklenemedi: $e')));
    }
    if (mounted) setState(() => _isLoadingSeries = false);
  }

  Future<void> _fetchModels(String brand, String series) async {
    if (!mounted) return;
    setState(() {
      _isLoadingModels = true;
      _models = [];
      _selectedModel = null;
    });
    try {
      _models = await _carService.fetchCarModels(brand, series);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Modeller yüklenemedi: $e')));
    }
    if (mounted) setState(() => _isLoadingModels = false);
  }

  Future<void> _saveVehicle() async {
    if (_vehicleFormKey.currentState!.validate()) {
      if (_selectedBrand == null || _selectedSeries == null || _selectedModel == null || _selectedUsage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen tüm seçimleri yapınız.')),
        );
        return;
      }
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('vehicles')
              .add({
            'marka': _selectedBrand,
            'seri': _selectedSeries,
            'model': _selectedModel,
            'modelYili': _yearController.text.trim(),
            'kullanim': _selectedUsage,
            'plaka': _plateController.text.trim().toUpperCase(), // Plakayı büyük harfe çevir
            'createdAt': FieldValue.serverTimestamp(), // Oluşturulma tarihi
            'photos': [], // Başlangıçta boş fotoğraf listesi
          });
          Navigator.pop(context); // Dialogu kapat
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Araç başarıyla eklendi.')),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Araç eklenirken hata oluştu: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Input stilleri tema'dan gelecek (main.dart'ta tanımlı)
    // final inputDecoration = theme.inputDecorationTheme;

    return AlertDialog(
      title: const Text('Yeni Araç Ekle'),
      content: SingleChildScrollView(
        child: Form(
          key: _vehicleFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Marka Seçimi
              _isLoadingBrands
                  ? const Center(child: CircularProgressIndicator())
                  : DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Araç Markası', prefixIcon: Icon(Icons.factory_outlined)),
                      value: _selectedBrand,
                      hint: const Text('Marka Seçiniz'),
                      isExpanded: true,
                      items: _brands.map((String brand) {
                        return DropdownMenuItem<String>(value: brand, child: Text(brand));
                      }).toList(),
                      onChanged: (String? newValue) {
                        if (newValue != null) {
                          setState(() => _selectedBrand = newValue);
                          _fetchSeries(newValue);
                        }
                      },
                      validator: (value) => value == null ? 'Marka seçimi zorunludur' : null,
                    ),
              const SizedBox(height: 16),

              // Seri Seçimi
              if (_selectedBrand != null)
                _isLoadingSeries
                    ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                    : DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Araç Serisi', prefixIcon: Icon(Icons.view_stream_outlined)),
                        value: _selectedSeries,
                        hint: const Text('Seri Seçiniz'),
                        isExpanded: true,
                        items: _series.map((String series) {
                          return DropdownMenuItem<String>(value: series, child: Text(series));
                        }).toList(),
                        onChanged: _series.isEmpty ? null : (String? newValue) {
                           if (newValue != null) {
                            setState(() => _selectedSeries = newValue);
                            _fetchModels(_selectedBrand!, newValue);
                          }
                        },
                        validator: (value) => _series.isNotEmpty && value == null ? 'Seri seçimi zorunludur' : null,
                      ),
              if (_selectedBrand != null) const SizedBox(height: 16),

              // Model Seçimi
              if (_selectedBrand != null && _selectedSeries != null)
                _isLoadingModels
                    ? const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator()))
                    : DropdownButtonFormField<String>(
                        decoration: const InputDecoration(labelText: 'Araç Modeli', prefixIcon: Icon(Icons.directions_car_outlined)),
                        value: _selectedModel,
                        hint: const Text('Model Seçiniz'),
                        isExpanded: true,
                        items: _models.map((String model) {
                          return DropdownMenuItem<String>(value: model, child: Text(model));
                        }).toList(),
                        onChanged: _models.isEmpty ? null : (String? newValue) {
                          if (newValue != null) {
                            setState(() => _selectedModel = newValue);
                          }
                        },
                        validator: (value) => _models.isNotEmpty && value == null ? 'Model seçimi zorunludur' : null,
                      ),
              if (_selectedBrand != null && _selectedSeries != null) const SizedBox(height: 16),

              // Model Yılı
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(labelText: 'Model Yılı', prefixIcon: Icon(Icons.calendar_today_outlined)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Lütfen model yılı giriniz';
                  if (value.length != 4) return 'Model yılı 4 haneli olmalıdır';
                  // İsteğe bağlı: Yılın geçerli bir aralıkta olup olmadığını kontrol et
                  int? year = int.tryParse(value);
                  if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                     return 'Geçerli bir yıl giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Kullanım Şekli
              DropdownButtonFormField<String>(
                decoration: const InputDecoration(labelText: 'Kullanım Şekli', prefixIcon: Icon(Icons.work_outline)),
                value: _selectedUsage,
                hint: const Text('Kullanım Şekli Seçiniz'),
                isExpanded: true,
                items: _usageOptions.map((String usage) {
                  return DropdownMenuItem<String>(value: usage, child: Text(usage));
                }).toList(),
                onChanged: (String? newValue) {
                  if (newValue != null) {
                    setState(() => _selectedUsage = newValue);
                  }
                },
                validator: (value) => value == null ? 'Kullanım şekli seçimi zorunludur' : null,
              ),
              const SizedBox(height: 16),

              // Plaka Numarası
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Plaka Numarası', prefixIcon: Icon(Icons.pin_outlined)),
                textCapitalization: TextCapitalization.characters, // Otomatik büyük harf
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Lütfen plaka numarası giriniz';
                  // İsteğe bağlı: Plaka formatı için regex kontrolü eklenebilir
                  return null;
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton(
          onPressed: _saveVehicle,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}