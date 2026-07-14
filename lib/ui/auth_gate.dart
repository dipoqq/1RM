import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/theme.dart';
import '../services/supabase_service.dart';
import 'home_shell.dart';

/// Shows the sign-in screen until there is a session, then the app.
///
/// Sign-in is not decoration. Row Level Security keys every row to auth.uid(),
/// and cross-device sync only works if the same account is used on desktop and
/// phone — an anonymous session would mint a new user per install and strand
/// the history on the old device.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key, required this.service});

  final SupabaseService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: service.authChanges,
      builder: (context, snapshot) {
        // currentSession is read directly rather than from the stream so a
        // restored session shows the app immediately, with no sign-in flash.
        final session = service.session;
        if (session == null) return SignInScreen(service: service);
        return HomeShell(service: service);
      },
    );
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.service});

  final SupabaseService service;

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  bool _signUp = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    final password = _password.text;
    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'Email and password are required.');
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_signUp) {
        await widget.service.signUp(email, password);
      } else {
        await widget.service.signIn(email, password);
      }
      // AuthGate's stream swaps the screen; nothing to do here.
    } on AuthException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(28),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.fitness_center,
                    size: 40, color: AppColors.accent),
                const SizedBox(height: 16),
                const Text(
                  'Bench Tracker',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textHi),
                ),
                const SizedBox(height: 6),
                Text(
                  _signUp
                      ? 'Create the account your data syncs to.'
                      : 'Sign in to sync across your devices.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMid),
                ),
                const SizedBox(height: 26),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  enabled: !_busy,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _password,
                  obscureText: true,
                  enabled: !_busy,
                  onSubmitted: (_) => _busy ? null : _submit(),
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerTint,
                      borderRadius: BorderRadius.circular(AppRadii.control),
                      border: Border.all(
                          color: AppColors.danger.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      _error!,
                      style: const TextStyle(
                          fontSize: 13, color: AppColors.danger),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppColors.onAccent),
                        )
                      : Text(_signUp ? 'Create account' : 'Sign in'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: _busy
                      ? null
                      : () => setState(() {
                            _signUp = !_signUp;
                            _error = null;
                          }),
                  style:
                      TextButton.styleFrom(foregroundColor: AppColors.textMid),
                  child: Text(_signUp
                      ? 'I already have an account'
                      : 'Create an account'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
