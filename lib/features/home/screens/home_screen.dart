import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:latlong2/latlong.dart' as dist;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../services/ride_service.dart';
import '../../../services/user_service.dart';
import '../../../services/auth_service.dart';
import 'ranking_screen.dart';
import '../../../services/google_maps_service.dart';
import '../../../services/notification_service.dart';

class HomeScreen extends StatefulWidget {
  final String role;
  const HomeScreen({super.key, required this.role});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  GoogleMapController? _mapController;
  final Location _locationController = Location();
  final RideService _rideService = RideService();
  final UserService _userService = UserService();
  final GoogleMapsService _googleMapsService = GoogleMapsService();
  final NotificationService _notificationService = NotificationService();
  
  LatLng _currentP = const LatLng(-0.1807, -78.4678); // Quito por defecto para precarga
  LatLng? _otherPersonP; 
  LatLng? _destinationP; 
  String? _activeRideId;
  String? _otherPersonPhone; 
  String? _otherPersonId;
  bool _isSearching = false;
  String _userRole = 'client'; // Valor por defecto seguro
  List<Marker> _onlineDriverMarkers = [];
  bool _isOnline = false;
  String _userName = "Usuario";
  String _userPhone = "";
  double _estimatedPrice = 0.0; 
  StreamSubscription? _requestsSubscription;
  StreamSubscription? _rideSubscription;
  Set<Marker> _markers = {};
  Set<Polyline> _polylines = {};
  StreamSubscription? _onlineDriversSubscription;
  bool _initialLocationSet = false;
  BitmapDescriptor? _driverIcon;
  BitmapDescriptor? _clientIcon;
  BitmapDescriptor? _destinationIcon;
  bool _isMapLoading = true;

  // Paleta de Colores Oficial
  // Nueva Paleta Duo-Tone
  static const Color colorNaranja = Color(0xFFFF8C00);
  static const Color colorAzulOscuro = Color(0xFF1D2D44);
  static const Color colorAzulBotonSecundario = Color(0xFF324A6D);
  static const Color colorTextoPrincipal = Colors.white;
  static const Color colorTextoSecundario = Colors.white70;

  @override
  void initState() {
    super.initState();
    _userRole = widget.role;
    _loadCustomIcons();
    _loadUserData();
    _getLocationUpdates();
  }

  void _loadCustomIcons() async {
    // Marcadores estándar por ahora para evitar problemas de fondo
    _driverIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);
    _clientIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueGreen);
    _destinationIcon = BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed);
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _requestsSubscription?.cancel();
    _rideSubscription?.cancel();
    _onlineDriversSubscription?.cancel();
    super.dispose();
  }

  void _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      _userPhone = user.phoneNumber ?? "";
      final data = await _userService.getUserData(user.uid, _userRole);
      
      setState(() {
        if (data != null) {
          _userName = data['name'] ?? (_userRole == 'driver' ? "Conductor" : "Cliente");
        }
        if (_userRole == 'client') {
          _listenForOnlineDrivers();
        }
        // Guardar Token para Notificaciones (Plan Blaze)
        _notificationService.saveToken(user.uid, _userRole);
      });
    }
  }

  void _listenForOnlineDrivers() {
    _onlineDriversSubscription?.cancel();
    _onlineDriversSubscription = _rideService.getOnlineDrivers().listen((snapshot) {
      if (_userRole == 'client' && mounted) {
        List<Marker> driverMarkers = [];
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final lat = data['lat'];
          final lng = data['lng'];
          final isOnline = data['isOnline'] ?? false;
          
          if (isOnline && lat != null && lng != null) {
            driverMarkers.add(Marker(
              markerId: MarkerId('driver_${doc.id}'),
              position: LatLng(lat, lng),
              icon: _driverIcon ?? BitmapDescriptor.defaultMarker,
              anchor: const Offset(0.5, 0.5),
            ));
          }
        }
        setState(() {
          _onlineDriverMarkers = driverMarkers;
        });
        _updateMarkers();
      }
    });
  }

  void _updateMarkers() {
    if (!mounted) return;
    
    Set<Marker> newMarkers = {};

    // Marcador de posición actual
    if (_currentP != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('current_pos'),
        position: _currentP!,
        icon: _userRole == 'driver' ? (_driverIcon ?? BitmapDescriptor.defaultMarker) : (_clientIcon ?? BitmapDescriptor.defaultMarker),
        anchor: const Offset(0.5, 0.5),
      ));
    }

    // Marcador de destino
    if (_destinationP != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('destination'),
        position: _destinationP!,
        icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
      ));
    }

    // Marcador de la otra persona (si hay viaje activo)
    if (_otherPersonP != null) {
      newMarkers.add(Marker(
        markerId: const MarkerId('other_person'),
        position: _otherPersonP!,
        icon: _userRole == 'driver' ? (_clientIcon ?? BitmapDescriptor.defaultMarker) : (_driverIcon ?? BitmapDescriptor.defaultMarker),
      ));
    }

    // Agregar todas las motos online cercanas
    if (_userRole == 'client') {
      newMarkers.addAll(_onlineDriverMarkers);
    }

    setState(() {
      _markers = newMarkers;
    });
  }

  void _calculatePrice() async {
    if (_currentP != null && _destinationP != null) {
      // Primero un cálculo rápido (Haversine) para feedback inmediato
      final quickDistance = const dist.Distance().as(
        dist.LengthUnit.Kilometer, 
        dist.LatLng(_currentP!.latitude, _currentP!.longitude), 
        dist.LatLng(_destinationP!.latitude, _destinationP!.longitude)
      );
      
      setState(() {
        _estimatedPrice = 1.0 + (quickDistance * 0.25);
      });

      // Ahora el cálculo real con Google Maps (Plan Blaze)
      final directions = await _googleMapsService.getDirections(
        LatLng(_currentP!.latitude, _currentP!.longitude),
        LatLng(_destinationP!.latitude, _destinationP!.longitude),
      );

      if (directions != null && mounted) {
        final distanceKm = directions['distance_value'] / 1000.0;
        final polylinePoints = _googleMapsService.decodePolyline(directions['polyline_points']);

        setState(() {
          _estimatedPrice = 1.0 + (distanceKm * 0.25);
          _polylines = {
            Polyline(
              polylineId: const PolylineId("route"),
              points: polylinePoints,
              color: colorNaranja,
              width: 5,
            ),
          };
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isDriver = _userRole == 'driver';

    return Scaffold(
      body: Stack(
        children: [
          // Capa del Mapa (Siempre presente para precarga)
          GoogleMap(
            onMapCreated: (controller) {
              _mapController = controller;
              _mapController?.setMapStyle(_googleMapsStyle);
            },
            initialCameraPosition: CameraPosition(
              target: _currentP,
              zoom: 15,
            ),
            markers: _markers,
            polylines: _polylines,
            myLocationEnabled: true,
            myLocationButtonEnabled: false,
            zoomControlsEnabled: false,
            mapType: MapType.normal,
            onTap: (point) {
              if (!isDriver && _activeRideId == null && !_isSearching) {
                setState(() { _destinationP = point; });
                _updateMarkers();
                _calculatePrice();
              }
            },
          ),

          // Pantalla de Carga Inicial
          if (_isMapLoading)
            Container(
              color: colorAzulOscuro,
              width: double.infinity,
              height: double.infinity,
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
                            color: colorNaranja,
                            letterSpacing: 3,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
                  const CircularProgressIndicator(color: colorNaranja, strokeWidth: 2),
                  const SizedBox(height: 20),
                  Text(
                    'UBICANDO TU POSICIÓN...',
                    style: GoogleFonts.outfit(color: Colors.white38, fontSize: 10, letterSpacing: 2),
                  ),
                ],
              ),
            ),
          
          Positioned(
            top: 0, 
            left: 20, 
            right: 20, 
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: _buildHeader(isDriver),
              ),
            ),
          ),

          if (!isDriver && _destinationP != null && !_isSearching && _activeRideId == null)
            Positioned(bottom: 110, left: 20, right: 20, child: _buildPriceTag()),

          Positioned(
            bottom: 0, 
            left: 20, 
            right: 20, 
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 20),
                child: isDriver ? _buildDriverUI() : (_isSearching ? _buildSearchingCard() : _buildRequestButton()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(bool isDriver) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.85),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: Colors.white10, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              shape: BoxShape.circle,
              border: Border.all(color: colorNaranja, width: 1.5),
            ),
            child: ClipOval(
              child: Image.asset(
                _userRole == 'driver' ? 'assets/images/moto_icon.png' : 'assets/images/user_icon.png',
                width: 35,
                height: 35,
                fit: BoxFit.contain,
              ),
            ),
          ),
          const SizedBox(width: 15),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Hola, $_userName', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Row(
                  children: [
                    const Icon(Icons.star, color: colorNaranja, size: 14),
                    const SizedBox(width: 4),
                    const Text('4.9', style: TextStyle(color: colorNaranja, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 8),
                    Container(width: 4, height: 4, decoration: const BoxDecoration(color: Colors.white24, shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        isDriver ? (_isOnline ? 'En línea' : 'Desconectado') : 'Cliente Verificado', 
                        style: const TextStyle(color: Colors.white70, fontSize: 12),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Icono de Ranking (Trofeo)
          IconButton(
            icon: const Icon(Icons.emoji_events, color: colorNaranja, size: 28),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const RankingScreen())),
          ),
          const SizedBox(width: 5),
          // Icono decorativo de rol
          Icon(isDriver ? Icons.verified_user : Icons.person_pin_circle, color: isDriver ? colorNaranja : Colors.blueAccent, size: 20),
          const SizedBox(width: 10),
          IconButton(
            icon: const Icon(Icons.logout, color: Colors.white70), 
            onPressed: _showLogoutConfirmation,
          ),
        ],
      ),
    );
  }

  Widget _buildPriceTag() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
      decoration: BoxDecoration(
        color: colorAzulOscuro,
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: colorNaranja, width: 2),
      ),
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _priceBtn("-0.5", () => setState(() => _estimatedPrice = (_estimatedPrice - 0.50).clamp(0.50, 100.0))),
            _priceBtn("-0.1", () => setState(() => _estimatedPrice = (_estimatedPrice - 0.10).clamp(0.50, 100.0))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('TU OFERTA', style: GoogleFonts.outfit(color: Colors.white70, fontSize: 9, fontWeight: FontWeight.bold)),
                  Text('\$${_estimatedPrice.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: colorNaranja, fontSize: 20, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
            _priceBtn("+0.1", () => setState(() => _estimatedPrice += 0.10)),
            _priceBtn("+0.5", () => setState(() => _estimatedPrice += 0.50)),
          ],
        ),
      ),
    );
  }

  Widget _priceBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildDriverUI() {
    if (_activeRideId != null) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: colorAzulOscuro, borderRadius: BorderRadius.circular(25), border: Border.all(color: colorNaranja)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('VIAJE EN CURSO', style: GoogleFonts.outfit(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: _launchWhatsApp, icon: const Icon(Icons.message), label: const Text('WhatsApp'), style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(onPressed: _finishRide, style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white), child: const Text('FINALIZAR'))),
              ],
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_isOnline) 
          Container(
            margin: const EdgeInsets.only(bottom: 15), padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.green.withOpacity(0.5))),
            child: Row(children: [const CircularProgressIndicator(color: Colors.green, strokeWidth: 2), const SizedBox(width: 20), Expanded(child: Text('Buscando pasajeros...', style: GoogleFonts.outfit(color: Colors.white)))]),
          ),
        SizedBox(
          width: double.infinity, 
          height: 60, 
          child: ElevatedButton(
            onPressed: _toggleOnline, 
            style: ElevatedButton.styleFrom(
              backgroundColor: _isOnline ? colorAzulBotonSecundario : colorNaranja, 
              foregroundColor: Colors.white, 
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(30),
                side: _isOnline ? const BorderSide(color: Colors.white24) : BorderSide.none,
              )
            ), 
            child: Text(_isOnline ? 'DESCONECTARSE' : 'PONERSE ONLINE', style: GoogleFonts.outfit(fontWeight: FontWeight.bold))
          )
        ),
      ],
    );
  }

  void _launchWhatsApp() async {
    if (_otherPersonPhone == null) return;

    String message = "";
    if (_userRole == 'driver') {
      // Mensaje profesional del conductor al cliente
      final user = FirebaseAuth.instance.currentUser;
      final userData = await _userService.getUserData(user?.uid ?? "", 'driver');
      final name = userData?['name'] ?? "Conductor";
      final plate = userData?['plate'] ?? "";
      final model = userData?['model'] ?? "";
      
      message = "Hola, soy $name, tu conductor de DeliciasGo. Voy en camino en una moto $model (Placa: $plate).";
    } else {
      // Mensaje del cliente al conductor
      message = "Hola, soy tu pasajero de DeliciasGo. ¿En cuánto tiempo llegas?";
    }

    final cleanPhone = _otherPersonPhone!.replaceAll(RegExp(r'[^0-9]'), '');
    final encodedMsg = Uri.encodeComponent(message);
    final url = "https://wa.me/$cleanPhone?text=$encodedMsg";
    
    if (await canLaunchUrl(Uri.parse(url))) {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  void _toggleOnline() {
    setState(() { 
      _isOnline = !_isOnline; 
      if (_isOnline) { 
        _listenForRequests(); 
      } else { 
        _requestsSubscription?.cancel(); 
      } 
    });
    
    // Actualizar estado global inmediatamente
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && _userRole == 'driver' && _currentP != null) {
      _rideService.updateGlobalDriverLocation(
        user.uid, 
        dist.LatLng(_currentP!.latitude, _currentP!.longitude), 
        _isOnline
      );
    }
  }

  void _listenForRequests() {
    _requestsSubscription?.cancel();
    _requestsSubscription = _rideService.getPendingRequests().listen((snapshot) async {
      if (snapshot.docs.isNotEmpty && _isOnline && _activeRideId == null) {
        final request = snapshot.docs.first;
        final data = request.data() as Map<String, dynamic>;

        // CALCULAR DISTANCIAS REALES (Plan Blaze)
        double distToClient = 0;
        double rideDist = 0;

        if (_currentP != null && data['pickupLat'] != null) {
          // Distancia del conductor al cliente
          final toClientDir = await _googleMapsService.getDirections(
            LatLng(_currentP!.latitude, _currentP!.longitude),
            LatLng(data['pickupLat'], data['pickupLng']),
          );
          if (toClientDir != null) {
            distToClient = toClientDir['distance_value'] / 1000.0;
          }
        }

        if (data['pickupLat'] != null && data['destinationLat'] != null) {
          // Distancia del viaje (Cliente a Destino)
          final rideDir = await _googleMapsService.getDirections(
            LatLng(data['pickupLat'], data['pickupLng']),
            LatLng(data['destinationLat'], data['destinationLng']),
          );
          if (rideDir != null) {
            rideDist = rideDir['distance_value'] / 1000.0;
          }
        }

        // Lógica de Radar (Plan Blaze): Solo mostrar si está a menos de 5km
        if (distToClient <= 5.0) {
          _showRideRequestModal(request.id, data, distToClient, rideDist);
        } else {
          if (kDebugMode) {
            print('Solicitud ignorada por distancia: ${distToClient.toStringAsFixed(1)} km');
          }
        }
      }
    });
  }

  void _showRideRequestModal(String rideId, Map<String, dynamic> data, double distToClient, double rideDist) {
    double currentOfferPrice = (data['estimatedPrice'] ?? 0.0).toDouble();
    showModalBottomSheet(
      context: context, 
      backgroundColor: Colors.transparent,
      isDismissible: false,
      isScrollControlled: true,
      builder: (modalContext) => Container(
        padding: const EdgeInsets.all(25),
        decoration: const BoxDecoration(color: Color(0xFF1A1A1A), borderRadius: BorderRadius.vertical(top: Radius.circular(30))),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            Text('¡NUEVA SOLICITUD!', style: GoogleFonts.outfit(color: colorNaranja, fontWeight: FontWeight.bold, fontSize: 18, letterSpacing: 1.2)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(data['clientName'] ?? 'Pasajero', style: GoogleFonts.outfit(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: Colors.greenAccent, size: 16),
                        const SizedBox(width: 5),
                        Text('A ${distToClient.toStringAsFixed(1)} km de ti', style: const TextStyle(color: Colors.greenAccent)),
                      ],
                    ),
                  ],
                ),
                Text('\$${data['estimatedPrice']?.toStringAsFixed(2) ?? "0.00"}', style: GoogleFonts.outfit(color: colorNaranja, fontSize: 32, fontWeight: FontWeight.bold)),
              ],
            ),
            const Divider(color: Colors.white12, height: 20),
            Row(
              children: [
                const Icon(Icons.directions_bike, color: Colors.white70, size: 20),
                const SizedBox(width: 10),
                Text('Recorrido: ${rideDist.toStringAsFixed(1)} km', style: const TextStyle(color: Colors.white70, fontSize: 14)),
              ],
            ),
            const SizedBox(height: 15),
            // Panel de Negociación del Conductor
            StatefulBuilder(
              builder: (context, setModalState) {
                return Column(
                  children: [
                    Text('TU CONTRAOFERTA:', style: GoogleFonts.outfit(color: Colors.white54, fontSize: 10)),
                    Text('\$${currentOfferPrice.toStringAsFixed(2)}', style: GoogleFonts.outfit(color: colorNaranja, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _modalPriceBtn("+0.10", () => setModalState(() => currentOfferPrice += 0.10)),
                        _modalPriceBtn("+0.50", () => setModalState(() => currentOfferPrice += 0.50)),
                        _modalPriceBtn("+1.00", () => setModalState(() => currentOfferPrice += 1.00)),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Expanded(child: TextButton(onPressed: () => Navigator.pop(modalContext), child: Text('IGNORAR', style: TextStyle(color: Colors.grey[400], fontSize: 13)))),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () {
                              final user = FirebaseAuth.instance.currentUser;
                              if (currentOfferPrice > (data['estimatedPrice'] ?? 0.0) && user != null) {
                                _rideService.counterOffer(rideId, currentOfferPrice, user.uid, _userName, _userPhone);
                                Navigator.pop(modalContext);
                                _startDriverRideListener(rideId, data['clientPhone'] ?? "", data['clientId']);
                                _showSuccess("Contraoferta enviada, esperando respuesta...");
                              } else if (user != null) {
                                Navigator.pop(modalContext);
                                _acceptRide(rideId, data['clientPhone'] ?? "", data['clientId']);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: colorNaranja, 
                              padding: const EdgeInsets.symmetric(vertical: 12), 
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                            ),
                            child: Text(currentOfferPrice > (data['estimatedPrice'] ?? 0.0) ? 'ENVIAR OFERTA' : 'ACEPTAR', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              }
            ),
          ],
        ),
      ),
    );
  }

  Widget _modalPriceBtn(String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
        decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.white24)),
        child: Text(label, style: const TextStyle(color: colorNaranja, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _acceptRide(String rideId, String clientPhone, String clientId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await _rideService.acceptRide(rideId, user.uid, _userName, _userPhone);
      _startDriverRideListener(rideId, clientPhone, clientId);
      _showSuccess("Viaje aceptado");
    }
  }

  void _startDriverRideListener(String rideId, String clientPhone, String clientId) {
    _rideSubscription?.cancel();
    _rideSubscription = _rideService.streamRideRequest(rideId).listen((doc) {
      if (doc.exists) {
        final data = doc.data() as Map<String, dynamic>;
        if (mounted) {
          setState(() {
            if (data['status'] == 'accepted') {
              _activeRideId = rideId;
              _otherPersonPhone = clientPhone;
              _otherPersonId = clientId;
              if (data['pickupLat'] != null && data['pickupLng'] != null) {
                _otherPersonP = LatLng(data['pickupLat'], data['pickupLng']);
              }
              if (data['destinationLat'] != null && data['destinationLng'] != null) {
                _destinationP = LatLng(data['destinationLat'], data['destinationLng']);
              }
              if (_otherPersonP != null) {
                _mapController?.animateCamera(CameraUpdate.newLatLng(_otherPersonP!));
              }
            }
          });
        }
      }
    });
  }

  void _finishRide() async {
    if (_activeRideId != null) {
      await _rideService.updateRideStatus(_activeRideId!, 'completed');
      if (_otherPersonId != null) {
        _showRatingDialog(_activeRideId!, _otherPersonId!); // Calificar al pasajero
      }
      _clearActiveRide();
      _showSuccess("Viaje completado ✅");
    }
  }

  void _clearActiveRide() {
    _rideSubscription?.cancel();
    setState(() { 
      _activeRideId = null; 
      _isOnline = true; 
      _otherPersonP = null; 
      _otherPersonPhone = null; 
      _otherPersonId = null; 
      _destinationP = null; 
      _estimatedPrice = 0.0; 
      _polylines = {};
    });
  }

  Widget _buildRequestButton() {
    return SizedBox(height: 60, child: ElevatedButton(onPressed: _requestRide, style: ElevatedButton.styleFrom(backgroundColor: colorNaranja, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30))), child: Text(_destinationP == null ? 'TOCA EL MAPA PARA TU DESTINO' : 'PEDIR MOTO', style: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.bold))));
  }

  Widget _buildSearchingCard() {
    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: colorAzulOscuro, borderRadius: BorderRadius.circular(20), border: Border.all(color: colorNaranja.withOpacity(0.5))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [const CircularProgressIndicator(color: colorNaranja), const SizedBox(height: 20), Text('Buscando...', style: GoogleFonts.outfit(color: Colors.white)), const SizedBox(height: 20), TextButton(onPressed: _cancelRide, child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)))]),
    );
  }

  void _requestRide() async {
    if (_currentP == null || _destinationP == null) return;
    setState(() => _isSearching = true);
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final rideId = await _rideService.createRideRequest(
        clientId: user.uid, 
        clientName: _userName, 
        clientPhone: _userPhone, 
        pickupLocation: dist.LatLng(_currentP!.latitude, _currentP!.longitude), 
        destinationLocation: dist.LatLng(_destinationP!.latitude, _destinationP!.longitude), 
        estimatedPrice: _estimatedPrice
      );
      if (rideId != null) {
        setState(() => _activeRideId = rideId);
        _rideSubscription = _rideService.streamRideRequest(rideId).listen((doc) {
          if (doc.exists) {
            final data = doc.data() as Map<String, dynamic>;
            if (data['status'] == 'accepted') {
               if (data['driverLat'] != null && data['driverLng'] != null) {
                setState(() { _otherPersonP = LatLng(data['driverLat'], data['driverLng']); _otherPersonPhone = data['driverPhone']; _otherPersonId = data['driverId']; });
              }
              if (!_isSearching) return;
              _showDriverAccepted(data['driverName'] ?? "Conductor"); 
            } else if (data['status'] == 'counter_offer' && _isSearching) {
              _showCounterOfferDialog(rideId, data['driverName'] ?? "Conductor", (data['estimatedPrice'] ?? 0.0).toDouble());
            } else if (data['status'] == 'completed' && _userRole == 'client') {
              _showRatingDialog(rideId, data['driverId'] ?? "");
              _clearActiveRide();
            }
          }
        });
      }
    }
  }
  void _showCounterOfferDialog(String rideId, String driverName, double price) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('NUEVA OFERTA', style: GoogleFonts.outfit(color: colorNaranja, fontWeight: FontWeight.bold)),
        content: Text('$driverName ofrece realizar el viaje por \$${price.toStringAsFixed(2)}', style: const TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () { _cancelRide(); Navigator.pop(context); }, child: const Text('RECHAZAR', style: TextStyle(color: Colors.white54))),
          ElevatedButton(
            onPressed: () {
              _rideService.confirmCounterOffer(rideId);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(backgroundColor: colorNaranja),
            child: const Text('ACEPTAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildMarker(IconData icon, Color color, {bool isDest = false}) {
    return Container(
      decoration: BoxDecoration(
        color: color.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: color, width: 2),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 10, spreadRadius: 2)],
      ),
      child: Center(
        child: Container(
          width: 40, height: 40,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          child: Icon(icon, color: Colors.black, size: 25),
        ),
      ),
    );
  }

  void _showRatingDialog(String rideId, String ratedUserId) {
    double stars = 5.0;
    final commentController = TextEditingController();
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          backgroundColor: colorAzulOscuro,
          title: Text('¿Cómo estuvo tu viaje?', style: GoogleFonts.outfit(color: colorNaranja)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(5, (i) => IconButton(icon: Icon(i < stars ? Icons.star : Icons.star_border, color: colorNaranja, size: 35), onPressed: () => setModalState(() => stars = i + 1.0)))),
              const SizedBox(height: 15),
              TextField(controller: commentController, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(hintText: 'Escribe un comentario...', hintStyle: TextStyle(color: Colors.white38), enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)))),
            ],
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                final user = FirebaseAuth.instance.currentUser;
                if (user != null) {
                  _rideService.submitRating(rideId: rideId, ratedUserId: ratedUserId, raterUserId: user.uid, rating: stars, comment: commentController.text);
                }
                Navigator.pop(context);
                _showSuccess("¡Gracias por tu calificación!");
              },
              style: ElevatedButton.styleFrom(backgroundColor: colorNaranja),
              child: const Text('ENVIAR', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  void _cancelRide() async {
    if (_activeRideId != null) { await _rideService.cancelRide(_activeRideId!); }
    _clearActiveRide();
    setState(() => _isSearching = false);
  }

  void _showDriverAccepted(String driverName) {
    setState(() => _isSearching = false);
    showDialog(context: context, builder: (context) => AlertDialog(backgroundColor: colorAzulOscuro, title: Text('¡Moto Encontrada!', style: TextStyle(color: colorNaranja, fontWeight: FontWeight.bold)), content: Column(mainAxisSize: MainAxisSize.min, children: [Text('$driverName viene en camino.', style: const TextStyle(color: Colors.white)), const SizedBox(height: 20), ElevatedButton.icon(onPressed: _launchWhatsApp, icon: const Icon(Icons.message), label: const Text('Contactar por WhatsApp'), style: ElevatedButton.styleFrom(backgroundColor: colorNaranja, foregroundColor: Colors.white))]), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK', style: TextStyle(color: colorNaranja)))]));
  }

  void _showLogoutConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: colorAzulOscuro,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          '¿Cerrar sesión?',
          style: GoogleFonts.outfit(
            color: colorNaranja,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Si sales de tu cuenta, tendrás que volver a verificar tu número de teléfono para entrar de nuevo.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.white54)),
          ),
          ElevatedButton(
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                // Eliminar token antes de salir (Plan Blaze)
                await _notificationService.deleteToken(user.uid, _userRole);
              }
              Navigator.pop(context); 
              await AuthService.instance.signOut();
              if (mounted) {
                Navigator.of(context).pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: colorNaranja,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text(
              'CERRAR SESIÓN',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccess(String message) { 
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), 
        backgroundColor: colorNaranja
      )
    ); 
  }

  // Estilo oscuro para Google Maps
  final String _googleMapsStyle = '''
[
  { "elementType": "geometry", "stylers": [ { "color": "#242f3e" } ] },
  { "elementType": "labels.text.fill", "stylers": [ { "color": "#746855" } ] },
  { "elementType": "labels.text.stroke", "stylers": [ { "color": "#242f3e" } ] },
  { "featureType": "administrative.locality", "elementType": "labels.text.fill", "stylers": [ { "color": "#d59563" } ] },
  { "featureType": "poi", "elementType": "labels.text.fill", "stylers": [ { "color": "#d59563" } ] },
  { "featureType": "poi.park", "elementType": "geometry", "stylers": [ { "color": "#263c3f" } ] },
  { "featureType": "poi.park", "elementType": "labels.text.fill", "stylers": [ { "color": "#6b9a76" } ] },
  { "featureType": "road", "elementType": "geometry", "stylers": [ { "color": "#38414e" } ] },
  { "featureType": "road", "elementType": "geometry.stroke", "stylers": [ { "color": "#212a37" } ] },
  { "featureType": "road", "elementType": "labels.text.fill", "stylers": [ { "color": "#9ca5b3" } ] },
  { "featureType": "road.highway", "elementType": "geometry", "stylers": [ { "color": "#746855" } ] },
  { "featureType": "road.highway", "elementType": "geometry.stroke", "stylers": [ { "color": "#1f2827" } ] },
  { "featureType": "road.highway", "elementType": "labels.text.fill", "stylers": [ { "color": "#f3d19c" } ] },
  { "featureType": "transit", "elementType": "geometry", "stylers": [ { "color": "#2f3948" } ] },
  { "featureType": "transit.station", "elementType": "labels.text.fill", "stylers": [ { "color": "#d59563" } ] },
  { "featureType": "water", "elementType": "geometry", "stylers": [ { "color": "#17263c" } ] },
  { "featureType": "water", "elementType": "labels.text.fill", "stylers": [ { "color": "#515c6d" } ] },
  { "featureType": "water", "elementType": "labels.text.stroke", "stylers": [ { "color": "#17263c" } ] }
]
''';

  Future<void> _getLocationUpdates() async {
    try {
      bool _serviceEnabled = await _locationController.serviceEnabled();
      if (!_serviceEnabled) { _serviceEnabled = await _locationController.requestService(); if (!_serviceEnabled) return; }
      
      final initialLocation = await _locationController.getLocation();
      if (initialLocation.latitude != null && initialLocation.longitude != null) {
        final initialPos = LatLng(initialLocation.latitude!, initialLocation.longitude!);
        setState(() { 
          _currentP = initialPos; 
          _initialLocationSet = true;
        });
        _updateMarkers();
        _mapController?.animateCamera(CameraUpdate.newLatLngZoom(_currentP, 15));
        
        // Esperamos un segundo extra para asegurar que el mapa renderizó la nueva posición
        await Future.delayed(const Duration(milliseconds: 1500));
        if (mounted) setState(() => _isMapLoading = false);
      }

      _locationController.onLocationChanged.listen((LocationData currentLocation) {
        if (currentLocation.latitude != null && currentLocation.longitude != null) {
          final newPos = LatLng(currentLocation.latitude!, currentLocation.longitude!);
          if (mounted) { 
            setState(() { _currentP = newPos; }); 
            _updateMarkers();
            if (!_initialLocationSet) {
              _mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 15));
              _initialLocationSet = true;
            }
            if (_userRole == 'driver') {
              if (_activeRideId != null) {
                _rideService.updateDriverLocation(
                  _activeRideId!, 
                  dist.LatLng(newPos.latitude, newPos.longitude)
                );
              }
              final user = FirebaseAuth.instance.currentUser;
              if (user != null) {
                _rideService.updateGlobalDriverLocation(
                  user.uid, 
                  dist.LatLng(newPos.latitude, newPos.longitude), 
                  _isOnline
                );
              }
            }
          }
        }
      });
    } catch (e) { print("Error ubicación: $e"); }
  }
}
