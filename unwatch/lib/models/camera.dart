import 'package:latlong2/latlong.dart';

enum CameraType { flock, redLight, speed, generic }

class Camera {
  final String id;
  final CameraType type;
  final LatLng position;
  final String? operator;
  final String? manufacturer;
  final double? direction; // degrees from north
  final String? name;
  final Map<String, String> tags;
  double? distanceMeters;

  Camera({
    required this.id,
    required this.type,
    required this.position,
    this.operator,
    this.manufacturer,
    this.direction,
    this.name,
    this.tags = const {},
    this.distanceMeters,
  });

  factory Camera.fromOverpassNode(Map<String, dynamic> node) {
    final tags = Map<String, String>.from(
      (node['tags'] as Map<String, dynamic>? ?? {}).map(
        (k, v) => MapEntry(k, v.toString()),
      ),
    );

    final lat = (node['lat'] as num).toDouble();
    final lon = (node['lon'] as num).toDouble();
    final id = node['id'].toString();

    final type = _classifyCamera(tags);

    double? direction;
    final dirStr = tags['camera:direction'] ?? tags['direction'];
    if (dirStr != null) direction = double.tryParse(dirStr);

    return Camera(
      id: id,
      type: type,
      position: LatLng(lat, lon),
      operator: tags['operator'] ?? tags['name'],
      manufacturer: tags['manufacturer'],
      direction: direction,
      name: tags['name'],
      tags: tags,
    );
  }

  static CameraType _classifyCamera(Map<String, String> tags) {
    final survType = (tags['surveillance:type'] ?? '').toLowerCase();
    final mfr = (tags['manufacturer'] ?? '').toLowerCase();
    final enforcement = (tags['enforcement'] ?? '').toLowerCase();
    final highway = (tags['highway'] ?? '').toLowerCase();
    final operator_ = (tags['operator'] ?? '').toLowerCase();

    if (survType == 'alpr' ||
        mfr.contains('flock') ||
        mfr.contains('motorola') ||
        mfr.contains('vigilant') ||
        mfr.contains('rekor') ||
        operator_.contains('flock') ||
        tags['surveillance:type'] == 'ALPR') {
      return CameraType.flock;
    }
    if (highway == 'speed_camera' || enforcement == 'maxspeed') {
      return CameraType.speed;
    }
    if (enforcement == 'traffic_signals' ||
        tags['amenity'] == 'enforcement' && enforcement == 'traffic_signals') {
      return CameraType.redLight;
    }
    return CameraType.generic;
  }

  String get typeLabel {
    switch (type) {
      case CameraType.flock:
        return 'Flock / ALPR';
      case CameraType.redLight:
        return 'Red Light Camera';
      case CameraType.speed:
        return 'Speed Camera';
      case CameraType.generic:
        return 'Surveillance Camera';
    }
  }

  String get displayName {
    if (manufacturer?.toLowerCase().contains('flock') ?? false) {
      return 'Flock Safety';
    }
    return operator ?? manufacturer ?? typeLabel;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type.index,
        'lat': position.latitude,
        'lon': position.longitude,
        'operator': operator,
        'manufacturer': manufacturer,
        'direction': direction,
        'name': name,
      };

  factory Camera.fromJson(Map<String, dynamic> j) => Camera(
        id: j['id'],
        type: CameraType.values[j['type'] as int],
        position: LatLng(j['lat'], j['lon']),
        operator: j['operator'],
        manufacturer: j['manufacturer'],
        direction: j['direction'],
        name: j['name'],
      );
}
