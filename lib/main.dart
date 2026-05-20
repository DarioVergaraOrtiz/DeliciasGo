import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'firebase_options.dart';
import 'features/auth/screens/role_selection_screen.dart';
import 'features/home/screens/home_screen.dart';
import 'services/user_service.dart';
import 'services/notification_service.dart';
import 'services/connectivity_service.dart';

final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Inicializar Notificaciones (Plan Blaze)
  await NotificationService().initNotifications();

  // Inicializar Monitoreo de Internet
  ConnectivityService().init();

  // Activar App Check solo en plataformas móviles (Android/iOS)
  if (!kIsWeb) {
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );
  }

  // Persistencia en Web (en móvil ya viene activada por defecto)
  if (kIsWeb) {
    try {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    } catch (_) {}
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DeliciasGo',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: const Color(0xFFFF8C00), // Naranja Vibrante
        scaffoldBackgroundColor: const Color(0xFF1D2D44), // Azul Marino Oscuro
        textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF8C00),
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
        ),
      ),
      home: StreamBuilder<User?>(
        stream: FirebaseAuth.instance.authStateChanges(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const _SplashScreen();
          }
          if (snapshot.hasData) {
            return const SessionRouter(); // Detectar rol antes de entrar
          }
          return const WelcomeScreen(); // No logueado -> Bienvenida
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// SessionRouter: Detecta el rol del usuario y lo enruta
// ─────────────────────────────────────────────────────────
class SessionRouter extends StatefulWidget {
  const SessionRouter({super.key});

  @override
  State<SessionRouter> createState() => _SessionRouterState();
}

class _SessionRouterState extends State<SessionRouter> {
  final UserService _userService = UserService();
  bool _isLoading = true;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _resolveSession();
  }

  Future<void> _resolveSession() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        // No debería pasar (StreamBuilder ya validó), pero por seguridad
        if (mounted) setState(() { _isLoading = false; _hasError = true; });
        return;
      }

      final roles = await _userService.findAllRoles(user.uid);

      if (!mounted) return;

      if (roles.isEmpty) {
        // Usuario autenticado pero NO registrado → completar registro
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const RoleSelectionScreen()),
        );
      } else if (roles.length == 1) {
        // Tiene exactamente 1 rol → directo al mapa
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => HomeScreen(role: roles[0]['role'])),
        );
      } else {
        // Tiene AMBOS roles → mostrar selector
        _showRolePicker(roles);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _hasError = true; });
    }
  }

  void _showRolePicker(List<Map<String, dynamic>> roles) {
    setState(() => _isLoading = false);
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: const Color(0xFF1A1A1A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('¿Cómo quieres entrar hoy?',
              style: GoogleFonts.outfit(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 25),
            ...roles.map((r) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(builder: (_) => HomeScreen(role: r['role'])),
                    );
                  },
                  icon: Icon(r['role'] == 'driver' ? Icons.motorcycle : Icons.person, size: 28),
                  label: Text(
                    r['role'] == 'driver' ? 'Conductor' : 'Pasajero',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: r['role'] == 'driver' ? const Color(0xFFFF8C00) : const Color(0xFF324A6D),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  ),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_hasError) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.wifi_off, color: Colors.white38, size: 60),
              const SizedBox(height: 20),
              Text('Error de conexión', style: GoogleFonts.outfit(color: Colors.white, fontSize: 18)),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() { _isLoading = true; _hasError = false; });
                  _resolveSession();
                },
                child: const Text('REINTENTAR'),
              ),
            ],
          ),
        ),
      );
    }
    return const _SplashScreen();
  }
}

// ─────────────────────────────────────────────────────────
// SplashScreen: Pantalla de carga con el logo
// ─────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D2D44),
      body: Center(
        child: RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            children: [
              TextSpan(
                text: 'DELICIAS',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w200,
                  color: Colors.white,
                  letterSpacing: 4,
                ),
              ),
              TextSpan(
                text: 'GO',
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFFFF8C00),
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────
// WelcomeScreen: Pantalla de bienvenida (primer uso)
// ─────────────────────────────────────────────────────────
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1D2D44),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                children: [
                  TextSpan(
                    text: 'DELICIAS\n',
                    style: GoogleFonts.outfit(
                      fontSize: 48,
                      fontWeight: FontWeight.w200,
                      color: Colors.white,
                      letterSpacing: 8,
                    ),
                  ),
                  TextSpan(
                    text: 'GO',
                    style: GoogleFonts.outfit(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFFFF8C00),
                      letterSpacing: 4,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              height: 2,
              width: 100,
              color: const Color(0xFFFF8C00).withOpacity(0.5),
            ),
            const SizedBox(height: 20),
            Text(
              'TU CIUDAD EN MOVIMIENTO',
              style: GoogleFonts.outfit(
                fontSize: 14,
                color: Colors.white54,
                letterSpacing: 3,
                fontWeight: FontWeight.w500,
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const RoleSelectionScreen()),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF8C00),
                  foregroundColor: Colors.white,
                  elevation: 10,
                ),
                child: const Text(
                  'COMENZAR',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }
}
