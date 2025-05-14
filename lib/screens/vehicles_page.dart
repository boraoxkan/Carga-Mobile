// lib/screens/vehicles_page.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:flutter/services.dart';
import 'package:tutanak/services/car_service.dart';
import '../widgets/cupertino_picker_dialog.dart';
import 'vehicle_details_page.dart';

class VehiclesPage extends StatefulWidget {
  const VehiclesPage({Key? key}) : super(key: key);

  static void showAddVehicleDialog(BuildContext context) {
    // Çağırıldığında, mevcut state üzerinden dialog'u göstermek için:
    _VehiclesPageState()._showAddVehicleDialog(context);
  }

  @override
  _VehiclesPageState createState() => _VehiclesPageState();
}

class _VehiclesPageState extends State<VehiclesPage> {
  @override
  Widget build(BuildContext context) {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) return const Center(child: Text('Giriş yapılmamış.'));

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
          return Center(child: Text('Hata: ${snapshot.error}'));
        } else if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
          return const Center(child: Text('Hiç araç eklenmemiş.'));
        } else {
          final vehicles = snapshot.data!.docs;
          return ListView.builder(
            itemCount: vehicles.length,
            itemBuilder: (context, index) {
              final doc = vehicles[index];
              final vehicleData = doc.data() as Map<String, dynamic>;
              // ListTile'ı Slidable içerisine yerleştiriyoruz.
              return Slidable(
                key: Key(doc.id),
                startActionPane: ActionPane(
                  motion: const DrawerMotion(),
                  extentRatio: 0.25,
                  children: [
                    SlidableAction(
                      onPressed: (context) async {
                        bool confirm = await showDialog<bool>(
                          context: context,
                          builder: (context) {
                            return AlertDialog(
                              title: const Text('Silme Onayı'),
                              content: const Text('Bu aracı silmek istediğinize emin misiniz?'),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('İptal'),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(true),
                                  child: const Text('Sil'),
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
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Araç silindi.')),
                            );
                          } catch (e) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Silme hatası: $e')),
                            );
                          }
                        }
                      },
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      icon: Icons.delete,
                      label: 'Sil',
                    ),
                  ],
                ),
                child: ListTile(
                  leading: const Icon(Icons.directions_car, color: Colors.purple),
                  title: Text('${vehicleData['marka'] ?? '-'} - ${vehicleData['seri'] ?? '-'}'),
                  subtitle: Text('${vehicleData['model'] ?? '-'} | Plaka: ${vehicleData['plaka'] ?? '-'}'),
                  // Trailing kısmına bilgi ikonunu ekledik.
                  trailing: IconButton(
                    icon: const Icon(Icons.info_outline, color: Colors.blue),
                    onPressed: () {
                      // VehicleDetailsPage'e navigasyon: aracın tüm detaylarını gönderiyoruz.
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

  void _showAddVehicleDialog(BuildContext context) {
    final _vehicleFormKey = GlobalKey<FormState>();
    final CarService carService = CarService();

    List<String> brands = [];
    List<String> series = [];
    List<String> models = [];
    final List<String> usageOptions = ['Bireysel', 'Ticari'];

    String? selectedBrand;
    String? selectedSeries;
    String? selectedModel;
    String? selectedUsage;

    TextEditingController yearController = TextEditingController();
    TextEditingController plateController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(builder: (context, setState) {
          return AlertDialog(
            title: const Text('Araç Ekle'),
            content: SingleChildScrollView(
              child: Form(
                key: _vehicleFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Araç Markası seçimi
                    FutureBuilder<List<String>>(
                      future: carService.fetchCarMakes(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const CircularProgressIndicator();
                        } else if (snapshot.hasError) {
                          return Text('Hata: ${snapshot.error}');
                        } else {
                          brands = snapshot.data!;
                          return GestureDetector(
                            onTap: () async {
                              String? result = await showCupertinoPickerDialog(
                                  context: context, items: brands, title: 'Araç Markası Seçiniz');
                              if (result != null) {
                                setState(() {
                                  selectedBrand = result;
                                  selectedSeries = null;
                                  selectedModel = null;
                                  series = [];
                                  models = [];
                                });
                                List<String> fetchedSeries = await carService.fetchCarSeries(result);
                                setState(() {
                                  series = fetchedSeries;
                                });
                              }
                            },
                            child: InputDecorator(
                              decoration: InputDecoration(
                                labelText: 'Araç Markası',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              child: Text(selectedBrand ?? 'Seçiniz'),
                            ),
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 16),
                    // Araç Serisi seçimi (sadece marka seçildiyse)
                    if (selectedBrand != null)
                      GestureDetector(
                        onTap: () async {
                          String? result = await showCupertinoPickerDialog(
                              context: context, items: series, title: 'Araç Serisi Seçiniz');
                          if (result != null) {
                            setState(() {
                              selectedSeries = result;
                              selectedModel = null;
                              models = [];
                            });
                            List<String> fetchedModels = await carService.fetchCarModels(selectedBrand!, result);
                            setState(() {
                              models = fetchedModels;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Araç Serisi',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(selectedSeries ?? 'Seçiniz'),
                        ),
                      ),
                    if (selectedBrand != null) const SizedBox(height: 16),
                    // Araç Modeli seçimi (sadece marka ve seri seçildiyse)
                    if (selectedBrand != null && selectedSeries != null)
                      GestureDetector(
                        onTap: () async {
                          String? result = await showCupertinoPickerDialog(
                              context: context, items: models, title: 'Araç Modeli Seçiniz');
                          if (result != null) {
                            setState(() {
                              selectedModel = result;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: InputDecoration(
                            labelText: 'Araç Modeli',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text(selectedModel ?? 'Seçiniz'),
                        ),
                      ),
                    const SizedBox(height: 16),
                    // Model Yılı
                    TextFormField(
                      controller: yearController,
                      decoration: InputDecoration(
                        labelText: 'Model Yılı',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Lütfen model yılı giriniz';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    // Kullanım Şekli seçimi
                    GestureDetector(
                      onTap: () async {
                        String? result = await showCupertinoPickerDialog(
                            context: context, items: usageOptions, title: 'Kullanım Şekli Seçiniz');
                        if (result != null) {
                          setState(() {
                            selectedUsage = result;
                          });
                        }
                      },
                      child: InputDecorator(
                        decoration: InputDecoration(
                          labelText: 'Kullanım Şekli',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text(selectedUsage ?? 'Seçiniz'),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Plaka Numarası
                    TextFormField(
                      controller: plateController,
                      decoration: InputDecoration(
                        labelText: 'Plaka Numarası',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) return 'Lütfen plaka numarası giriniz';
                        return null;
                      },
                    )
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
                onPressed: () async {
                  if (_vehicleFormKey.currentState!.validate()) {
                    try {
                      User? user = FirebaseAuth.instance.currentUser;
                      if (user != null) {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('vehicles')
                            .add({
                          'marka': selectedBrand,
                          'seri': selectedSeries,
                          'model': selectedModel,
                          'modelYili': yearController.text.trim(),
                          'kullanim': selectedUsage,
                          'plaka': plateController.text.trim(),
                        });
                        Navigator.pop(context);
                      }
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Araç eklenirken hata oluştu: $e')),
                      );
                    }
                  }
                },
                child: const Text('Kaydet'),
              )
            ],
          );
        });
      },
    );
  }
}
