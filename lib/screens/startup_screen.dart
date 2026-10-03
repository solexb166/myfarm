import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../services/backend.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import '../services/treatment_db.dart';
import '../theme/app_theme.dart';
import 'app_gate.dart';

/// Opening screen. The MY FARM logo builds itself - the leaf tile pops in,
/// the dashed "scan" rings sweep out around it, the name rises in - while
/// the app loads saved settings and connects the backend. Then it fades
/// into sign-in or home. Shortened when the phone asks for reduced motion.
class StartupScreen extends StatefulWidget {
  const StartupScreen({super.key});

  @override
  State<StartupScreen> createState() => _StartupScreenState();
}

class _StartupScreenState extends State<StartupScreen>
    with TickerProviderStateMixin {
  late final AnimationController _intro = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2300));
  // Slow, continuous turn of the rings while starting up.
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 14))
        ..repeat();

  String _lang = 'en';
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    _lang = await Storage.getLang();
    if (mounted) setState(() {});
    final reduceMotion = WidgetsBinding
        .instance.platformDispatcher.accessibilityFeatures.disableAnimations;
    if (reduceMotion) _intro.duration = const Duration(milliseconds: 400);
    final intro = _intro.forward().orCancel.catchError((_) {});

    // Startup work runs during the animation.
    TreatmentDB.setOverrides(await Storage.getTreatmentOverrides());
    await Backend.init();
    await intro;
    if (!mounted) return;
    setState(() => _ready = true);
    _spin.stop();
    Backend.sync();
  }

  @override
  void dispose() {
    _intro.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 700),
      // The logo fades out in the first half, then the app fades in, so the
      // two never overlap. (The outgoing child runs this in reverse.)
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: CurvedAnimation(
            parent: animation,
            curve: const Interval(0.5, 1, curve: Curves.easeOut)),
        child: child,
      ),
      child: _ready
          ? AppGate(key: const ValueKey('app'), initialLang: _lang)
          : _logo(),
    );
  }

  Widget _logo() {
    const tile = 112.0;
    final t = L10n(_lang);
    return Scaffold(
      key: const ValueKey('startup'),
      backgroundColor: AppColors.bg,
      body: Center(
        child: AnimatedBuilder(
          animation: Listenable.merge([_intro, _spin]),
          builder: (context, _) {
            final v = _intro.value;
            // Progress of the part of the animation between a and b.
            double part(double a, double b, [Curve curve = Curves.easeOut]) =>
                curve.transform(((v - a) / (b - a)).clamp(0.0, 1.0));
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox.square(
                  dimension: tile * 2.7,
                  child: Stack(alignment: Alignment.center, children: [
                    CustomPaint(
                      size: const Size.square(tile * 2.7),
                      painter: _RingsPainter(
                        tile: tile,
                        reveal: [
                          part(0.22, 0.55),
                          part(0.32, 0.65),
                          part(0.42, 0.75),
                        ],
                        turn: _spin.value * 2 * math.pi,
                      ),
                    ),
                    Opacity(
                      opacity: part(0, 0.2),
                      child: Transform.scale(
                        scale: 0.4 + 0.6 * part(0, 0.38, Curves.easeOutBack),
                        child: Container(
                          width: tile,
                          height: tile,
                          decoration: BoxDecoration(
                            color: _logoGreen,
                            borderRadius: BorderRadius.circular(tile * 0.24),
                          ),
                          child: Transform.scale(
                            scale: part(0.14, 0.45, Curves.easeOutBack),
                            child: Transform.rotate(
                              angle: -0.6 * (1 - part(0.14, 0.45)),
                              child: const Icon(Icons.eco,
                                  size: tile * 0.46, color: _leafDark),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ]),
                ),
                const SizedBox(height: 18),
                Opacity(
                  opacity: part(0.55, 0.8),
                  child: Transform.translate(
                    offset: Offset(0, 18 * (1 - part(0.55, 0.85))),
                    child: Text(t.get('appName'),
                        style: AppText.display(32, spacing: 0.5)),
                  ),
                ),
                const SizedBox(height: 8),
                Opacity(
                  opacity: part(0.68, 0.95),
                  child: Transform.translate(
                    offset: Offset(0, 12 * (1 - part(0.68, 0.98))),
                    child: Text(t.get('tagline'),
                        style: AppText.body(16, color: AppColors.textDim)),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// Colours taken from the app icon (assets/icon/app_icon.png).
const _logoGreen = Color(0xFF88B769);
const _ringGreen = Color(0xFF8EB176);
const _leafDark = Color(0xFF101E0D);

/// The icon's three rings of dashes. Each ring sweeps in clockwise as its
/// [reveal] goes 0 to 1, and the rings turn slowly, alternating direction.
class _RingsPainter extends CustomPainter {
  final double tile;
  final List<double> reveal;
  final double turn;
  _RingsPainter({required this.tile, required this.reveal, required this.turn});

  // Radius (in tile widths), dash count and turn speed, as in the icon.
  static const _rings = [(0.78, 8, 1.0), (0.95, 10, -0.7), (1.17, 12, 0.5)];

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final paint = Paint()
      ..color = _ringGreen
      ..style = PaintingStyle.stroke
      ..strokeWidth = tile * 0.06
      ..strokeCap = StrokeCap.round;
    for (var r = 0; r < _rings.length; r++) {
      final (radius, dashes, speed) = _rings[r];
      final shown = reveal[r] * dashes;
      if (shown <= 0) continue;
      final rect = Rect.fromCircle(center: centre, radius: radius * tile);
      final step = 2 * math.pi / dashes;
      final dash = step * 0.58;
      for (var i = 0; i < dashes && i < shown; i++) {
        final fraction = (shown - i).clamp(0.0, 1.0);
        final start = -math.pi / 2 + i * step + turn * speed + r * 0.35;
        canvas.drawArc(rect, start, dash * fraction, false, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.turn != turn ||
      old.reveal[0] != reveal[0] ||
      old.reveal[1] != reveal[1] ||
      old.reveal[2] != reveal[2];
}
