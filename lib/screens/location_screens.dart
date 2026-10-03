import 'package:flutter/material.dart';
import '../services/areas.dart';
import '../services/l10n.dart';
import '../services/location.dart';
import '../services/storage.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// Asks the farmer whether, and how, to record where scans are made. Shown
/// before any location is collected (first scan) and from Account. Pops
/// with true once a choice is saved.
class LocationConsentScreen extends StatefulWidget {
  final String lang;
  const LocationConsentScreen({super.key, required this.lang});

  @override
  State<LocationConsentScreen> createState() => _LocationConsentScreenState();
}

class _LocationConsentScreenState extends State<LocationConsentScreen> {
  LocationMode _mode = LocationMode.gps;
  bool _busy = false;
  String? _noticeKey;

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    Storage.getLocationMode().then((m) {
      final saved = LocationMode.parse(m);
      if (saved != null && mounted) setState(() => _mode = saved);
    });
  }

  Future<void> _continue() async {
    setState(() {
      _busy = true;
      _noticeKey = null;
    });
    try {
      switch (_mode) {
        case LocationMode.none:
          await Storage.setLocation(mode: 'none');
          _done();
        case LocationMode.manual:
          final pick = await _pickArea();
          if (pick == null) return;
          await Storage.setLocation(
              mode: 'manual', district: pick.$1, subcounty: pick.$2);
          _done();
        case LocationMode.gps:
          if (!await LocationService.requestPermission()) {
            // Permission refused: fall back to choosing the area by hand.
            setState(() {
              _mode = LocationMode.manual;
              _noticeKey = 'locDenied';
            });
            return;
          }
          // Remember the current district as the home area, used when GPS
          // isn't available at scan time. Ask if it can't be found.
          final pick = await LocationService.currentArea() ?? await _pickArea();
          if (pick == null) return;
          await Storage.setLocation(
              mode: 'gps', district: pick.$1, subcounty: pick.$2);
          _done();
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<(String, String?)?> _pickArea() => Navigator.push<(String, String?)>(
      context,
      MaterialPageRoute(builder: (_) => AreaPickerScreen(lang: widget.lang)));

  void _done() {
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('locTitle')),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 20),
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: IconTile(icon: Icons.location_on_outlined),
                ),
                const SizedBox(height: 16),
                Text(t.get('locHeading'), style: AppText.display(24)),
                const SizedBox(height: 8),
                Text(t.get('locWhy'),
                    style: AppText.body(15, color: AppColors.textDim)),
                const SizedBox(height: 14),
                Notice(
                  icon: Icons.lock_outline,
                  color: AppColors.info,
                  text: t.get('locPrivacy'),
                ),
                const SizedBox(height: 20),
                for (final (mode, icon, title, sub) in [
                  (LocationMode.gps, Icons.my_location, 'locGps', 'locGpsSub'),
                  (
                    LocationMode.manual,
                    Icons.map_outlined,
                    'locManual',
                    'locManualSub'
                  ),
                  (
                    LocationMode.none,
                    Icons.location_off_outlined,
                    'locNone',
                    'locNoneSub'
                  ),
                ])
                  _OptionCard(
                    icon: icon,
                    title: t.get(title),
                    sub: t.get(sub),
                    selected: _mode == mode,
                    onTap: _busy ? null : () => setState(() => _mode = mode),
                  ),
                if (_noticeKey != null) ...[
                  const SizedBox(height: 4),
                  Notice(
                      icon: Icons.info_outline,
                      color: AppColors.accent,
                      text: t.get(_noticeKey!)),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 18),
            child: BigButton(
              label: _busy ? t.get('locFinding') : t.get('continue'),
              icon: Icons.arrow_forward,
              loading: _busy,
              onTap: _continue,
            ),
          ),
        ]),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final bool selected;
  final VoidCallback? onTap;
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.selected,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? AppColors.primarySoft : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
              color: selected ? AppColors.primary : AppColors.border,
              width: selected ? 1.5 : 1),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 10, 14),
            child: Row(children: [
              Icon(icon,
                  size: 24,
                  color: selected ? AppColors.primary : AppColors.textDim),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: AppText.body(15.5, weight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: AppText.body(13.5, color: AppColors.textDim)),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected ? AppColors.primary : AppColors.textDim,
              ),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Searchable district list, then an optional sub-county. Pops with
/// (districtId, subcounty or null).
class AreaPickerScreen extends StatefulWidget {
  final String lang;
  const AreaPickerScreen({super.key, required this.lang});

  @override
  State<AreaPickerScreen> createState() => _AreaPickerScreenState();
}

class _AreaPickerScreenState extends State<AreaPickerScreen> {
  final _search = TextEditingController();
  List<District> _all = [];
  District? _district; // chosen district: now showing its sub-counties

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    Areas.districts().then((d) {
      if (mounted) setState(() => _all = d);
    });
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _chooseDistrict(District d) {
    _search.clear();
    setState(() => _district = d);
  }

  @override
  Widget build(BuildContext context) {
    final d = _district;
    final q = _search.text.trim().toLowerCase();
    final items = d == null
        ? _all.where((x) => x.name.toLowerCase().contains(q)).toList()
        : d.subcounties.where((s) => s.toLowerCase().contains(q)).toList();

    return PopScope(
      // Back from the sub-county list returns to the district list.
      canPop: d == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _district = null);
      },
      child: Scaffold(
        body: SafeArea(
          child: Column(children: [
            TopBar(
              title: d == null ? t.get('pickDistrict') : d.name,
              onBack: d == null
                  ? null
                  : () => setState(() {
                        _search.clear();
                        _district = null;
                      }),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (d != null) ...[
                    Text(t.get('pickSubcounty'),
                        style: AppText.body(15, color: AppColors.textDim)),
                    const SizedBox(height: 12),
                  ],
                  AppTextField(
                    controller: _search,
                    hint: t.get(d == null ? 'searchDistrict' : 'searchSub'),
                    icon: Icons.search,
                    onChanged: (_) => setState(() {}),
                  ),
                  const SizedBox(height: 8),
                  // Required attribution for the boundary data (CC BY 3.0 IGO).
                  Text(t.get('areasSource'),
                      style: AppText.body(12, color: AppColors.textDim)),
                ],
              ),
            ),
            if (d != null)
              _AreaTile(
                title: t.get('skipSubcounty'),
                icon: Icons.arrow_forward,
                emphasis: true,
                onTap: () => Navigator.pop(context, (d.id, null)),
              ),
            Expanded(
              child: _all.isEmpty
                  ? const Center(
                      child:
                          CircularProgressIndicator(color: AppColors.primary))
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: items.length,
                      itemBuilder: (_, i) {
                        final item = items[i];
                        if (item is District) {
                          return _AreaTile(
                            title: item.name,
                            icon: Icons.chevron_right,
                            onTap: () => _chooseDistrict(item),
                          );
                        }
                        final sub = item as String;
                        return _AreaTile(
                          title: sub,
                          onTap: () => Navigator.pop(context, (d!.id, sub)),
                        );
                      },
                    ),
            ),
          ]),
        ),
      ),
    );
  }
}

class _AreaTile extends StatelessWidget {
  final String title;
  final IconData? icon;
  final bool emphasis;
  final VoidCallback onTap;
  const _AreaTile({
    required this.title,
    required this.onTap,
    this.icon,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 15),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: AppColors.border)),
        ),
        child: Row(children: [
          Expanded(
            child: Text(title,
                style: AppText.body(15.5,
                    weight: emphasis ? FontWeight.w700 : FontWeight.w500,
                    color: emphasis ? AppColors.primary : AppColors.text)),
          ),
          if (icon != null)
            Icon(icon,
                size: 20,
                color: emphasis ? AppColors.primary : AppColors.textDim),
        ]),
      ),
    );
  }
}
