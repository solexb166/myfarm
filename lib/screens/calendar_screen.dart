import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/l10n.dart';
import '../services/calendar_service.dart';
import '../services/backend.dart';
import '../services/inference_service.dart';
import '../services/storage.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import 'home_screen.dart' show taskIcon;

/// Season planner: set up a crop + planting date, then follow a checklist
/// of tasks from planting to harvest. Fully offline.
class CalendarScreen extends StatefulWidget {
  final String lang;
  const CalendarScreen({super.key, required this.lang});
  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  final _cropCtrl = TextEditingController();
  final _regionCtrl = TextEditingController();
  DateTime? _planted;
  bool _loading = false;
  CropPlan? _plan;

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    _loadSaved();
  }

  Future<void> _loadSaved() async {
    final saved = await Storage.getPlan();
    if (saved != null && mounted) setState(() => _plan = saved);
  }

  @override
  void dispose() {
    _cropCtrl.dispose();
    _regionCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _planted ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: now,
    );
    if (d != null) setState(() => _planted = d);
  }

  Future<void> _generate() async {
    if (_cropCtrl.text.trim().isEmpty || _planted == null) return;
    setState(() => _loading = true);
    try {
      final typed = _cropCtrl.text.trim();
      final plan = CalendarService.generate(
        cropKey: CalendarService.cropKeyFor(typed),
        cropName: typed,
        planted: _planted!,
        region: _regionCtrl.text.trim(),
        lang: widget.lang,
      );
      await Storage.savePlan(plan);
      Backend.sync();
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.get('errGeneric'),
            style: AppText.body(14, color: AppColors.onPrimary)),
      ));
    }
  }

  Future<void> _toggleTask(int i) async {
    setState(() => _plan!.tasks[i].done = !_plan!.tasks[i].done);
    await Storage.savePlan(_plan!);
    Backend.sync();
  }

  Future<void> _startNew() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(t.get('newSeasonTitle'),
            style: AppText.display(20, weight: FontWeight.w700)),
        content: Text(t.get('newSeasonBody'),
            style: AppText.body(15, color: AppColors.textDim)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t.get('cancel'),
                style: AppText.body(15, weight: FontWeight.w600)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(t.get('newSeason'),
                style: AppText.body(15,
                    weight: FontWeight.w700, color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() {
      _plan = null;
      _cropCtrl.clear();
      _regionCtrl.clear();
      _planted = null;
    });
    await Storage.clearPlan();
    Backend.sync();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: _plan == null ? _buildSetup() : _buildPlan(),
      ),
    );
  }

  // ---------- SETUP ----------
  Widget _buildSetup() {
    final ready = _cropCtrl.text.trim().isNotEmpty && _planted != null;
    final typedKey = CalendarService.cropKeyFor(_cropCtrl.text);
    return Column(children: [
      TopBar(title: t.get('setup')),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
          children: [
            Text(t.get('setupSub'),
                style: AppText.body(15, color: AppColors.textDim)),
            const SizedBox(height: 22),
            FieldLabel(t.get('crop')),
            Wrap(spacing: 8, runSpacing: 8, children: [
              for (final c in InferenceService.crops)
                ChoiceChip(
                  avatar: CropArt(cropKey: c['key']!, size: 20, tile: false),
                  label: Text(widget.lang == 'lg' ? c['luganda']! : c['name']!),
                  labelStyle: AppText.body(14, weight: FontWeight.w600),
                  selected: typedKey == c['key'],
                  showCheckmark: false,
                  selectedColor: AppColors.primarySoft,
                  backgroundColor: AppColors.surface,
                  side: BorderSide(
                      color: typedKey == c['key']
                          ? AppColors.primary
                          : AppColors.border),
                  onSelected: (_) => setState(() => _cropCtrl.text =
                      widget.lang == 'lg' ? c['luganda']! : c['name']!),
                ),
            ]),
            const SizedBox(height: 10),
            AppTextField(
                controller: _cropCtrl,
                hint: t.get('cropPh'),
                icon: Icons.edit_outlined,
                onChanged: (_) => setState(() {})),
            const SizedBox(height: 20),
            FieldLabel(t.get('planted')),
            Material(
              color: AppColors.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: const BorderSide(color: AppColors.border),
              ),
              child: InkWell(
                onTap: _pickDate,
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  child: Row(children: [
                    const Icon(Icons.calendar_today_outlined,
                        size: 20, color: AppColors.textDim),
                    const SizedBox(width: 12),
                    Text(
                      _planted == null
                          ? t.get('pickDate')
                          : DateFormat('d MMMM yyyy').format(_planted!),
                      style: AppText.body(16,
                          color: _planted == null
                              ? AppColors.textDim
                              : AppColors.text),
                    ),
                  ]),
                ),
              ),
            ),
            const SizedBox(height: 20),
            FieldLabel(t.get('region')),
            AppTextField(
                controller: _regionCtrl,
                hint: t.get('regionPh'),
                icon: Icons.place_outlined),
            const SizedBox(height: 26),
            BigButton(
              label: _loading ? t.get('building') : t.get('generate'),
              icon: Icons.event_note_outlined,
              loading: _loading,
              onTap: ready ? _generate : null,
            ),
          ],
        ),
      ),
    ]);
  }

  // ---------- PLAN ----------
  Widget _buildPlan() {
    final p = _plan!;
    final planted = DateTime.tryParse(p.plantedDate);
    final weeksIn = planted == null
        ? 0
        : (DateTime.now().difference(planted).inDays ~/ 7).clamp(0, 999);
    final done = p.tasks.where((tk) => tk.done).length;
    final nextIndex = p.tasks.indexWhere((tk) => !tk.done);

    // Group task indexes by month, keeping their order.
    final groups = <String, List<int>>{};
    for (var i = 0; i < p.tasks.length; i++) {
      final d = DateTime.tryParse(p.tasks[i].date);
      final key = d == null ? '' : DateFormat('MMMM yyyy').format(d);
      groups.putIfAbsent(key, () => []).add(i);
    }

    return Column(children: [
      TopBar(
        title: t.get('season'),
        // Icon only, so the title has room ("Your season plan").
        trailing: IconButton(
          onPressed: _startNew,
          tooltip: t.get('newSeason'),
          icon: const Icon(Icons.restart_alt, color: AppColors.primary),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            _SeasonHeader(
              plan: p,
              weeksIn: weeksIn,
              done: done,
              t: t,
            ),
            for (final entry in groups.entries) ...[
              if (entry.key.isNotEmpty) SettingsHeader(entry.key),
              for (final (j, i) in entry.value.indexed) ...[
                if (j > 0) const Divider(height: 1, indent: 64),
                _TaskTile(
                  task: p.tasks[i],
                  isNext: i == nextIndex,
                  upNextLabel: t.get('upNext'),
                  onToggle: () => _toggleTask(i),
                ),
              ],
            ],
          ],
        ),
      ),
    ]);
  }
}

/// The crop, how far into the season, and progress - flat, no card.
class _SeasonHeader extends StatelessWidget {
  final CropPlan plan;
  final int weeksIn;
  final int done;
  final L10n t;
  const _SeasonHeader(
      {required this.plan,
      required this.weeksIn,
      required this.done,
      required this.t});

  @override
  Widget build(BuildContext context) {
    final total = plan.tasks.length;
    final planted = DateTime.tryParse(plan.plantedDate);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            CropArt(
                cropKey: CalendarService.cropKeyFor(plan.crop), size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.crop, style: AppText.display(20)),
                  Text(
                    [
                      t.get('weekN').replaceAll('{n}', '${weeksIn + 1}'),
                      if (planted != null)
                        '${t.get('plantedOn')} ${DateFormat('d MMM').format(planted)}',
                      if (plan.region.isNotEmpty) plan.region,
                    ].join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.body(13, color: AppColors.textDim),
                  ),
                ],
              ),
            ),
          ]),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  value: total == 0 ? 0 : done / total,
                  minHeight: 6,
                  color: AppColors.primary,
                  backgroundColor: AppColors.surfaceAlt,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
                t
                    .get('tasksDone')
                    .replaceAll('{done}', '$done')
                    .replaceAll('{total}', '$total'),
                style: AppText.body(13, weight: FontWeight.w600)),
          ]),
        ],
      ),
    );
  }
}

/// One task: tick it off; the next task is marked and shows its detail.
class _TaskTile extends StatelessWidget {
  final CropTask task;
  final bool isNext;
  final String upNextLabel;
  final VoidCallback onToggle;
  const _TaskTile({
    required this.task,
    required this.isNext,
    required this.upNextLabel,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final done = task.done;
    final date = DateTime.tryParse(task.date);
    return Material(
      color: isNext ? AppColors.primarySoft.withValues(alpha: 0.5) : null,
      child: InkWell(
        onTap: onToggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 16, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: done,
                onChanged: (_) => onToggle(),
                shape: const CircleBorder(),
                activeColor: AppColors.primary,
                side: const BorderSide(color: AppColors.textDim, width: 1.6),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 9),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                          child: Text(task.title,
                              style: AppText.body(15,
                                      weight: FontWeight.w600,
                                      color: done
                                          ? AppColors.textDim
                                          : AppColors.text)
                                  .copyWith(
                                      decoration: done
                                          ? TextDecoration.lineThrough
                                          : null)),
                        ),
                        if (date != null)
                          Text(DateFormat('d MMM').format(date),
                              style: AppText.body(12.5,
                                  weight: FontWeight.w600,
                                  color: AppColors.textDim)),
                      ]),
                      const SizedBox(height: 2),
                      Row(children: [
                        Icon(taskIcon(task.type),
                            size: 14, color: AppColors.textDim),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(task.stage,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  AppText.body(12.5, color: AppColors.textDim)),
                        ),
                        if (isNext) ...[
                          const SizedBox(width: 8),
                          Text(upNextLabel,
                              style: AppText.body(12.5,
                                  weight: FontWeight.w700,
                                  color: AppColors.primary)),
                        ],
                      ]),
                      if (isNext && !done) ...[
                        const SizedBox(height: 4),
                        Text(task.detail,
                            style: AppText.body(13.5, color: AppColors.text)),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
