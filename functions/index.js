const { onDocumentCreated } = require("firebase-functions/v2/firestore");
const admin = require("firebase-admin");

admin.initializeApp();

// Función v2 para detectar nuevos viajes
exports.notifyDriversNewRide = onDocumentCreated("ride_requests/{rideId}", async (event) => {
    const snap = event.data;
    if (!snap) {
        console.log("No hay datos en el evento");
        return null;
    }

    const rideData = snap.data();
    const rideId = event.params.rideId;

    console.log(`Nuevo viaje detectado (v2): ${rideId}`);

    // 1. Obtener todos los conductores que tengan un Token
    const driversSnapshot = await admin.firestore().collection("drivers").get();

    const tokens = [];
    driversSnapshot.forEach(doc => {
        const data = doc.data();
        if (data.fcmToken) {
            tokens.push(data.fcmToken); // Corregido: .push() en lugar de .add()
        }
    });

    if (tokens.length === 0) {
        console.log("No hay conductores con tokens.");
        return null;
    }

    // 2. Configurar el mensaje
    const message = {
        notification: {
            title: "¡Nueva solicitud de viaje! 🚨",
            body: `Un pasajero cerca de ti necesita un viaje por $${rideData.estimatedPrice}.`,
        },
        android: {
            priority: "high",
            notification: {
                sound: "default",
                clickAction: "FLUTTER_NOTIFICATION_CLICK",
                priority: "high",
                channelId: "high_importance_channel", // Necesario para Android 8+
            },
        },
        data: {
            rideId: rideId,
            type: "NEW_RIDE"
        },
        tokens: tokens,
    };

    // 3. Enviar las notificaciones (Multicast v2)
    try {
        const response = await admin.messaging().sendEachForMulticast(message);
        console.log(`Notificaciones enviadas con éxito: ${response.successCount}`);
    } catch (error) {
        console.error("Error enviando notificaciones:", error);
    }

    return null;
});
