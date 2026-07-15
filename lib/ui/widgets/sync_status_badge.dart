import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../state/app_state.dart';
import '../../state/sync_controller.dart';

/// A subtle pill that appears only when there is something to say: the device
/// is offline, or drafts are still draining after a reconnect. When everything
/// is synced and online it takes up no space at all.
///
/// Reads the optional [SyncScope]; if there is none (a boot without offline
/// support, or a widget test), it renders nothing — so it can be dropped into
/// the app bar unconditionally.
class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.maybeOf(context);
    if (sync == null) return const SizedBox.shrink();

    final offline = !sync.online;
    final hasPending = sync.pendingCount > 0;
    // Nothing to report: online and fully drained.
    if (!offline && !hasPending) return const SizedBox.shrink();

    final c = context.colors;
    final s = context.s;

    // Offline wins the styling — it is the state the user most needs to notice.
    final (icon, label, fg, bg) = offline
        ? (Icons.cloud_off_rounded, s.offlineMode, c.warning, c.warningTint)
        : (
            Icons.cloud_sync_rounded,
            sync.syncing ? s.syncing : s.pendingSync(sync.pendingCount),
            c.accentDim,
            c.accentTint,
          );

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fg),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

/// A non-blocking full-width banner for the top of the training tab, shown only
/// while offline. Explains that logging still works, so a lifter who loses
/// signal mid-session keeps going instead of assuming the app is broken.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = SyncScope.maybeOf(context);
    if (sync == null || sync.online) return const SizedBox.shrink();

    final c = context.colors;
    final s = context.s;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: c.warningTint,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: c.warning.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.wifi_off_rounded, size: 18, color: c.warning),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.offlineMode,
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: c.textHi),
                ),
                const SizedBox(height: 2),
                Text(
                  s.offlineBanner,
                  style: TextStyle(
                      fontSize: 12, color: c.textMid, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
