// lib/screens/vehicles_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart';
import 'package:tutanak/services/car_service.dart'; 
import 'package:intl/intl.dart'; 
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'vehicle_details_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({Key? key}) : super(key: key);

  static void showAddVehicleDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return _AddVehicleDialog();
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
          .orderBy('createdAt', descending: true) 
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
            padding: const EdgeInsets.all(8.0),
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final doc = vehicles[index];
              final vehicleData = doc.data() as Map<String, dynamic>;
              final String marka = vehicleData['marka'] ?? 'Bilinmiyor';
              final String seri = vehicleData['seri'] ?? 'Bilinmiyor';
              final String model = vehicleData['model'] ?? 'Bilinmiyor';
              final String plaka = vehicleData['plaka'] ?? 'Plakasız';

              return Card(
                margin: const EdgeInsets.symmetric(vertical: 6.0, horizontal: 8.0),
                child: Slidable(
                  key: Key(doc.id),
                  startActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.25,
                    children: [
                      SlidableAction(
                        onPressed: (context) async {
                           bool confirm = await showDialog<bool>(
                            context: context,
                            builder: (BuildContext dialogContext) {
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
                              // Araçla ilişkili fotoğrafları Firebase Storage'dan sil
                              if (vehicleData['photos'] != null && vehicleData['photos'] is List) {
                                for (String photoUrl in List<String>.from(vehicleData['photos'])) {
                                  try {
                                    await firebase_storage.FirebaseStorage.instance.refFromURL(photoUrl).delete();
                                  } catch (e) {
                                    print("Storage'dan fotoğraf silinirken hata ($photoUrl): $e");
                                    // Hata olsa bile Firestore'dan silme işlemine devam et
                                  }
                                }
                              }
                              // Firestore'dan araç belgesini sil
                              await FirebaseFirestore.instance
                                  .collection('users')
                                  .doc(user.uid)
                                  .collection('vehicles')
                                  .doc(doc.id)
                                  .delete();
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Araç (${plaka}) ve ilişkili fotoğrafları silindi.')),
                                );
                              }
                            } catch (e) {
                               if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Araç silinirken genel hata: $e')),
                                );
                              }
                            }
                          }
                        },
                        backgroundColor: theme.colorScheme.errorContainer,
                        foregroundColor: theme.colorScheme.onErrorContainer,
                        icon: Icons.delete_outline,
                        label: 'Sil',
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                    leading: CircleAvatar(
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
                    isThreeLine: true,
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
                    onTap: () {
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
  final List<String> _usageOptions = ['Bireysel', 'Ticari', 'Resmi', 'Diğer'];

  String? _selectedBrand;
  String? _selectedSeries;
  String? _selectedModel;
  String? _selectedUsage;

  bool _isLoadingBrands = true;
  bool _isLoadingSeries = false;
  bool _isLoadingModels = false;
  bool _isSaving = false; 

  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _chassisNoController = TextEditingController(); 
  final TextEditingController _policyHolderNameController = TextEditingController(); 
  final TextEditingController _policyHolderIdController = TextEditingController(); 
  final TextEditingController _insuranceCompanyController = TextEditingController(); 
  final TextEditingController _agencyNoController = TextEditingController(); 
  final TextEditingController _policyNoController = TextEditingController(); 
  final TextEditingController _tramerNoController = TextEditingController(); 
  DateTime? _policyStartDate; 
  DateTime? _policyEndDate; 

  // Yeşil Kart bilgileri için controller'lar (opsiyonel)
  final TextEditingController _greenCardNoController = TextEditingController();
  final TextEditingController _greenCardCountryController = TextEditingController();
  final TextEditingController _greenCardPassportNoController = TextEditingController();
  bool _hasGreenCard = false; 

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

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: (isStartDate ? _policyStartDate : _policyEndDate) ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      helpText: isStartDate ? 'Poliçe Başlangıç Tarihi' : 'Poliçe Bitiş Tarihi',
      confirmText: 'TAMAM',
      cancelText: 'İPTAL',
      locale: const Locale('tr', 'TR'), 
    );
    if (picked != null && mounted) {
      setState(() {
        if (isStartDate) {
          _policyStartDate = picked;
          // Başlangıç tarihi, bitiş tarihinden sonra olamaz
          if (_policyEndDate != null && _policyStartDate!.isAfter(_policyEndDate!)) {
            _policyEndDate = null; 
          }
        } else {
          _policyEndDate = picked;
           // Bitiş tarihi, başlangıç tarihinden önce olamaz
          if (_policyStartDate != null && _policyEndDate!.isBefore(_policyStartDate!)) {
            _policyStartDate = null;
             ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Bitiş tarihi başlangıç tarihinden önce olamaz. Lütfen başlangıç tarihini de kontrol edin.')),
            );
          }
        }
      });
    }
  }


  Future<void> _saveVehicle() async {
    if (_vehicleFormKey.currentState!.validate()) {
      if (_selectedBrand == null || _selectedSeries == null || _selectedModel == null || _selectedUsage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lütfen Marka, Seri, Model ve Kullanım Şekli seçimlerini yapınız.')),
        );
        return;
      }
      if(mounted) setState(() => _isSaving = true);
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          Map<String, dynamic> vehicleData = {
            'marka': _selectedBrand,
            'seri': _selectedSeries,
            'model': _selectedModel,
            'modelYili': _yearController.text.trim(),
            'kullanim': _selectedUsage,
            'plaka': _plateController.text.trim().toUpperCase(),
            'sasiNo': _chassisNoController.text.trim().toUpperCase(),
            'sigortaliAdiSoyadi': _policyHolderNameController.text.trim(),
            'sigortaliTcVergiNo': _policyHolderIdController.text.trim(),
            'sigortaSirketi': _insuranceCompanyController.text.trim(),
            'acenteNo': _agencyNoController.text.trim(),
            'policeNo': _policyNoController.text.trim(),
            'tramerBelgeNo': _tramerNoController.text.trim(),
            'policeBaslangicTarihi': _policyStartDate != null ? Timestamp.fromDate(_policyStartDate!) : null,
            'policeBitisTarihi': _policyEndDate != null ? Timestamp.fromDate(_policyEndDate!) : null,
            'yesilKartVar': _hasGreenCard,
            'yesilKartNo': _hasGreenCard ? _greenCardNoController.text.trim() : null,
            'yesilKartUlke': _hasGreenCard ? _greenCardCountryController.text.trim() : null,
            'yesilKartPasaportNo': _hasGreenCard ? _greenCardPassportNoController.text.trim() : null,
            'createdAt': FieldValue.serverTimestamp(),
            'photos': [],
          };

          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('vehicles')
              .add(vehicleData);

          if(mounted) {
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Araç başarıyla eklendi.')),
            );
          }
        }
      } catch (e) {
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Araç eklenirken hata oluştu: $e')),
          );
        }
      } finally {
        if(mounted) setState(() => _isSaving = false);
      }
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 8.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: const Text('Yeni Araç Ekle'),
      content: SingleChildScrollView(
        child: Form(
          key: _vehicleFormKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionTitle("Temel Araç Bilgileri"),
              // Marka, Seri, Model, Yıl, Kullanım, Plaka, Şasi No
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
              TextFormField(
                controller: _yearController,
                decoration: const InputDecoration(labelText: 'Model Yılı', prefixIcon: Icon(Icons.calendar_today_outlined)),
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(4)],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Lütfen model yılı giriniz';
                  if (value.length != 4) return 'Model yılı 4 haneli olmalıdır';
                  int? year = int.tryParse(value);
                  if (year == null || year < 1900 || year > DateTime.now().year + 1) {
                     return 'Geçerli bir yıl giriniz';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
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
              TextFormField(
                controller: _plateController,
                decoration: const InputDecoration(labelText: 'Plaka Numarası', prefixIcon: Icon(Icons.pin_outlined)),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Lütfen plaka numarası giriniz';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _chassisNoController,
                decoration: const InputDecoration(labelText: 'Şasi Numarası', prefixIcon: Icon(Icons.confirmation_number_outlined)),
                textCapitalization: TextCapitalization.characters,
                validator: (value) {
                  if (value == null || value.trim().isEmpty) return 'Lütfen şasi numarası giriniz';
                  if (value.length != 17) return 'Şasi numarası 17 karakter olmalıdır.'; // Standart Şasi No uzunluğu
                  return null;
                },
              ),

              _buildSectionTitle("Trafik Sigortası Bilgileri"),
              TextFormField(controller: _policyHolderNameController, decoration: const InputDecoration(labelText: 'Sigortalının Adı Soyadı', prefixIcon: Icon(Icons.person_outline))),
              const SizedBox(height: 16),
              TextFormField(controller: _policyHolderIdController, decoration: const InputDecoration(labelText: 'Sigortalının TC Kimlik/Vergi No', prefixIcon: Icon(Icons.badge_outlined)), keyboardType: TextInputType.text), // TC veya Vergi No metin olabilir
              const SizedBox(height: 16),
              TextFormField(controller: _insuranceCompanyController, decoration: const InputDecoration(labelText: 'Sigorta Şirketinin Unvanı', prefixIcon: Icon(Icons.business_outlined))),
              const SizedBox(height: 16),
              TextFormField(controller: _agencyNoController, decoration: const InputDecoration(labelText: 'Acente Numarası', prefixIcon: Icon(Icons.support_agent_outlined))),
              const SizedBox(height: 16),
              TextFormField(controller: _policyNoController, decoration: const InputDecoration(labelText: 'Poliçe Numarası', prefixIcon: Icon(Icons.article_outlined))),
              const SizedBox(height: 16),
              TextFormField(controller: _tramerNoController, decoration: const InputDecoration(labelText: 'TRAMER Belge No (varsa)', prefixIcon: Icon(Icons.assignment_outlined))),
              const SizedBox(height: 16),
              Row(children: [
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Poliçe Başlangıç Tarihi',
                        prefixIcon: Icon(Icons.date_range_outlined),
                        suffixIcon: IconButton(icon: Icon(Icons.calendar_month), onPressed: () => _selectDate(context, true)),
                      ),
                      controller: TextEditingController(text: _policyStartDate != null ? DateFormat('dd.MM.yyyy', 'tr').format(_policyStartDate!) : ''),
                      validator: (value) => _policyStartDate == null ? 'Başlangıç tarihi seçiniz' : null,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Poliçe Bitiş Tarihi',
                        prefixIcon: Icon(Icons.date_range_outlined),
                        suffixIcon: IconButton(icon: Icon(Icons.calendar_month), onPressed: () => _selectDate(context, false)),
                      ),
                      controller: TextEditingController(text: _policyEndDate != null ? DateFormat('dd.MM.yyyy', 'tr').format(_policyEndDate!) : ''),
                       validator: (value) {
                        if (_policyEndDate == null) return 'Bitiş tarihi seçiniz';
                        if (_policyStartDate != null && _policyEndDate!.isBefore(_policyStartDate!)) {
                          return 'Bitiş tarihi, başlangıçtan önce olamaz';
                        }
                        return null;
                      },
                    ),
                  ),
                ]),
              const SizedBox(height: 16),
              
              _buildSectionTitle("Yeşil Kart Bilgileri (varsa)"),
              SwitchListTile(
                title: const Text('Yeşil Kart Mevcut mu?'),
                value: _hasGreenCard,
                onChanged: (bool value) {
                  setState(() {
                    _hasGreenCard = value;
                  });
                },
                secondary: Icon(_hasGreenCard ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded, color: theme.colorScheme.primary),
              ),
              if (_hasGreenCard) ...[
                const SizedBox(height: 16),
                TextFormField(controller: _greenCardNoController, decoration: const InputDecoration(labelText: 'Yeşil Kart Numarası', prefixIcon: Icon(Icons.credit_card_outlined))),
                const SizedBox(height: 16),
                TextFormField(controller: _greenCardCountryController, decoration: const InputDecoration(labelText: 'Yeşil Kart Ülkesi', prefixIcon: Icon(Icons.public_outlined))),
                const SizedBox(height: 16),
                TextFormField(controller: _greenCardPassportNoController, decoration: const InputDecoration(labelText: 'Pasaport Numarası (Yeşil Kart için)', prefixIcon: Icon(Icons.badge_outlined))),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('İptal'),
        ),
        ElevatedButton.icon(
          icon: _isSaving ? SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Icon(Icons.save_alt_rounded),
          label: Text(_isSaving ? 'KAYDEDİLİYOR...' : 'Kaydet'),
          onPressed: _isSaving ? null : _saveVehicle,
        ),
      ],
    );
  }
}