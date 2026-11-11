import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../services/links.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// About MY FARM: who builds it (Afrotym), how to reach support, and the
/// privacy policy.
class AboutScreen extends StatelessWidget {
  final String lang;
  const AboutScreen({super.key, required this.lang});

  Future<void> _open(BuildContext context, String url) async {
    if (await Links.open(url) || !context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(L10n(lang).get('noBrowser').replaceAll('{url}', url))));
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n(lang);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('about')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const IconTile(icon: Icons.eco, size: 40),
                      const SizedBox(width: 10),
                      Text(t.get('appName'), style: AppText.display(22)),
                    ]),
                    const SizedBox(height: 12),
                    Text(t.get('aboutBody'),
                        textAlign: TextAlign.center,
                        style: AppText.body(14.5, color: AppColors.textDim)),
                    const SizedBox(height: 22),
                    const Divider(height: 1),
                    const SizedBox(height: 18),
                    Text(t.get('builtByShort'),
                        style: AppText.body(12.5,
                            weight: FontWeight.w600,
                            color: AppColors.textDim)),
                    const SizedBox(height: 10),
                    Image.asset('assets/brand/afrotym.png', height: 96),
                  ]),
                ),
                const SizedBox(height: 16),
                SettingsGroup(children: [
                  SettingsRow.icon(Icons.public,
                      title: t.get('website'),
                      sub: 'afrotym.co',
                      trailing: Icons.open_in_new,
                      onTap: () => _open(context, Links.afrotym)),
                  SettingsRow.icon(Icons.mail_outline,
                      title: t.get('support'),
                      sub: Links.supportEmail,
                      trailing: Icons.open_in_new,
                      onTap: () =>
                          _open(context, 'mailto:${Links.supportEmail}')),
                  SettingsRow.icon(Icons.privacy_tip_outlined,
                      title: t.get('privacyPolicy'),
                      trailing: Icons.open_in_new,
                      onTap: () => _open(context, Links.privacyPolicy)),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
