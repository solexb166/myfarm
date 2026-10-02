import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// EN / LUG pill toggle.
class LangToggle extends StatelessWidget {
  final String lang;
  final ValueChanged<String> onChange;
  const LangToggle({super.key, required this.lang, required this.onChange});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(999),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final l in const ['en', 'lg'])
            GestureDetector(
              onTap: () => onChange(l),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: lang == l ? AppColors.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l == 'en' ? 'EN' : 'LUG',
                  style: AppText.body(12,
                      weight: FontWeight.w700,
                      color:
                          lang == l ? AppColors.onPrimary : AppColors.textDim),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Titled card for one part of the advice (cause, treatment, prevention).
class InfoBlock extends StatelessWidget {
  final IconData icon;
  final String label;
  final String text;
  final Color? tint;
  const InfoBlock(
      {super.key,
      required this.icon,
      required this.label,
      required this.text,
      this.tint});

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? AppColors.textDim;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(icon, size: 17, color: accent),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(label,
                  style: AppText.body(15.5, weight: FontWeight.w700)),
            ),
          ]),
          const SizedBox(height: 10),
          Text(text, style: AppText.body(15, color: AppColors.text)),
        ],
      ),
    );
  }
}

/// Screen title with a back button. Without [onBack] the button pops the
/// route, and it is hidden when there is nothing to go back to (e.g. the
/// screen is a tab).
class TopBar extends StatelessWidget {
  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  const TopBar({super.key, required this.title, this.onBack, this.trailing});

  @override
  Widget build(BuildContext context) {
    final back = onBack ??
        (Navigator.of(context).canPop()
            ? () => Navigator.of(context).maybePop()
            : null);
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Row(children: [
        if (back != null) ...[
          Material(
            color: AppColors.surface,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: AppColors.border),
            ),
            child: InkWell(
              onTap: back,
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 42,
                height: 42,
                child: Icon(Icons.arrow_back,
                    size: 20,
                    color: AppColors.text,
                    semanticLabel:
                        MaterialLocalizations.of(context).backButtonTooltip),
              ),
            ),
          ),
          const SizedBox(width: 14),
        ],
        Expanded(
          child: Text(title,
              style: AppText.display(22, weight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
        ),
        if (trailing != null) trailing!,
      ]),
    );
  }
}

/// Primary big button with optional loading state.
class BigButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final bool loading;
  final Color color;
  final Color fg;
  const BigButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onTap,
    this.loading = false,
    this.color = AppColors.leaf,
    this.fg = AppColors.soil,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 17),
        decoration: BoxDecoration(
          color: enabled ? color : AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(17),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2.4, color: enabled ? fg : AppColors.creamDim),
              )
            else
              Icon(icon, size: 20, color: enabled ? fg : AppColors.creamDim),
            const SizedBox(width: 9),
            Text(label,
                style: AppText.display(17,
                    weight: FontWeight.w700,
                    color: enabled ? fg : AppColors.creamDim,
                    spacing: 0)),
          ],
        ),
      ),
    );
  }
}

/// Bold label above a form field.
class FieldLabel extends StatelessWidget {
  final String text;
  const FieldLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child:
            Text(text, style: AppText.display(14.5, weight: FontWeight.w700)),
      );
}

/// Text input in the app's card style.
class AppTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final IconData? icon;
  final bool enabled;
  final bool autofocus;
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.autofillHints,
    this.icon,
    this.enabled = true,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      keyboardType: keyboardType,
      autofillHints: autofillHints,
      enabled: enabled,
      autofocus: autofocus,
      autocorrect: false,
      style: AppText.body(16, color: AppColors.cream),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(15, color: AppColors.creamDim),
        prefixIcon: icon == null
            ? null
            : Icon(icon, size: 20, color: AppColors.creamDim),
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        disabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

/// Inline message strip, e.g. for errors or confirmations.
class Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const Notice(
      {super.key,
      required this.icon,
      required this.text,
      this.color = AppColors.rust});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, size: 19, color: color),
        const SizedBox(width: 10),
        Expanded(
            child: Text(text, style: AppText.body(14, color: AppColors.cream))),
      ]),
    );
  }
}

/// Rounded leaf-green square holding an icon.
class IconTile extends StatelessWidget {
  final IconData icon;
  final double size;
  const IconTile({super.key, required this.icon, this.size = 56});

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

/// Small icon + text button, e.g. "Send a new code".
class TextLink extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const TextLink(
      {super.key, required this.icon, required this.label, this.onTap});

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
