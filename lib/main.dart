import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/l10n/app_locale.dart';
import 'core/l10n/app_strings.dart';
import 'core/theme.dart';
import 'services/supabase_service.dart';
import 'state/app_state.dart';
import 'ui/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Month and weekday names for every locale the app ships. Without this,
  // DateFormat(..., 'ru') throws the moment the calendar strip renders.
  await initializeDateFormatting();

  String? bootError;
  try {
    await SupabaseService.init();
  } catch (e) {
    // Surface a readable screen instead of a white void when the --dart-define
    // values were not passed at build time.
    bootError = '$e';
  }

  runApp(BenchApp(bootError: bootError));
}

class BenchApp extends StatefulWidget {
  const BenchApp({super.key, this.bootError});

  final String? bootError;

  @override
  State<BenchApp> createState() => _BenchAppState();
}

class _BenchAppState extends State<BenchApp> {
  AppState? _state;

  @override
  void initState() {
    super.initState();
    // Supabase.instance.client throws if initialize() never ran, so the state —
    // and everything that depends on a profile — only exists on a good boot.
    if (widget.bootError == null) {
      _state = AppState(SupabaseService(Supabase.instance.client));
    }
  }

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = _state;
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
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) => _app(
          locale: state.locale,
          themeMode: state.themeMode,
          home: AppScope(state: state, child: AuthGate(state: state)),
        ),
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
