import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';

class GoogleMapsService {
  static const String _apiKey = String.fromEnvironment('GOOGLE_MAPS_API_KEY');

  Future<Map<String, dynamic>?> getDirections(
    LatLng origin,
    LatLng destination,
  ) async {
    if (_apiKey.isEmpty) {
      debugPrint(
        'Google Maps API key missing. Set GOOGLE_MAPS_API_KEY via --dart-define.',
      );
      return null;
    }
    final String url =
        "https://maps.googleapis.com/maps/api/directions/json?origin=${origin.latitude},${origin.longitude}&destination=${destination.latitude},${destination.longitude}&key=$_apiKey";

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if ((data['routes'] as List).isNotEmpty) {
          final route = data['routes'][0];
          final leg = route['legs'][0];

          return {
            'distance_text': leg['distance']['text'],
            'distance_value': leg['distance']['value'], // en metros
            'duration_text': leg['duration']['text'],
            'duration_value': leg['duration']['value'], // en segundos
            'polyline_points': route['overview_polyline']['points'],
          };
        }
      }
    } catch (e) {
      print("Error fetching directions: $e");
    }
    return null;
  }

  // Decodificar polilínea (Helper opcional si no usas flutter_polyline_points)
  List<LatLng> decodePolyline(String encoded) {
    List<LatLng> poly = [];
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lat += dlat;

      shift = 0;
      result = 0;
      do {
        b = encoded.codeUnitAt(index++) - 63;
        result |= (b & 0x1f) << shift;
        shift += 5;
      } while (b >= 0x20);
      int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
      lng += dlng;

      poly.add(LatLng(lat / 1E5, lng / 1E5));
    }
    return poly;
  }
}
