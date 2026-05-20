import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import 'registration_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../../services/user_service.dart';

class OtpScreen extends StatefulWidget {
  final String verificationId;
  final String phoneNumber;
  final String role;
  final Map<String, dynamic>? existingUserData; // Datos del usuario si ya existe

  const OtpScreen({
    super.key,
    required this.verificationId,
    required this.phoneNumber,
    required this.role,
    this.existingUserData,
  });

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> {
  final TextEditingController _codeController = TextEditingController();
  final AuthService _authService = AuthService.instance;
  bool _isLoading = false;

  bool get _isReturningUser => widget.existingUserData != null;

  void _verifyCode() async {
    final code = _codeController.text.trim();
    if (code.length != 6) {
      _showError("Ingresa el código de 6 dígitos");
      return;
    }

    setState(() => _isLoading = true);

    final userCredential = await _authService.verifyCode(widget.verificationId, code);

    if (userCredential != null) {
      setState(() => _isLoading = false);
      if (!mounted) return;

      if (_isReturningUser) {
        // USUARIO EXISTENTE
        final String existingRole = widget.existingUserData!['role'];
        final bool isDifferentRole = widget.existingUserData!['isDifferentRole'] == true;

        if (isDifferentRole) {
          // TIENE OTRO ROL PERO NO EL SOLICITADO → Al registro del nuevo rol
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => RegistrationScreen(role: widget.role)),
            (route) => false,
          );
        } else {
          // YA TIENE EL ROL SOLICITADO → Directo al mapa
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(role: existingRole)),
            (route) => false,
          );
        }
      } else {
        // USUARIO COMPLETAMENTE NUEVO (no se encontró por teléfono antes del SMS)
        // Verificar por si acaso en Firestore (doble check por UID)
        final uid = userCredential.user!.uid;
        final driverData = await UserService().getUserData(uid, 'driver');
        final clientData = await UserService().getUserData(uid, 'client');

        if (!mounted) return;

        if (widget.role == 'driver' && driverData != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(role: 'driver')),
            (route) => false,
          );
        } else if (widget.role == 'client' && clientData != null) {
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(role: 'client')),
            (route) => false,
          );
        } else {
          // No existe para el rol solicitado → Al registro
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(builder: (context) => RegistrationScreen(role: widget.role)),
            (route) => false,
          );
        }
      }
    } else {
      setState(() => _isLoading = false);
      _showError("Código inválido.");
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D2D44),
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, iconTheme: const IconThemeData(color: Colors.white)),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'DELICIAS',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        letterSpacing: 4,
                      ),
                    ),
                    TextSpan(
                      text: 'GO',
                      style: GoogleFonts.outfit(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF8C00),
                        letterSpacing: 2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 30),

              // Título dinámico
              if (_isReturningUser) ...[
                const Icon(Icons.lock_open, color: Colors.greenAccent, size: 40),
                const SizedBox(height: 15),
                Text(
                  '¡Casi listo, ${widget.existingUserData!['name']}!',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white),
                ),
                const SizedBox(height: 10),
                Text(
                  'Ingresa el código enviado a ${widget.phoneNumber}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60),
                ),
              ] else ...[
                Text('Verificación', style: GoogleFonts.outfit(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white)),
                const SizedBox(height: 10),
                Text('Ingresa el código enviado a ${widget.phoneNumber}', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white60)),
              ],

              const SizedBox(height: 40),
              TextField(
                controller: _codeController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 10),
                decoration: InputDecoration(
                  counterText: "", 
                  filled: true, 
                  fillColor: Colors.white.withOpacity(0.05), 
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: const BorderSide(color: Colors.white10))
                ),
              ),
              const SizedBox(height: 30),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _verifyCode,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isReturningUser ? Colors.green : const Color(0xFFFF8C00),
                    foregroundColor: Colors.white, 
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                    elevation: 5,
                  ),
                  child: _isLoading 
                    ? const CircularProgressIndicator(color: Colors.white) 
                    : Text(
                        _isReturningUser ? 'ENTRAR' : 'VERIFICAR', 
                        style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                      ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
