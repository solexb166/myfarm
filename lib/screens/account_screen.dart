import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/backend.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import '../widgets/common.dart';

/// Email sign-in (code by email, no password) and the signed-in account
/// view: name, backup status and sign-out. Signing in is optional; the rest
/// of the app works the same without it.
class AccountScreen extends StatefulWidget {
  final String lang;
  const AccountScreen({super.key, required this.lang});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  static const _resendSeconds = 60;

  late final L10n t = L10n(widget.lang);
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  StreamSubscription<void>? _accountSub;
  Timer? _resendTimer;

  // Signing in
  String? _sentTo; // email the code was sent to; null while entering email
  int _resendIn = 0;
  bool _busy = false;
  String? _error;

  // Signed in
  String _savedName = '';
  bool _nameSaved = false;
  int _pending = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _accountSub = Backend.accountChanges.listen((_) => _refresh());
    _refresh();
  }

  @override
  void dispose() {
    _accountSub?.cancel();
    _resendTimer?.cancel();
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    if (Backend.account == null) {
      if (mounted) setState(() {});
      return;
    }
    _pending = await Storage.pendingScanCount();
    if (mounted) setState(() {});
    final name = await Backend.loadDisplayName() ?? '';
    if (!mounted) return;
    setState(() {
      _savedName = name;
      _nameCtrl.text = name;
    });
  }

  String _message(AccountError e) => t.get(switch (e) {
        AccountError.offline => 'errOffline',
        AccountError.wrongCode => 'errCode',
        AccountError.tooManyTries => 'errTooMany',
        AccountError.failed => 'errGeneric',
      });

  /// Run an account action with a spinner, showing any error inline.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AccountError catch (e) {
      if (mounted) setState(() => _error = _message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (!Backend.looksLikeEmail(email)) {
      setState(() => _error = t.get('errEmail'));
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
      setState(() => _error = t.get('errCode'));
      return;
    }
    await _run(() async {
      await Backend.verifyEmailCode(_sentTo!, code);
      _resendTimer?.cancel();
      _sentTo = null;
      await _refresh();
    });
  }

  void _changeEmail() {
    _resendTimer?.cancel();
    setState(() {
      _sentTo = null;
      _error = null;
      _resendIn = 0;
    });
  }

  Future<void> _saveName() async {
    final name = _nameCtrl.text.trim();
    await _run(() async {
      await Backend.saveDisplayName(name);
      if (!mounted) return;
      setState(() {
        _savedName = name;
        _nameSaved = true;
      });
    });
  }

  Future<void> _backUpNow() async {
    setState(() => _syncing = true);
    await Backend.sync();
    final pending = await Storage.pendingScanCount();
    if (!mounted) return;
    setState(() {
      _pending = pending;
      _syncing = false;
    });
  }

  Future<void> _signOut() async {
    // Give unsaved scans one last chance to upload before warning about them.
    if (_pending > 0) await _backUpNow();
    if (!mounted) return;
    final pending = _pending;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.card,
        title: Text(t.get('signOutTitle'),
            style: AppText.display(20, weight: FontWeight.w700)),
        content: Text(
          pending > 0
              ? t.get('signOutPending').replaceAll('{n}', '$pending')
              : t.get('signOutBody'),
          style: AppText.body(15, color: AppColors.creamDim),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.get('cancel'),
                style: AppText.body(15,
                    weight: FontWeight.w600, color: AppColors.cream)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(pending > 0 ? t.get('signOutAnyway') : t.get('signOut'),
                style: AppText.body(15,
                    weight: FontWeight.w700, color: AppColors.rust)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await Backend.signOut();
    if (!mounted) return;
    setState(() {
      _savedName = '';
      _nameCtrl.clear();
      _emailCtrl.clear();
      _pending = 0;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final account = Backend.account;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('account'), onBack: () => Navigator.pop(context)),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
              child: account == null
                  ? _buildSignIn()
                  : _buildAccount(account.email ?? ''),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------- SIGN IN ----------
  Widget _buildSignIn() {
    final sent = _sentTo != null;
    return AutofillGroup(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _IconTile(icon: Icons.cloud_sync_outlined),
          const SizedBox(height: 18),
          Text(t.get('accountTitle'), style: AppText.display(26)),
          const SizedBox(height: 8),
          Text(t.get('accountSub'),
              style: AppText.body(15, color: AppColors.creamDim)),
          const SizedBox(height: 26),
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
          if (_error != null) ...[
            const SizedBox(height: 14),
            Notice(icon: Icons.error_outline, text: _error!),
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
              _TextLink(
                icon: Icons.refresh,
                label: _resendIn > 0
                    ? t.get('resendIn').replaceAll('{s}', '$_resendIn')
                    : t.get('resend'),
                onTap: _resendIn > 0 || _busy ? null : _sendCode,
              ),
              _TextLink(
                icon: Icons.edit_outlined,
                label: t.get('changeEmail'),
                onTap: _busy ? null : _changeEmail,
              ),
            ]),
          ],
        ],
      ),
    );
  }

  // ---------- SIGNED IN ----------
  Widget _buildAccount(String email) {
    final nameChanged = _nameCtrl.text.trim() != _savedName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _Card(
          child: Row(children: [
            const _IconTile(icon: Icons.person_outline, size: 48),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _savedName.isEmpty ? t.get('addName') : _savedName,
                    style: AppText.display(19, weight: FontWeight.w700),
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text('${t.get('signedInAs')} $email',
                      style: AppText.body(13.5, color: AppColors.creamDim),
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ]),
        ),
        const SizedBox(height: 22),
        FieldLabel(t.get('yourName')),
        AppTextField(
          controller: _nameCtrl,
          hint: t.get('namePh'),
          icon: Icons.badge_outlined,
          autofillHints: const [AutofillHints.name],
          onChanged: (_) => setState(() => _nameSaved = false),
          onSubmitted: (_) => nameChanged ? _saveName() : null,
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Notice(icon: Icons.error_outline, text: _error!),
        ] else if (_nameSaved) ...[
          const SizedBox(height: 12),
          Notice(
              icon: Icons.check_circle_outline,
              color: AppColors.leaf,
              text: t.get('saved')),
        ],
        if (nameChanged) ...[
          const SizedBox(height: 12),
          BigButton(
            label: t.get('save'),
            icon: Icons.check,
            loading: _busy,
            color: AppColors.gold,
            onTap: _saveName,
          ),
        ],
        const SizedBox(height: 26),
        FieldLabel(t.get('backup')),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                  _pending == 0
                      ? Icons.cloud_done_outlined
                      : Icons.cloud_upload_outlined,
                  size: 24,
                  color: _pending == 0 ? AppColors.leaf : AppColors.gold,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _pending == 0
                        ? t.get('syncAll')
                        : t.get('syncPending').replaceAll('{n}', '$_pending'),
                    style: AppText.body(15.5, weight: FontWeight.w600),
                  ),
                ),
              ]),
              if (_pending > 0) ...[
                const SizedBox(height: 6),
                Padding(
                  padding: const EdgeInsets.only(left: 36),
                  child: Text(t.get('syncPendingSub'),
                      style: AppText.body(13.5, color: AppColors.creamDim)),
                ),
                const SizedBox(height: 14),
                BigButton(
                  label: t.get('syncNow'),
                  icon: Icons.sync,
                  loading: _syncing,
                  onTap: _backUpNow,
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 32),
        _OutlineButton(
          icon: Icons.logout,
          label: t.get('signOut'),
          color: AppColors.rust,
          onTap: _busy || _syncing ? null : _signOut,
        ),
      ],
    );
  }
}

class _IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const _IconTile({required this.icon, this.size = 56});

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.leaf,
          borderRadius: BorderRadius.circular(size * 0.29),
        ),
        child: Icon(icon, size: size * 0.48, color: AppColors.soil),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.line),
        ),
        child: child,
      );
}

class _TextLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _TextLink({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? AppColors.creamDim : AppColors.gold;
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: color),
      label: Text(label,
          style: AppText.body(14, weight: FontWeight.w600, color: color)),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _OutlineButton(
      {required this.icon,
      required this.label,
      required this.color,
      this.onTap});

  @override
  Widget build(BuildContext context) {
    final c = onTap == null ? AppColors.creamDim : color;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: c.withValues(alpha: 0.6)),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 19, color: c),
          const SizedBox(width: 9),
          Text(label,
              style: AppText.display(16,
                  weight: FontWeight.w700, color: c, spacing: 0)),
        ]),
      ),
    );
  }
}
