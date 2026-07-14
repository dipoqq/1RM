import 'dart:async';

import 'package:flutter/material.dart';

import '../core/l10n/app_locale.dart';
import '../core/theme.dart';
import '../services/backend.dart';
import '../state/app_state.dart';
import 'home_shell.dart';

/// Shows the sign-in screen until there is a session, then the app.
///
/// Sign-in is not decoration. Row Level Security keys every row to auth.uid(),
/// and cross-device sync only works if the same account is used on desktop and
/// phone — an anonymous session would mint a new user per install and strand
/// the history on the old device.
///
/// This is also where the profile is pulled: the language and the bench press
/// goal are per-account, so they can only be known once there is an account.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key, required this.state});

  final AppState state;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  StreamSubscription<AuthStatus>? _sub;

  /// Whether a session exists. Mirrored into widget state so `build` is a pure
  /// function of it — reading the service inside `build` and *acting* on what
  /// it says is what caused the rebuild storm.
  late bool _signedIn = widget.state.service.isSignedIn;

  @override
  void initState() {
    super.initState();

    // Auth is a stream of EVENTS, so it is subscribed to once here rather than
    // via a StreamBuilder. A StreamBuilder hands the same latest value to every
    // rebuild, so firing load() from its builder re-fired it on every rebuild —
    // and load() notifies, which causes a rebuild, which fires load()… The
    // signed-in state changes a handful of times in a session; it does not need
    // to be re-derived on every frame.
    _sub = widget.state.service.authStatus.listen((status) {
      final signedIn = status == AuthStatus.signedIn;

      // Only transitions do work. A repeated signedIn (a token refresh, say)
      // must not re-fetch the profile.
      if (signedIn == _signedIn) return;

      setState(() => _signedIn = signedIn);
      if (signedIn) {
        // Pull this account's saved language and bench goal.
        widget.state.load();
      } else {
        widget.state.clear();
      }
    });

    // A session restored from disk means we are already signed in and no event
    // may fire; pull the profile now or the app opens on defaults — in the
    // wrong language, against the wrong bench goal. AppState defers the
    // resulting notification out of this build phase.
    if (_signedIn) widget.state.load();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No side effects here — just the branch.
    if (!_signedIn) return SignInScreen(state: widget.state);
    return HomeShell(state: widget.state);
  }
}

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key, required this.state});

  final AppState state;

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
      setState(() => _error = context.s.credentialsRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      if (_signUp) {
        await widget.state.service.signUp(email, password);
      } else {
        await widget.state.service.signIn(email, password);
      }
      // AuthGate's stream swaps the screen; nothing to do here.
    } on BackendException catch (e) {
      // "Invalid login credentials", not the whole exception's toString().
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // The language switch is on the sign-in screen, not only inside
            // Settings: Settings is behind the account, and a Russian speaker
            // should not have to read an English screen to reach their own
            // language.
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: LanguageToggle(
                  locale: context.app.locale,
                  onChanged: (l) => context.app.update(locale: l),
                ),
              ),
            ),
            Center(
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
                      Text(
                        s.appTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textHi),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _signUp ? s.signUpSubtitle : s.signInSubtitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textMid),
                      ),
                      const SizedBox(height: 26),
                      TextField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autocorrect: false,
                        enabled: !_busy,
                        decoration: InputDecoration(labelText: s.email),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _password,
                        obscureText: true,
                        enabled: !_busy,
                        onSubmitted: (_) => _busy ? null : _submit(),
                        decoration: InputDecoration(labelText: s.password),
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.dangerTint,
                            borderRadius:
                                BorderRadius.circular(AppRadii.control),
                            border: Border.all(
                                color:
                                    AppColors.danger.withValues(alpha: 0.35)),
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
                                    strokeWidth: 2,
                                    color: AppColors.onAccent),
                              )
                            : Text(_signUp ? s.createAccount : s.signIn),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => setState(() {
                                  _signUp = !_signUp;
                                  _error = null;
                                }),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.textMid),
                        child:
                            Text(_signUp ? s.haveAccount : s.createAccount),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The language switch itself: one segmented control, used both on the sign-in
/// screen and in Settings so there is a single widget to keep in step.
class LanguageToggle extends StatelessWidget {
  const LanguageToggle({
    super.key,
    required this.locale,
    required this.onChanged,
  });

  final AppLocale locale;
  final ValueChanged<AppLocale> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<AppLocale>(
      segments: [
        for (final l in AppLocale.values)
          ButtonSegment(
            value: l,
            label: Text(l.nativeName),
          ),
      ],
      selected: {locale},
      showSelectedIcon: false,
      onSelectionChanged: (set) => onChanged(set.first),
      style: SegmentedButton.styleFrom(
        backgroundColor: AppColors.bgBase,
        foregroundColor: AppColors.textMid,
        selectedBackgroundColor: AppColors.accentTint,
        selectedForegroundColor: AppColors.accentDim,
        side: const BorderSide(color: AppColors.border),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
