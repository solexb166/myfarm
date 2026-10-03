import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/models.dart';
import '../services/areas.dart';
import '../services/backend.dart';
import '../services/inference_service.dart';
import '../services/l10n.dart';
import '../services/storage.dart';
import '../services/treatment_db.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import 'location_screens.dart';
import 'sign_in_screen.dart' show accountErrorKey;

/// The district "Diseases near you" is about: one picked on that screen,
/// else the farmer's home area, else where their last scan was made.
Future<String?> nearYouDistrict() async {
  final picked = await Storage.getAreaDistrict();
  if (picked != null) return picked;
  final home = await Storage.getHomeDistrict();
  if (home != null) return home;
  for (final d in await Storage.getHistory()) {
    if (d.districtId != null) return d.districtId;
  }
  return null;
}

/// Diseases near you: which diseases farmers in the district are finding,
/// with the advice to protect against each. Totals only, from the server;
/// the last download is kept for offline use.
class AreaScreen extends StatefulWidget {
  final String lang;
  const AreaScreen({super.key, required this.lang});

  @override
  State<AreaScreen> createState() => _AreaScreenState();
}

class _AreaScreenState extends State<AreaScreen> {
  L10n get t => L10n(widget.lang);

  bool _loading = true;
  District? _district;
  AreaReport? _report;
  String? _errorKey;
  String? _open; // label of the disease showing its advice

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final id = await nearYouDistrict();
    final district = await Areas.byId(id);
    if (!mounted) return;
    setState(() {
      _district = district;
      _loading = district != null;
      _errorKey = null;
    });
    if (district == null) return;
    try {
      final report = await Backend.areaReport(district.id);
      if (mounted) setState(() => _report = report);
    } on AccountError catch (e) {
      if (mounted) {
        setState(() => _errorKey =
            e == AccountError.offline ? 'areaNeedsNet' : accountErrorKey(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickDistrict() async {
    final pick = await Navigator.push<(String, String?)>(context,
        MaterialPageRoute(builder: (_) => AreaPickerScreen(lang: widget.lang)));
    if (pick == null) return;
    await Storage.setAreaDistrict(pick.$1);
    setState(() => _report = null);
    await _load();
  }

  @override
  Widget build(BuildContext context) {
    final d = _district;
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(
            title: t.get('nearYou'),
            trailing: d == null
                ? null
                : TextButton(
                    onPressed: _pickDistrict,
                    child: Text(t.get('change'),
                        style: AppText.body(14.5,
                            weight: FontWeight.w700, color: AppColors.primary)),
                  ),
          ),
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                children: d == null ? _noDistrict() : _forDistrict(d),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  List<Widget> _noDistrict() => [
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
                child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else ...[
          const SizedBox(height: 24),
          const Align(
              alignment: Alignment.centerLeft,
              child: IconTile(icon: Icons.travel_explore, size: 52)),
          const SizedBox(height: 16),
          Text(t.get('nearYouPick'),
              style: AppText.body(16, color: AppColors.textDim)),
          const SizedBox(height: 20),
          BigButton(
            label: t.get('pickDistrictBtn'),
            icon: Icons.map_outlined,
            onTap: _pickDistrict,
          ),
        ],
      ];

  List<Widget> _forDistrict(District d) {
    final report = _report;
    final date = DateFormat('d MMM y');
    return [
      Text(t.get('nearYouSub').replaceAll('{district}', d.name),
          style: AppText.display(22)),
      const SizedBox(height: 6),
      if (report != null && report.farmers > 0)
        Text(
            t
                .get('areaBasis')
                .replaceAll('{n}', '${report.farmers}')
                .replaceAll('{d}', '${report.days}'),
            style: AppText.body(14.5, color: AppColors.textDim)),
      if (report != null &&
          DateTime.now().millisecondsSinceEpoch - report.fetchedAt >
              const Duration(minutes: 10).inMilliseconds) ...[
        const SizedBox(height: 4),
        Row(children: [
          const Icon(Icons.history, size: 16, color: AppColors.textDim),
          const SizedBox(width: 6),
          Text(
              t.get('areaUpdated').replaceAll(
                  '{date}',
                  date.format(
                      DateTime.fromMillisecondsSinceEpoch(report.fetchedAt))),
              style: AppText.body(13.5, color: AppColors.textDim)),
        ]),
      ],
      const SizedBox(height: 18),
      if (_loading && report == null)
        const Padding(
          padding: EdgeInsets.only(top: 60),
          child: Center(
              child: CircularProgressIndicator(color: AppColors.primary)),
        )
      else if (report == null) ...[
        Notice(
            icon: Icons.wifi_off,
            color: AppColors.accent,
            text: t.get(_errorKey ?? 'areaNeedsNet')),
        const SizedBox(height: 14),
        BigButton(label: t.get('retry'), icon: Icons.refresh, onTap: _load),
      ] else if (report.diseases.isEmpty)
        _EmptyArea(
          title: t.get('areaEmpty').replaceAll('{district}', d.name),
          sub: t.get('areaEmptySub'),
        )
      else
        for (final disease in report.diseases)
          _DiseaseCard(
            disease: disease,
            lang: widget.lang,
            open: _open == disease.label,
            onTap: () => setState(
                () => _open = _open == disease.label ? null : disease.label),
          ),
      const SizedBox(height: 10),
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lock_outline, size: 16, color: AppColors.textDim),
        const SizedBox(width: 8),
        Expanded(
          child: Text(t.get('areaPrivacy'),
              style: AppText.body(13, color: AppColors.textDim)),
        ),
      ]),
    ];
  }
}

class _EmptyArea extends StatelessWidget {
  final String title;
  final String sub;
  const _EmptyArea({required this.title, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.verified_outlined, size: 26, color: AppColors.primary),
        const SizedBox(height: 10),
        Text(title, style: AppText.body(16, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(sub, style: AppText.body(14, color: AppColors.textDim)),
      ]),
    );
  }
}

/// One disease: crop picture, name, how many farmers found it; tap to show
/// how to protect against it.
class _DiseaseCard extends StatelessWidget {
  final AreaDisease disease;
  final String lang;
  final bool open;
  final VoidCallback onTap;
  const _DiseaseCard({
    required this.disease,
    required this.lang,
    required this.open,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final t = L10n(lang);
    final cropKey = InferenceService.cropKeyFor(disease.crop) ?? '';
    final lastSeen = DateTime.tryParse(disease.lastSeen);
    final advice = TreatmentDB.lookup(disease.label, lang);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
              color: open ? AppColors.primary : AppColors.border,
              width: open ? 1.5 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  CropArt(cropKey: cropKey, size: 50),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(InferenceService.prettyLabel(disease.label),
                            style: AppText.body(16.5, weight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(
                          InferenceService.cropDisplayName(disease.crop, lang),
                          style: AppText.body(13.5, color: AppColors.textDim),
                        ),
                      ],
                    ),
                  ),
                  Icon(open ? Icons.expand_less : Icons.expand_more,
                      color: AppColors.textDim),
                ]),
                const SizedBox(height: 12),
                Row(children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const Icon(Icons.groups_outlined,
                          size: 16, color: AppColors.danger),
                      const SizedBox(width: 6),
                      Text(
                          t
                              .get('areaFarmers')
                              .replaceAll('{n}', '${disease.farmers}'),
                          style: AppText.body(13.5,
                              weight: FontWeight.w700,
                              color: AppColors.danger)),
                    ]),
                  ),
                  const SizedBox(width: 10),
                  if (lastSeen != null)
                    Expanded(
                      child: Text(
                        t.get('areaLastSeen').replaceAll(
                            '{date}', DateFormat('d MMM').format(lastSeen)),
                        style: AppText.body(13.5, color: AppColors.textDim),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ]),
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  alignment: Alignment.topCenter,
                  child: !open
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.get('whatToDo'),
                                  style: AppText.display(16,
                                      weight: FontWeight.w700)),
                              const SizedBox(height: 10),
                              InfoBlock(
                                  icon: Icons.shield_outlined,
                                  label: t.get('prevent'),
                                  text: advice.prevent,
                                  tint: AppColors.info),
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
