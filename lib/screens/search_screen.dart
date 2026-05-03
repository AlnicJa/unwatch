import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../models/route.dart';
import '../providers/app_providers.dart';
import '../theme/app_theme.dart';

class _GeoResult {
  final String label;
  final String sublabel;
  final LatLng position;
  const _GeoResult({required this.label, required this.sublabel, required this.position});
}

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  List<_GeoResult> _results = [];
  bool _isSearching = false;
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onQueryChanged(String q) {
    _debounce?.cancel();
    if (q.trim().length < 3) {
      setState(() => _results = []);
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), () => _search(q));
  }

  Future<void> _search(String q) async {
    setState(() => _isSearching = true);
    try {
      final encoded = Uri.encodeComponent(q);
      final url =
          'https://nominatim.openstreetmap.org/search?q=$encoded&format=json&limit=6&addressdetails=1';
      final res = await http
          .get(Uri.parse(url), headers: {'User-Agent': 'Unwatch/1.0'})
          .timeout(const Duration(seconds: 10));
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as List;
        setState(() {
          _results = data.map((item) {
            final addr = item['address'] as Map<String, dynamic>? ?? {};
            final city = addr['city'] ?? addr['town'] ?? addr['county'] ?? '';
            final state = addr['state'] ?? '';
            return _GeoResult(
              label: item['name'] ?? item['display_name'] as String,
              sublabel: [city, state].where((s) => s.isNotEmpty).join(', '),
              position: LatLng(
                double.parse(item['lat'].toString()),
                double.parse(item['lon'].toString()),
              ),
            );
          }).toList();
        });
      }
    } catch (_) {
      setState(() => _results = []);
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _selectResult(_GeoResult result) {
    HapticFeedback.selectionClick();
    ref.read(destinationProvider.notifier).state = result.position;
    ref.read(destinationLabelProvider.notifier).state = result.label;
    Navigator.of(context).pop();
    _launchRoute(result);
  }

  void _launchRoute(_GeoResult dest) {
    final origin = ref.read(userLocationProvider);
    if (origin == null) return;

    final avoidCams = ref.read(avoidCamerasProvider);
    final cameras = ref.read(filteredCamerasProvider);

    ref.read(routeProvider.notifier).plan(
          origin: origin,
          destination: dest.position,
          avoidCameras: avoidCams,
          nearbyCameras: cameras,
        );
    ref.read(routeStatusProvider.notifier).state = RouteStatus.calculating;
  }

  @override
  Widget build(BuildContext context) {
    final avoidCams = ref.watch(avoidCamerasProvider);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: UnwatchTheme.bg,
        body: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: UnwatchTheme.surface2,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: UnwatchTheme.border),
                        ),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: UnwatchTheme.textSecondary, size: 15),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: UnwatchTheme.surface2,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: UnwatchTheme.borderMid),
                        ),
                        child: Row(
                          children: [
                            const SizedBox(width: 12),
                            const Icon(Icons.search_rounded,
                                color: UnwatchTheme.textSecondary, size: 18),
                            const SizedBox(width: 8),
                            Expanded(
                              child: TextField(
                                controller: _controller,
                                onChanged: _onQueryChanged,
                                autofocus: true,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(color: UnwatchTheme.textPrimary),
                                decoration: InputDecoration(
                                  hintText: 'Search destination',
                                  hintStyle: Theme.of(context)
                                      .textTheme
                                      .bodyMedium,
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                cursorColor: UnwatchTheme.speedBlue,
                              ),
                            ),
                            if (_controller.text.isNotEmpty)
                              GestureDetector(
                                onTap: () {
                                  _controller.clear();
                                  setState(() => _results = []);
                                },
                                child: const Padding(
                                  padding: EdgeInsets.all(10),
                                  child: Icon(Icons.cancel_rounded,
                                      color: UnwatchTheme.textSecondary,
                                      size: 16),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Avoid cameras toggle
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(avoidCamerasProvider.notifier).state = !avoidCams;
                  },
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: avoidCams
                          ? UnwatchTheme.flockAmber.withOpacity(0.12)
                          : UnwatchTheme.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: avoidCams
                            ? UnwatchTheme.flockAmber.withOpacity(0.4)
                            : UnwatchTheme.border,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          avoidCams
                              ? Icons.alt_route_rounded
                              : Icons.route_rounded,
                          color: avoidCams
                              ? UnwatchTheme.flockAmber
                              : UnwatchTheme.textSecondary,
                          size: 18,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                avoidCams
                                    ? 'Avoiding cameras'
                                    : 'Camera avoidance off',
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: avoidCams
                                          ? UnwatchTheme.flockAmber
                                          : UnwatchTheme.textSecondary,
                                    ),
                              ),
                              Text(
                                avoidCams
                                    ? 'Route will avoid Flock & red light cameras'
                                    : 'Tap to enable camera avoidance routing',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: avoidCams,
                          onChanged: (v) =>
                              ref.read(avoidCamerasProvider.notifier).state = v,
                          activeColor: UnwatchTheme.flockAmber,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              const Divider(color: UnwatchTheme.border, height: 1),

              if (_isSearching)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: UnwatchTheme.speedBlue,
                  ),
                )
              else
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: _results.length,
                    itemBuilder: (_, i) => _ResultTile(
                      result: _results[i],
                      onTap: () => _selectResult(_results[i]),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final _GeoResult result;
  final VoidCallback onTap;

  const _ResultTile({required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: UnwatchTheme.surface2,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: UnwatchTheme.border),
              ),
              child: const Icon(Icons.place_rounded,
                  color: UnwatchTheme.textSecondary, size: 17),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.label,
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.sublabel.isNotEmpty)
                    Text(
                      result.sublabel,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            const Icon(Icons.north_east_rounded,
                color: UnwatchTheme.textTertiary, size: 15),
          ],
        ),
      ),
    );
  }
}
