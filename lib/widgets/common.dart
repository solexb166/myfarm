import 'package:flutter/material.dart';
import '../services/l10n.dart';
import '../theme/app_theme.dart';

/// "Built by Afrotym" with the Afrotym mark, for footers and About.
class AfrotymCredit extends StatelessWidget {
  final String lang;
  final double size;
  const AfrotymCredit({super.key, required this.lang, this.size = 13});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/brand/afrotym_mark.png',
          width: size * 1.4, height: size * 1.4),
      const SizedBox(width: 6),
      Text(L10n(lang).get('builtBy'),
          style: AppText.body(size,
              weight: FontWeight.w600, color: AppColors.textDim)),
    ]);
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
      padding: EdgeInsets.fromLTRB(back == null ? 16 : 6, 12, 12, 6),
      child: Row(children: [
        if (back != null) ...[
          IconButton(
            onPressed: back,
            visualDensity: VisualDensity.compact,
            icon: Icon(Icons.arrow_back,
                color: AppColors.text,
                semanticLabel:
                    MaterialLocalizations.of(context).backButtonTooltip),
          ),
          const SizedBox(width: 4),
        ],
        Expanded(
          child: Text(title,
              style: AppText.display(21, weight: FontWeight.w800),
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
  final String? prefixText;
  final bool enabled;
  final bool autofocus;
  final bool obscure;
  const AppTextField({
    super.key,
    required this.controller,
    required this.hint,
    this.onChanged,
    this.onSubmitted,
    this.keyboardType,
    this.autofillHints,
    this.icon,
    this.prefixText,
    this.enabled = true,
    this.autofocus = false,
    this.obscure = false,
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
      obscureText: obscure,
      autocorrect: false,
      style: AppText.body(16, color: AppColors.cream),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(15, color: AppColors.creamDim),
        // A prefix (like +256) sits next to the icon and always shows;
        // InputDecoration.prefixText would hide it until the field is used.
        prefixIcon: icon == null
            ? null
            : prefixText == null
                ? Icon(icon, size: 20, color: AppColors.creamDim)
                : Padding(
                    padding: const EdgeInsets.only(left: 12, right: 4),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(icon, size: 20, color: AppColors.creamDim),
                      const SizedBox(width: 10),
                      Text(prefixText!,
                          style: AppText.body(16, color: AppColors.cream)),
                    ]),
                  ),
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

/// Small grey heading above a [SettingsGroup], with an optional action
/// on the right (e.g. "See all").
class SettingsHeader extends StatelessWidget {
  final String text;
  final String? action;
  final VoidCallback? onAction;
  const SettingsHeader(this.text, {super.key, this.action, this.onAction});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 18, 8, 4),
        child: SizedBox(
          height: 30,
          child: Row(children: [
            Expanded(
              child: Text(text.toUpperCase(),
                  style: AppText.body(12,
                          weight: FontWeight.w700, color: AppColors.textDim)
                      .copyWith(letterSpacing: 0.6)),
            ),
            if (action != null)
              TextButton(
                onPressed: onAction,
                style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    foregroundColor: AppColors.primary),
                child: Text(action!,
                    style: AppText.body(13.5,
                        weight: FontWeight.w600, color: AppColors.primary)),
              ),
          ]),
        ),
      );
}

/// Rows separated by thin lines, flat on the page (no card around them),
/// like a phone's settings app. [indent] lines the dividers up with the
/// row text.
class SettingsGroup extends StatelessWidget {
  final List<Widget> children;
  final double indent;
  const SettingsGroup({super.key, required this.children, this.indent = 56});

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      for (final (i, c) in children.indexed) ...[
        if (i > 0) Divider(height: 1, indent: indent),
        c,
      ],
    ]);
  }
}

/// One row: a leading icon or picture, title, optional detail line, and a
/// value or arrow on the right.
class SettingsRow extends StatelessWidget {
  final Widget leading;
  final double leadingWidth;
  final String title;
  final String? sub;
  final Widget? subWidget;
  final String? value;
  final IconData? trailing;
  final Color? trailingColor;
  final Color? color;
  final Color? background;
  final int subLines;
  final VoidCallback? onTap;
  const SettingsRow({
    super.key,
    required this.leading,
    this.leadingWidth = 24,
    required this.title,
    this.sub,
    this.subWidget,
    this.value,
    this.trailing = Icons.chevron_right,
    this.trailingColor,
    this.color,
    this.background,
    this.subLines = 1,
    this.onTap,
  });

  /// [SettingsRow] with a plain icon.
  SettingsRow.icon(
    IconData icon, {
    Key? key,
    required String title,
    String? sub,
    String? value,
    IconData? trailing = Icons.chevron_right,
    Color? color,
    VoidCallback? onTap,
  }) : this(
          key: key,
          leading: Icon(icon, size: 22, color: color ?? AppColors.textDim),
          title: title,
          sub: sub,
          value: value,
          trailing: trailing,
          color: color,
          onTap: onTap,
        );

  @override
  Widget build(BuildContext context) {
    return Material(
      color: background ?? Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 9, 10, 9),
            child: Row(children: [
              SizedBox(width: leadingWidth, child: Center(child: leading)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(15.5,
                            weight: FontWeight.w600,
                            color: color ?? AppColors.text)),
                    if (sub != null)
                      Text(sub!,
                          maxLines: subLines,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.body(13, color: AppColors.textDim)),
                    if (subWidget != null) ...[
                      const SizedBox(height: 3),
                      subWidget!,
                    ],
                  ],
                ),
              ),
              if (value != null) ...[
                const SizedBox(width: 8),
                Text(value!,
                    style: AppText.body(14.5, color: AppColors.textDim)),
              ],
              if (trailing != null) ...[
                const SizedBox(width: 2),
                Icon(trailing,
                    size: 20, color: trailingColor ?? AppColors.textDim),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

/// Small rounded square with a tinted icon, for list rows.
class RowIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color? bg;
  const RowIcon(this.icon,
      {super.key, this.color = AppColors.primary, this.bg});

  @override
  Widget build(BuildContext context) => Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: bg ?? color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 19, color: color),
      );
}
