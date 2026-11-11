import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/areas.dart';
import '../services/backend.dart';
import '../services/location.dart';
import '../services/l10n.dart';
import '../services/links.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import '../services/languages.dart';
import '../widgets/language_picker.dart';
import 'about_screen.dart';
import 'location_screens.dart';
import 'sign_in_screen.dart' show accountErrorKey;

/// The signed-in farmer's account: name, backup status, location choice,
/// privacy (policy and account deletion) and sign-out.
/// (Signing in happens on [SignInScreen], before the app opens.)
class AccountScreen extends StatefulWidget {
  final String lang;
  final ValueChanged<String> onLang;
  const AccountScreen({super.key, required this.lang, required this.onLang});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  late final L10n t = L10n(widget.lang);
  final _nameCtrl = TextEditingController();

  bool _busy = false;
  String? _error;
  String _savedName = '';
  LocationMode? _locMode;
  String? _homeArea; // 'Mbale · Bufumbo'
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
    _locMode = LocationMode.parse(await Storage.getLocationMode());
    final district = await Areas.byId(await Storage.getHomeDistrict());
    final sub = await Storage.getHomeSubcounty();
    _homeArea = district == null
        ? null
        : [district.name, if (sub != null) sub].join('  ·  ');
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
      setState(() => _savedName = name);
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

  Future<void> _deleteAccount() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('deleteTitle'),
            style: AppText.display(20, weight: FontWeight.w700)),
        content: Text(t.get('deleteBody'),
            style: AppText.body(15, color: AppColors.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.get('cancel'),
                style: AppText.body(15,
                    weight: FontWeight.w600, color: AppColors.text)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.get('deleteConfirm'),
                style: AppText.body(15,
                    weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await Backend.deleteAccount();
    } on AccountError catch (e) {
      // Shown here rather than under the name field, which is far away.
      messenger
          .showSnackBar(SnackBar(content: Text(t.get(accountErrorKey(e)))));
      return;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
    messenger.showSnackBar(SnackBar(content: Text(t.get('deleted'))));
    // AppGate now shows the sign-in screen underneath.
    navigator.popUntil((r) => r.isFirst);
  }

  Future<void> _openPrivacyPolicy() async {
    if (await Links.open(Links.privacyPolicy) || !mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content:
            Text(t.get('noBrowser').replaceAll('{url}', Links.privacyPolicy))));
  }

  Future<void> _changeLocation() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => LocationConsentScreen(lang: widget.lang)));
    Backend.sync();
    _refresh();
  }

  Future<void> _changeLanguage() async {
    final picked = await showLanguageSheet(context, widget.lang);
    if (picked != null && picked != widget.lang) widget.onLang(picked);
  }

  /// Bottom sheet to change the farmer's name.
  Future<void> _editName() async {
    _nameCtrl.text = _savedName;
    final save = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            16, 0, 16, 16 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t.get('editName'),
                style: AppText.display(20, weight: FontWeight.w700)),
            const SizedBox(height: 14),
            AppTextField(
              controller: _nameCtrl,
              hint: t.get('namePh'),
              icon: Icons.badge_outlined,
              autofocus: true,
              autofillHints: const [AutofillHints.name],
              onSubmitted: (_) => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 14),
            BigButton(
              label: t.get('save'),
              icon: Icons.check,
              onTap: () => Navigator.pop(ctx, true),
            ),
          ],
        ),
      ),
    );
    if (save == true && _nameCtrl.text.trim() != _savedName) {
      await _saveName();
      if (mounted && _error == null) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.get('saved'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = Backend.account;
    final signedInAs = account == null ? '' : Backend.accountLabel(account);
    final (locIcon, locKey) = switch (_locMode) {
      LocationMode.gps => (Icons.my_location, 'locStateGps'),
      LocationMode.manual => (Icons.map_outlined, 'locStateManual'),
      LocationMode.none => (Icons.location_off_outlined, 'locStateNone'),
      null => (Icons.location_searching, 'locNotSet'),
    };
    final idle = !_busy && !_syncing;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('account')),
          if (_busy)
            const LinearProgressIndicator(
                minHeight: 2, color: AppColors.primary),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                _profileCard(signedInAs),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Notice(icon: Icons.error_outline, text: _error!),
                ],
                SettingsHeader(t.get('settings')),
                SettingsGroup(children: [
                  SettingsRow.icon(Icons.language,
                      title: t.get('language'),
                      value: Languages.of(widget.lang).name,
                      onTap: _changeLanguage),
                  SettingsRow.icon(locIcon,
                      title: t.get(locKey),
                      sub: _homeArea != null && _locMode != LocationMode.none
                          ? _homeArea
                          : null,
                      onTap: _changeLocation),
                  SettingsRow(
                    leading: _syncing
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: AppColors.primary))
                        : Icon(
                            _pending == 0
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_upload_outlined,
                            size: 22,
                            color: _pending == 0
                                ? AppColors.primary
                                : AppColors.accent),
                    title: _pending == 0
                        ? t.get('syncAll')
                        : t
                            .get(_pending == 1
                                ? 'syncPendingOne'
                                : 'syncPending')
                            .replaceAll('{n}', '$_pending'),
                    sub: _pending == 0 ? null : t.get('syncNow'),
                    trailing: _pending == 0 ? null : Icons.sync,
                    onTap: _pending == 0 || _syncing ? null : _backUpNow,
                  ),
                ]),
                SettingsHeader(t.get('privacy')),
                SettingsGroup(children: [
                  SettingsRow.icon(Icons.privacy_tip_outlined,
                      title: t.get('privacyPolicy'),
                      trailing: Icons.open_in_new,
                      onTap: _openPrivacyPolicy),
                  SettingsRow.icon(Icons.delete_outline,
                      title: t.get('deleteAccount'),
                      color: AppColors.danger,
                      onTap: idle ? _deleteAccount : null),
                ]),
                SettingsHeader(t.get('about')),
                SettingsGroup(children: [
                  SettingsRow(
                    leading: Image.asset('assets/brand/afrotym_mark.png',
                        width: 24, height: 24),
                    title: t.get('builtBy'),
                    sub: 'afrotym.co',
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => AboutScreen(lang: widget.lang))),
                  ),
                ]),
                const SizedBox(height: 20),
                SettingsGroup(children: [
                  SettingsRow.icon(Icons.logout,
                      title: t.get('signOut'),
                      color: AppColors.danger,
                      trailing: null,
                      onTap: idle ? _signOut : null),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }

  /// Name and sign-in address; tap to change the name.
  Widget _profileCard(String signedInAs) {
    final name = _savedName.trim();
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: _busy ? null : _editName,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: AppColors.primary,
              child: name.isEmpty
                  ? const Icon(Icons.person_outline,
                      color: AppColors.onPrimary)
                  : Text(name.characters.first.toUpperCase(),
                      style: AppText.display(22,
                          weight: FontWeight.w700,
                          color: AppColors.onPrimary)),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(name.isEmpty ? t.get('addName') : name,
                      style: AppText.display(18, weight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(signedInAs,
                      style: AppText.body(13.5, color: AppColors.textDim)),
                ],
              ),
            ),
            const Icon(Icons.edit_outlined,
                size: 20, color: AppColors.textDim),
          ]),
        ),
      ),
    );
  }
}
