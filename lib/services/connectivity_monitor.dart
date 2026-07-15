import 'package:connectivity_plus/connectivity_plus.dart';

/// A network-reachability signal, abstracted from the plugin behind it.
///
/// A seam, exactly like [Backend]: the sync logic and the UI can be driven by a
/// hand-controlled fake in tests, without a live radio. The one production
/// implementation is [ConnectivityPlusMonitor].
///
/// NOTE: this reports whether the device has *a network interface*, not whether
/// the internet is actually reachable — a captive Wi-Fi portal reads as online.
/// The sync path treats that honestly: it attempts the upload and, if it fails,
/// leaves the draft queued for the next attempt.
abstract interface class ConnectivityMonitor {
  /// Whether there is a network route right now.
  Future<bool> get isOnline;

  /// Emits `true` (online) / `false` (offline) whenever connectivity changes.
  /// Deduplicated, so a Wi-Fi→cellular handover that stays "online" is silent.
  Stream<bool> get onStatusChange;

  void dispose();
}

/// [ConnectivityMonitor] backed by connectivity_plus.
class ConnectivityPlusMonitor implements ConnectivityMonitor {
  ConnectivityPlusMonitor([Connectivity? connectivity])
      : _connectivity = connectivity ?? Connectivity();

  final Connectivity _connectivity;

  /// A device is "online" if any interface is up — anything other than
  /// [ConnectivityResult.none] in the reported set.
  static bool _online(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Future<bool> get isOnline async =>
      _online(await _connectivity.checkConnectivity());

  @override
  Stream<bool> get onStatusChange =>
      _connectivity.onConnectivityChanged.map(_online).distinct();

  @override
  void dispose() {}
}
