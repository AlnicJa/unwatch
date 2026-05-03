import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/camera.dart';

class LocationService {
  static const _proximityAlertRadius = 150.0; // meters
  static const _highAlertRadius = 60.0; // meters — closer alert

  StreamSubscription<Position>? _positionSub;
  StreamController<LatLng>? _locationController;
  StreamController<ProximityAlert>? _alertController;

  List<Camera> _monitoredCameras = [];
  final Set<String> _alertedCameraIds = {};
  LatLng? _lastPosition;

  Stream<LatLng> get locationStream =>
      (_locationController ??= StreamController.broadcast()).stream;

  Stream<ProximityAlert> get proximityAlerts =>
      (_alertController ??= StreamController.broadcast()).stream;

  LatLng? get lastPosition => _lastPosition;

  Future<bool> requestPermissions() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.deniedForever) return false;
    return permission != LocationPermission.denied;
  }

  Future<LatLng?> getCurrentPosition() async {
    try {
      final pos = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
        timeLimit: const Duration(seconds: 10),
      );
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return null;
    }
  }

  void startTracking({required List<Camera> cameras}) {
    _monitoredCameras = cameras;
    _alertedCameraIds.clear();

    _locationController ??= StreamController.broadcast();
    _alertController ??= StreamController.broadcast();

    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10, // update every 10m movement
      ),
    ).listen((pos) {
      final location = LatLng(pos.latitude, pos.longitude);
      _lastPosition = location;
      _locationController!.add(location);
      _checkProximity(location);
    });
  }

  void updateMonitoredCameras(List<Camera> cameras) {
    _monitoredCameras = cameras;
    // Clear alerts for cameras no longer in range
    final newIds = cameras.map((c) => c.id).toSet();
    _alertedCameraIds.removeWhere((id) => !newIds.contains(id));
  }

  void _checkProximity(LatLng userPos) {
    for (final cam in _monitoredCameras) {
      final dist = const Distance().as(
        LengthUnit.Meter,
        userPos,
        cam.position,
      );

      if (dist <= _highAlertRadius && !_alertedCameraIds.contains('${cam.id}_close')) {
        _alertedCameraIds.add('${cam.id}_close');
        _alertController!.add(ProximityAlert(
          camera: cam,
          distanceMeters: dist,
          severity: AlertSeverity.close,
        ));
      } else if (dist <= _proximityAlertRadius && !_alertedCameraIds.contains(cam.id)) {
        _alertedCameraIds.add(cam.id);
        _alertController!.add(ProximityAlert(
          camera: cam,
          distanceMeters: dist,
          severity: AlertSeverity.approaching,
        ));
      } else if (dist > _proximityAlertRadius * 1.5) {
        // Reset so we can alert again if they come back
        _alertedCameraIds.remove(cam.id);
        _alertedCameraIds.remove('${cam.id}_close');
      }
    }
  }

  void stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
  }

  void dispose() {
    stopTracking();
    _locationController?.close();
    _alertController?.close();
  }
}

enum AlertSeverity { approaching, close }

class ProximityAlert {
  final Camera camera;
  final double distanceMeters;
  final AlertSeverity severity;

  const ProximityAlert({
    required this.camera,
    required this.distanceMeters,
    required this.severity,
  });

  String get distanceLabel {
    if (distanceMeters < 100) return '${distanceMeters.round()} ft ahead';
    return '${(distanceMeters * 3.281).round()} ft ahead';
  }
}
