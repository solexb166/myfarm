import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/backend.dart';
import '../services/l10n.dart';
import '../services/links.dart';
import '../widgets/common.dart';

/// First screen of the app: sign in with a code sent by SMS to the farmer's
/// phone, or by email (no password). Needs internet once; afterwards the
/// session stays on the phone and the app works offline. [AppGate] swaps
/// this for the home screen on success.
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
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  Timer? _resendTimer;

  // Phone first: most farmers have a phone number, fewer use email.
  bool _byPhone = true;
  // Where the code was sent (+256... or an email); null while entering it.
  String? _sentTo;
  int _resendIn = 0;
  bool _busy = false;
  String? _errorKey;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneCtrl.dispose();
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
    final String to;
    if (_byPhone) {
      final phone = Backend.ugandaPhone(_phoneCtrl.text);
      if (phone == null) {
        setState(() => _errorKey = 'errPhone');
        return;
      }
      to = phone;
    } else {
      to = _emailCtrl.text.trim();
      if (!Backend.looksLikeEmail(to)) {
        setState(() => _errorKey = 'errEmail');
        return;
      }
    }
    await _run(() async {
      if (_byPhone) {
        await Backend.sendPhoneCode(to, lang: widget.lang);
      } else {
        await Backend.sendEmailCode(to);
      }
      if (!mounted) return;
      setState(() {
        _sentTo = to;
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
    await _run(() => _byPhone
        ? Backend.verifyPhoneCode(_sentTo!, code)
        : Backend.verifyEmailCode(_sentTo!, code));
  }

  void _setMethod(bool byPhone) {
    if (byPhone == _byPhone || _busy) return;
    setState(() {
      _byPhone = byPhone;
      _errorKey = null;
    });
  }

  void _changeAddress() {
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
                    _MethodSwitch(
                      byPhone: _byPhone,
                      phoneLabel: t.get('phone'),
                      emailLabel: t.get('emailTab'),
                      onChange: _setMethod,
                    ),
                    const SizedBox(height: 20),
                    if (_byPhone) ...[
                      FieldLabel(t.get('phoneNumber')),
                      AppTextField(
                        key: const ValueKey('phone'),
                        controller: _phoneCtrl,
                        hint: t.get('phonePh'),
                        icon: Icons.phone_android,
                        prefixText: '+256',
                        keyboardType: TextInputType.phone,
                        autofillHints: const [
                          AutofillHints.telephoneNumberNational
                        ],
                        onSubmitted: (_) => _sendCode(),
                      ),
                    ] else ...[
                      FieldLabel(t.get('email')),
                      AppTextField(
                        key: const ValueKey('email'),
                        controller: _emailCtrl,
                        hint: t.get('emailPh'),
                        icon: Icons.mail_outline,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        onSubmitted: (_) => _sendCode(),
                      ),
                    ],
                  ] else ...[
                    Notice(
                      icon: _byPhone
                          ? Icons.sms_outlined
                          : Icons.mark_email_read_outlined,
                      color: AppColors.leaf,
                      text: _byPhone
                          ? t.get('smsSent').replaceAll(
                              '{phone}', Backend.formatPhone(_sentTo!))
                          : t.get('codeSent').replaceAll('{email}', _sentTo!),
                    ),
                    const SizedBox(height: 18),
                    FieldLabel(t.get(_byPhone ? 'codeSms' : 'code')),
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
                        label: t.get(_byPhone ? 'changePhone' : 'changeEmail'),
                        onTap: _busy ? null : _changeAddress,
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
                  const SizedBox(height: 14),
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.privacy_tip_outlined,
                        size: 18, color: AppColors.creamDim),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          text: '${t.get('agreePrivacy')} ',
                          style: AppText.body(13.5, color: AppColors.creamDim),
                          children: [
                            WidgetSpan(
                              alignment: PlaceholderAlignment.baseline,
                              baseline: TextBaseline.alphabetic,
                              child: GestureDetector(
                                onTap: () => Links.open(Links.privacyPolicy),
                                child: Text('${t.get('privacyPolicy')}.',
                                    style: AppText.body(13.5,
                                            weight: FontWeight.w600,
                                            color: AppColors.primary)
                                        .copyWith(
                                            decoration:
                                                TextDecoration.underline,
                                            decorationColor:
                                                AppColors.primary)),
                              ),
                            ),
                          ],
                        ),
                      ),
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

/// Phone / Email choice above the sign-in field.
class _MethodSwitch extends StatelessWidget {
  final bool byPhone;
  final String phoneLabel;
  final String emailLabel;
  final ValueChanged<bool> onChange;
  const _MethodSwitch({
    required this.byPhone,
    required this.phoneLabel,
    required this.emailLabel,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    Widget option(bool phone, IconData icon, String label) {
      final selected = phone == byPhone;
      return Expanded(
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? AppColors.surface : Colors.transparent,
            elevation: selected ? 1 : 0,
            shadowColor: Colors.black26,
            borderRadius: BorderRadius.circular(11),
            child: InkWell(
              borderRadius: BorderRadius.circular(11),
              onTap: () => onChange(phone),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 11),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon,
                        size: 18,
                        color:
                            selected ? AppColors.primary : AppColors.textDim),
                    const SizedBox(width: 8),
                    Text(label,
                        style: AppText.body(15,
                            weight:
                                selected ? FontWeight.w700 : FontWeight.w500,
                            color:
                                selected ? AppColors.text : AppColors.textDim)),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(children: [
        option(true, Icons.phone_android, phoneLabel),
        const SizedBox(width: 4),
        option(false, Icons.mail_outline, emailLabel),
      ]),
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
