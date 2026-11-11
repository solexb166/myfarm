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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            Row(children: [
              const IconTile(icon: Icons.eco, size: 32),
              const SizedBox(width: 9),
              Text(t.get('appName'), style: AppText.display(17, spacing: 0.2)),
              const Spacer(),
              LangButton(lang: widget.lang, onChange: widget.onLang),
            ]),
            const SizedBox(height: 18),
            Text(_greeting(),
                style: AppText.display(24, weight: FontWeight.w800),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
            const SizedBox(height: 14),
            _ScanCard(
                title: t.get('scan'), sub: t.get('scanSub'), onTap: _scan),
            const SizedBox(height: 22),
            _SectionHeader(title: t.get('today')),
            _Group(children: [
              _nextTaskRow(),
              if (Backend.enabled) _nearYouRow(),
            ]),
            const SizedBox(height: 22),
            _SectionHeader(
              title: t.get('history'),
              action: _recent.isEmpty ? null : t.get('seeAll'),
              onAction: () => widget.onOpenTab(Tabs.scans),
            ),
            _recentScans(),
          ],
        ),
      ),
    );
  }

  Widget _nextTaskRow() {
    final plan = _plan;
    if (plan == null) {
      return _Row(
        icon: Icons.calendar_month_outlined,
        iconColor: AppColors.accent,
        iconBg: AppColors.accentSoft,
        title: t.get('planSeason'),
        sub: t.get('planSeasonSub'),
        onTap: () => widget.onOpenTab(Tabs.calendar),
      );
    }
    final next = plan.tasks.where((task) => !task.done).firstOrNull;
    if (next == null) {
      return _Row(
        icon: Icons.task_alt,
        title: t.get('allTasksDone'),
        sub: plan.crop,
        onTap: () => widget.onOpenTab(Tabs.calendar),
      );
    }
    final date = DateTime.tryParse(next.date);
    return _Row(
      icon: taskIcon(next.type),
      title: next.title,
      sub: [
        t.get('nextTask'),
        if (date != null) DateFormat('d MMM').format(date),
        plan.crop,
      ].where((s) => s.isNotEmpty).join('  ·  '),
      onTap: () => widget.onOpenTab(Tabs.calendar),
    );
  }

  Widget _nearYouRow() {
    final top = _areaReport?.diseases.firstOrNull;
    if (_area == null || top == null) {
      return _Row(
        icon: Icons.travel_explore,
        iconColor: AppColors.info,
        iconBg: AppColors.info.withValues(alpha: 0.12),
        title: _area == null
            ? t.get('nearYou')
            : t.get('nearYouSub').replaceAll('{district}', _area!.name),
        sub: t.get('nearYouCard'),
        onTap: _openArea,
      );
    }
    return _Row(
      icon: Icons.coronavirus_outlined,
      iconColor: AppColors.danger,
      iconBg: AppColors.dangerSoft,
      title:
          '${InferenceService.prettyLabel(top.label)} · ${InferenceService.cropDisplayName(top.crop, widget.lang)}',
      sub:
          '${t.get('nearYou')}  ·  ${t.get('areaFarmers').replaceAll('{n}', '${top.farmers}')}  ·  ${_area!.name}',
      onTap: _openArea,
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
      return _Group(children: [
        _Row(
          icon: Icons.document_scanner_outlined,
          iconColor: AppColors.textDim,
          iconBg: AppColors.surfaceAlt,
          title: t.get('noScansYet'),
          sub: t.get('noHistory'),
          onTap: _scan,
        ),
      ]);
    }
    return SizedBox(
      height: 170,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _recent.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (_, i) => _ScanTile(
            d: _recent[i], lang: widget.lang, onTap: () => _openScan(_recent[i])),
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
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
          child: Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.display(19,
                          weight: FontWeight.w700,
                          color: AppColors.onPrimary,
                          spacing: -0.2)),
                  const SizedBox(height: 3),
                  Text(sub,
                      style: AppText.body(13.5,
                          color: AppColors.onPrimary.withValues(alpha: 0.88))),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: AppColors.onPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_camera_outlined,
                  size: 25, color: AppColors.primary),
            ),
          ]),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;
  const _SectionHeader({required this.title, this.action, this.onAction});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 34,
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: AppText.display(16, weight: FontWeight.w700))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                foregroundColor: AppColors.primary),
            child: Text(action!,
                style: AppText.body(13.5,
                    weight: FontWeight.w600, color: AppColors.primary)),
          ),
      ]),
    );
  }
}

/// One white card holding several [_Row]s, separated by thin lines.
class _Group extends StatelessWidget {
  final List<Widget> children;
  const _Group({required this.children});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border),
      ),
      child: Column(children: [
        for (final (i, c) in children.indexed) ...[
          if (i > 0) const Divider(height: 1, indent: 64),
          c,
        ],
      ]),
    );
  }
}

/// A row in a [_Group]: icon, title, one line of detail.
class _Row extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const _Row({
    required this.icon,
    required this.title,
    required this.sub,
    this.iconColor = AppColors.primary,
    this.iconBg = AppColors.primarySoft,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 11, 8, 11),
        child: Row(children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(11),
            ),
            child: Icon(icon, size: 21, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: AppText.body(15, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                const SizedBox(height: 1),
                Text(sub,
                    style: AppText.body(13, color: AppColors.textDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (onTap != null)
            const Icon(Icons.chevron_right, color: AppColors.textDim),
        ]),
      ),
    );
  }
}

/// A recent scan in the sideways list on Home: photo, result, status.
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
      width: 160,
      child: Material(
        color: AppColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.border),
        ),
        child: InkWell(
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 88,
                width: double.infinity,
                child: photo != null && photo.existsSync()
                    ? Image.file(photo, fit: BoxFit.cover)
                    : CropArt(cropKey: cropKey, size: 88),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
                child: Text(d.diagnosis,
                    style: AppText.body(14, weight: FontWeight.w600),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 1, 10, 0),
                child: Text(
                    '${InferenceService.cropDisplayName(d.crop, lang)} · ${DateFormat('d MMM').format(DateTime.fromMillisecondsSinceEpoch(d.timestamp))}',
                    style: AppText.body(12.5, color: AppColors.textDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: StatusBadge(healthy: d.healthy, lang: lang, small: true),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
