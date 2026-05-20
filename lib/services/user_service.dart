import 'package:cloud_firestore/cloud_firestore.dart';

class UserService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Guardar datos del usuario (Cliente o Conductor)
  Future<void> saveUserData({
    required String uid,
    required String role,
    required Map<String, dynamic> data,
  }) async {
    final collection = role == 'driver' ? 'drivers' : 'users';
    await _db.collection(collection).doc(uid).set({
      ...data,
      'uid': uid,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
      'isApproved': role == 'driver' ? false : true, // Los conductores necesitan aprobación
    });
  }

  // Verificar si el usuario ya existe
  Future<Map<String, dynamic>?> getUserData(String uid, String role) async {
    final collection = role == 'driver' ? 'drivers' : 'users';
    final doc = await _db.collection(collection).doc(uid).get();
    return doc.data();
  }

  /// Busca un usuario por número de teléfono en ambas colecciones.
  /// Retorna el primer resultado encontrado con nombre y rol, o null si no existe.
  Future<Map<String, dynamic>?> findUserByPhone(String phoneNumber) async {
    try {
      // Buscar en conductores
      final driverQuery = await _db.collection('drivers')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      if (driverQuery.docs.isNotEmpty) {
        final data = driverQuery.docs.first.data();
        return {'role': 'driver', 'name': data['name'] ?? 'Conductor', ...data};
      }

      // Buscar en clientes
      final clientQuery = await _db.collection('users')
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      if (clientQuery.docs.isNotEmpty) {
        final data = clientQuery.docs.first.data();
        return {'role': 'client', 'name': data['name'] ?? 'Cliente', ...data};
      }

      return null; // No existe
    } catch (e) {
      print("Error buscando usuario por teléfono: $e");
      return null;
    }
  }

  /// Busca un usuario por teléfono en una colección específica.
  Future<Map<String, dynamic>?> findUserInCollectionByPhone(String collection, String phoneNumber) async {
    try {
      final query = await _db.collection(collection)
          .where('phone', isEqualTo: phoneNumber)
          .limit(1)
          .get();
      if (query.docs.isNotEmpty) {
        return query.docs.first.data();
      }
      return null;
    } catch (e) {
      print("Error buscando en $collection: $e");
      return null;
    }
  }

  /// Busca al usuario en ambas colecciones. Devuelve una lista de roles encontrados.
  /// Ejemplo: [{'role': 'driver', 'name': 'Juan', ...}]
  Future<List<Map<String, dynamic>>> findAllRoles(String uid) async {
    final List<Map<String, dynamic>> roles = [];

    final driverDoc = await _db.collection('drivers').doc(uid).get();
    if (driverDoc.exists && driverDoc.data() != null) {
      roles.add({'role': 'driver', ...driverDoc.data()!});
    }

    final userDoc = await _db.collection('users').doc(uid).get();
    if (userDoc.exists && userDoc.data() != null) {
      roles.add({'role': 'client', ...userDoc.data()!});
    }

    return roles;
  }
}
