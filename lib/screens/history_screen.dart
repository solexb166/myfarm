import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import '../models/models.dart';
import '../widgets/common.dart';

/// Past diagnoses — fulfils the concept doc's "save past diagnoses and
/// treatments to track what worked over multiple seasons". Works offline:
/// reads straight from local storage.
class HistoryScreen extends StatefulWidget {
  final String lang;
  const HistoryScreen({super.key, required this.lang});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Diagnosis> _items = [];
  bool _loaded = false;

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final h = await Storage.getHistory();
    if (mounted) setState(() { _items = h; _loaded = true; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('history'), onBack: () => Navigator.pop(context)),
          Expanded(
            child: !_loaded
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.leaf))
                : _items.isEmpty
                    ? _empty()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                        itemCount: _items.length,
                        itemBuilder: (_, i) => _HistoryCard(
                          d: _items[i],
                          lang: widget.lang,
                        ),
                      ),
          ),
        ]),
      ),
    );
  }

  Widget _empty() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: AppColors.card,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: AppColors.line),
              ),
              child: const Icon(Icons.history,
                  size: 34, color: AppColors.creamDim),
            ),
            const SizedBox(height: 16),
            Text(t.get('noHistory'),
                textAlign: TextAlign.center,
                style: AppText.body(15, color: AppColors.creamDim)),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Diagnosis d;
  final String lang;
  const _HistoryCard({required this.d, required this.lang});

  @override
  Widget build(BuildContext context) {
    final col = d.healthy ? AppColors.leaf : AppColors.rust;
    final hasImg = d.imagePath != null && File(d.imagePath!).existsSync();
    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DiagnosisDetailScreen(d: d, lang: lang)),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(children: [
          ClipRRect(
            borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16)),
            child: SizedBox(
              width: 78,
              height: 78,
              child: hasImg
                  ? Image.file(File(d.imagePath!), fit: BoxFit.cover)
                  : Container(
                      color: AppColors.soil2,
                      child: const Icon(Icons.eco,
                          color: AppColors.creamDim, size: 26)),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration:
                          BoxDecoration(color: col, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(d.diagnosis,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.display(16,
                              weight: FontWeight.w700)),
                    ),
                  ]),
                  const SizedBox(height: 3),
                  Text(
                    '${d.crop.isEmpty ? '' : '${d.crop} · '}${_ago(d.timestamp)}',
                    style: AppText.body(12.5, color: AppColors.creamDim),
                  ),
                  const SizedBox(height: 5),
                  Text('${d.confidence}% ${L10n(lang).get('confidence').toLowerCase()}',
                      style: AppText.body(12,
                          weight: FontWeight.w600, color: col)),
                ],
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(right: 10),
            child: Icon(Icons.chevron_right, color: AppColors.creamDim),
          ),
        ]),
      ),
    );
  }

  String _ago(int ts) {
    final d = DateTime.fromMillisecondsSinceEpoch(ts);
    return DateFormat('d MMM, HH:mm').format(d);
  }
}

/// Read-only re-view of a stored diagnosis (no re-running the AI).
class DiagnosisDetailScreen extends StatelessWidget {
  final Diagnosis d;
  final String lang;
  const DiagnosisDetailScreen({super.key, required this.d, required this.lang});

  @override
  Widget build(BuildContext context) {
    final t = L10n(lang);
    final hasImg = d.imagePath != null && File(d.imagePath!).existsSync();
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: TopBar(
                title: t.get('diagnose'), onBack: () => Navigator.pop(context)),
          ),
          Stack(children: [
            SizedBox(
              height: 200,
              width: double.infinity,
              child: hasImg
                  ? Image.file(File(d.imagePath!), fit: BoxFit.cover)
                  : Container(color: AppColors.card),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.soil, Colors.transparent],
                    stops: [0.04, 0.6],
                  ),
                ),
              ),
            ),
          ]),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: d.healthy ? AppColors.leaf : AppColors.rust,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(d.crop.isEmpty ? 'Crop' : d.crop,
                        style: AppText.body(13,
                            weight: FontWeight.w700,
                            color: d.healthy
                                ? AppColors.soil
                                : AppColors.cream)),
                  ),
                  const SizedBox(height: 14),
                  Text(d.diagnosis, style: AppText.display(28, spacing: -1)),
                  const SizedBox(height: 14),
                  Row(children: [
                    ConfidenceRing(pct: d.confidence),
                    const SizedBox(width: 12),
                    Text(t.get('confidence'),
                        style: AppText.body(13, color: AppColors.creamDim)),
                  ]),
                  const SizedBox(height: 18),
                  InfoBlock(
                      icon: Icons.eco, label: t.get('cause'), text: d.cause),
                  if (!d.healthy)
                    InfoBlock(
                        icon: Icons.spa,
                        label: t.get('organic'),
                        text: d.organic,
                        tint: AppColors.leaf),
                  if (!d.healthy)
                    InfoBlock(
                        icon: Icons.science,
                        label: t.get('chemical'),
                        text: d.chemical,
                        tint: AppColors.gold),
                  InfoBlock(
                      icon: Icons.check_circle_outline,
                      label: t.get('prevent'),
                      text: d.prevent),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
