import 'dart:async';

import 'package:flutter/widgets.dart';

import '../services/connectivity_monitor.dart';
import '../services/offline_sync_backend.dart';

/// The connectivity + sync state the UI reads: are we online, how many workouts
/// are queued, and are we mid-flush.
///
/// It owns the reconnect trigger — the instant the [ConnectivityMonitor] reports
/// the network is back, it drains the [OfflineSyncBackend]'s queue. Nothing in
/// the widget tree has to remember to do that; a badge just listens here.
///
/// Provided to the tree through [SyncScope]. It is deliberately optional: on a
/// boot where connectivity/Hive could not be set up (or in a widget test), there
/// is simply no scope, and [SyncStatusBadge] renders nothing.
class SyncController extends ChangeNotifier {
  SyncController({required this.monitor, required this.backend}) {
    backend.pending.addListener(notifyListeners);
    _sub = monitor.onStatusChange.listen(_onStatus);
    // Seed the initial state; assume online until the first check says otherwise
    // so we never flash "offline" on a healthy launch.
    monitor.isOnline.then((online) {
      if (_disposed) return;
      _online = online;
      notifyListeners();
      if (online) unawaited(_flush());
    });
  }

  final ConnectivityMonitor monitor;
  final OfflineSyncBackend backend;
  StreamSubscription<bool>? _sub;
  bool _disposed = false;

  bool _online = true;
  bool _syncing = false;

  /// Whether the device currently has a network route.
  bool get online => _online;

  /// Whether queued drafts are being pushed to the server right now.
  bool get syncing => _syncing;

  /// How many workouts are waiting to sync.
  int get pendingCount => backend.pending.value;

  Future<void> _onStatus(bool online) async {
    _online = online;
    notifyListeners();
    if (online) await _flush();
  }

  Future<void> _flush() async {
    if (_syncing || backend.pending.value == 0) return;
    _syncing = true;
    notifyListeners();
    try {
      await backend.flush();
    } finally {
      if (!_disposed) {
        _syncing = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _sub?.cancel();
    backend.pending.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Puts a [SyncController] in the tree and rebuilds dependents when it notifies.
///
/// Use [maybeOf]: the scope is optional, so widgets must tolerate its absence.
class SyncScope extends InheritedNotifier<SyncController> {
  const SyncScope({super.key, required SyncController controller, required super.child})
      : super(notifier: controller);

  static SyncController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SyncScope>()?.notifier;
}
