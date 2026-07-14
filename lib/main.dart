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
        home: _BootErrorScreen(message: widget.bootError!),
      );
    }

    // AppScope sits ABOVE MaterialApp, so a language switch rebuilds the app's
    // own locale and delegates too — not just the screen that toggled it.
    return AppScope(
      state: state,
      child: AnimatedBuilder(
        animation: state,
        builder: (context, _) => _app(
          locale: state.locale,
          home: AppScope(state: state, child: AuthGate(state: state)),
        ),
      ),
    );
  }

  Widget _app({required AppLocale locale, required Widget home}) {
    return MaterialApp(
      title: AppStrings.of(locale).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
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

    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.settings_ethernet,
                  size: 40, color: AppColors.textLow),
              const SizedBox(height: 16),
              Text(
                s.configMissing,
                style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textHi),
              ),
              const SizedBox(height: 10),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textMid, height: 1.5),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.card,
                  borderRadius: BorderRadius.circular(AppRadii.control),
                  border: Border.all(color: AppColors.border),
                ),
                child: const SelectableText(
                  'flutter run -d chrome \\\n'
                  '  --dart-define=SUPABASE_URL=https://xxx.supabase.co \\\n'
                  '  --dart-define=SUPABASE_ANON_KEY=eyJ... \\\n'
                  '  --dart-define=GEMINI_API_KEY=...',
                  style: TextStyle(
                      fontFamily: 'Consolas',
                      fontSize: 12,
                      color: AppColors.textMid),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
