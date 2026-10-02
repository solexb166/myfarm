import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../services/inference_service.dart';
import '../services/l10n.dart';
import '../services/treatment_db.dart';
import '../theme/app_theme.dart';
import 'common.dart';
import 'crop_art.dart';

/// A diagnosis result: photo, a clear Healthy / Disease detected status,
/// how sure the model is, read-aloud, and the treatment advice. Used right
/// after a scan and when reopening one from history.
class DiagnosisView extends StatefulWidget {
  final Diagnosis d;
  final String lang;
  final VoidCallback? onBack;

  /// Shown under the advice, e.g. a "Scan another" button.
  final Widget? footer;
  const DiagnosisView({
    super.key,
    required this.d,
    required this.lang,
    this.onBack,
    this.footer,
  });

  @override
  State<DiagnosisView> createState() => _DiagnosisViewState();
}

class _DiagnosisViewState extends State<DiagnosisView> {
  final _tts = FlutterTts();
  bool _speaking = false;

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    // Phones have no Luganda voice; Swahili is the closest available.
    await _tts.setLanguage(widget.lang == 'lg' ? 'sw' : 'en-GB');
    await _tts.setSpeechRate(0.46);
    setState(() => _speaking = true);
    final d = widget.d;
    await _tts.speak(d.spoken.isNotEmpty ? d.spoken : d.diagnosis);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final photo = d.imagePath == null ? null : File(d.imagePath!);
    final hasPhoto = photo != null && photo.existsSync();
    final cropKey = InferenceService.cropKeyFor(d.crop) ?? '';
    // Show the advice in the current language (and any corrected text
    // downloaded since the scan); fall back to what was saved with it.
    final label = d.label;
    final advice = label == null
        ? Treatment(
            cause: d.cause,
            organic: d.organic,
            chemical: d.chemical,
            prevent: d.prevent)
        : TreatmentDB.lookup(label, widget.lang);
    final crop = InferenceService.crops
        .where((c) => c['key'] == cropKey)
        .map((c) => widget.lang == 'lg' ? c['luganda']! : c['name']!)
        .firstOrNull;

    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('result'), onBack: widget.onBack),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 32),
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (hasPhoto) ...[
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.file(photo,
                              height: 210,
                              width: double.infinity,
                              fit: BoxFit.cover),
                        ),
                        const SizedBox(height: 18),
                      ],
                      StatusBadge(healthy: d.healthy, lang: widget.lang),
                      const SizedBox(height: 12),
                      Text(d.diagnosis,
                          style: AppText.display(30, spacing: -0.8)),
                      const SizedBox(height: 8),
                      Row(children: [
                        CropArt(cropKey: cropKey, size: 26, tile: false),
                        const SizedBox(width: 8),
                        Text(crop ?? d.crop,
                            style: AppText.body(15,
                                weight: FontWeight.w600,
                                color: AppColors.textDim)),
                      ]),
                      const SizedBox(height: 18),
                      _ConfidenceCard(pct: d.confidence, t: t),
                      const SizedBox(height: 12),
                      _ListenButton(
                        speaking: _speaking,
                        label: _speaking ? t.get('stop') : t.get('listen'),
                        onTap: _toggleSpeak,
                      ),
                      const SizedBox(height: 22),
                      InfoBlock(
                          icon: Icons.info_outline,
                          label: t.get('cause'),
                          text: advice.cause),
                      if (!d.healthy) ...[
                        InfoBlock(
                            icon: Icons.spa_outlined,
                            label: t.get('organic'),
                            text: advice.organic,
                            tint: AppColors.primary),
                        InfoBlock(
                            icon: Icons.science_outlined,
                            label: t.get('chemical'),
                            text: advice.chemical,
                            tint: AppColors.accent),
                      ],
                      InfoBlock(
                          icon: Icons.shield_outlined,
                          label: t.get('prevent'),
                          text: advice.prevent,
                          tint: AppColors.info),
                      const SizedBox(height: 4),
                      Notice(
                        icon: Icons.support_agent,
                        color: AppColors.info,
                        text: t.get('confirmNote'),
                      ),
                      if (widget.footer != null) ...[
                        const SizedBox(height: 20),
                        widget.footer!,
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}

/// "Healthy" or "Disease detected" pill.
class StatusBadge extends StatelessWidget {
  final bool healthy;
  final String lang;
  final bool small;
  const StatusBadge(
      {super.key,
      required this.healthy,
      required this.lang,
      this.small = false});

  @override
  Widget build(BuildContext context) {
    final fg = healthy ? AppColors.primary : AppColors.danger;
    final bg = healthy ? AppColors.primarySoft : AppColors.dangerSoft;
    return Container(
      padding: EdgeInsets.symmetric(
          horizontal: small ? 9 : 12, vertical: small ? 3 : 6),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(healthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: small ? 13 : 16, color: fg),
        SizedBox(width: small ? 4 : 6),
        Text(L10n(lang).get(healthy ? 'statusHealthy' : 'statusDisease'),
            style: AppText.body(small ? 12 : 13.5,
                weight: FontWeight.w700, color: fg)),
      ]),
    );
  }
}

/// How sure the model is, in words first (High / Medium) and the number
/// second. Deliberately neutral in colour: it is not good or bad news.
class _ConfidenceCard extends StatelessWidget {
  final int pct;
  final L10n t;
  const _ConfidenceCard({required this.pct, required this.t});

  @override
  Widget build(BuildContext context) {
    final level = pct >= 80
        ? t.get('confHigh')
        : pct >= 65
            ? t.get('confMedium')
            : t.get('confLow');
    return Container(
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
            const Icon(Icons.insights, size: 18, color: AppColors.textDim),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.get('confidence'),
                  style: AppText.body(14, color: AppColors.textDim)),
            ),
            Text('$level  ·  $pct%',
                style: AppText.body(14.5, weight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: pct / 100,
              minHeight: 7,
              color: AppColors.text,
              backgroundColor: AppColors.surfaceAlt,
            ),
          ),
        ],
      ),
    );
  }
}

class _ListenButton extends StatelessWidget {
  final bool speaking;
  final String label;
  final VoidCallback onTap;
  const _ListenButton(
      {required this.speaking, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.volume_up,
            size: 20),
        label: Text(label,
            style: AppText.body(15,
                weight: FontWeight.w700, color: AppColors.primary)),
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          backgroundColor: speaking ? AppColors.primarySoft : AppColors.surface,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
      ),
    );
  }
}
