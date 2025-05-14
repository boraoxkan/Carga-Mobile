import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

class CarService {
  // JSON dosyasını yükler ve Map<String,dynamic> olarak döner.
  Future<Map<String, dynamic>> loadCarData() async {
    final String jsonString = await rootBundle.loadString('assets/all_car_data.json');
    final Map<String, dynamic> data = jsonDecode(jsonString);
    return data;
  }

  // Tüm markaları döndürür (JSON anahtarları).
  Future<List<String>> fetchCarMakes() async {
    final data = await loadCarData();
    return data.keys.toList();
  }

  // Seçilen markaya ait serileri döndürür.
  Future<List<String>> fetchCarSeries(String brand) async {
    final data = await loadCarData();
    if (data.containsKey(brand)) {
      final brandData = data[brand];
      if (brandData is Map<String, dynamic>) {
        return brandData.keys.toList();
      }
    }
    return [];
  }

  // Seçilen marka ve seriye ait modelleri döndürür.
  Future<List<String>> fetchCarModels(String brand, String series) async {
    final data = await loadCarData();
    if (data.containsKey(brand)) {
      final brandData = data[brand];
      if (brandData is Map<String, dynamic> && brandData.containsKey(series)) {
        final List<dynamic> models = brandData[series];
        return models.map((e) => e.toString()).toList();
      }
    }
    return [];
  }
}
