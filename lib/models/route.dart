import 'package:latlong2/latlong.dart';
import 'camera.dart';

enum RouteStatus { idle, calculating, ready, navigating, arrived }

class RouteWaypoint {
  final LatLng position;
  final String label;

  const RouteWaypoint({required this.position, required this.label});
}

class RouteResult {
  final List<LatLng> polyline;
  final double distanceMeters;
  final int durationSeconds;
  final List<Camera> avoidedCameras;
  final List<Camera> unavoidableCameras;
  final String summary;

  const RouteResult({
    required this.polyline,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.avoidedCameras,
    required this.unavoidableCameras,
    required this.summary,
  });

  String get distanceLabel {
    if (distanceMeters < 1609) {
      return '${(distanceMeters * 3.281).round()} ft';
    }
    final miles = distanceMeters / 1609.34;
    return '${miles.toStringAsFixed(1)} mi';
  }

  String get durationLabel {
    final mins = (durationSeconds / 60).round();
    if (mins < 60) return '$mins min';
    final h = mins ~/ 60;
    final m = mins % 60;
    return m == 0 ? '${h}h' : '${h}h ${m}m';
  }
}

class NavigationState {
  final RouteResult route;
  final int currentStepIndex;
  final LatLng userPosition;
  final double? bearing;
  final double distanceToNextTurn;
  final String nextInstruction;

  const NavigationState({
    required this.route,
    required this.currentStepIndex,
    required this.userPosition,
    this.bearing,
    required this.distanceToNextTurn,
    required this.nextInstruction,
  });
}
