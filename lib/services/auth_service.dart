import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  // Constructor privado para Singleton
  AuthService._internal();
  
  // La instancia única
  static final AuthService instance = AuthService._internal();
  
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Enviar código SMS
  Future<void> verifyPhoneNumber({
    required String phoneNumber,
    required Function(String) onCodeSent,
    required Function(String) onError,
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (PhoneAuthCredential credential) async {
          await _auth.signInWithCredential(credential);
        },
        verificationFailed: (FirebaseAuthException e) {
          String errorMessage = "Error de autenticación";
          
          // Diagnóstico detallado basado en el código de error
          switch (e.code) {
            case 'too-many-requests':
              errorMessage = "Número bloqueado temporalmente por demasiados intentos. Intenta mañana.";
              break;
            case 'invalid-phone-number':
              errorMessage = "El número de teléfono no es válido.";
              break;
            case 'quota-exceeded':
              errorMessage = "Se ha excedido la cuota de SMS. Contacta al administrador.";
              break;
            case 'app-not-authorized':
              errorMessage = "Error interno: La app no está autorizada (Verificar SHA-256).";
              break;
            default:
              errorMessage = e.message ?? "Error desconocido";
          }
          
          print("Firebase Auth Error (${e.code}): ${e.message}");
          onError(errorMessage);
        },
        codeSent: (String verificationId, int? resendToken) {
          onCodeSent(verificationId);
        },
        codeAutoRetrievalTimeout: (String verificationId) {},
      );
    } catch (e) {
      print("Error general verifyPhoneNumber: $e");
      onError("Error inesperado: ${e.toString()}");
    }
  }

  // Verificar el código (recibe 2 argumentos)
  Future<UserCredential?> verifyCode(String verificationId, String smsCode) async {
    try {
      PhoneAuthCredential credential = PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: smsCode,
      );
      return await _auth.signInWithCredential(credential);
    } catch (e) {
      print("Error verifyCode: $e");
      return null;
    }
  }

  User? get currentUser => _auth.currentUser;
  Future<void> signOut() => _auth.signOut();
}
