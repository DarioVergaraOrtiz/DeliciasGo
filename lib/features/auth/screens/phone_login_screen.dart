import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/auth_service.dart';
import '../../../services/user_service.dart';
import 'otp_screen.dart';

class PhoneLoginScreen extends StatefulWidget {
  final String role;
  const PhoneLoginScreen({super.key, required this.role});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService.instance;
  final UserService _userService = UserService();
  bool _isLoading = false;

  // Datos del usuario existente (si lo encontramos en Firestore)
  Map<String, dynamic>? _existingUser;
  bool _checkedNumber = false;

  /// Paso 1: Verificar si el número ya existe en la base de datos
  void _checkNumber() async {
    String phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');
    
    if (phone.isEmpty) {
      _showError("Ingresa tu número de celular");
      return;
    }

    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    final fullPhone = '+593$phone';

    setState(() => _isLoading = true);

    // Buscar en ambas colecciones
    final driverDoc = await _userService.findUserInCollectionByPhone('drivers', fullPhone);
    final clientDoc = await _userService.findUserInCollectionByPhone('users', fullPhone);

    setState(() {
      _isLoading = false;
      _checkedNumber = true;
      
      // Priorizar el rol que el usuario solicitó inicialmente
      if (widget.role == 'driver' && driverDoc != null) {
        _existingUser = {'role': 'driver', ...driverDoc};
      } else if (widget.role == 'client' && clientDoc != null) {
        _existingUser = {'role': 'client', ...clientDoc};
      } else {
        // Si no existe en el rol solicitado, pero existe en el otro
        if (driverDoc != null) {
          _existingUser = {'role': 'driver', ...driverDoc, 'isDifferentRole': true};
        } else if (clientDoc != null) {
          _existingUser = {'role': 'client', ...clientDoc, 'isDifferentRole': true};
        } else {
          _existingUser = null;
        }
      }
    });

    if (_existingUser != null) {
      if (_existingUser!['isDifferentRole'] == true) {
        _showSuccess("¡Hola! Vemos que ya eres ${_existingUser!['role'] == 'driver' ? 'Conductor' : 'Pasajero'}.");
      } else {
        _showSuccess("¡Bienvenido de vuelta, ${_existingUser!['name']}!");
      }
    }
  }

  /// Paso 2: Enviar el código SMS (tanto para nuevos como existentes)
  void _sendCode() async {
    String phone = _phoneController.text.replaceAll(RegExp(r'[^\d]'), '');

    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }

    final fullPhone = '+593$phone';

    setState(() => _isLoading = true);
    
    bool exists = (await _userService.findUserByPhone(fullPhone)) != null;

    if (exists) {
      _showSuccess("¡Hola de nuevo! Te enviamos el código de acceso.");
    }
    
    await AuthService.instance.verifyPhoneNumber(
      phoneNumber: fullPhone,
      onCodeSent: (verificationId) {
        setState(() => _isLoading = false);
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => OtpScreen(
              verificationId: verificationId,
              phoneNumber: fullPhone,
              role: widget.role,
            ),
          ),
        );
      },
      onError: (errorMessage) {
        setState(() => _isLoading = false);
        _showError(errorMessage);
      },
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.redAccent),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFFF8C00)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isReturningUser = _existingUser != null;

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
              const SizedBox(height: 40),

              // Título dinámico según si es usuario existente o nuevo
              if (isReturningUser) ...[
                const Icon(Icons.waving_hand, color: Color(0xFFFF8C00), size: 40),
                const SizedBox(height: 15),
                Text(
                  '¡Hola de nuevo,',
                  style: GoogleFonts.outfit(fontSize: 22, color: Colors.white70),
                ),
                Text(
                  '${_existingUser!['name']}!',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF8C00),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _existingUser!['isDifferentRole'] == true
                    ? '¿Quieres registrarte también como ${widget.role == 'driver' ? 'Conductor' : 'Pasajero'}?'
                    : 'Verifica tu número para continuar.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(color: Colors.white60, fontSize: 14),
                ),
              ] else ...[
                Text(
                  'Tu número',
                  style: GoogleFonts.outfit(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFFF8C00),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _checkedNumber 
                    ? 'Número nuevo. Te enviaremos un código de verificación.'
                    : 'Ingresa tu número para comenzar.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60),
                ),
              ],

              const SizedBox(height: 40),
              TextField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white, fontSize: 18),
                enabled: !isReturningUser, // Bloquear campo si ya se encontró al usuario
                onChanged: (_) {
                  // Si editan el número, resetear la verificación
                  if (_checkedNumber) {
                    setState(() {
                      _checkedNumber = false;
                      _existingUser = null;
                    });
                  }
                },
                decoration: InputDecoration(
                  hintText: '096 219 4290',
                  hintStyle: const TextStyle(color: Colors.white24),
                  filled: true,
                  fillColor: Colors.white.withOpacity(0.05),
                  prefixIcon: const Icon(Icons.phone, color: Color(0xFFFF8C00)),
                  prefixText: '+593 ',
                  prefixStyle: const TextStyle(color: Color(0xFFFF8C00), fontWeight: FontWeight.bold, fontSize: 18),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(15),
                    borderSide: const BorderSide(color: Colors.white10),
                  ),
                  // Indicador visual si el usuario fue encontrado
                  suffixIcon: isReturningUser 
                    ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 28) 
                    : null,
                ),
              ),

              const SizedBox(height: 30),

              // Botón dinámico según el estado
              if (!_checkedNumber) ...[
                // PASO 1: Botón "VERIFICAR NÚMERO"
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _checkNumber,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('VERIFICAR NÚMERO', style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  ),
                ),
              ] else ...[
                // PASO 2: Botón "ENVIAR CÓDIGO" o "INICIAR SESIÓN"
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _sendCode,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isReturningUser ? Colors.green : const Color(0xFFFF8C00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          isReturningUser ? 'INICIAR SESIÓN' : 'ENVIAR CÓDIGO',
                          style: const TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
                        ),
                  ),
                ),

                // Botón para cambiar número si se encontró al usuario equivocado
                if (isReturningUser)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _checkedNumber = false;
                        _existingUser = null;
                        _phoneController.clear();
                      });
                    },
                    child: const Text('Usar otro número', style: TextStyle(color: Colors.white54)),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
