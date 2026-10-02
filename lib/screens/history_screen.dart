import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/backend.dart';
import '../services/inference_service.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import '../widgets/diagnosis_view.dart';

/// Past diagnoses, newest first, read straight from the phone (works
/// offline). Shows whether each one has been backed up.
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
    if (mounted) {
      setState(() {
        _items = h;
        _loaded = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('history')),
          Expanded(
            child: !_loaded
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : _items.isEmpty
                    ? _empty()
                    : RefreshIndicator(
                        color: AppColors.primary,
                        onRefresh: () async {
                          await Backend.sync();
                          await _load();
                        },
                        child: ListView.builder(
                          padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
                          itemCount: _items.length,
                          itemBuilder: (_, i) => _HistoryCard(
                            d: _items[i],
                            lang: widget.lang,
                            onReturn: _load,
                          ),
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
              width: 76,
              height: 76,
              decoration: const BoxDecoration(
                  color: AppColors.surfaceAlt, shape: BoxShape.circle),
              child: const Icon(Icons.document_scanner_outlined,
                  size: 34, color: AppColors.textDim),
            ),
            const SizedBox(height: 16),
            Text(t.get('noScansYet'),
                style: AppText.display(18, weight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(t.get('noHistory'),
                textAlign: TextAlign.center,
                style: AppText.body(15, color: AppColors.textDim)),
          ],
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final Diagnosis d;
  final String lang;
  final VoidCallback onReturn;
  const _HistoryCard(
      {required this.d, required this.lang, required this.onReturn});

  @override
  Widget build(BuildContext context) {
    final t = L10n(lang);
    final hasImg = d.imagePath != null && File(d.imagePath!).existsSync();
    final when = DateFormat('d MMM yyyy, HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(d.timestamp));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () async {
            await Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => DiagnosisDetailScreen(d: d, lang: lang)));
            onReturn();
          },
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: hasImg
                    ? Image.file(File(d.imagePath!),
                        width: 64, height: 64, fit: BoxFit.cover)
                    : CropArt(
                        cropKey: InferenceService.cropKeyFor(d.crop) ?? '',
                        size: 64),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d.diagnosis,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(16, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text('${d.crop}  ·  $when',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppText.body(13, color: AppColors.textDim)),
                    const SizedBox(height: 7),
                    Row(children: [
                      StatusBadge(healthy: d.healthy, lang: lang, small: true),
                      const Spacer(),
                      if (Backend.enabled)
                        Tooltip(
                          message: t.get(d.synced ? 'syncedOne' : 'pendingOne'),
                          child: Icon(
                            d.synced
                                ? Icons.cloud_done_outlined
                                : Icons.cloud_upload_outlined,
                            size: 18,
                            color:
                                d.synced ? AppColors.textDim : AppColors.accent,
                          ),
                        ),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// A saved diagnosis, reopened from history.
class DiagnosisDetailScreen extends StatelessWidget {
  final Diagnosis d;
  final String lang;
  const DiagnosisDetailScreen({super.key, required this.d, required this.lang});

  @override
  Widget build(BuildContext context) => DiagnosisView(d: d, lang: lang);
}
