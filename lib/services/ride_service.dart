import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:latlong2/latlong.dart';

class RideService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Crear una solicitud de viaje
  Future<String?> createRideRequest({
    required String clientId,
    required String clientName,
    required String clientPhone,
    required LatLng pickupLocation,
    required LatLng destinationLocation,
    required double estimatedPrice,
  }) async {
    try {
      final docRef = await _db.collection('ride_requests').add({
        'clientId': clientId,
        'clientName': clientName,
        'clientPhone': clientPhone,
        'pickupLat': pickupLocation.latitude,
        'pickupLng': pickupLocation.longitude,
        'destinationLat': destinationLocation.latitude,
        'destinationLng': destinationLocation.longitude,
        'estimatedPrice': estimatedPrice,
        'status': 'searching',
        'createdAt': FieldValue.serverTimestamp(),
        'driverId': null,
      });
      return docRef.id;
    } catch (e) {
      print("Error creando viaje: $e");
      return null;
    }
  }

  // Escuchar cambios en el viaje
  Stream<DocumentSnapshot> streamRideRequest(String rideId) {
    return _db.collection('ride_requests').doc(rideId).snapshots();
  }

  // Escuchar solicitudes pendientes
  Stream<QuerySnapshot> getPendingRequests() {
    return _db.collection('ride_requests')
      .where('status', isEqualTo: 'searching')
      .snapshots();
  }

  // Aceptar un viaje
  Future<void> acceptRide(String rideId, String driverId, String driverName, String driverPhone) async {
    await _db.collection('ride_requests').doc(rideId).update({
      'status': 'accepted',
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  // Nueva contraoferta
  Future<void> counterOffer(String rideId, double newPrice, String driverId, String driverName, String driverPhone) async {
    await _db.collection('ride_requests').doc(rideId).update({
      'status': 'counter_offer',
      'estimatedPrice': newPrice,
      'driverId': driverId,
      'driverName': driverName,
      'driverPhone': driverPhone,
    });
  }

  Future<void> confirmCounterOffer(String rideId) async {
    await _db.collection('ride_requests').doc(rideId).update({
      'status': 'accepted',
      'acceptedAt': FieldValue.serverTimestamp(),
    });
  }

  // Actualizar ubicación del conductor en el viaje activo
  Future<void> updateDriverLocation(String rideId, LatLng location) async {
    await _db.collection('ride_requests').doc(rideId).update({
      'driverLat': location.latitude,
      'driverLng': location.longitude,
      'lastUpdate': FieldValue.serverTimestamp(),
    });
  }

  // NUEVO: Actualizar ubicación global del conductor para el "Radar"
  Future<void> updateGlobalDriverLocation(String driverId, LatLng location, bool isOnline) async {
    await _db.collection('drivers').doc(driverId).update({
      'lat': location.latitude,
      'lng': location.longitude,
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  // NUEVO: Escuchar todos los conductores online para el cliente
  Stream<QuerySnapshot> getOnlineDrivers() {
    return _db.collection('drivers')
      .where('isOnline', isEqualTo: true)
      .snapshots();
  }

  // Actualizar estado general
  Future<void> updateRideStatus(String rideId, String status) async {
    await _db.collection('ride_requests').doc(rideId).update({
      'status': status,
    });
  }

  // Método específico para cancelar/finalizar
  Future<void> cancelRide(String rideId) async {
    await _db.collection('ride_requests').doc(rideId).update({
      'status': 'cancelled',
    });
  }

  // Guardar calificación
  Future<void> submitRating({
    required String rideId,
    required String ratedUserId,
    required String raterUserId,
    required double rating,
    required String comment,
  }) async {
    await _db.collection('ratings').add({
      'rideId': rideId,
      'ratedUserId': ratedUserId,
      'raterUserId': raterUserId,
      'rating': rating,
      'comment': comment,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
