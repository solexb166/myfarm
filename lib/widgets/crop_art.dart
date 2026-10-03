import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Picture of a crop. Uses a real photo from assets/crops/<crop>.jpg when
/// one is bundled, and otherwise a flat illustration drawn in code (cassava
/// roots, bean pods, matooke bunch, maize cob; a leaf for anything else).
/// Shown on a rounded tile unless [tile] is false (then a small circle).
class CropArt extends StatelessWidget {
  final String cropKey;
  final double size;
  final bool tile;
  final bool muted;
  const CropArt({
    super.key,
    required this.cropKey,
    this.size = 56,
    this.tile = true,
    this.muted = false,
  });

  /// Where a crop's photo goes. See assets/crops/README.txt.
  static String photoPath(String cropKey) => 'assets/crops/$cropKey.jpg';

  @override
  Widget build(BuildContext context) {
    final radius = tile ? size * 0.28 : size / 2;
    final drawing = _drawing();
    if (cropKey.isEmpty) return drawing;
    final photo = ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        photoPath(cropKey),
        width: size,
        height: size,
        fit: BoxFit.cover,
        // Shrink large photos in memory to the size they're shown at.
        cacheWidth: (size * MediaQuery.devicePixelRatioOf(context)).round(),
        // No photo bundled for this crop: use the drawing.
        errorBuilder: (_, __, ___) => drawing,
        frameBuilder: (_, child, frame, sync) =>
            sync || frame != null ? child : _blank(radius),
      ),
    );
    if (!muted) return photo;
    // "Coming soon" crops: faded and grey.
    return Opacity(
      opacity: 0.55,
      child: ColorFiltered(
        colorFilter: const ColorFilter.matrix(<double>[
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0.2126, 0.7152, 0.0722, 0, 0, //
          0, 0, 0, 1, 0,
        ]),
        child: photo,
      ),
    );
  }

  Widget _blank(double radius) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(radius),
        ),
      );

  Widget _drawing() {
    final art = CustomPaint(
      size: Size.square(tile ? size * 0.72 : size),
      painter: _CropPainter(cropKey, muted),
    );
    final child = muted ? Opacity(opacity: 0.45, child: art) : art;
    if (!tile) return child;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: muted ? AppColors.surfaceAlt : _tint(cropKey),
        borderRadius: BorderRadius.circular(size * 0.28),
      ),
      alignment: Alignment.center,
      child: child,
    );
  }

  static Color _tint(String key) => switch (key) {
        'maize' => const Color(0xFFFBF1D6),
        'matooke' => const Color(0xFFEDF5DC),
        _ => AppColors.primarySoft,
      };
}

class _CropPainter extends CustomPainter {
  final String cropKey;
  final bool muted;
  _CropPainter(this.cropKey, this.muted);

  static const _leafDark = Color(0xFF2E7D32);
  static const _leaf = Color(0xFF43A047);
  static const _leafLight = Color(0xFF7CB342);
  static const _vein = Color(0xFFC5E1A5);
  static const _stem = Color(0xFF6D4C41);
  static const _gold = Color(0xFFF2B632);
  static const _goldDark = Color(0xFFD38F12);

  @override
  void paint(Canvas canvas, Size size) {
    // Draw on a 100 x 100 grid.
    canvas.scale(size.width / 100, size.height / 100);
    switch (cropKey) {
      case 'cassava':
        _cassava(canvas);
      case 'beans':
        _beans(canvas);
      case 'matooke':
        _matooke(canvas);
      case 'maize':
        _maize(canvas);
      default:
        _leafShape(canvas);
    }
  }

  Paint _fill(Color c) => Paint()
    ..color = c
    ..isAntiAlias = true;

  Paint _stroke(Color c, double w) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..isAntiAlias = true;

  /// Cassava roots: three tapered tubers below a stem with a small leaf.
  void _cassava(Canvas c) {
    const root = Color(0xFF8D5A3B);
    const rootLight = Color(0xFFB07A55);
    void tuber(double angle, double length, Color color) {
      c.save();
      c.translate(50, 40);
      c.rotate(angle);
      final body = Path()
        ..moveTo(-8, 0)
        ..quadraticBezierTo(-10, length * 0.55, 0, length)
        ..quadraticBezierTo(10, length * 0.55, 8, 0)
        ..close();
      c.drawPath(body, _fill(color));
      for (final y in [length * 0.35, length * 0.62]) {
        c.drawLine(Offset(-5, y), Offset(4, y + 2),
            _stroke(const Color(0xFF6D4027), 1.2));
      }
      c.restore();
    }

    tuber(0.55, 50, rootLight);
    tuber(-0.55, 50, rootLight);
    tuber(0, 58, root);
    // stem and a three-lobed leaf
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(46, 24, 8, 18), const Radius.circular(3)),
        _fill(_stem));
    for (final a in [-0.9, 0.0, 0.9]) {
      c.save();
      c.translate(50, 25);
      c.rotate(a - math.pi / 2);
      final lobe = Path()
        ..moveTo(0, 0)
        ..quadraticBezierTo(10, -7, 22, 0)
        ..quadraticBezierTo(10, 7, 0, 0)
        ..close();
      c.drawPath(lobe, _fill(a == 0 ? _leafDark : _leaf));
      c.restore();
    }
  }

  /// Two bean pods hanging from a stem, with beans showing.
  void _beans(Canvas c) {
    c.drawLine(
        const Offset(50, 6), const Offset(50, 30), _stroke(_leafDark, 4));
    void pod(double dx, double angle, Color color) {
      c.save();
      c.translate(dx, 28);
      c.rotate(angle);
      final body = Path()
        ..moveTo(0, 0)
        ..cubicTo(12, 6, 14, 40, 6, 66)
        ..cubicTo(2, 72, -6, 72, -7, 64)
        ..cubicTo(-10, 40, -10, 10, 0, 0)
        ..close();
      c.drawPath(body, _fill(color));
      for (final y in [18.0, 34.0, 50.0]) {
        c.drawOval(Rect.fromCenter(center: Offset(0, y), width: 9, height: 12),
            _fill(_vein.withValues(alpha: 0.85)));
      }
      c.restore();
    }

    pod(50, 0.42, _leafLight);
    pod(52, -0.30, _leaf);
    // small leaf at the stem
    final leaf = Path()
      ..moveTo(50, 14)
      ..quadraticBezierTo(70, 2, 84, 12)
      ..quadraticBezierTo(68, 24, 50, 14)
      ..close();
    c.drawPath(leaf, _fill(_leafDark));
  }

  /// A bunch of green matooke bananas on a crown.
  void _matooke(Canvas c) {
    c.drawRRect(
        RRect.fromRectAndRadius(
            const Rect.fromLTWH(45, 4, 10, 22), const Radius.circular(4)),
        _fill(_stem));
    void finger(Offset tip, Offset ctrl, Color color) {
      final path = Path()
        ..moveTo(50, 26)
        ..quadraticBezierTo(ctrl.dx, ctrl.dy, tip.dx, tip.dy);
      c.drawPath(path, _stroke(color, 15));
      c.drawCircle(tip, 3.2, _fill(_stem));
    }

    finger(const Offset(16, 74), const Offset(16, 32), _leafLight);
    finger(const Offset(84, 74), const Offset(84, 32), _leafLight);
    finger(const Offset(32, 90), const Offset(30, 46), _leaf);
    finger(const Offset(68, 90), const Offset(70, 46), _leaf);
    finger(const Offset(50, 94), const Offset(50, 60), _leafDark);
    c.drawCircle(const Offset(50, 27), 9, _fill(_leafDark));
  }

  /// A maize cob with kernels, wrapped in two husk leaves.
  void _maize(Canvas c) {
    final cob = RRect.fromRectAndRadius(
        const Rect.fromLTWH(34, 8, 32, 74), const Radius.circular(16));
    c.drawRRect(cob, _fill(_gold));
    c.save();
    c.clipRRect(cob);
    for (var row = 0; row < 10; row++) {
      for (var col = 0; col < 4; col++) {
        final x = 38.5 + col * 7.6 + (row.isEven ? 0 : 3.8);
        final y = 13 + row * 7.2;
        c.drawOval(Rect.fromCenter(center: Offset(x, y), width: 6, height: 5.6),
            _fill(_goldDark));
      }
    }
    c.restore();
    final left = Path()
      ..moveTo(50, 96)
      ..quadraticBezierTo(18, 80, 22, 30)
      ..quadraticBezierTo(36, 62, 52, 70)
      ..close();
    final right = Path()
      ..moveTo(50, 96)
      ..quadraticBezierTo(82, 80, 78, 30)
      ..quadraticBezierTo(64, 62, 48, 70)
      ..close();
    c.drawPath(left, _fill(_leaf));
    c.drawPath(right, _fill(_leafLight));
  }

  /// Generic leaf for crops without their own drawing.
  void _leafShape(Canvas c) {
    final leaf = Path()
      ..moveTo(18, 84)
      ..cubicTo(14, 40, 44, 12, 86, 14)
      ..cubicTo(88, 56, 60, 88, 18, 84)
      ..close();
    c.drawPath(leaf, _fill(_leaf));
    c.drawLine(const Offset(20, 82), const Offset(70, 30), _stroke(_vein, 2.2));
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.cropKey != cropKey || old.muted != muted;
}
