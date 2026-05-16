// Web implementation — uses browser Geolocation API
import 'dart:html' as html;
import 'dart:async';

class LocationService {
  static Future<void> getPosition({
    required Future<void> Function(double lat, double lng) onPosition,
    required void Function(Stream<(double, double)>) onStream,
    required void Function() onError,
  }) async {
    try {
      final geo = html.window.navigator.geolocation;

      final pos = await geo.getCurrentPosition(
        enableHighAccuracy: true,
        timeout: const Duration(seconds: 15),
      );

      final lat = pos.coords!.latitude!.toDouble();
      final lng = pos.coords!.longitude!.toDouble();
      await onPosition(lat, lng);

      // Live stream
      final stream = geo
          .watchPosition(enableHighAccuracy: true)
          .map((p) => (
                p.coords!.latitude!.toDouble(),
                p.coords!.longitude!.toDouble(),
              ));
      onStream(stream);
    } catch (_) {
      onError();
    }
  }
}