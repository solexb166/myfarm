import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/backend.dart';
import '../services/l10n.dart';
import '../widgets/common.dart';

/// First screen of the app: sign in with an email code (no password).
/// Needs internet once; afterwards the session stays on the phone and the
/// app works offline. [AppGate] swaps this for the home screen on success.
class SignInScreen extends StatefulWidget {
  final String lang;
  final ValueChanged<String> onLang;
  const SignInScreen({super.key, required this.lang, required this.onLang});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  static const _resendSeconds = 60;

  L10n get t => L10n(widget.lang);
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  Timer? _resendTimer;

  String? _sentTo; // email the code was sent to; null while entering email
  int _resendIn = 0;
  bool _busy = false;
  String? _errorKey;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  /// Run a sign-in step with a spinner, showing any error inline.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _errorKey = null;
    });
    try {
      await action();
    } on AccountError catch (e) {
      if (mounted) setState(() => _errorKey = accountErrorKey(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!Backend.looksLikeEmail(email)) {
      setState(() => _errorKey = 'errEmail');
      return;
    }
    await _run(() async {
      await Backend.sendEmailCode(email);
      if (!mounted) return;
      setState(() {
        _sentTo = email;
        _codeCtrl.clear();
      });
      _startResendTimer();
    });
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendIn = _resendSeconds);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _resendIn--);
      if (_resendIn <= 0) timer.cancel();
    });
  }

  Future<void> _verify() async {
    final code = _codeCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (code.length < 6) {
      setState(() => _errorKey = 'errCode');
      return;
    }
    // On success AppGate replaces this screen with the home screen.
    await _run(() => Backend.verifyEmailCode(_sentTo!, code));
  }

  void _changeEmail() {
    _resendTimer?.cancel();
    setState(() {
      _sentTo = null;
      _errorKey = null;
      _resendIn = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final sent = _sentTo != null;
    return Scaffold(
      body: SafeArea(
        child: Stack(children: [
          SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 64, 24, 32),
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const IconTile(icon: Icons.eco, size: 38),
                    const SizedBox(width: 10),
                    Text(t.get('appName'),
                        style: AppText.display(20,
                            weight: FontWeight.w800, spacing: 0)),
                  ]),
                  const SizedBox(height: 28),
                  Text(t.get('signInTitle'), style: AppText.display(30)),
                  const SizedBox(height: 10),
                  Text(t.get('signInSub'),
                      style: AppText.body(15, color: AppColors.creamDim)),
                  const SizedBox(height: 28),
                  if (!sent) ...[
                    FieldLabel(t.get('email')),
                    AppTextField(
                      controller: _emailCtrl,
                      hint: t.get('emailPh'),
                      icon: Icons.mail_outline,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      onSubmitted: (_) => _sendCode(),
                    ),
                  ] else ...[
                    Notice(
                      icon: Icons.mark_email_read_outlined,
                      color: AppColors.leaf,
                      text: t.get('codeSent').replaceAll('{email}', _sentTo!),
                    ),
                    const SizedBox(height: 18),
                    FieldLabel(t.get('code')),
                    AppTextField(
                      controller: _codeCtrl,
                      hint: t.get('codePh'),
                      icon: Icons.pin_outlined,
                      keyboardType: TextInputType.number,
                      autofillHints: const [AutofillHints.oneTimeCode],
                      autofocus: true,
                      onSubmitted: (_) => _verify(),
                    ),
                  ],
                  if (_errorKey != null) ...[
                    const SizedBox(height: 14),
                    Notice(icon: Icons.error_outline, text: t.get(_errorKey!)),
                  ],
                  const SizedBox(height: 20),
                  BigButton(
                    label: sent ? t.get('verify') : t.get('sendCode'),
                    icon: sent ? Icons.login : Icons.send_outlined,
                    loading: _busy,
                    onTap: sent ? _verify : _sendCode,
                  ),
                  if (sent) ...[
                    const SizedBox(height: 10),
                    Wrap(spacing: 8, children: [
                      TextLink(
                        icon: Icons.refresh,
                        label: _resendIn > 0
                            ? t.get('resendIn').replaceAll('{s}', '$_resendIn')
                            : t.get('resend'),
                        onTap: _resendIn > 0 || _busy ? null : _sendCode,
                      ),
                      TextLink(
                        icon: Icons.edit_outlined,
                        label: t.get('changeEmail'),
                        onTap: _busy ? null : _changeEmail,
                      ),
                    ]),
                  ],
                  const SizedBox(height: 28),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.wifi_off,
                        size: 18, color: AppColors.creamDim),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(t.get('onlineOnce'),
                          style: AppText.body(13.5, color: AppColors.creamDim)),
                    ),
                  ]),
                ],
              ),
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: LangToggle(lang: widget.lang, onChange: widget.onLang),
          ),
        ]),
      ),
    );
  }
}

/// L10n key for an [AccountError].
String accountErrorKey(AccountError e) => switch (e) {
      AccountError.offline => 'errOffline',
      AccountError.wrongCode => 'errCode',
      AccountError.tooManyTries => 'errTooMany',
      AccountError.failed => 'errGeneric',
    };
