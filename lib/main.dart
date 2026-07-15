import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/l10n/app_locale.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme.dart';
import 'services/backend.dart';
import 'services/connectivity_monitor.dart';
import 'services/offline_sync_backend.dart';
import 'services/supabase_service.dart';
import 'services/workout_draft_store.dart';
import 'state/app_state.dart';
import 'state/sync_controller.dart';
import 'ui/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Month and weekday names for every locale the app ships. Without this,
  // DateFormat(..., 'ru') throws the moment the calendar strip renders.
  await initializeDateFormatting();

  String? bootError;
  AppState? state;
  SyncController? sync;
  try {
    await SupabaseService.init();
    final remote = SupabaseService(Supabase.instance.client);

    // Offline-first stack. Wrap the server in a queue-backed decorator so
    // workouts logged with no signal are kept locally and synced on reconnect.
    // If any of it fails to initialise (Hive can't open its box, no plugin on
    // this platform), fall back to talking to the server directly — the app
    // must still run, just without the draft queue.
    Backend backend = remote;
    try {
      await Hive.initFlutter();
      final drafts = await HiveWorkoutDraftStore.open();
      final monitor = ConnectivityPlusMonitor();
      final offline = OfflineSyncBackend(
        remote: remote,
        drafts: drafts,
        connectivity: monitor,
      );
      await offline.init();
      backend = offline;
      sync = SyncController(monitor: monitor, backend: offline);
    } catch (e) {
      debugPrint('Offline sync unavailable, using direct backend: $e');
    }

    state = AppState(backend);
  } catch (e) {
    // Surface a readable screen instead of a white void when the --dart-define
    // values were not passed at build time.
    bootError = '$e';
  }

  runApp(BenchApp(state: state, sync: sync, bootError: bootError));
}

class BenchApp extends StatefulWidget {
  const BenchApp({super.key, this.state, this.sync, this.bootError});

  final AppState? state;
  final SyncController? sync;
  final String? bootError;

  @override
  State<BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<BenchApp> {
  @override
  void dispose() {
    widget.state?.dispose();
    widget.sync?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    if (state == null) {
      return _app(
        locale: AppLocale.fromSystem(),
        // No profile to read a preference from on a failed boot, so the error
        // screen opens in the app's own default look.
        themeMode: AppThemeMode.dark,
        home: _BootErrorScreen(message: widget.bootError!),
      );
    }

    // AppScope sits ABOVE MaterialApp, so a language switch — or a theme
    // switch — rebuilds the app's own theme, locale and delegates too, not just
    // the screen that toggled it.
    final sync = widget.sync;
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) {
          Widget home = AppScope(state: state, child: AuthGate(state: state));
          // The sync scope sits above the gate (and thus the whole app), so the
          // offline badge and banner can read it from anywhere in the tree. It
          // is optional: a boot without offline support has no controller.
          if (sync != null) home = SyncScope(controller: sync, child: home);
          return _app(
            locale: state.locale,
            themeMode: state.themeMode,
            home: home,
          );
        },
      ),
    );
  }

  Widget _app({
    required AppLocale locale,
    required AppThemeMode themeMode,
    required Widget home,
  }) {
    return MaterialApp(
      title: AppStrings.of(locale).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(themeMode),
      locale: Locale(locale.code),
      supportedLocales: [for (final l in AppLocale.values) Locale(l.code)],
      // Flutter's own widget text (text-selection menus, tooltips, semantics)
      // follows the same switch as ours.
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    );
  }
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    // Deliberately not from context.s: this screen renders when there is no
    // AppState, and the message itself is a developer-facing build error.
    final s = AppStrings.of(AppLocale.fromSystem());
    final c = context.colors;

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_ethernet, size: 40, color: c.textLow),
              const SizedBox(height: 16),
              Text(
                s.configMissing,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: c.textHi),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(color: c.textMid, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: c.card,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: c.border),
                ),
                child: SelectableText(
                  'flutter run -d chrome \\\n'
                  '  --dart-define=SUPABASE_URL=https://xxx.supabase.co \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=eyJ... \\\n'
                  '  --dart-define=GEMINI_API_KEY=...',
                  style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: c.textMid),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
