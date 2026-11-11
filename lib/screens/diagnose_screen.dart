import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/app_theme.dart';
import '../services/l10n.dart';
import '../services/inference_service.dart';
import '../services/backend.dart';
import '../services/location.dart';
import '../services/storage.dart';
import '../models/models.dart';
import '../widgets/common.dart';
import '../widgets/crop_art.dart';
import '../widgets/diagnosis_view.dart';
import 'location_screens.dart';

/// Offline crop-disease diagnosis. Flow: pick crop -> photo -> on-device
/// TFLite classification -> result with treatment (no internet needed).
class DiagnoseScreen extends StatefulWidget {
  final String lang;
  const DiagnoseScreen({super.key, required this.lang});
  @override
  State<DiagnoseScreen> createState() => _DiagnoseScreenState();
}

class _DiagnoseScreenState extends State<DiagnoseScreen> {
  final _picker = ImagePicker();

  String? _cropKey; // selected crop; null = show picker
  File? _image;
  bool _loading = false;
  _ErrorKind? _error;
  Diagnosis? _result;

  // Which crops actually have a bundled model (others show "coming soon").
  final Map<String, bool> _available = {};
  bool _checked = false;

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    _checkAvailability();
    _askLocationOnce();
  }

  /// Before the first scan is recorded, ask whether to record where scans
  /// are made. Only needed when scans are uploaded (backend on).
  Future<void> _askLocationOnce() async {
    if (!Backend.enabled || await Storage.getLocationMode() != null) return;
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => LocationConsentScreen(lang: widget.lang)));
    Backend.sync(); // upload the choice to the profile
  }

  Future<void> _checkAvailability() async {
    for (final c in InferenceService.crops) {
      final key = c['key']!;
      _available[key] = await InferenceService.isAvailable(key);
    }
    if (mounted) setState(() => _checked = true);
  }

  Future<void> _pick(ImageSource src) async {
    final x =
        await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 88);
    if (x == null) return;
    setState(() {
      _image = File(x.path);
      _error = null;
      _result = null;
    });
  }

  Future<void> _diagnose() async {
    if (_image == null || _cropKey == null) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    // Find where the scan is made while the model runs; never wait long.
    final place = LocationService.placeForScan()
        .timeout(const Duration(seconds: 10), onTimeout: () => null)
        .catchError((_) => null);
    try {
      var d = await InferenceService.classify(
        image: _image!,
        cropKey: _cropKey!,
        lang: widget.lang,
      );
      final p = await place;
      if (p != null) {
        d = d.copyWith(
          districtId: p.districtId,
          subcounty: p.subcounty,
          locationSource: p.source,
          lat: p.lat,
          lng: p.lng,
        );
      }
      await Storage.addToHistory(d);
      Backend.sync();
      if (!mounted) return;
      setState(() {
        _result = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e is NotAPlantException
            ? _ErrorKind.notPlant
            : e is LowConfidenceException
                ? _ErrorKind.unsure
                : _ErrorKind.generic;
        _loading = false;
      });
    }
  }

  void _resetToCapture() {
    setState(() {
      _image = null;
      _result = null;
      _error = null;
    });
  }

  void _changeCrop() {
    setState(() {
      _cropKey = null;
      _image = null;
      _result = null;
      _error = null;
    });
  }

  String _cropName(Map<String, String> c) =>
      widget.lang == 'lg' ? (c['luganda'] ?? c['name']!) : c['name']!;

  @override
  Widget build(BuildContext context) {
    if (_result != null) {
      return DiagnosisView(
        d: _result!,
        lang: widget.lang,
        onBack: _resetToCapture,
        footer: BigButton(
          label: t.get('newScan'),
          icon: Icons.photo_camera_outlined,
          onTap: _resetToCapture,
        ),
      );
    }
    if (_cropKey == null) return _buildCropPicker();
    return _buildCapture();
  }

  // ---------- CROP PICKER ----------
  Widget _buildCropPicker() {
    final ready = InferenceService.crops
        .where((c) => _available[c['key']] == true)
        .toList();
    final soon = InferenceService.crops
        .where((c) => _available[c['key']] != true)
        .toList();
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('chooseCrop')),
          Expanded(
            child: !_checked
                ? const Center(
                    child: CircularProgressIndicator(color: AppColors.primary))
                : ListView(
                    padding: const EdgeInsets.only(bottom: 24),
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                        child: Text(t.get('chooseCropSub'),
                            style: AppText.body(14, color: AppColors.textDim)),
                      ),
                      SettingsGroup(indent: 80, children: [
                        for (final c in ready)
                          _CropRow(
                            cropKey: c['key']!,
                            name: _cropName(c),
                            sub: widget.lang == 'lg'
                                ? c['name']!
                                : c['luganda']!,
                            onTap: () => setState(() => _cropKey = c['key']),
                          ),
                      ]),
                      if (soon.isNotEmpty) ...[
                        SettingsHeader(t.get('comingSoonTitle')),
                        SettingsGroup(indent: 80, children: [
                          for (final c in soon)
                            _CropRow(
                              cropKey: c['key']!,
                              name: _cropName(c),
                              sub: t.get('cropUnavailable'),
                              soonLabel: t.get('comingSoon'),
                            ),
                        ]),
                      ],
                    ],
                  ),
          ),
        ]),
      ),
    );
  }

  // ---------- CAPTURE ----------
  Widget _buildCapture() {
    final crop = InferenceService.crops.firstWhere((c) => c['key'] == _cropKey);
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: _cropName(crop), onBack: _changeCrop),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              children: [
                _image == null ? _photoTips() : _photoPreview(),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  _ErrorNotice(kind: _error!, t: t),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
            child: Column(children: [
              Row(children: [
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_camera_outlined,
                    label: t.get('takePhoto'),
                    onTap: _loading ? null : () => _pick(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SourceButton(
                    icon: Icons.photo_library_outlined,
                    label: t.get('gallery'),
                    onTap: _loading ? null : () => _pick(ImageSource.gallery),
                  ),
                ),
              ]),
              const SizedBox(height: 12),
              BigButton(
                label: _loading ? t.get('analyzing') : t.get('diagnose'),
                icon: Icons.biotech_outlined,
                loading: _loading,
                onTap: _image == null ? null : _diagnose,
              ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _photoPreview() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Image.file(_image!, fit: BoxFit.cover),
      ),
    );
  }

  Widget _photoTips() {
    Widget tip(IconData icon, String text) => Padding(
          padding: const EdgeInsets.only(top: 14),
          child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(child: Text(text, style: AppText.body(14.5))),
          ]),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 12),
        Center(
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
                color: AppColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.photo_camera_outlined,
                size: 34, color: AppColors.primary),
          ),
        ),
        const SizedBox(height: 14),
        Center(
          child: Text(t.get('photoTitle'),
              textAlign: TextAlign.center,
              style: AppText.display(19, weight: FontWeight.w700)),
        ),
        const SizedBox(height: 22),
        Text(t.get('tipsTitle').toUpperCase(),
            style: AppText.body(12,
                    weight: FontWeight.w700, color: AppColors.textDim)
                .copyWith(letterSpacing: 0.6)),
        tip(Icons.crop_free, t.get('tip1')),
        tip(Icons.wb_sunny_outlined, t.get('tip2')),
        tip(Icons.center_focus_strong_outlined, t.get('tip3')),
      ],
    );
  }
}

class _CropRow extends StatelessWidget {
  final String cropKey;
  final String name;
  final String sub;
  final String? soonLabel; // set for crops that aren't available yet
  final VoidCallback? onTap;
  const _CropRow({
    required this.cropKey,
    required this.name,
    required this.sub,
    this.soonLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final soon = soonLabel != null;
    return SettingsRow(
      leadingWidth: 48,
      leading: CropArt(cropKey: cropKey, size: 48, muted: soon),
      title: name,
      sub: sub.isNotEmpty && sub != name ? sub : null,
      color: soon ? AppColors.textDim : null,
      value: soonLabel,
      trailing: soon ? null : Icons.chevron_right,
      onTap: onTap,
    );
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  const _SourceButton({required this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 20),
      label: Text(label,
          style: AppText.body(14.5,
              weight: FontWeight.w600,
              color: onTap == null ? AppColors.textDim : AppColors.text)),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.primary,
        backgroundColor: AppColors.surface,
        side: const BorderSide(color: AppColors.border),
        padding: const EdgeInsets.symmetric(vertical: 15),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

enum _ErrorKind { generic, notPlant, unsure }

class _ErrorNotice extends StatelessWidget {
  final _ErrorKind kind;
  final L10n t;
  const _ErrorNotice({required this.kind, required this.t});

  @override
  Widget build(BuildContext context) {
    final (title, body) = switch (kind) {
      _ErrorKind.notPlant => ('notPlantTitle', 'notPlantBody'),
      _ErrorKind.unsure => ('unsureTitle', 'unsureBody'),
      _ErrorKind.generic => ('errTitle', 'errBody'),
    };
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerSoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 21),
        const SizedBox(width: 11),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.get(title),
                style: AppText.body(15, weight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(t.get(body), style: AppText.body(14, color: AppColors.text)),
          ]),
        ),
      ]),
    );
  }
}
