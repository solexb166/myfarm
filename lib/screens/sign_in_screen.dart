import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

/// Phone (SMS) sign-in is switched off until the SMS sender is set up; the
/// screen then offers email only. Turn it on with
/// --dart-define=PHONE_SIGN_IN=true (see supabase/README.md, Phone sign-in).
const phoneSignIn = bool.fromEnvironment('PHONE_SIGN_IN');

class _SignInScreenState extends State<SignInScreen> {
  static const _resendSeconds = 60;

  L10n get t => L10n(widget.lang);
  final _phoneCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  Timer? _resendTimer;

  // Phone first when available: most farmers have a phone number, fewer
  // use email.
  bool _byPhone = phoneSignIn;
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
    if (_busy) return; // the 6th digit and Enter can both submit
    final code = _codeCtrl.text.replaceAll(RegExp(r'\D'), '');
    if (code.length < 6) {
      setState(() => _errorKey = 'errCode');
      return;
    }
    // On success AppGate replaces this screen with the home screen.
    await _run(() => _byPhone
        ? Backend.verifyPhoneCode(_sentTo!, code)
        : Backend.verifyEmailCode(_sentTo!, code));
    // Wrong code: empty the box so it can be typed again.
    if (mounted && _errorKey == 'errCode') _codeCtrl.clear();
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
    return PopScope(
      // Back from the code step returns to the number / email step.
      canPop: !sent,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _changeAddress();
      },
      child: Scaffold(
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: ConstrainedBox(
                // Fill the screen so the footer sits at the bottom.
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),
                        _header(),
                        const SizedBox(height: 44),
                        ...(sent ? _codeStep() : _addressStep()),
                        if (_errorKey != null) ...[
                          const SizedBox(height: 14),
                          Notice(
                              icon: Icons.error_outline,
                              text: t.get(_errorKey!)),
                        ],
                        const SizedBox(height: 20),
                        BigButton(
                          label: sent ? t.get('verify') : t.get('sendCode'),
                          icon: sent ? Icons.login : Icons.arrow_forward,
                          loading: _busy,
                          onTap: sent ? _verify : _sendCode,
                        ),
                        if (sent) _resendRow(),
                        const Spacer(),
                        const SizedBox(height: 32),
                        _footer(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Logo and name on the left, language on the right.
  Widget _header() => Row(children: [
        const IconTile(icon: Icons.eco, size: 36),
        const SizedBox(width: 10),
        Text(t.get('appName'),
            style: AppText.display(18, weight: FontWeight.w800, spacing: 0)),
        const Spacer(),
        LangToggle(lang: widget.lang, onChange: widget.onLang),
      ]);

  /// Step 1: phone number or email (email only while [phoneSignIn] is off).
  List<Widget> _addressStep() => [
        Text(t.get('signInTitle'), style: AppText.display(30)),
        const SizedBox(height: 8),
        Text(t.get(phoneSignIn ? 'signInSub' : 'signInSubEmail'),
            style: AppText.body(15.5, color: AppColors.textDim)),
        const SizedBox(height: 28),
        if (phoneSignIn) ...[
          _MethodSwitch(
            byPhone: _byPhone,
            phoneLabel: t.get('phone'),
            emailLabel: t.get('emailTab'),
            onChange: _setMethod,
          ),
          const SizedBox(height: 16),
        ],
        if (_byPhone)
          AppTextField(
            key: const ValueKey('phone'),
            controller: _phoneCtrl,
            hint: t.get('phonePh'),
            icon: Icons.phone_android,
            prefixText: '+256',
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumberNational],
            onSubmitted: (_) => _sendCode(),
          )
        else
          AppTextField(
            key: const ValueKey('email'),
            controller: _emailCtrl,
            hint: t.get('emailPh'),
            icon: Icons.mail_outline,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _sendCode(),
          ),
      ];

  /// Step 2: the 6-digit code. Signs in by itself once 6 digits are in.
  List<Widget> _codeStep() {
    final to = _byPhone ? Backend.formatPhone(_sentTo!) : _sentTo!;
    return [
      Text(t.get('codeTitle'), style: AppText.display(30)),
      const SizedBox(height: 8),
      Text.rich(
        TextSpan(
          text: t
              .get(_byPhone ? 'codeSentSms' : 'codeSentEmail')
              .replaceAll('{to}', to),
          style: AppText.body(15.5, color: AppColors.textDim),
          children: [
            const TextSpan(text: '  '),
            WidgetSpan(
              alignment: PlaceholderAlignment.baseline,
              baseline: TextBaseline.alphabetic,
              child: _InlineLink(
                label: t.get('change'),
                onTap: _busy ? null : _changeAddress,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 28),
      _CodeField(
        controller: _codeCtrl,
        enabled: !_busy,
        onComplete: _verify,
      ),
    ];
  }

  Widget _resendRow() => Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(t.get('noCode'),
                style: AppText.body(14, color: AppColors.textDim)),
            const SizedBox(width: 6),
            _resendIn > 0
                ? Text(t.get('resendIn').replaceAll('{s}', '$_resendIn'),
                    style: AppText.body(14,
                        weight: FontWeight.w600, color: AppColors.textDim))
                : _InlineLink(
                    label: t.get('resend'),
                    onTap: _busy ? null : _sendCode,
                  ),
          ],
        ),
      );

  /// Small print at the bottom: offline note and privacy policy.
  Widget _footer() => Column(children: [
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const Icon(Icons.wifi_off, size: 15, color: AppColors.textDim),
          const SizedBox(width: 6),
          Flexible(
            child: Text(t.get('onlineOnceShort'),
                textAlign: TextAlign.center,
                style: AppText.body(13, color: AppColors.textDim)),
          ),
        ]),
        const SizedBox(height: 6),
        _InlineLink(
          label: t.get('privacyPolicy'),
          small: true,
          onTap: () => Links.open(Links.privacyPolicy),
        ),
      ]);
}

/// Text that acts as a link, in the primary colour.
class _InlineLink extends StatelessWidget {
  final String label;
  final VoidCallback? onTap;
  final bool small;
  const _InlineLink({required this.label, this.onTap, this.small = false});

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.textDim : AppColors.primary;
    return Semantics(
      link: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
          child: Text(label,
              style: AppText.body(small ? 13 : 15,
                      weight: FontWeight.w700, color: color)
                  .copyWith(
                      decoration: small ? TextDecoration.underline : null,
                      decorationColor: color)),
        ),
      ),
    );
  }
}

/// Large, centred box for the 6-digit code. Calls [onComplete] as soon as
/// the sixth digit is typed (or pasted, or filled in from the SMS).
class _CodeField extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;
  final VoidCallback onComplete;
  const _CodeField({
    required this.controller,
    required this.enabled,
    required this.onComplete,
  });

  @override
  Widget build(BuildContext context) {
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: AppColors.border),
    );
    return TextField(
      controller: controller,
      enabled: enabled,
      autofocus: true,
      keyboardType: TextInputType.number,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(6),
      ],
      textAlign: TextAlign.center,
      style: AppText.display(30, weight: FontWeight.w700, spacing: 12),
      onChanged: (v) {
        if (v.length == 6) onComplete();
      },
      onSubmitted: (_) => onComplete(),
      decoration: InputDecoration(
        hintText: '••••••',
        hintStyle: AppText.display(30,
            weight: FontWeight.w700, color: AppColors.border, spacing: 12),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: border,
        disabledBorder: border,
        focusedBorder: border.copyWith(
            borderSide: const BorderSide(color: AppColors.primary, width: 1.5)),
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
      AccountError.server => 'errServer',
      AccountError.failed => 'errGeneric',
    };
