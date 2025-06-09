// Firebase Functions v2 SDK'sından gerekli modülleri import ediyoruz
const {onDocumentUpdated} = require("firebase-functions/v2/firestore");
const {setGlobalOptions} = require("firebase-functions/v2");

const admin = require("firebase-admin");
const axios = require("axios");

// SDK'yı başlat ve tüm fonksiyonlar için global olarak bölgeyi ayarla
admin.initializeApp();
setGlobalOptions({region: "europe-west1"});

const db = admin.firestore();

// Python sunucunuzun IP adresi ve portu
const AI_SERVER_URL = "http://100.71.209.113:6001/generate_ai_pdf_report";

/**
 * Gerekli tüm kullanıcı ve araç verilerini Firestore'dan çeker.
 */
async function getFullPartyDetails(userId, vehicleId) {
  if (!userId || !vehicleId) {
    return {userData: null, vehicleData: null};
  }
  const userPromise = db.collection("users").doc(userId).get();
  const vehiclePromise = db.collection("users").doc(userId).collection("vehicles").doc(vehicleId).get();

  const [userSnap, vehicleSnap] = await Promise.all([userPromise, vehiclePromise]);

  return {
    userData: userSnap.exists ? userSnap.data() : null,
    vehicleData: vehicleSnap.exists ? vehicleSnap.data() : null,
  };
}

// v2 SDK'sının doğru yazım stiliyle fonksiyonu export ediyoruz
exports.generateAiReportOnCompletion = onDocumentUpdated("records/{recordId}", async (event) => {
  const recordId = event.params.recordId;
  const dataAfter = event.data.after.data();
  const dataBefore = event.data.before.data();

  if (dataAfter.status !== "all_data_submitted" || dataBefore.status === "all_data_submitted" || dataAfter.aiReportStatus === "Processing" || dataAfter.aiReportStatus === "Completed") {
    console.log(`[${recordId}] Tetikleme koşulları sağlanmadı. Status: ${dataAfter.status}, AI Status: ${dataAfter.aiReportStatus}. Çıkılıyor.`);
    return null;
  }

  console.log(`[${recordId}] AI Raporu oluşturma süreci başlatıldı.`);

  try {
    await event.data.after.ref.update({aiReportStatus: "Processing"});

    const creatorDetails = await getFullPartyDetails(dataAfter.creatorUid, dataAfter.creatorVehicleId);
    const joinerDetails = await getFullPartyDetails(dataAfter.joinerUid, dataAfter.joinerVehicleId);

    const payload = {
      ...dataAfter,
      creatorUserData: creatorDetails.userData,
      creatorVehicleInfo: creatorDetails.vehicleData,
      joinerUserData: joinerDetails.userData,
      joinerVehicleInfo: joinerDetails.vehicleData,
      recordId: recordId,
      kazaTarihi: dataAfter.kazaTimestamp?.toDate().toLocaleDateString("tr-TR"),
      kazaSaati: dataAfter.kazaTimestamp?.toDate().toLocaleTimeString("tr-TR", {hour: "2-digit", minute: "2-digit"}),
    };

    console.log(`[${recordId}] Python sunucusuna istek gönderiliyor...`);
    const response = await axios.post(AI_SERVER_URL, payload, {
      responseType: "arraybuffer",
      timeout: 120000,
    });

    if (response.status !== 200) {
      throw new Error(`AI sunucusu hatası: ${response.status} - ${response.statusText}`);
    }

    console.log(`[${recordId}] PDF verisi sunucudan alındı. Firebase Storage'a yükleniyor...`);
    const pdfBuffer = Buffer.from(response.data);
    const bucket = admin.storage().bucket();
    const filePath = `ai_reports/${recordId}.pdf`;
    const file = bucket.file(filePath);

    await file.save(pdfBuffer, {
      metadata: {
        contentType: "application/pdf",
      },
    });

    const downloadUrl = await file.getSignedUrl({
      action: "read",
      expires: "03-09-2491",
    });

    console.log(`[${recordId}] PDF yüklendi. URL Firestore'a kaydediliyor: ${downloadUrl[0]}`);
    return event.data.after.ref.update({
      aiReportPdfUrl: downloadUrl[0],
      aiReportStatus: "Completed",
    });
  } catch (error) {
    console.error(`[${recordId}] AI Raporu oluşturulurken hata oluştu:`, error);
    return event.data.after.ref.update({
      aiReportStatus: "Failed",
      aiReportError: error.message || "Bilinmeyen bir hata oluştu.",
    });
  }
});
