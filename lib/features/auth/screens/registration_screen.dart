import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../services/user_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../home/screens/home_screen.dart';

class RegistrationScreen extends StatefulWidget {
  final String role;
  
  const RegistrationScreen({super.key, required this.role});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final UserService _userService = UserService();
  
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _whatsappController = TextEditingController();
  
  final TextEditingController _plateController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _colorController = TextEditingController();

  bool _isLoading = false;
  Map<String, dynamic>? _otherRoleData;

  @override
  void initState() {
    super.initState();
    _checkOtherRole();
  }

  void _checkOtherRole() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final otherRole = widget.role == 'driver' ? 'client' : 'driver';
      final data = await _userService.getUserData(user.uid, otherRole);
      if (mounted && data != null) {
        setState(() {
          _otherRoleData = data;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDriver = widget.role == 'driver';

    return Scaffold(
      backgroundColor: const Color(0xFF1D2D44), // Azul Noche
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('Completa tu Perfil', style: GoogleFonts.outfit(color: const Color(0xFFFF8C00), fontWeight: FontWeight.bold)),
        centerTitle: true,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              if (_otherRoleData != null) ...[
                Container(
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFF8C00).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: const Color(0xFFFF8C00).withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.stars, color: Color(0xFFFF8C00)),
                      const SizedBox(width: 15),
                      Expanded(
                        child: Text(
                          '¡Hola ${_otherRoleData!['name']}! Vemos que ya eres ${_otherRoleData!['role'] == 'driver' ? 'Conductor' : 'Pasajero'}. Completa este perfil para ser ambos.',
                          style: GoogleFonts.outfit(color: Colors.white, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 25),
              ],
              _buildTextField(
                controller: _nameController,
                label: 'Nombre Completo',
                icon: Icons.person_outline,
                validator: (v) => v!.isEmpty ? 'Ingresa tu nombre' : null,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _whatsappController,
                label: 'WhatsApp',
                icon: Icons.chat_bubble_outline,
                keyboardType: TextInputType.phone,
                validator: (v) => v!.isEmpty ? 'Ingresa tu WhatsApp' : null,
              ),
              
              if (isDriver) ...[
                const SizedBox(height: 30),
                const Divider(color: Colors.white24),
                const SizedBox(height: 10),
                Text(
                  'Datos de la Moto',
                  style: GoogleFonts.outfit(color: const Color(0xFFFF8C00), fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _plateController,
                  label: 'Placa',
                  icon: Icons.pin_outlined,
                  validator: (v) => isDriver && v!.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _modelController,
                  label: 'Modelo / Marca',
                  icon: Icons.motorcycle,
                  validator: (v) => isDriver && v!.isEmpty ? 'Campo requerido' : null,
                ),
                const SizedBox(height: 20),
                _buildTextField(
                  controller: _colorController,
                  label: 'Color de la moto',
                  icon: Icons.color_lens_outlined,
                  validator: (v) => isDriver && v!.isEmpty ? 'Campo requerido' : null,
                ),
              ],
              
              const SizedBox(height: 40),
              
              if (_isLoading)
                const CircularProgressIndicator(color: Color(0xFFFF8C00))
              else
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _submitForm,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFFF8C00),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 5,
                    ),
                    child: const Text('Guardar y Comenzar', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white10),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(color: Colors.white38),
          prefixIcon: Icon(icon, color: const Color(0xFFFF8C00)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
        ),
      ),
    );
  }

  void _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Map<String, dynamic> data = {
          'name': _nameController.text.trim(),
          'whatsapp': _whatsappController.text.trim(),
          'phone': user.phoneNumber,
        };

        if (widget.role == 'driver') {
          data.addAll({
            'plate': _plateController.text.trim().toUpperCase(),
            'model': _modelController.text.trim(),
            'color': _colorController.text.trim(),
          });
        }

        await _userService.saveUserData(
          uid: user.uid,
          role: widget.role,
          data: data,
        );

        _showSuccess("¡Registro completado!");
        
        if (!mounted) return;
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => HomeScreen(role: widget.role)),
          (route) => false,
        );
      }
    } catch (e) {
      _showError("Error al guardar datos: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: const Color(0xFFFF8C00)),
    );
  }
}
