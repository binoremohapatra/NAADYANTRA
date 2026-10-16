import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/motion_tokens.dart';
import '../services/providers.dart';

// ──────────────────────────────────────────────────────────────────────────────
// ConnectivityBanner — persistent amber offline/stale indicator
//
// Shows only when the device has NO network connectivity (not when the
// backend is merely slow). Uses isOfflineProvider from providers.dart.
// Auto-dismisses when network returns.
// ──────────────────────────────────────────────────────────────────────────────

class ConnectivityBanner extends ConsumerWidget {
  const ConnectivityBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isOffline = ref.watch(isOfflineProvider);

    return AnimatedSlide(
      offset: isOffline ? Offset.zero : const Offset(0, -1),
      duration: MotionTokens.durationMedium,
      curve: MotionTokens.curveSnappy,
      child: AnimatedOpacity(
        opacity: isOffline ? 1.0 : 0.0,
        duration: MotionTokens.durationFast,
        child: isOffline ? _BannerContent() : const SizedBox.shrink(),
      ),
    );
  }
}

class _BannerContent extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: AppColors.alertCaution.withValues(alpha: 0.12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          const Icon(
            Icons.wifi_off_rounded,
            size: 14,
            color: AppColors.alertCaution,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'No network connection — showing cached data',
              style: AppTypography.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: AppColors.alertCaution,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
