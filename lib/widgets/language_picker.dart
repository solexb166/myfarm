import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../services/languages.dart';
import '../theme/app_theme.dart';

/// The list of languages, each named in its own language. Languages that
/// aren't translated yet are shown as coming soon and can't be picked.
class LanguageList extends StatelessWidget {
  final String selected;
  final String uiLang;
  final ValueChanged<String> onPick;
  const LanguageList(
      {super.key,
      required this.selected,
      required this.uiLang,
      required this.onPick});

  @override
  Widget build(BuildContext context) {
    final t = L10n(uiLang);
    return Column(children: [
      for (final (i, l) in Languages.all.indexed) ...[
        if (i > 0) const Divider(height: 1, indent: 16, endIndent: 16),
        ListTile(
          enabled: l.ready,
          onTap: () => onPick(l.code),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16),
          minTileHeight: 58,
          title: Text(l.name,
              style: AppText.body(16,
                  weight: FontWeight.w600,
                  color: l.ready ? AppColors.text : AppColors.textDim)),
          subtitle: l.name == l.english && l.ready
              ? null
              : Text(l.ready ? l.english : '${l.english} · ${t.get('langSoon')}',
                  style: AppText.body(13, color: AppColors.textDim)),
          trailing: l.code == selected
              ? const Icon(Icons.check_circle, color: AppColors.primary)
              : Icon(Icons.circle_outlined,
                  color: l.ready ? AppColors.border : Colors.transparent),
        ),
      ],
    ]);
  }
}

/// Bottom sheet to change the language. Returns the chosen code, or null.
Future<String?> showLanguageSheet(BuildContext context, String current) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppColors.surface,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(L10n(current).get('language'),
                  style: AppText.display(20, weight: FontWeight.w700)),
            ),
            LanguageList(
              selected: current,
              uiLang: current,
              onPick: (code) => Navigator.pop(ctx, code),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Compact language button for screen headers: a globe and the language's
/// short code. Opens [showLanguageSheet].
class LangButton extends StatelessWidget {
  final String lang;
  final ValueChanged<String> onChange;
  const LangButton({super.key, required this.lang, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: const StadiumBorder(side: BorderSide(color: AppColors.border)),
      child: InkWell(
        customBorder: const StadiumBorder(),
        onTap: () async {
          final picked = await showLanguageSheet(context, lang);
          if (picked != null && picked != lang) onChange(picked);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.language, size: 17, color: AppColors.textDim),
            const SizedBox(width: 5),
            Text(Languages.of(lang).short,
                style: AppText.body(13, weight: FontWeight.w700)),
            const Icon(Icons.expand_more, size: 16, color: AppColors.textDim),
          ]),
        ),
      ),
    );
  }
}
