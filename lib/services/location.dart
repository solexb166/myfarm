import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'areas.dart';
import 'storage.dart';

/// How the farmer agreed to share where their scans are made.
enum LocationMode {
  gps, // use the phone's (coarse) location, falling back to the home area
  manual, // only the district / sub-county they picked
  none; // nothing

  static LocationMode? parse(String? s) =>
      LocationMode.values.where((m) => m.name == s).firstOrNull;
}

/// Where one scan was made.
class ScanPlace {
  final String districtId;
  final String? subcounty;
  final String source; // 'gps' | 'manual'
  final double? lat; // rounded to 2 decimals (about 1 km)
  final double? lng;
  const ScanPlace({
    required this.districtId,
    required this.source,
    this.subcounty,
    this.lat,
    this.lng,
  });
}

/// Location for scans, only ever with the farmer's consent ([LocationMode]).
/// Never blocks a diagnosis: if GPS is off or slow, the home area is used.
class LocationService {
  /// Rounds a coordinate to 2 decimal places, about 1 km. Precise positions
  /// are never stored or uploaded.
  static double round2(double v) => (v * 100).round() / 100;

  /// Asks Android/iOS for location permission (after our own consent
  /// screen). Returns true if the app may use location.
  static Future<bool> requestPermission() async {
    try {
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      return p == LocationPermission.whileInUse ||
          p == LocationPermission.always;
    } catch (e) {
      debugPrint('Location permission failed: $e');
      return false;
    }
  }

  /// The district id and sub-county the phone is in now, or null.
  static Future<(String, String?)?> currentArea() async {
    final p = await _position();
    if (p == null) return null;
    final d = await Areas.districtAt(p.latitude, p.longitude);
    return d == null ? null : (d.id, d.subcountyAt(p.latitude, p.longitude));
  }

  /// Where a scan made now should be recorded, following the farmer's
  /// choice. Null when they chose not to share, or nothing is known.
  static Future<ScanPlace?> placeForScan() async {
    final mode = LocationMode.parse(await Storage.getLocationMode());
    if (mode == null || mode == LocationMode.none) return null;
    if (mode == LocationMode.gps) {
      final p = await _position();
      if (p != null) {
        final d = await Areas.districtAt(p.latitude, p.longitude);
        if (d != null) {
          return ScanPlace(
            districtId: d.id,
            subcounty: d.subcountyAt(p.latitude, p.longitude),
            source: 'gps',
            lat: round2(p.latitude),
            lng: round2(p.longitude),
          );
        }
      }
    }
    final home = await Storage.getHomeDistrict();
    if (home == null) return null;
    return ScanPlace(
      districtId: home,
      subcounty: await Storage.getHomeSubcounty(),
      source: 'manual',
    );
  }

  /// A coarse position without prompting the farmer: null if location is
  /// off, not permitted, or takes too long.
  static Future<Position?> _position() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return null;
      final perm = await Geolocator.checkPermission();
      if (perm != LocationPermission.whileInUse &&
          perm != LocationPermission.always) {
        return null;
      }
      try {
        return await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.low,
            timeLimit: Duration(seconds: 8),
          ),
        );
      } catch (_) {
        return await Geolocator.getLastKnownPosition();
      }
    } catch (e) {
      debugPrint('Location unavailable: $e');
      return null;
    }
  }
}
