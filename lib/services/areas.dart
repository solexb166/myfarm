import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

/// A simplified outline: bounding box plus rings (outlines and holes) of
/// flattened lng,lat pairs.
class _Shape {
  final List<double> bbox; // minLng, minLat, maxLng, maxLat
  final List<List<double>> rings;
  _Shape(this.bbox, this.rings);

  factory _Shape.fromJson(Map<String, dynamic> j) => _Shape(
        (j['bbox'] as List).map((e) => (e as num).toDouble()).toList(),
        (j['rings'] as List)
            .map((r) => (r as List).map((e) => (e as num).toDouble()).toList())
            .toList(),
      );

  /// Even-odd rule across every ring, so holes are respected.
  bool contains(double lat, double lng) {
    if (lng < bbox[0] || lat < bbox[1] || lng > bbox[2] || lat > bbox[3]) {
      return false;
    }
    var inside = false;
    for (final ring in rings) {
      final n = ring.length ~/ 2;
      for (var i = 0, j = n - 1; i < n; j = i++) {
        final xi = ring[2 * i], yi = ring[2 * i + 1];
        final xj = ring[2 * j], yj = ring[2 * j + 1];
        if ((yi > lat) != (yj > lat) &&
            lng < (xj - xi) * (lat - yi) / (yj - yi) + xi) {
          inside = !inside;
        }
      }
    }
    return inside;
  }
}

/// A Uganda district with its sub-counties.
class District {
  final String id; // slug, e.g. 'mbale' - same ids as the districts table
  final String name;
  final _Shape _outline;
  final List<(String, _Shape)> _subs;

  District._(this.id, this.name, this._outline, this._subs);

  factory District._fromJson(Map<String, dynamic> j) => District._(
        j['id'] as String,
        j['name'] as String,
        _Shape.fromJson(j),
        (j['subcounties'] as List).map((s) {
          final m = s as Map<String, dynamic>;
          return (m['name'] as String, _Shape.fromJson(m));
        }).toList(),
      );

  List<String> get subcounties => [for (final s in _subs) s.$1];

  bool contains(double lat, double lng) => _outline.contains(lat, lng);

  /// The sub-county a position falls in, if any.
  String? subcountyAt(double lat, double lng) {
    for (final (name, shape) in _subs) {
      if (shape.contains(lat, lng)) return name;
    }
    return null;
  }
}

/// Uganda's districts and sub-counties, bundled with the app so the area
/// picker and GPS lookup work offline. Built by tool/build_areas.py from
/// geoBoundaries.
class Areas {
  static List<District>? _districts;

  static Future<List<District>> districts() async {
    final cached = _districts;
    if (cached != null) return cached;
    final raw = await rootBundle.loadString('assets/areas/uganda_areas.json');
    final list = (jsonDecode(raw)['districts'] as List)
        .map((e) => District._fromJson(e as Map<String, dynamic>))
        .toList();
    return _districts = list;
  }

  static Future<District?> byId(String? id) async {
    if (id == null) return null;
    for (final d in await districts()) {
      if (d.id == id) return d;
    }
    return null;
  }

  /// The district a position falls in, or null (outside Uganda, or on a
  /// lake). Outlines are simplified, so a spot right on a border may land
  /// in the neighbouring district.
  static Future<District?> districtAt(double lat, double lng) async {
    for (final d in await districts()) {
      if (d.contains(lat, lng)) return d;
    }
    return null;
  }
}
