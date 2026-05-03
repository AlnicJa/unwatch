import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../models/camera.dart';
import '../models/route.dart';
import '../services/overpass_service.dart';
import '../services/routing_service.dart';
import '../services/location_service.dart';
import '../services/notification_service.dart';

// ─── Location ───────────────────────────────────────────────────────────────

final locationServiceProvider = Provider<LocationService>((ref) {
  final svc = LocationService();
  ref.onDispose(svc.dispose);
  return svc;
});

final userLocationProvider = StateProvider<LatLng?>((ref) => null);

final locationStreamProvider = StreamProvider<LatLng>((ref) {
  final svc = ref.watch(locationServiceProvider);
  return svc.locationStream;
});

// ─── Camera Filters ──────────────────────────────────────────────────────────

class FilterState {
  final bool showFlock;
  final bool showRedLight;
  final bool showSpeed;
  final bool showGeneric;
  final double radiusKm;

  const FilterState({
    this.showFlock = true,
    this.showRedLight = true,
    this.showSpeed = true,
    this.showGeneric = false,
    this.radiusKm = 8.0,
  });

  FilterState copyWith({
    bool? showFlock,
    bool? showRedLight,
    bool? showSpeed,
    bool? showGeneric,
    double? radiusKm,
  }) =>
      FilterState(
        showFlock: showFlock ?? this.showFlock,
        showRedLight: showRedLight ?? this.showRedLight,
        showSpeed: showSpeed ?? this.showSpeed,
        showGeneric: showGeneric ?? this.showGeneric,
        radiusKm: radiusKm ?? this.radiusKm,
      );

  bool get isVisible => showFlock || showRedLight || showSpeed || showGeneric;
}

class FilterNotifier extends StateNotifier<FilterState> {
  FilterNotifier() : super(const FilterState());

  void toggle(CameraType type) {
    state = switch (type) {
      CameraType.flock => state.copyWith(showFlock: !state.showFlock),
      CameraType.redLight => state.copyWith(showRedLight: !state.showRedLight),
      CameraType.speed => state.copyWith(showSpeed: !state.showSpeed),
      CameraType.generic => state.copyWith(showGeneric: !state.showGeneric),
    };
  }

  void setRadius(double km) => state = state.copyWith(radiusKm: km);
}

final filterProvider =
    StateNotifierProvider<FilterNotifier, FilterState>((ref) => FilterNotifier());

// ─── Cameras ─────────────────────────────────────────────────────────────────

class CameraNotifier extends StateNotifier<AsyncValue<List<Camera>>> {
  CameraNotifier() : super(const AsyncValue.loading());

  Future<void> fetch({required double lat, required double lng, double radiusKm = 8}) async {
    state = const AsyncValue.loading();
    try {
      final cameras = await OverpassService.fetchNearby(
        lat: lat,
        lng: lng,
        radiusMeters: radiusKm * 1000,
      );
      state = AsyncValue.data(cameras);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() => state = const AsyncValue.data([]);
}

final cameraProvider =
    StateNotifierProvider<CameraNotifier, AsyncValue<List<Camera>>>(
  (ref) => CameraNotifier(),
);

final filteredCamerasProvider = Provider<List<Camera>>((ref) {
  final camerasAsync = ref.watch(cameraProvider);
  final filters = ref.watch(filterProvider);

  return camerasAsync.maybeWhen(
    data: (cameras) => cameras.where((cam) {
      return switch (cam.type) {
        CameraType.flock => filters.showFlock,
        CameraType.redLight => filters.showRedLight,
        CameraType.speed => filters.showSpeed,
        CameraType.generic => filters.showGeneric,
      };
    }).toList(),
    orElse: () => [],
  );
});

// ─── Route ────────────────────────────────────────────────────────────────────

class RouteNotifier extends StateNotifier<AsyncValue<RouteResult?>> {
  RouteNotifier() : super(const AsyncValue.data(null));

  Future<void> plan({
    required LatLng origin,
    required LatLng destination,
    required bool avoidCameras,
    List<Camera> nearbyCameras = const [],
  }) async {
    state = const AsyncValue.loading();
    try {
      final result = avoidCameras
          ? await RoutingService.getCameraAvoidingRoute(
              origin: origin,
              destination: destination,
              nearbyCameras: nearbyCameras,
            )
          : await RoutingService.getRoute(
              origin: origin,
              destination: destination,
            );
      state = AsyncValue.data(result);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  void clear() => state = const AsyncValue.data(null);
}

final routeProvider =
    StateNotifierProvider<RouteNotifier, AsyncValue<RouteResult?>>(
  (ref) => RouteNotifier(),
);

final routeStatusProvider = StateProvider<RouteStatus>((ref) => RouteStatus.idle);

// ─── Proximity Alerts ─────────────────────────────────────────────────────────

final proximityAlertProvider = StreamProvider<ProximityAlert>((ref) {
  final svc = ref.watch(locationServiceProvider);
  return svc.proximityAlerts;
});

// ─── Search ───────────────────────────────────────────────────────────────────

final searchQueryProvider = StateProvider<String>((ref) => '');

final destinationProvider = StateProvider<LatLng?>((ref) => null);
final destinationLabelProvider = StateProvider<String?>((ref) => null);

final avoidCamerasProvider = StateProvider<bool>((ref) => true);

// ─── Map view ─────────────────────────────────────────────────────────────────

final selectedCameraProvider = StateProvider<Camera?>((ref) => null);
final mapCenterProvider = StateProvider<LatLng>((ref) => const LatLng(39.8, -98.5));
