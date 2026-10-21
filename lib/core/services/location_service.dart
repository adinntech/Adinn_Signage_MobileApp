import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

class GeoFix {
  const GeoFix(this.lat, this.lng);
  final double lat;
  final double lng;
  String get label => '${lat.toStringAsFixed(5)}, ${lng.toStringAsFixed(5)}';
}

/// Best-effort GPS. Returns null (never throws) when permission is denied or location is off,
/// so field staff are never blocked by a weak signal; the caller records "GPS unavailable".
class LocationService {
  const LocationService();

  Future<GeoFix?> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      var perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) perm = await Geolocator.requestPermission();
      if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return null;
      final p = await Geolocator.getCurrentPosition(locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, timeLimit: Duration(seconds: 12)));
      return GeoFix(p.latitude, p.longitude);
    } catch (_) {
      return null;
    }
  }
}

final locationServiceProvider = Provider<LocationService>((_) => const LocationService());
