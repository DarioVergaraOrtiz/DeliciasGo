import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import '../main.dart'; // Importar la llave global

class NotificationService {
  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Inicializar notificaciones
  Future<void> initNotifications() async {
    // Solicitar permisos (obligatorio en iOS y Android 13+)
    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) {
        print('Usuario otorgó permiso para notificaciones');
      }
      
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('Mensaje recibido en primer plano: ${message.notification?.title}');
        }
        
        // Mostrar aviso dentro de la app (Plan Blaze)
        if (message.notification != null) {
          scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(message.notification!.title ?? 'Notificación', 
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                  Text(message.notification!.body ?? '', 
                    style: const TextStyle(color: Colors.white70, fontSize: 12)),
                ],
              ),
              backgroundColor: const Color(0xFFFF8C00), // Naranja DeliciasGo
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 4),
              // Ajuste para que aparezca arriba
              margin: EdgeInsets.only(
                bottom: MediaQuery.of(scaffoldMessengerKey.currentContext!).size.height - 160,
                left: 20,
                right: 20,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      });

      // Manejar clics en notificaciones cuando la app está en segundo plano pero abierta
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        if (kDebugMode) {
          print('App abierta desde notificación: ${message.data}');
        }
      });
    }
  }

  // Obtener y guardar el token del dispositivo
  Future<void> saveToken(String userId, String role) async {
    String? token = await _fcm.getToken();
    
    if (token != null) {
      if (kDebugMode) {
        print('-----------------------------------------');
        print('TOKEN PARA PRUEBAS: $token');
        print('-----------------------------------------');
      }
      await _db.collection(role == 'driver' ? 'drivers' : 'users').doc(userId).update({
        'fcmToken': token,
        'lastTokenUpdate': FieldValue.serverTimestamp(),
      });
    }
  }

  // Eliminar token (útil al cerrar sesión)
  Future<void> deleteToken(String userId, String role) async {
    await _db.collection(role == 'driver' ? 'drivers' : 'users').doc(userId).update({
      'fcmToken': FieldValue.delete(),
    });
  }
}
