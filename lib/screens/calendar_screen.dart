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
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 28),
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
        trailing: TextButton.icon(
          onPressed: _startNew,
          icon: const Icon(Icons.restart_alt, size: 19),
          label: Text(t.get('newSeason'),
              style: AppText.body(14,
                  weight: FontWeight.w600, color: AppColors.primary)),
          style: TextButton.styleFrom(foregroundColor: AppColors.primary),
        ),
      ),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
          children: [
            _SeasonHeader(
              plan: p,
              weeksIn: weeksIn,
              done: done,
              t: t,
            ),
            for (final entry in groups.entries) ...[
              if (entry.key.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 22, 0, 10),
                  child: Text(entry.key,
                      style: AppText.display(16, weight: FontWeight.w700)),
                ),
              for (final i in entry.value)
                _TaskTile(
                  task: p.tasks[i],
                  isNext: i == nextIndex,
                  upNextLabel: t.get('upNext'),
                  onToggle: () => _toggleTask(i),
                ),
            ],
          ],
        ),
      ),
    ]);
  }
}

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
    const on = AppColors.onPrimary;
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      decoration: BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.crop,
                      style: AppText.display(28, color: on, spacing: -0.6)),
                  const SizedBox(height: 4),
                  Text(
                    [
                      t.get('weekN').replaceAll('{n}', '${weeksIn + 1}'),
                      if (planted != null)
                        '${t.get('plantedOn')} ${DateFormat('d MMM yyyy').format(planted)}',
                      if (plan.region.isNotEmpty) plan.region,
                    ].join('  ·  '),
                    style: AppText.body(13.5, color: on.withValues(alpha: 0.9)),
                  ),
                ],
              ),
            ),
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: on,
                borderRadius: BorderRadius.circular(16),
              ),
              alignment: Alignment.center,
              child: CropArt(
                  cropKey: CalendarService.cropKeyFor(plan.crop),
                  size: 40,
                  tile: false),
            ),
          ]),
          const SizedBox(height: 18),
          Row(children: [
            Expanded(
              child: Text(t.get('progress'),
                  style:
                      AppText.body(13.5, weight: FontWeight.w600, color: on)),
            ),
            Text(
                t
                    .get('tasksDone')
                    .replaceAll('{done}', '$done')
                    .replaceAll('{total}', '$total'),
                style: AppText.body(13.5, weight: FontWeight.w700, color: on)),
          ]),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              value: total == 0 ? 0 : done / total,
              minHeight: 8,
              color: on,
              backgroundColor: on.withValues(alpha: 0.25),
            ),
          ),
        ],
      ),
    );
  }
}

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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: isNext ? AppColors.primary : AppColors.border,
              width: isNext ? 1.5 : 1),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onToggle,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(6, 10, 14, 14),
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
                const SizedBox(width: 2),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Expanded(
                            child: Text(task.title,
                                style: AppText.body(15.5,
                                        weight: FontWeight.w700,
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
                                style: AppText.body(13,
                                    weight: FontWeight.w600,
                                    color: AppColors.textDim)),
                        ]),
                        const SizedBox(height: 4),
                        Row(children: [
                          Icon(taskIcon(task.type),
                              size: 15, color: AppColors.textDim),
                          const SizedBox(width: 5),
                          Text(task.stage,
                              style:
                                  AppText.body(12.5, color: AppColors.textDim)),
                          if (isNext) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: AppColors.primarySoft,
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(upNextLabel,
                                  style: AppText.body(11.5,
                                      weight: FontWeight.w700,
                                      color: AppColors.primary)),
                            ),
                          ],
                        ]),
                        if (!done) ...[
                          const SizedBox(height: 8),
                          Text(task.detail,
                              style: AppText.body(14, color: AppColors.text)),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
