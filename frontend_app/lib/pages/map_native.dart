// Native implementation — uses geolocator package (Android / iOS)
import 'dart:async';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static Future<void> getPosition({
    required Future<void> Function(double lat, double lng) onPosition,
    required void Function(Stream<(double, double)>) onStream,
    required void Function() onError,
  }) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) throw Exception('Location disabled');

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          throw Exception('Permission denied');
        }
      }
      if (permission == LocationPermission.deniedForever) {
        throw Exception('Permission denied forever');
      }

      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
      await onPosition(pos.latitude, pos.longitude);

      // Live stream
      final stream = Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 10,
        ),
      ).map((p) => (p.latitude, p.longitude));
      onStream(stream);
    } catch (_) {
      onError();
    }
  }
}