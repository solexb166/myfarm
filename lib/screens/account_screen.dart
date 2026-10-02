import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/backend.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'sign_in_screen.dart' show accountErrorKey;

/// The signed-in farmer's account: name, backup status and sign-out.
/// (Signing in happens on [SignInScreen], before the app opens.)
class AccountScreen extends StatefulWidget {
  final String lang;
  const AccountScreen({super.key, required this.lang});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final L10n t = L10n(widget.lang);
  final _nameCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  String _savedName = '';
  bool _nameSaved = false;
  int _pending = 0;
  bool _syncing = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    _pending = await Storage.pendingScanCount();
    if (mounted) setState(() {});
    final name = await Backend.loadDisplayName() ?? '';
    if (!mounted) return;
    setState(() {
      _savedName = name;
      _nameCtrl.text = name;
    });
  }

  /// Run an account action with a spinner, showing any error inline.
  Future<void> _run(Future<void> Function() action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
    } on AccountError catch (e) {
      if (mounted) setState(() => _error = t.get(accountErrorKey(e)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
    // AppGate now shows the sign-in screen underneath; close everything above it.
    if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final account = Backend.account;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('account')),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(22, 12, 22, 32),
              child: _buildAccount(account?.email ?? ''),
            ),
          ),
        ]),
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
            const IconTile(icon: Icons.person_outline, size: 48),
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
