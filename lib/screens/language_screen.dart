import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/language_picker.dart';

/// First launch: pick the app's language before signing in. The screen
/// switches to the picked language straight away.
class LanguageScreen extends StatefulWidget {
  final String initial;
  final ValueChanged<String> onDone;
  const LanguageScreen(
      {super.key, required this.initial, required this.onDone});

  @override
  State<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends State<LanguageScreen> {
  late String _lang = widget.initial;

  @override
  Widget build(BuildContext context) {
    final t = L10n(_lang);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(top: 16, bottom: 16),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          const IconTile(icon: Icons.eco, size: 32),
                          const SizedBox(width: 10),
                          Text(t.get('appName'),
                              style: AppText.display(17, spacing: 0.2)),
                        ]),
                        const SizedBox(height: 24),
                        Text(t.get('chooseLanguage'),
                            style:
                                AppText.display(24, weight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(t.get('chooseLanguageSub'),
                            style: AppText.body(14, color: AppColors.textDim)),
                      ]),
                ),
                const Divider(height: 1),
                LanguageList(
                  selected: _lang,
                  uiLang: _lang,
                  onPick: (code) => setState(() => _lang = code),
                ),
                const Divider(height: 1),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(children: [
              BigButton(
                label: t.get('continue'),
                icon: Icons.arrow_forward,
                onTap: () => widget.onDone(_lang),
              ),
              const SizedBox(height: 12),
              AfrotymCredit(lang: _lang),
            ]),
          ),
        ]),
      ),
    );
  }
}
