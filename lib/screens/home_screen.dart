import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../services/l10n.dart';
import '../widgets/common.dart';
import 'diagnose_screen.dart';
import 'calendar_screen.dart';
import 'history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String lang = 'en';
  late L10n t = L10n(lang);

  void _setLang(String l) => setState(() {
        lang = l;
        t = L10n(l);
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero
              Container(
                padding: const EdgeInsets.fromLTRB(28, 64, 28, 36),
                decoration: const BoxDecoration(
                  gradient: RadialGradient(
                    center: Alignment(0, -1),
                    radius: 1.1,
                    colors: [AppColors.soil2, AppColors.soil],
                    stops: [0, 0.7],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 38,
                        height: 38,
                        decoration: BoxDecoration(
                          color: AppColors.leaf,
                          borderRadius: BorderRadius.circular(11),
                        ),
                        child: const Icon(Icons.eco,
                            size: 22, color: AppColors.soil),
                      ),
                      const SizedBox(width: 10),
                      Text(t.get('appName'),
                          style: AppText.display(19, spacing: -0.3)),
                    ]),
                    const SizedBox(height: 28),
                    _Tagline(text: t.get('tagline')),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 300,
                      child: Text(t.get('heroSub'),
                          style:
                              AppText.body(15, color: AppColors.creamDim)),
                    ),
                  ],
                ),
              ),

              // Actions
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(children: [
                  _ActionCard(
                    accent: AppColors.leaf,
                    icon: Icons.photo_camera,
                    title: t.get('scan'),
                    sub: t.get('scanSub'),
                    big: true,
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => DiagnoseScreen(lang: lang))),
                  ),
                  _ActionCard(
                    accent: AppColors.gold,
                    icon: Icons.calendar_month,
                    title: t.get('calendar'),
                    sub: t.get('calendarSub'),
                    onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => CalendarScreen(lang: lang))),
                  ),
                ]),
              ),

              // Recent scans link
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: GestureDetector(
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => HistoryScreen(lang: lang))),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.card,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Row(children: [
                      const Icon(Icons.history,
                          size: 20, color: AppColors.creamDim),
                      const SizedBox(width: 12),
                      Text(t.get('history'),
                          style: AppText.body(15,
                              weight: FontWeight.w600,
                              color: AppColors.cream)),
                      const Spacer(),
                      const Icon(Icons.chevron_right,
                          color: AppColors.creamDim),
                    ]),
                  ),
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
                child: Row(children: [
                  _Stat(n: '1:10,000', l: 'agronomist gap'),
                  const SizedBox(width: 10),
                  _Stat(n: '30–70%', l: 'yield lost late'),
                  const SizedBox(width: 10),
                  _Stat(n: '<10s', l: 'to diagnose'),
                ]),
              ),
            ],
          ),
        ),
        Positioned(
          top: 16,
          right: 16,
          child: LangToggle(lang: lang, onChange: _setLang),
        ),
      ]),
    );
  }
}

class _Tagline extends StatelessWidget {
  final String text;
  const _Tagline({required this.text});
  @override
  Widget build(BuildContext context) {
    final words = text.split(' ');
    return RichText(
      text: TextSpan(
        style: AppText.display(40, spacing: -1.5),
        children: [
          for (int i = 0; i < words.length; i++)
            TextSpan(
              text: '${words[i]} ',
              style: AppText.display(40,
                  spacing: -1.5,
                  color: i == words.length - 1
                      ? AppColors.leafBright
                      : AppColors.cream),
            ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  final Color accent;
  final IconData icon;
  final String title;
  final String sub;
  final bool big;
  final VoidCallback onTap;
  const _ActionCard({
    required this.accent,
    required this.icon,
    required this.title,
    required this.sub,
    required this.onTap,
    this.big = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: big ? 22 : 18),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          Container(
            width: big ? 56 : 50,
            height: big ? 56 : 50,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                    color: accent.withOpacity(0.28),
                    blurRadius: 22,
                    offset: const Offset(0, 8))
              ],
            ),
            child: Icon(icon, size: 26, color: AppColors.soil),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.display(big ? 21 : 18,
                        weight: FontWeight.w700, spacing: -0.4)),
                const SizedBox(height: 3),
                Text(sub, style: AppText.body(13.5, color: AppColors.creamDim)),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.creamDim),
        ]),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String n;
  final String l;
  const _Stat({required this.n, required this.l});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(n,
                style: AppText.display(17,
                    weight: FontWeight.w700, color: AppColors.gold)),
            const SizedBox(height: 2),
            Text(l, style: AppText.body(12.5, color: AppColors.creamDim)),
          ],
        ),
      ),
    );
  }
}
