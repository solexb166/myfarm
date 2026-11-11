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
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                  child: Column(children: [
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      const IconTile(icon: Icons.eco, size: 36),
                      const SizedBox(width: 10),
                      Text(t.get('appName'), style: AppText.display(21)),
                    ]),
                    const SizedBox(height: 10),
                    Text(t.get('aboutBody'),
                        textAlign: TextAlign.center,
                        style: AppText.body(14, color: AppColors.textDim)),
                    const SizedBox(height: 22),
                    Text(t.get('builtByShort'),
                        style: AppText.body(12,
                            weight: FontWeight.w600, color: AppColors.textDim)),
                    const SizedBox(height: 6),
                    Image.asset('assets/brand/afrotym.png', height: 84),
                  ]),
                ),
                const SizedBox(height: 12),
                const Divider(height: 1),
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
                const Divider(height: 1),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
