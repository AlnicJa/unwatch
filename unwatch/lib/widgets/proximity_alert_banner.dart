import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';
import '../screens/map_screen.dart';

class ProximityAlertBanner extends ConsumerWidget {
  final ProximityAlert alert;
  const ProximityAlertBanner({super.key, required this.alert});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isClose = alert.severity == AlertSeverity.close;
    final color = isClose ? UnwatchTheme.danger : UnwatchTheme.flockAmber;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutBack,
      builder: (context, value, child) => Transform.scale(
        scale: value,
        child: child,
      ),
      child: GestureDetector(
        onTap: () => ref.read(proximityAlertBannerProvider.notifier).dismiss(),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: color.withOpacity(isClose ? 0.2 : 0.12),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: color.withOpacity(0.5)),
          ),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isClose
                      ? Icons.warning_amber_rounded
                      : Icons.camera_alt_rounded,
                  color: color,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isClose
                          ? '${alert.camera.typeLabel} — Very Close!'
                          : '${alert.camera.typeLabel} Ahead',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(color: color),
                    ),
                    Text(
                      '${alert.camera.displayName} · ${alert.distanceLabel}',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.close_rounded, color: color.withOpacity(0.6), size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
