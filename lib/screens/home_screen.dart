import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/areas.dart';
import '../services/backend.dart';
import '../services/inference_service.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import '../widgets/language_picker.dart';
import '../widgets/diagnosis_view.dart' show StatusBadge;
import 'area_screen.dart';
import 'diagnose_screen.dart';
import 'history_screen.dart';
import 'main_shell.dart' show Tabs;

/// Home tab: the farmer's own dashboard - scan, next task, diseases near
/// them, last scan and backup status. [onOpenTab] switches the bottom navigation tab.
class HomeScreen extends StatefulWidget {
  final String lang;
  final ValueChanged<String> onLang;
  final ValueChanged<int> onOpenTab;
  const HomeScreen({
    super.key,
    required this.lang,
    required this.onLang,
    required this.onOpenTab,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _name;
  CropPlan? _plan;
  List<Diagnosis> _recent = [];
  District? _area;
  AreaReport? _areaReport;

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final name = await Storage.getDisplayName();
    final plan = await Storage.getPlan();
    final history = await Storage.getHistory();
    final area =
        Backend.enabled ? await Areas.byId(await nearYouDistrict()) : null;
    var report = await Storage.getAreaReport();
    if (report?.districtId != area?.id) report = null;
    if (!mounted) return;
    setState(() {
      _name = name;
      _plan = plan;
      _recent = history.take(8).toList();
      _area = area;
      _areaReport = report;
    });
    // Refresh the area totals a few times a day, in the background.
    final age = report == null
        ? null
        : DateTime.now().millisecondsSinceEpoch - report.fetchedAt;
    if (area != null &&
        Backend.account != null &&
        (age == null || age > const Duration(hours: 6).inMilliseconds)) {
      try {
        final fresh = await Backend.areaReport(area.id);
        if (mounted && _area?.id == fresh.districtId) {
          setState(() => _areaReport = fresh);
        }
      } on AccountError {
        // Offline: keep what we have.
      }
    }
  }

  Future<void> _openArea() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => AreaScreen(lang: widget.lang)));
    _load();
  }

  Future<void> _scan() async {
    await Navigator.push(context,
        MaterialPageRoute(builder: (_) => DiagnoseScreen(lang: widget.lang)));
    _load();
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    final hello = t.get(hour < 12
        ? 'greetMorning'
        : hour < 17
            ? 'greetAfternoon'
            : 'greetEvening');
    final first = (_name ?? '').trim().split(' ').first;
    return first.isEmpty ? hello : '$hello, $first';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () async {
          await Backend.sync();
          await _load();
        },
        child: ListView(
          padding: const EdgeInsets.only(top: 10, bottom: 16),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(children: [
                const IconTile(icon: Icons.eco, size: 30),
                const SizedBox(width: 9),
                Text(t.get('appName'),
                    style: AppText.display(16.5, spacing: 0.2)),
                const Spacer(),
                LangButton(lang: widget.lang, onChange: widget.onLang),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
              child: Text(_greeting(),
                  style: AppText.display(23, weight: FontWeight.w800),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _ScanCard(
                  title: t.get('scan'), sub: t.get('scanSub'), onTap: _scan),
            ),
            SettingsHeader(t.get('today')),
            SettingsGroup(indent: 68, children: [
              _nextTaskRow(),
              if (Backend.enabled) _nearYouRow(),
            ]),
            SettingsHeader(
              t.get('history'),
              action: _recent.isEmpty ? null : t.get('seeAll'),
              onAction: () => widget.onOpenTab(Tabs.scans),
            ),
            _recentScans(),
          ],
        ),
      ),
    );
  }

  SettingsRow _row(IconData icon, Color color, String title, String sub,
          VoidCallback? onTap) =>
      SettingsRow(
        leading: RowIcon(icon, color: color),
        leadingWidth: 36,
        title: title,
        sub: sub,
        onTap: onTap,
      );

  Widget _nextTaskRow() {
    final plan = _plan;
    void open() => widget.onOpenTab(Tabs.calendar);
    if (plan == null) {
      return _row(Icons.calendar_month_outlined, AppColors.accent,
          t.get('planSeason'), t.get('planSeasonSub'), open);
    }
    final next = plan.tasks.where((task) => !task.done).firstOrNull;
    if (next == null) {
      return _row(Icons.task_alt, AppColors.primary, t.get('allTasksDone'),
          plan.crop, open);
    }
    final date = DateTime.tryParse(next.date);
    return _row(
      taskIcon(next.type),
      AppColors.primary,
      next.title,
      [
        t.get('nextTask'),
        if (date != null) DateFormat('d MMM').format(date),
        plan.crop,
      ].where((s) => s.isNotEmpty).join(' · '),
      open,
    );
  }

  Widget _nearYouRow() {
    final top = _areaReport?.diseases.firstOrNull;
    if (_area == null || top == null) {
      return _row(
        Icons.travel_explore,
        AppColors.info,
        _area == null
            ? t.get('nearYou')
            : t.get('nearYouSub').replaceAll('{district}', _area!.name),
        t.get('nearYouCard'),
        _openArea,
      );
    }
    return _row(
      Icons.coronavirus_outlined,
      AppColors.danger,
      '${InferenceService.prettyLabel(top.label)} · ${InferenceService.cropDisplayName(top.crop, widget.lang)}',
      '${t.get('nearYou')} · ${t.get('areaFarmers').replaceAll('{n}', '${top.farmers}')} · ${_area!.name}',
      _openArea,
    );
  }

  Future<void> _openScan(Diagnosis d) async {
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => DiagnosisDetailScreen(d: d, lang: widget.lang)));
    _load();
  }

  Widget _recentScans() {
    if (_recent.isEmpty) {
      return _row(Icons.document_scanner_outlined, AppColors.textDim,
          t.get('noScansYet'), t.get('noHistory'), _scan);
    }
    return SizedBox(
      height: 164,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        scrollDirection: Axis.horizontal,
        itemCount: _recent.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (_, i) => _ScanTile(
            d: _recent[i],
            lang: widget.lang,
            onTap: () => _openScan(_recent[i])),
      ),
    );
  }
}

/// Icon for a calendar task type.
IconData taskIcon(String type) => switch (type) {
      'fertilizer' => Icons.spa_outlined,
      'spray' => Icons.sanitizer_outlined,
      'water' => Icons.water_drop_outlined,
      'harvest' => Icons.agriculture_outlined,
      'weeding' => Icons.grass,
      _ => Icons.search,
    };

/// The one big action on Home.
class _ScanCard extends StatelessWidget {
  final String title;
  final String sub;
  final VoidCallback onTap;
  const _ScanCard(
      {required this.title, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.primary,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.display(18,
                          weight: FontWeight.w700,
                          color: AppColors.onPrimary,
                          spacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.body(13,
                          color: AppColors.onPrimary.withValues(alpha: 0.88))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.onPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_camera_outlined,
                  size: 22, color: AppColors.primary),
            ),
          ]),
        ),
      ),
    );
  }
}

/// A recent scan in the sideways list on Home: photo, result, status.
/// No card: just the rounded photo with text under it.
class _ScanTile extends StatelessWidget {
  final Diagnosis d;
  final String lang;
  final VoidCallback onTap;
  const _ScanTile({required this.d, required this.lang, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final path = d.imagePath;
    final photo = path == null ? null : File(path);
    final cropKey = InferenceService.cropKeyFor(d.crop) ?? '';
    return SizedBox(
      width: 140,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                height: 92,
                width: double.infinity,
                child: photo != null && photo.existsSync()
                    ? Image.file(photo, fit: BoxFit.cover)
                    : CropArt(cropKey: cropKey, size: 92),
              ),
            ),
            const SizedBox(height: 6),
            Text(d.diagnosis,
                style: AppText.body(14, weight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            Text(
                '${InferenceService.cropDisplayName(d.crop, lang)} · ${DateFormat('d MMM').format(DateTime.fromMillisecondsSinceEpoch(d.timestamp))}',
                style: AppText.body(12.5, color: AppColors.textDim),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            StatusBadge(healthy: d.healthy, lang: lang, small: true, plain: true),
          ],
        ),
      ),
    );
  }
}
