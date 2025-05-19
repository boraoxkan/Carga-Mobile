// lib/screens/report_detail_page.dart
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:intl/intl.dart';
import 'package:tutanak/screens/pdf_viewer_page.dart';
import 'package:tutanak/models/crash_region.dart';
import 'package:geocoding/geocoding.dart'; // Eklendi

class ReportDetailPage extends StatefulWidget { // StatefulWidget olarak değiştirildi
  final String recordId;

  const ReportDetailPage({Key? key, required this.recordId}) : super(key: key);

  @override
  _ReportDetailPageState createState() => _ReportDetailPageState();
}

class _ReportDetailPageState extends State<ReportDetailPage> { // State sınıfı oluşturuldu
  String? _address;
  bool _isFetchingAddress = false; // Başlangıçta false, veri gelince kontrol edilecek
  String? _addressError;
  Map<String, dynamic>? _recordData; // Firestore'dan gelen veriyi tutmak için

  @override
  void initState() {
    super.initState();
    // StreamBuilder kullandığımız için, adres çekme işlemini StreamBuilder'ın
    // snapshot'ı veri döndürdüğünde tetikleyebiliriz veya doğrudan snapshot.data üzerinden
    // formattedAddress alanını okuyabiliriz.
    // Ya da, ilk veri geldiğinde bir kerelik adres çekme işlemi yapabiliriz.
    // Şimdilik, adres bilgisini StreamBuilder içinden almayı deneyelim.
  }

  Future<String> _getUserFullName(String? userId) async {
    if (userId == null || userId.isEmpty) return "Bilinmiyor";
    try {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
      if (userDoc.exists && userDoc.data() != null) {
        final data = userDoc.data() as Map<String, dynamic>;
        return '${data['isim'] ?? ''} ${data['soyisim'] ?? ''}'.trim();
      }
    } catch (e) {
      print("Kullanıcı adı çekme hatası: $e");
    }
    return "Kullanıcı Bulunamadı";
  }

  String _formatTimestamp(Timestamp? timestamp, BuildContext context) {
    if (timestamp == null) return 'Belirtilmemiş';
    final locale = Localizations.localeOf(context).toString();
    try {
      return DateFormat('dd MMMM yyyy, HH:mm', locale).format(timestamp.toDate());
    } catch (e) {
      print("Tarih formatlama hatası (locale: $locale): $e");
      return DateFormat('dd.MM.yyyy HH:mm').format(timestamp.toDate());
    }
  }

  String _regionLabel(CrashRegion region) {
    switch (region) {
      case CrashRegion.frontLeft:   return 'Ön Sol';
      case CrashRegion.frontCenter: return 'Ön Orta';
      case CrashRegion.frontRight:  return 'Ön Sağ';
      case CrashRegion.left:        return 'Sol Taraf';
      case CrashRegion.right:       return 'Sağ Taraf';
      case CrashRegion.rearLeft:    return 'Arka Sol';
      case CrashRegion.rearCenter:  return 'Arka Orta';
      case CrashRegion.rearRight:   return 'Arka Sağ';
      default: return region.name;
    }
  }

  // report_summary_page.dart'daki adres çekme fonksiyonunun bir benzeri
  Future<void> _fetchAddressFromLatLng(double latitude, double longitude) async {
    if (!mounted) return;
    print("report_detail_page: Adres çekme işlemi başlıyor... Enlem: $latitude, Boylam: $longitude");
    setState(() {
      _isFetchingAddress = true;
      _addressError = null;
      _address = null; // Önceki adresi temizle
    });
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(latitude, longitude);
      print("report_detail_page: Placemarks alındı: ${placemarks.length} adet");

      if (placemarks.isNotEmpty && mounted) {
        final Placemark place = placemarks.first;
        print("report_detail_page: İlk placemark: ${place.toJson()}");

        String street = place.street ?? '';
        String thoroughfare = place.thoroughfare ?? '';
        String subLocality = place.subLocality ?? '';
        String locality = place.locality ?? '';
        String administrativeArea = place.administrativeArea ?? '';
        String postalCode = place.postalCode ?? '';

        List<String> addressParts = [];
        if (street.isNotEmpty) addressParts.add(street);
        if (thoroughfare.isNotEmpty && !street.toLowerCase().contains(thoroughfare.toLowerCase())) {
           addressParts.add(thoroughfare);
        }
        if (subLocality.isNotEmpty) addressParts.add(subLocality);
        if (locality.isNotEmpty) addressParts.add(locality);
        if (administrativeArea.isNotEmpty) addressParts.add(administrativeArea);
        if (postalCode.isNotEmpty) addressParts.add(postalCode);

        String formattedAddress = addressParts.where((part) => part.isNotEmpty).join(', ');
        formattedAddress = formattedAddress.replaceAll(RegExp(r',\s*,'), ', ').replaceAll(RegExp(r'^[\s,]+|[\s,]+$'), '');

        print("report_detail_page: Formatlanmış Adres: $formattedAddress");
        setState(() {
          _address = formattedAddress.isNotEmpty ? formattedAddress : "Adres detayı bulunamadı.";
        });
      } else if (mounted) {
        print("report_detail_page: Placemark bulunamadı.");
        setState(() {
          _address = "Adres bilgisi bulunamadı.";
        });
      }
    } catch (e) {
      if (mounted) {
        print("report_detail_page: Adres çevirme hatası (catch bloğu): $e");
        setState(() {
          _addressError = "Adres alınamadı: ${e.toString().substring(0, (e.toString().length > 50) ? 50 : e.toString().length)}...";
          _address = null;
        });
      }
    } finally {
      if (mounted) {
        print("report_detail_page: Adres çekme işlemi tamamlandı. _isFetchingAddress: false, Adres: $_address, Hata: $_addressError");
        setState(() {
          _isFetchingAddress = false;
        });
      }
    }
  }


  Widget _buildSectionTitle(BuildContext context, String title, IconData icon, Color color) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 20.0, bottom: 10.0),
      child: Row(
        children: [
          Icon(icon, color: color, size: 28),
          const SizedBox(width: 10),
          Text(title, style: theme.textTheme.headlineSmall?.copyWith(color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required BuildContext context,
    String? title,
    IconData? titleIcon,
    required List<Widget> children,
    EdgeInsetsGeometry? padding,
    Color? cardColor,
    Color? titleColor,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 2,
      color: cardColor ?? theme.cardTheme.color,
      shape: theme.cardTheme.shape,
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      child: Padding(
        padding: padding ?? const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (title != null) ...[
              Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, color: titleColor ?? theme.colorScheme.primary, size: 22),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: Text(
                      title,
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600, color: titleColor ?? theme.colorScheme.primary),
                    ),
                  ),
                ],
              ),
              const Divider(height: 20, thickness: 0.5),
            ],
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildTextInfoRow(BuildContext context, String label, String? value, {bool isBoldValue = false}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text('$label:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant))),
          Expanded(flex: 3, child: Text(value?.isNotEmpty == true ? value! : '-', style: theme.textTheme.bodyLarge?.copyWith(fontWeight: isBoldValue ? FontWeight.w600 : FontWeight.normal))),
        ],
      ),
    );
  }

 Widget _buildAddressInfoRow(Map<String, dynamic> recordData) {
    final theme = Theme.of(context);
    String? formattedAddressFromFirestore = recordData['formattedAddress'] as String?;
    final LatLng? accidentLocation = (recordData['latitude'] != null && recordData['longitude'] != null)
        ? LatLng(recordData['latitude'] as double, recordData['longitude'] as double)
        : null;

    // Eğer Firestore'da adres varsa ve daha önce çekilmemişse veya farklıysa
    if (formattedAddressFromFirestore != null && formattedAddressFromFirestore.isNotEmpty) {
      if (_address == null || _address != formattedAddressFromFirestore) {
         // Firestore'daki adresi state'e ata, böylece tekrar çekmeye gerek kalmaz.
         // Bu, widget yeniden build edildiğinde adresin korunmasını sağlar.
         WidgetsBinding.instance.addPostFrameCallback((_) {
            if(mounted) {
                setState(() {
                    _address = formattedAddressFromFirestore;
                    _isFetchingAddress = false;
                    _addressError = null;
                });
            }
         });
      }
      return _buildTextInfoRow(context, 'Kaza Adresi', _address);
    }
    // Firestore'da adres yoksa ama enlem/boylam varsa ve daha önce çekilmemişse
    else if (accidentLocation != null && _address == null && !_isFetchingAddress && _addressError == null) {
        // Adres çekme işlemini burada tetikle.
        // Bu, StreamBuilder'dan veri ilk geldiğinde çalışır.
        // _isFetchingAddress kontrolü sonsuz döngüyü engeller.
        WidgetsBinding.instance.addPostFrameCallback((_) {
             _fetchAddressFromLatLng(accidentLocation.latitude, accidentLocation.longitude);
        });
    }

    // Adres çekiliyorsa yükleme göstergesi
    if (_isFetchingAddress) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text('Kaza Adresi:', style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
            const SizedBox(width: 8),
            const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2)),
            const SizedBox(width: 8),
            Expanded(child: Text("Adres yükleniyor...", style: theme.textTheme.bodySmall)),
          ],
        ),
      );
    }
    // Hata varsa hata mesajı
    if (_addressError != null && _addressError!.isNotEmpty) {
      return _buildTextInfoRow(context, 'Kaza Adresi', _addressError);
    }
    // Başarılı bir şekilde adres çekildiyse veya Firestore'dan geldiyse göster
    if (_address != null && _address!.isNotEmpty) {
      return _buildTextInfoRow(context, 'Kaza Adresi', _address);
    }
    // Hiçbir bilgi yoksa veya enlem/boylam da yoksa
    if (accidentLocation == null) {
        return _buildTextInfoRow(context, 'Kaza Adresi', 'Konum bilgisi bulunamadı.');
    }
    // Eğer adres çekilemediyse ve hata da yoksa, son çare olarak enlem/boylam
    return _buildTextInfoRow(context, 'Kaza Konumu (Enlem/Boylam)', '${accidentLocation.latitude.toStringAsFixed(4)}, ${accidentLocation.longitude.toStringAsFixed(4)}');
  }


  Widget _buildPhotoDisplay(BuildContext context, String? base64Image, List<dynamic>? detections, String partyName) {
    final theme = Theme.of(context);
    if (base64Image == null || base64Image.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text("$partyName için işlenmiş fotoğraf bulunmuyor.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
      );
    }
    try {
      final Uint8List imageBytes = base64Decode(base64Image);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: () {
                showDialog(context: context, builder: (_) => Dialog(backgroundColor: Colors.transparent, child: InteractiveViewer(child: Image.memory(imageBytes))));
            },
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(imageBytes, height: 250, fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image_outlined, size: 100, color: theme.colorScheme.outline),
              ),
            ),
          ),
          if (detections != null && detections.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text("Otomatik Tespit Edilen Hasarlar:", style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            ...detections.map((d) {
              final detectionMap = d as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(left: 8.0, top: 3.0),
                child: Text("• ${detectionMap['label'] ?? 'Bilinmiyor'} (%${((detectionMap['confidence'] ?? 0.0) * 100).toStringAsFixed(0)})", style: theme.textTheme.bodyMedium),
              );
            }).toList(),
          ]
        ],
      );
    } catch (e) {
      print("Base64 decode error for $partyName: $e");
      return Text("$partyName için fotoğraf görüntülenirken hata oluştu.", style: TextStyle(color: theme.colorScheme.error));
    }
  }

  Widget _buildRegionsDisplay(BuildContext context, List<dynamic>? regionNames, String partyName) {
    final theme = Theme.of(context);
    if (regionNames == null || regionNames.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text("$partyName için hasar bölgesi seçilmemiş.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
      );
    }
    Set<CrashRegion> regions = regionNames.map((name) {
      try { return CrashRegion.values.byName(name.toString()); }
      catch(e) { print("Bölge enum parse hatası: $name, Hata: $e"); return null; }
    }).whereType<CrashRegion>().toSet();

    if (regions.isEmpty) {
       return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Text("$partyName için geçerli hasar bölgesi bulunamadı.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic)),
      );
    }

    return Wrap(
      spacing: 8, runSpacing: 6,
      children: regions.map((r) => Chip(
        label: Text(_regionLabel(r)),
        backgroundColor: theme.colorScheme.errorContainer.withOpacity(0.7),
        labelStyle: TextStyle(color: theme.colorScheme.onErrorContainer),
        avatar: Icon(Icons.car_crash_outlined, size: 18, color: theme.colorScheme.onErrorContainer),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      )).toList(),
    );
  }

  Widget _buildPartyInfoSection(
    BuildContext context,
    ThemeData theme,
    Map<String, dynamic> recordData,
    String rolePrefix, // Bu parametre zaten vardı ve doğru olan bu.
    String sectionTitle,
    IconData sectionIcon,
  ) {
    final String? userId = recordData['${rolePrefix}Uid'] as String?;
    final Map<String, dynamic>? vehicleInfo = recordData['${rolePrefix}VehicleInfo'] as Map<String, dynamic>? ?? {};
    final String? notes = recordData['${rolePrefix}Notes'] as String?;
    final List<dynamic>? damageRegions = recordData['${rolePrefix}DamageRegions'] as List<dynamic>?;
    final String? processedPhotoBase64 = recordData['${rolePrefix}ProcessedDamageImageBase64'] as String?;
    final List<dynamic>? detections = recordData['${rolePrefix}DetectionResults'] as List<dynamic>?;
    // DÜZELTME: userRolePrefix yerine rolePrefix kullanıldı
    final Timestamp? submissionTime = recordData['${rolePrefix}LastUpdateTimestamp'] as Timestamp?
        ?? recordData['${rolePrefix}InfoSubmittedTimestamp'] as Timestamp?; // Eski isme de bakabiliriz

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle(context, sectionTitle, sectionIcon, theme.colorScheme.secondary),
        if (userId != null)
          FutureBuilder<String>(
            future: _getUserFullName(userId),
            builder: (context, AsyncSnapshot<String> userSnapshot) {
              if (userSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator(strokeWidth: 2)));
              }
              // Kullanıcının telefon numarasını userDoc'tan (yani _userData Firestore'dan) veya doğrudan recordData'dan almayı dene
              String? userPhone;
              if (_recordData != null && _recordData!['${rolePrefix}UserData'] != null && _recordData!['${rolePrefix}UserData']['telefon'] != null) {
                userPhone = _recordData!['${rolePrefix}UserData']['telefon'] as String?;
              } else if (userSnapshot.data != "Bilinmiyor" && userSnapshot.data != "Kullanıcı Bulunamadı") {
                // Eğer _getUserFullName başarılı olduysa ve _recordData içinde yoksa, Firestore'dan çekmeyi deneyebiliriz
                // ancak bu _getUserFullName içinde zaten yapılmalı. Şimdilik null bırakalım veya "Belirtilmemiş" diyelim.
                // userPhone = "Firestore'dan çekilebilir"; // Veya null
              }


              return _buildInfoCard(
                context: context,
                title: "Sürücü Bilgileri",
                titleIcon: Icons.person_outline_rounded,
                children: [
                  _buildTextInfoRow(context, "Ad Soyad", userSnapshot.data ?? "Yüklenemedi", isBoldValue: true),
                  _buildTextInfoRow(context, "Telefon", userPhone ?? "-"),
                ],
              );
            },
          ),
        const SizedBox(height: 4),
        _buildInfoCard(
          context: context,
          title: "Araç Bilgileri",
          titleIcon: Icons.directions_car_outlined,
          children: [
            _buildTextInfoRow(context, "Marka", vehicleInfo?['brand']?.toString() ?? vehicleInfo?['marka']?.toString()),
            _buildTextInfoRow(context, "Model/Seri", vehicleInfo?['model']?.toString() ?? vehicleInfo?['seri']?.toString()),
            _buildTextInfoRow(context, "Plaka", vehicleInfo?['plate']?.toString() ?? vehicleInfo?['plaka']?.toString(), isBoldValue: true),
            if (vehicleInfo?['modelYili'] != null)
                _buildTextInfoRow(context, "Model Yılı", vehicleInfo?['modelYili']?.toString()),
            if (vehicleInfo?['kullanim'] != null)
                _buildTextInfoRow(context, "Kullanım Şekli", vehicleInfo?['kullanim']?.toString()),
          ],
        ),
        const SizedBox(height: 4),
        _buildInfoCard(
          context: context,
          title: "Seçilen Hasar Bölgeleri",
          titleIcon: Icons.car_crash_outlined,
          children: [_buildRegionsDisplay(context, damageRegions, sectionTitle)],
        ),
        const SizedBox(height: 4),
        _buildInfoCard(
          context: context,
          title: "Sürücü Notları ve Beyanı",
          titleIcon: Icons.edit_note_rounded,
          children: [
            Text(notes?.isNotEmpty == true ? notes! : "Eklenmiş bir not/beyan bulunmuyor.", style: theme.textTheme.bodyLarge?.copyWith(fontStyle: notes?.isNotEmpty == true ? FontStyle.normal : FontStyle.italic, height: 1.5)),
          ],
        ),
        const SizedBox(height: 4),
        if (processedPhotoBase64 != null)
          _buildInfoCard(
            context: context,
            title: "Hasar Fotoğrafı ve Tespitler",
            titleIcon: Icons.image_search_rounded,
            children: [_buildPhotoDisplay(context, processedPhotoBase64, detections, sectionTitle)],
          )
        else
           _buildInfoCard(
            context: context,
            title: "Hasar Fotoğrafı",
            titleIcon: Icons.image_not_supported_outlined,
            children: [Text("$sectionTitle için yüklenmiş bir hasar fotoğrafı bulunmuyor.", style: theme.textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic))],
          ),
        if (submissionTime != null)
           Padding(
             padding: const EdgeInsets.only(top: 10.0, right: 8.0, bottom: 8.0),
             child: Align(
                alignment: Alignment.centerRight,
                child: Text("Bilgi Giriş Zamanı: ${_formatTimestamp(submissionTime, context)}", style: theme.textTheme.bodySmall),
             ),
           ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text("Tutanak Detayı"),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection('records').doc(widget.recordId).snapshots(),
        builder: (context, AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text("Rapor detayı yüklenirken hata: ${snapshot.error}", style: TextStyle(color: theme.colorScheme.error)));
          }
          if (!snapshot.hasData || !snapshot.data!.exists) {
            return const Center(child: Text("Rapor bulunamadı."));
          }

          _recordData = snapshot.data!.data()!; // State'e veriyi ata

          final String? pdfTitleFromRecord = _recordData!['title'] as String?;
          final String? pdfUrl = _recordData!['pdfUrl'] as String?;
          final String status = _recordData!['status'] as String? ?? "Bilinmiyor";
          final Timestamp? createdAt = _recordData!['createdAt'] as Timestamp?;
          final Timestamp? finalizedAt = _recordData!['reportFinalizedTimestamp'] as Timestamp?;
          final LatLng? accidentLocation = (_recordData!['latitude'] != null && _recordData!['longitude'] != null)
              ? LatLng(_recordData!['latitude'] as double, _recordData!['longitude'] as double)
              : null;

          // Adres çekme işlemini burada, veri geldikten sonra tetikleyebiliriz.
          // Sadece Firestore'da adres yoksa ve enlem/boylam varsa çek.
          String? formattedAddressFromFirestore = _recordData!['formattedAddress'] as String?;
          if (formattedAddressFromFirestore == null && accidentLocation != null && _address == null && !_isFetchingAddress) {
             WidgetsBinding.instance.addPostFrameCallback((_) {
                 _fetchAddressFromLatLng(accidentLocation.latitude, accidentLocation.longitude);
             });
          } else if (formattedAddressFromFirestore != null && _address == null) {
            // Firestore'dan gelen adresi doğrudan state'e ata
            WidgetsBinding.instance.addPostFrameCallback((_) {
                if(mounted) {
                    setState(() {
                        _address = formattedAddressFromFirestore;
                        _isFetchingAddress = false; // Zaten çekilmiş, tekrar çekme
                    });
                }
            });
          }


          return SingleChildScrollView(
            padding: const EdgeInsets.all(12.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoCard(
                  context: context,
                  title: "Genel Tutanak Bilgileri",
                  titleIcon: Icons.article_outlined,
                  titleColor: theme.colorScheme.onSurface,
                  cardColor: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                  children: [
                    _buildTextInfoRow(context, "Tutanak ID", widget.recordId, isBoldValue: true),
                    _buildTextInfoRow(context, "Durum", status, isBoldValue: true),
                    if (createdAt != null)
                      _buildTextInfoRow(context, "Oluşturulma T.", _formatTimestamp(createdAt, context)),
                    if (finalizedAt != null)
                      _buildTextInfoRow(context, "Tamamlanma T.", _formatTimestamp(finalizedAt, context)),
                  ]
                ),

                if (pdfUrl != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Card(
                      elevation: 1,
                      color: theme.colorScheme.tertiaryContainer,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        leading: Icon(Icons.picture_as_pdf_rounded, color: theme.colorScheme.onTertiaryContainer, size: 32),
                        title: Text(pdfTitleFromRecord ?? "Tutanak PDF", style: TextStyle(fontWeight: FontWeight.bold, color: theme.colorScheme.onTertiaryContainer)),
                        subtitle: Text("Oluşturulan PDF'i Görüntüle", style: TextStyle(color: theme.colorScheme.onTertiaryContainer.withOpacity(0.9))),
                        trailing: Icon(Icons.arrow_forward_ios_rounded, color: theme.colorScheme.onTertiaryContainer.withOpacity(0.7)),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => PdfViewerPage(pdfUrl: pdfUrl, title: pdfTitleFromRecord ?? "Tutanak PDF"),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                if (accidentLocation != null)
                  _buildInfoCard(
                    context: context,
                    title: "Kaza Konumu",
                    titleIcon: Icons.map_rounded,
                    titleColor: theme.colorScheme.onSurface,
                    cardColor: theme.colorScheme.surfaceVariant.withOpacity(0.7),
                    padding: const EdgeInsets.fromLTRB(0, 16, 0, 0),
                    children: [
                      SizedBox(
                        height: 220,
                        child: GoogleMap(
                          initialCameraPosition: CameraPosition(target: accidentLocation, zoom: 16.5),
                          markers: {Marker(markerId: MarkerId(widget.recordId), position: accidentLocation, infoWindow: const InfoWindow(title: "Kaza Yeri"))},
                          scrollGesturesEnabled: true,
                          zoomGesturesEnabled: true,
                          mapToolbarEnabled: true,
                        ),
                      ),
                       Padding(
                         padding: const EdgeInsets.fromLTRB(16.0, 12.0, 16.0, 16.0),
                         child: Column(
                           children: [
                              _buildAddressInfoRow(_recordData!), // Adres satırı
                           ],
                         ),
                       ),
                    ]
                  )
                else
                  _buildInfoCard(
                    context: context,
                    title: "Kaza Konumu",
                    titleIcon: Icons.map_rounded,
                    children: [_buildTextInfoRow(context, 'Kaza Adresi', 'Konum bilgisi kaydedilmemiş.')]
                  ),


                _buildPartyInfoSection(context, theme, _recordData!, "creator", "Tutanak Oluşturan Taraf", Icons.person_pin_circle_rounded),

                const SizedBox(height: 10),
                Divider(thickness: 1, color: theme.dividerColor.withOpacity(0.6), height: 30, indent: 20, endIndent: 20),
                const SizedBox(height: 10),

                _buildPartyInfoSection(context, theme, _recordData!, "joiner", "Tutanağa Katılan Taraf", Icons.group_rounded),

                const SizedBox(height: 20),
              ],
            ),
          );
        },
      ),
    );
  }
}