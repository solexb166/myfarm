import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';
import '../services/l10n.dart';
import '../services/calendar_service.dart';
import '../services/storage.dart';
import '../models/models.dart';
import '../widgets/common.dart';

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
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(
            primary: AppColors.gold,
            onPrimary: AppColors.soil,
            surface: AppColors.card,
          ),
        ),
        child: child!,
      ),
    );
    if (d != null) setState(() => _planted = d);
  }

  Future<void> _generate() async {
    if (_cropCtrl.text.trim().isEmpty || _planted == null) return;
    setState(() => _loading = true);
    try {
      final typed = _cropCtrl.text.trim();
      // Map the typed crop to a known template key, else use the generic one.
      final lower = typed.toLowerCase();
      const known = {
        'cassava': ['cassava', 'muwogo'],
        'maize': ['maize', 'corn', 'kasooli'],
        'tomato': ['tomato', 'nyaanya'],
        'beans': ['bean', 'beans', 'bijanjaalo'],
      };
      String cropKey = 'generic';
      known.forEach((key, names) {
        if (names.any((n) => lower.contains(n))) cropKey = key;
      });

      final plan = CalendarService.generate(
        cropKey: cropKey,
        cropName: typed,
        planted: _planted!,
        region: _regionCtrl.text.trim(),
        lang: widget.lang,
      );
      await Storage.savePlan(plan);
      if (!mounted) return;
      setState(() {
        _plan = plan;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(t.get('errTitle'), style: AppText.body(14)),
        backgroundColor: AppColors.rust,
      ));
    }
  }

  Future<void> _toggleTask(int i) async {
    setState(() => _plan!.tasks[i].done = !_plan!.tasks[i].done);
    await Storage.savePlan(_plan!);
  }

  void _startNew() {
    setState(() {
      _plan = null;
      _cropCtrl.clear();
      _regionCtrl.clear();
      _planted = null;
    });
    Storage.clearPlan();
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
    return Column(children: [
      TopBar(title: t.get('setup'), onBack: () => Navigator.pop(context)),
      Expanded(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(t.get('crop')),
              _textField(_cropCtrl, t.get('cropPh'),
                  onChanged: (_) => setState(() {})),
              const SizedBox(height: 16),
              _label(t.get('planted')),
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
                  decoration: BoxDecoration(
                    color: AppColors.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.line),
                  ),
                  child: Row(children: [
                    const Icon(Icons.calendar_today,
                        size: 18, color: AppColors.creamDim),
                    const SizedBox(width: 12),
                    Text(
                      _planted == null
                          ? t.get('pickDate')
                          : DateFormat('d MMMM yyyy').format(_planted!),
                      style: AppText.body(16,
                          color: _planted == null
                              ? AppColors.creamDim
                              : AppColors.cream),
                    ),
                  ]),
                ),
              ),
              const SizedBox(height: 16),
              _label(t.get('region')),
              _textField(_regionCtrl, t.get('regionPh')),
              const SizedBox(height: 24),
              BigButton(
                label: _loading ? t.get('building') : t.get('generate'),
                icon: Icons.calendar_month,
                loading: _loading,
                color: AppColors.gold,
                onTap: ready ? _generate : null,
              ),
            ],
          ),
        ),
      ),
    ]);
  }

  // ---------- PLAN ----------
  Widget _buildPlan() {
    final p = _plan!;
    int weeksIn = 0;
    if (p.plantedDate.isNotEmpty) {
      final pd = DateTime.tryParse(p.plantedDate);
      if (pd != null) {
        weeksIn = DateTime.now().difference(pd).inDays ~/ 7;
        if (weeksIn < 0) weeksIn = 0;
      }
    }
    final nextIndex = p.tasks.indexWhere((tk) => !tk.done);

    return Column(children: [
      TopBar(title: t.get('season'), onBack: () => Navigator.pop(context)),
      Expanded(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 8, 22, 30),
          children: [
            // header card
            Container(
              padding: const EdgeInsets.fromLTRB(22, 20, 22, 20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [AppColors.leaf, Color(0xFF5D9134)],
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Icons.spa, size: 16, color: AppColors.soil),
                    const SizedBox(width: 8),
                    Text('$weeksIn ${t.get('weeksIn')}',
                        style: AppText.body(13,
                            weight: FontWeight.w700,
                            color: AppColors.soil.withOpacity(0.8))),
                    const Spacer(),
                    GestureDetector(
                      onTap: _startNew,
                      child: Icon(Icons.refresh,
                          size: 18, color: AppColors.soil.withOpacity(0.7)),
                    ),
                  ]),
                  const SizedBox(height: 4),
                  Text(p.crop,
                      style: AppText.display(28,
                          color: AppColors.soil, spacing: -0.8)),
                  const SizedBox(height: 6),
                  Text(p.summary,
                      style: AppText.body(14,
                          weight: FontWeight.w500, color: AppColors.soil)),
                ],
              ),
            ),
            if (nextIndex != -1) ...[
              const SizedBox(height: 18),
              Text(t.get('upNext').toUpperCase(),
                  style: AppText.display(12.5,
                      weight: FontWeight.w700,
                      color: AppColors.gold,
                      spacing: 1)),
              const SizedBox(height: 6),
            ] else
              const SizedBox(height: 12),
            // timeline
            for (int i = 0; i < p.tasks.length; i++)
              _TimelineItem(
                task: p.tasks[i],
                isFirst: i == 0,
                isLast: i == p.tasks.length - 1,
                isNext: i == nextIndex,
                doneLabel: t.get('done'),
                onDone: () => _toggleTask(i),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _label(String s) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(s, style: AppText.display(14.5, weight: FontWeight.w700)),
      );

  Widget _textField(TextEditingController c, String hint,
      {ValueChanged<String>? onChanged}) {
    return TextField(
      controller: c,
      onChanged: onChanged,
      style: AppText.body(16, color: AppColors.cream),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body(15, color: AppColors.creamDim),
        filled: true,
        fillColor: AppColors.card,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.gold),
        ),
      ),
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final CropTask task;
  final bool isFirst, isLast, isNext;
  final String doneLabel;
  final VoidCallback onDone;
  const _TimelineItem({
    required this.task,
    required this.isFirst,
    required this.isLast,
    required this.isNext,
    required this.doneLabel,
    required this.onDone,
  });

  static const _meta = {
    'fertilizer': [Icons.spa, AppColors.leaf],
    'spray': [Icons.water_drop, AppColors.gold],
    'water': [Icons.water_drop, AppColors.water],
    'harvest': [Icons.wb_sunny, AppColors.rust],
    'scout': [Icons.eco, AppColors.leafBright],
  };

  @override
  Widget build(BuildContext context) {
    final m = _meta[task.type] ?? _meta['scout']!;
    final icon = m[0] as IconData;
    final col = m[1] as Color;
    final done = task.done;

    return Opacity(
      opacity: done ? 0.45 : 1,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Column(children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: done ? AppColors.card : col,
                  borderRadius: BorderRadius.circular(12),
                  border:
                      isNext ? Border.all(color: AppColors.gold, width: 2) : null,
                ),
                child: Icon(done ? Icons.check_circle : icon,
                    size: 18,
                    color: done ? AppColors.creamDim : AppColors.soil),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                      width: 2,
                      color: AppColors.line,
                      margin: const EdgeInsets.symmetric(vertical: 2)),
                ),
            ]),
            const SizedBox(width: 14),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Expanded(
                        child: Text(task.title,
                            style: AppText.display(16.5,
                                weight: FontWeight.w700,
                                color: AppColors.cream)),
                      ),
                      const SizedBox(width: 8),
                      Text(_fmt(task.date),
                          style: AppText.body(11.5,
                              weight: FontWeight.w700, color: col)),
                    ]),
                    if (task.stage.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 1, bottom: 5),
                        child: Text(task.stage,
                            style: AppText.body(11.5,
                                color: AppColors.creamDim)),
                      ),
                    Text(task.detail,
                        style: AppText.body(14, color: AppColors.creamDim)),
                    if (!done)
                      Padding(
                        padding: const EdgeInsets.only(top: 9),
                        child: GestureDetector(
                          onTap: onDone,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 13, vertical: 7),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: AppColors.line),
                            ),
                            child: Row(mainAxisSize: MainAxisSize.min, children: [
                              const Icon(Icons.check_circle_outline,
                                  size: 14, color: AppColors.leafBright),
                              const SizedBox(width: 6),
                              Text(doneLabel,
                                  style: AppText.body(12.5,
                                      weight: FontWeight.w700,
                                      color: AppColors.leafBright)),
                            ]),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _fmt(String d) {
    try {
      return DateFormat('d MMM').format(DateTime.parse(d));
    } catch (_) {
      return d;
    }
  }
}
