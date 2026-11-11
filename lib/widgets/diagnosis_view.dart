import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../models/models.dart';
import '../services/areas.dart';
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
  District? _district;

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    Areas.byId(widget.d.districtId).then((d) {
      if (mounted && d != null) setState(() => _district = d);
    });
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
    final a = _advice();
    await _tts
        .speak([d.diagnosis, a.cause, if (!d.healthy) a.organic].join('. '));
  }

  /// The advice in the current language (and with any corrected text
  /// downloaded since the scan); falls back to what was saved with it.
  Treatment _advice() {
    final d = widget.d;
    final label = d.label;
    return label == null
        ? Treatment(
            cause: d.cause,
            organic: d.organic,
            chemical: d.chemical,
            prevent: d.prevent)
        : TreatmentDB.lookup(label, widget.lang);
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.d;
    final photo = d.imagePath == null ? null : File(d.imagePath!);
    final hasPhoto = photo != null && photo.existsSync();
    final cropKey = InferenceService.cropKeyFor(d.crop) ?? '';
    final advice = _advice();
    final crop = InferenceService.crops
        .where((c) => c['key'] == cropKey)
        .map((c) => widget.lang == 'lg' ? c['luganda']! : c['name']!)
        .firstOrNull;

    final place = _district == null
        ? null
        : [_district!.name, if (d.subcounty != null) d.subcounty!].join(', ');
    final back = widget.onBack ??
        (Navigator.of(context).canPop()
            ? () => Navigator.of(context).maybePop()
            : null);

    final sections = <(IconData, Color, String, String)>[
      (Icons.info_outline, AppColors.textDim, t.get('cause'), advice.cause),
      if (!d.healthy) ...[
        (Icons.spa_outlined, AppColors.primary, t.get('organic'),
            advice.organic),
        (Icons.science_outlined, AppColors.accent, t.get('chemical'),
            advice.chemical),
      ],
      (Icons.shield_outlined, AppColors.info, t.get('prevent'), advice.prevent),
    ];

    final meta = [
      crop ?? d.crop,
      if (place != null) place,
    ].join(' · ');
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
          child: Row(children: [
            StatusBadge(healthy: d.healthy, lang: widget.lang),
            const Spacer(),
            _ListenButton(
              speaking: _speaking,
              label: _speaking ? t.get('stop') : t.get('listenShort'),
              onTap: _toggleSpeak,
            ),
          ]),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Text(d.diagnosis, style: AppText.display(25, spacing: -0.6)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
          child: Row(children: [
            CropArt(cropKey: cropKey, size: 18, tile: false),
            const SizedBox(width: 6),
            Flexible(
              child: Text(meta,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body(13.5,
                      weight: FontWeight.w600, color: AppColors.textDim)),
            ),
            const SizedBox(width: 8),
            _MatchText(pct: d.confidence, t: t),
          ]),
        ),
        const Divider(height: 1),
        for (final (i, (icon, tint, label, text)) in sections.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 60),
          _AdviceSection(
            icon: icon,
            tint: tint,
            label: label,
            text: text,
            open: i == 0,
          ),
        ],
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Icon(Icons.support_agent, size: 16, color: AppColors.textDim),
            const SizedBox(width: 8),
            Expanded(
              child: Text(t.get('confirmNote'),
                  style: AppText.body(12.5, color: AppColors.textDim)),
            ),
          ]),
        ),
        if (widget.footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: widget.footer!,
          ),
        const SizedBox(height: 20),
      ],
    );

    if (!hasPhoto) {
      return Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(title: t.get('result'), onBack: widget.onBack),
            Expanded(child: ListView(children: [details])),
          ]),
        ),
      );
    }
    final top = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          Stack(children: [
            Image.file(photo,
                height: 230 + top, width: double.infinity, fit: BoxFit.cover),
            if (back != null)
              Positioned(
                left: 12,
                top: top + 10,
                child: Material(
                  color: AppColors.surface.withValues(alpha: 0.92),
                  shape: const CircleBorder(),
                  child: IconButton(
                    onPressed: back,
                    icon: Icon(Icons.arrow_back,
                        color: AppColors.text,
                        semanticLabel: MaterialLocalizations.of(context)
                            .backButtonTooltip),
                  ),
                ),
              ),
          ]),
          details,
        ],
      ),
    );
  }
}

/// One part of the advice that opens and closes when tapped.
class _AdviceSection extends StatelessWidget {
  final IconData icon;
  final Color tint;
  final String label;
  final String text;
  final bool open;
  const _AdviceSection({
    required this.icon,
    required this.tint,
    required this.label,
    required this.text,
    this.open = false,
  });

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        initiallyExpanded: open,
        tilePadding: const EdgeInsets.fromLTRB(16, 0, 12, 0),
        childrenPadding: const EdgeInsets.fromLTRB(60, 0, 16, 14),
        minTileHeight: 52,
        expandedCrossAxisAlignment: CrossAxisAlignment.start,
        iconColor: AppColors.textDim,
        collapsedIconColor: AppColors.textDim,
        leading: Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: tint.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(9),
          ),
          child: Icon(icon, size: 17, color: tint),
        ),
        title: Text(label, style: AppText.body(15.5, weight: FontWeight.w700)),
        children: [Text(text, style: AppText.body(14.5))],
      ),
    );
  }
}

/// How sure the model is, in words first (High / Medium) and the number
/// second. Deliberately neutral in colour: it is not good or bad news.
/// "Healthy" or "Disease detected" pill.
class StatusBadge extends StatelessWidget {
  final bool healthy;
  final String lang;
  final bool small;

  /// Coloured icon and text only, no pill behind it (for dense lists).
  final bool plain;
  const StatusBadge(
      {super.key,
      required this.healthy,
      required this.lang,
      this.small = false,
      this.plain = false});

  @override
  Widget build(BuildContext context) {
    final fg = healthy ? AppColors.primary : AppColors.danger;
    final bg = healthy ? AppColors.primarySoft : AppColors.dangerSoft;
    return Container(
      padding: plain
          ? EdgeInsets.zero
          : EdgeInsets.symmetric(
              horizontal: small ? 9 : 12, vertical: small ? 3 : 6),
      decoration: plain
          ? null
          : BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(999),
            ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(healthy ? Icons.check_circle_outline : Icons.warning_amber_rounded,
            size: small ? 13 : 16, color: fg),
        SizedBox(width: small ? 4 : 6),
        Flexible(
          child: Text(
              L10n(lang).get(healthy ? 'statusHealthy' : 'statusDisease'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.body(small ? 12 : 13.5,
                  weight: FontWeight.w700, color: fg)),
        ),
      ]),
    );
  }
}

/// How sure the model is, the number then the word (High / Medium).
/// Deliberately neutral in colour: it is not good or bad news.
class _MatchText extends StatelessWidget {
  final int pct;
  final L10n t;
  const _MatchText({required this.pct, required this.t});

  @override
  Widget build(BuildContext context) {
    final level = pct >= 80
        ? t.get('confHigh')
        : pct >= 65
            ? t.get('confMedium')
            : t.get('confLow');
    return Tooltip(
      message: t.get('confidence'),
      child: Text('$pct% ${t.get('match')} ($level)',
          style: AppText.body(13, color: AppColors.textDim)),
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
    return TextButton.icon(
      onPressed: onTap,
      icon: Icon(speaking ? Icons.stop_circle_outlined : Icons.volume_up,
          size: 20),
      label: Text(label,
          style: AppText.body(14,
              weight: FontWeight.w700, color: AppColors.primary)),
      style: TextButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: speaking ? AppColors.primarySoft : null,
        visualDensity: VisualDensity.compact,
      ),
    );
  }
}
