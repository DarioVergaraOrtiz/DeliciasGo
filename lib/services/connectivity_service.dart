import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import '../main.dart';

class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  StreamSubscription<List<ConnectivityResult>>? _subscription;
  bool _isShowingAlert = false;

  void init() {
    _subscription?.cancel();
    _subscription = Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> result) {
      _checkStatus(result);
    });
  }

  void _checkStatus(List<ConnectivityResult> result) {
    if (result.contains(ConnectivityResult.none)) {
      if (!_isShowingAlert) {
        _showAlert();
      }
    } else {
      if (_isShowingAlert) {
        _hideAlert();
      }
    }
  }

  void _showAlert() {
    _isShowingAlert = true;
    scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.wifi_off, color: Colors.white),
            SizedBox(width: 10),
            Text('Sin conexión a Internet', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        backgroundColor: Colors.redAccent,
        duration: const Duration(days: 1), // Permanente hasta que vuelva el internet
        behavior: SnackBarBehavior.fixed,
        action: SnackBarAction(
          label: 'REINTENTAR',
          textColor: Colors.white,
          onPressed: () {},
        ),
      ),
    );
  }

  void _hideAlert() {
    _isShowingAlert = false;
    scaffoldMessengerKey.currentState?.hideCurrentSnackBar();
    scaffoldMessengerKey.currentState?.showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            Icon(Icons.wifi, color: Colors.white),
            SizedBox(width: 10),
            Text('Conexión restaurada'),
          ],
        ),
        backgroundColor: Colors.green,
        duration: Duration(seconds: 3),
      ),
    );
  }

  void dispose() {
    _subscription?.cancel();
  }
}
