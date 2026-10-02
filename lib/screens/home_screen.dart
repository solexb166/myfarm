import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../theme/app_theme.dart';
import '../services/backend.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import '../widgets/common.dart';
import 'diagnose_screen.dart';
import 'history_screen.dart';

/// Home tab: the farmer's own dashboard - scan, next task, last scan and
/// backup status. [onOpenTab] switches the bottom navigation tab.
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
  Diagnosis? _lastScan;
  int _pending = 0;

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
    final pending = await Storage.pendingScanCount();
    if (!mounted) return;
    setState(() {
      _name = name;
      _plan = plan;
      _lastScan = history.isEmpty ? null : history.first;
      _pending = pending;
    });
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
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            Row(children: [
              const IconTile(icon: Icons.eco, size: 36),
              const SizedBox(width: 10),
              Text(t.get('appName'), style: AppText.display(18, spacing: 0.2)),
              const Spacer(),
              LangToggle(lang: widget.lang, onChange: widget.onLang),
            ]),
            const SizedBox(height: 26),
            Text(_greeting(), style: AppText.display(28)),
            const SizedBox(height: 6),
            Text(t.get('homeSub'),
                style: AppText.body(15, color: AppColors.textDim)),
            const SizedBox(height: 20),
            _ScanCard(
                title: t.get('scan'), sub: t.get('scanSub'), onTap: _scan),
            const SizedBox(height: 26),
            _SectionHeader(title: t.get('nextTask')),
            _nextTaskCard(),
            const SizedBox(height: 22),
            _SectionHeader(
              title: t.get('lastScan'),
              action: _lastScan == null ? null : t.get('seeAll'),
              onAction: () => widget.onOpenTab(2),
            ),
            _lastScanCard(),
            if (Backend.enabled) ...[
              const SizedBox(height: 22),
              _backupRow(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _nextTaskCard() {
    final plan = _plan;
    if (plan == null) {
      return _RowCard(
        icon: Icons.calendar_month_outlined,
        iconColor: AppColors.accent,
        iconBg: AppColors.accentSoft,
        title: t.get('planSeason'),
        sub: t.get('planSeasonSub'),
        onTap: () => widget.onOpenTab(1),
      );
    }
    final next = plan.tasks.where((task) => !task.done).firstOrNull;
    if (next == null) {
      return _RowCard(
        icon: Icons.task_alt,
        title: t.get('allTasksDone'),
        sub: plan.crop,
        onTap: () => widget.onOpenTab(1),
      );
    }
    final date = DateTime.tryParse(next.date);
    return _RowCard(
      icon: taskIcon(next.type),
      title: next.title,
      sub: [
        if (date != null) DateFormat('d MMM').format(date),
        plan.crop,
        next.stage,
      ].where((s) => s.isNotEmpty).join('  ·  '),
      onTap: () => widget.onOpenTab(1),
    );
  }

  Widget _lastScanCard() {
    final d = _lastScan;
    if (d == null) {
      return _RowCard(
        icon: Icons.document_scanner_outlined,
        iconColor: AppColors.textDim,
        iconBg: AppColors.surfaceAlt,
        title: t.get('noScansYet'),
        sub: t.get('noHistory'),
      );
    }
    final when = DateFormat('d MMM, HH:mm')
        .format(DateTime.fromMillisecondsSinceEpoch(d.timestamp));
    return _RowCard(
      icon: d.healthy ? Icons.check_circle_outline : Icons.coronavirus_outlined,
      iconColor: d.healthy ? AppColors.primary : AppColors.danger,
      iconBg: d.healthy ? AppColors.primarySoft : AppColors.dangerSoft,
      title: d.diagnosis,
      sub: '${d.crop}  ·  $when',
      onTap: () async {
        await Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    DiagnosisDetailScreen(d: d, lang: widget.lang)));
        _load();
      },
    );
  }

  Widget _backupRow() {
    final ok = _pending == 0;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => widget.onOpenTab(3),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Row(children: [
            Icon(ok ? Icons.cloud_done_outlined : Icons.cloud_upload_outlined,
                size: 19, color: ok ? AppColors.primary : AppColors.accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ok
                    ? t.get('syncAll')
                    : t.get('syncPending').replaceAll('{n}', '$_pending'),
                style: AppText.body(13.5, color: AppColors.textDim),
              ),
            ),
          ]),
        ),
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
      borderRadius: BorderRadius.circular(22),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(22),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 16, 22),
          child: Row(children: [
            Container(
              width: 58,
              height: 58,
              decoration: const BoxDecoration(
                color: AppColors.onPrimary,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.photo_camera_outlined,
                  size: 28, color: AppColors.primary),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.display(21,
                          weight: FontWeight.w700,
                          color: AppColors.onPrimary,
                          spacing: -0.2)),
                  const SizedBox(height: 4),
                  Text(sub,
                      style: AppText.body(14,
                          color: AppColors.onPrimary.withValues(alpha: 0.88))),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward, color: AppColors.onPrimary),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, left: 2),
      child: Row(children: [
        Expanded(
            child: Text(title,
                style: AppText.display(17, weight: FontWeight.w700))),
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                foregroundColor: AppColors.primary),
            child: Text(action!,
                style: AppText.body(14,
                    weight: FontWeight.w600, color: AppColors.primary)),
          ),
      ]),
    );
  }
}

/// White card with an icon tile, title, subtitle and optional tap.
class _RowCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String sub;
  final VoidCallback? onTap;
  const _RowCard({
    required this.icon,
    required this.title,
    required this.sub,
    this.iconColor = AppColors.primary,
    this.iconBg = AppColors.primarySoft,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.border),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(13),
              ),
              child: Icon(icon, size: 23, color: iconColor),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: AppText.body(15.5, weight: FontWeight.w600),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 2),
                  Text(sub,
                      style: AppText.body(13.5, color: AppColors.textDim),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, color: AppColors.textDim),
          ]),
        ),
      ),
    );
  }
}
