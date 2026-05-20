import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'phone_login_screen.dart';
import 'registration_screen.dart';
import '../../home/screens/home_screen.dart';
import '../../../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  final UserService _userService = UserService();
  Map<String, bool> _registeredRoles = {'client': false, 'driver': false};
  bool _isLoadingRoles = true;

  @override
  void initState() {
    super.initState();
    _checkRegisteredRoles();
  }

  void _checkRegisteredRoles() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final roles = await _userService.findAllRoles(user.uid);
      final Map<String, bool> status = {'client': false, 'driver': false};
      for (var r in roles) {
        if (r['role'] == 'client') status['client'] = true;
        if (r['role'] == 'driver') status['driver'] = true;
      }
      if (mounted) {
        setState(() {
          _registeredRoles = status;
          _isLoadingRoles = false;
        });
      }
    } else {
      if (mounted) setState(() => _isLoadingRoles = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    void handleRoleSelection(String role) async {
      final user = FirebaseAuth.instance.currentUser;
      
      if (user != null) {
        // Mostrar un cargando mientras revisamos la base de datos
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => const Center(child: CircularProgressIndicator(color: Color(0xFFFFB703))),
        );

        // Verificar si el usuario ya existe en Firestore para ese rol
        final userData = await _userService.getUserData(user.uid, role);
        
        if (!context.mounted) return;
        Navigator.pop(context); // Cerrar el cargando

        if (userData != null) {
          // YA EXISTE: Al mapa directo
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => HomeScreen(role: role)),
          );
        } else {
          // NO EXISTE: Al registro
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RegistrationScreen(role: role)),
          );
        }
      } else {
        // No hay sesión, a login primero
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => PhoneLoginScreen(role: role)),
        );
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF1D2D44),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  children: [
                    TextSpan(
                      text: 'DELICIAS',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.w200,
                        color: Colors.white,
                        letterSpacing: 6,
                      ),
                    ),
                    TextSpan(
                      text: 'GO',
                      style: GoogleFonts.outfit(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFFF8C00),
                        letterSpacing: 3,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'ELIGE TU ROL',
                style: GoogleFonts.outfit(color: Colors.white38, fontSize: 12, letterSpacing: 4),
              ),
              const SizedBox(height: 50),
              
              _buildRoleCard(
                context,
                'Pasajero',
                'Quiero pedir una moto',
                Icons.person,
                const Color(0xFFFF8C00), 
                _registeredRoles['client'] ?? false,
                () => handleRoleSelection('client'),
              ),
              
              const SizedBox(height: 20),
              
              _buildRoleCard(
                context,
                'Conductor',
                'Quiero ganar dinero',
                Icons.motorcycle,
                const Color(0xFFFF8C00), 
                _registeredRoles['driver'] ?? false,
                () => handleRoleSelection('driver'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleCard(BuildContext context, String title, String subtitle, IconData icon, Color color, bool isRegistered, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: const Color(0xFF1D2D44), // Azul Noche
          borderRadius: BorderRadius.circular(25),
          border: Border.all(
            color: isRegistered ? Colors.greenAccent.withOpacity(0.5) : color.withOpacity(0.3), 
            width: 2
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    if (isRegistered) ...[
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.greenAccent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'Ya registrado',
                          style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  subtitle,
                  style: const TextStyle(color: Colors.white60, fontSize: 13),
                ),
              ],
            ),
            const Spacer(),
            Icon(isRegistered ? Icons.check_circle : Icons.arrow_forward, color: isRegistered ? Colors.greenAccent : color, size: 20),
          ],
        ),
      ),
    );
  }
}
