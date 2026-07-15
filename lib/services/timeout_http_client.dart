import 'package:http/http.dart' as http;

/// An [http.Client] that fails a request that has not produced a response
/// within [timeout], instead of hanging on the platform default (which can be
/// well over a minute on Android).
///
/// Wraps an inner client and applies the deadline to every request it sends.
/// Because [http.BaseClient] routes `get`/`post`/… through [send], overriding
/// [send] alone covers the whole surface — which is exactly what the
/// google_generative_ai client uses under the hood.
///
/// The bound is a *receive* deadline: it covers connect + send + the full
/// response, so a stalled mobile connection surfaces as a clean [TimeoutException]
/// the UI can translate, rather than a spinner that never resolves.
class TimeoutHttpClient extends http.BaseClient {
  TimeoutHttpClient({
    http.Client? inner,
    this.timeout = const Duration(seconds: 30),
  }) : _inner = inner ?? http.Client();

  final http.Client _inner;
  final Duration timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(timeout);

  @override
  void close() => _inner.close();
}
