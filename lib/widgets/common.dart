import 'package:flutter/material.dart';
import 'dart:math' as math;
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
        color: Colors.black.withOpacity(0.3),
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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: lang == l ? AppColors.gold : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  l == 'en' ? 'EN' : 'LUG',
                  style: AppText.body(12,
                      weight: FontWeight.w700,
                      color: lang == l ? AppColors.soil : AppColors.creamDim),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Animated circular confidence indicator.
class ConfidenceRing extends StatelessWidget {
  final int pct;
  const ConfidenceRing({super.key, required this.pct});

  @override
  Widget build(BuildContext context) {
    final col = pct >= 80
        ? AppColors.leaf
        : pct >= 55
            ? AppColors.gold
            : AppColors.rust;
    return SizedBox(
      width: 52,
      height: 52,
      child: Stack(
        alignment: Alignment.center,
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: pct / 100),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, __) => CustomPaint(
              size: const Size(52, 52),
              painter: _RingPainter(v, col),
            ),
          ),
          Text('$pct%',
              style: AppText.display(14, weight: FontWeight.w700, color: col)),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;
  _RingPainter(this.progress, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    const r = 22.0;
    final track = Paint()
      ..color = AppColors.line
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5;
    final fg = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(c, r, track);
    canvas.drawArc(Rect.fromCircle(center: c, radius: r), -math.pi / 2,
        2 * math.pi * progress, false, fg);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// Titled card block for diagnosis sections.
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
    final accent = tint ?? AppColors.creamDim;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tint?.withOpacity(0.19) ?? AppColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 17, color: tint ?? AppColors.leafBright),
            const SizedBox(width: 8),
            Text(label.toUpperCase(),
                style: AppText.display(13,
                    weight: FontWeight.w700, color: accent, spacing: 0.3)),
          ]),
          const SizedBox(height: 7),
          Text(text, style: AppText.body(15, color: AppColors.cream)),
        ],
      ),
    );
  }
}

/// Sticky back-bar with title.
class TopBar extends StatelessWidget {
  final String title;
  final VoidCallback onBack;
  const TopBar({super.key, required this.title, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 20, 22, 8),
      child: Row(children: [
        GestureDetector(
          onTap: onBack,
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AppColors.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.line),
            ),
            child: const Icon(Icons.arrow_back, size: 20, color: AppColors.cream),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(title,
              style: AppText.display(21, weight: FontWeight.w800),
              overflow: TextOverflow.ellipsis),
        ),
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
          color: enabled ? color : AppColors.card,
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
