import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/theme.dart';
import 'services/supabase_service.dart';
import 'ui/auth_gate.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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

class BenchApp extends StatelessWidget {
  const BenchApp({super.key, this.bootError});

  final String? bootError;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bench Tracker',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      home: bootError != null
          ? _BootErrorScreen(message: bootError!)
          : AuthGate(service: SupabaseService(Supabase.instance.client)),
    );
  }
}

class _BootErrorScreen extends StatelessWidget {
  const _BootErrorScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Configuration missing',
                style: TextStyle(
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
