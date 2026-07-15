import 'dart:async';

import 'package:flutter/material.dart';

import '../core/l10n/app_locale.dart';
import '../core/l10n/app_strings.dart';
import '../core/password_policy.dart';
import '../core/theme.dart';
import '../services/backend.dart';
import '../state/app_state.dart';
import 'home_shell.dart';
import 'onboarding_screen.dart';
import 'widgets/common.dart' as ui;

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
    // No side effects here — just the branch. `context.app` subscribes this
    // gate to the profile landing, which is what re-runs the branch below once
    // load() completes.
    final state = context.app;

    if (!_signedIn) return SignInScreen(state: widget.state);

    // Signed in, but the profile is still in flight. The placeholder profile
    // AppState starts on has a null onboardedAt, so it reports needsOnboarding
    // — routing on it here would flash the setup screen at every returning
    // user for the frames between sign-in and the row landing. Wait instead.
    if (!state.loaded) return const _ProfileLoading();

    // The gate proper. A lifter who has never been through setup does not get
    // the tabs: the whole point of the milestone is that nobody trains against
    // 180 cm / 94 kg because that is what the column defaulted to. Onboarding
    // is a *replacement* for HomeShell, not a route pushed on top of it, so
    // there is no back gesture, no Navigator entry and no way around it — the
    // only exit is completing it, which flips this branch.
    if (state.needsOnboarding) return OnboardingScreen(state: widget.state);

    return HomeShell(state: widget.state);
  }
}

/// The gap between "signed in" and "profile in hand".
class _ProfileLoading extends StatelessWidget {
  const _ProfileLoading();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2, color: c.accent),
            ),
            const SizedBox(height: 16),
            Text(
              context.s.loadingProfile,
              style: TextStyle(color: c.textMid, fontSize: 13),
            ),
          ],
        ),
      ),
    );
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

    // Strict rules apply only when creating the account. Enforcing them on
    // sign-in would lock out anyone whose existing password predates the policy.
    if (_signUp) {
      final unmet = PasswordPolicy.firstUnmet(password);
      if (unmet != null) {
        setState(() => _error = context.s.passwordRuleError(unmet));
        return;
      }
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
    final c = context.colors;
    final s = context.s;

    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            // The language and theme switches are on the sign-in screen, not
            // only inside Settings: Settings is behind the account, and neither
            // a Russian speaker facing an English screen nor someone wincing at
            // a white flash should have to sign in first to fix it.
            Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    LanguageToggle(
                      locale: context.app.locale,
                      onChanged: (l) => context.app.update(locale: l),
                    ),
                    const SizedBox(height: 8),
                    ui.ThemeToggle(
                      mode: context.app.themeMode,
                      onChanged: (m) => context.app.update(themeMode: m),
                    ),
                  ],
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
                      Icon(Icons.fitness_center,
                          size: 40, color: c.accent),
                      const SizedBox(height: 16),
                      Text(
                        s.appTitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: c.textHi),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _signUp ? s.signUpSubtitle : s.signInSubtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: c.textMid),
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
                      // On sign-up the rules are shown up front, so the user
                      // reads them before the first rejection rather than after.
                      if (_signUp) ...[
                        const SizedBox(height: 8),
                        Text(
                          s.passwordRequirements,
                          style: TextStyle(fontSize: 12, color: c.textLow),
                        ),
                      ] else
                        // The "Забыл пароль" entry point. Only on the sign-in
                        // form: there is nothing to reset while creating an
                        // account.
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _busy
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute<void>(
                                        builder: (_) => ForgotPasswordScreen(
                                          state: widget.state,
                                          initialEmail: _email.text.trim(),
                                        ),
                                      ),
                                    ),
                            style: TextButton.styleFrom(
                                foregroundColor: c.textMid,
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 32)),
                            child: Text(s.forgotPassword),
                          ),
                        ),
                      if (_error != null) ...[
                        const SizedBox(height: 14),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: c.dangerTint,
                            borderRadius:
                                BorderRadius.circular(AppRadii.control),
                            border: Border.all(
                                color:
                                    c.danger.withValues(alpha: 0.35)),
                          ),
                          child: Text(
                            _error!,
                            style: TextStyle(
                                fontSize: 13, color: c.danger),
                          ),
                        ),
                      ],
                      const SizedBox(height: 18),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: c.onAccent),
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
                            foregroundColor: c.textMid),
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

/// The "Забыл пароль" flow: collect an email, trigger the reset, and confirm.
///
/// Pushed as its own route on top of [SignInScreen]. Wrapped in [AppScope] so
/// `context.s` resolves inside the pushed route regardless of where the tree's
/// scope sits, matching how the manual-meal sheet re-establishes it.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({
    super.key,
    required this.state,
    this.initialEmail = '',
  });

  final AppState state;
  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  late final _email = TextEditingController(text: widget.initialEmail);
  bool _busy = false;
  String? _error;

  /// The address a link was sent to, once the request succeeds. Non-null flips
  /// the screen to its confirmation state.
  String? _sentTo;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      setState(() => _error = context.s.credentialsRequired);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await widget.state.service.sendPasswordReset(email);
      if (mounted) setState(() => _sentTo = email);
    } on BackendException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Re-establish the scope for the pushed route (see class doc).
    return AppScope(
      state: widget.state,
      child: Builder(builder: (context) {
        final c = context.colors;
        final s = context.s;

        return Scaffold(
          appBar: AppBar(
            title: Text(s.resetPasswordTitle),
            backgroundColor: Colors.transparent,
          ),
          body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(28),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 380),
                  child: _sentTo == null
                      ? _form(context, c, s)
                      : _confirmation(context, c, s),
                ),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _form(BuildContext context, AppPalette c, AppStrings s) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.lock_reset, size: 40, color: c.accent),
          const SizedBox(height: 16),
          Text(
            s.resetPasswordSubtitle,
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMid, height: 1.5),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            enabled: !_busy,
            onSubmitted: (_) => _busy ? null : _submit(),
            decoration: InputDecoration(labelText: s.email),
          ),
          if (_error != null) ...[
            const SizedBox(height: 14),
            _ErrorBox(message: _error!),
          ],
          const SizedBox(height: 18),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: c.onAccent),
                  )
                : Text(s.sendResetLink),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            style: TextButton.styleFrom(foregroundColor: c.textMid),
            child: Text(s.backToSignIn),
          ),
        ],
      );

  Widget _confirmation(BuildContext context, AppPalette c, AppStrings s) =>
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.mark_email_read_outlined, size: 40, color: c.success),
          const SizedBox(height: 16),
          Text(
            s.resetEmailSent(_sentTo!),
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textMid, height: 1.5),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(s.backToSignIn),
          ),
        ],
      );
}

/// The sign-in error card, reused by the reset form so both look the same.
class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: c.dangerTint,
        borderRadius: BorderRadius.circular(AppRadii.control),
        border: Border.all(color: c.danger.withValues(alpha: 0.35)),
      ),
      child: Text(
        message,
        style: TextStyle(fontSize: 13, color: c.danger),
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
    final c = context.colors;
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
        backgroundColor: c.bgBase,
        foregroundColor: c.textMid,
        selectedBackgroundColor: c.accentTint,
        selectedForegroundColor: c.accentDim,
        side: BorderSide(color: c.border),
        textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
