import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_tts/flutter_tts.dart';
import '../theme/app_theme.dart';
import '../services/l10n.dart';
import '../services/inference_service.dart';
import '../services/storage.dart';
import '../models/models.dart';
import '../widgets/common.dart';

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
  final _tts = FlutterTts();

  String? _cropKey; // selected crop; null = show picker
  File? _image;
  bool _loading = false;
  bool _error = false;
  bool _speaking = false;
  Diagnosis? _result;

  // Which crops actually have a bundled model (others show "coming soon").
  final Map<String, bool> _available = {};

  L10n get t => L10n(widget.lang);

  @override
  void initState() {
    super.initState();
    _checkAvailability();
    _tts.setCompletionHandler(() {
      if (mounted) setState(() => _speaking = false);
    });
  }

  Future<void> _checkAvailability() async {
    for (final c in InferenceService.crops) {
      final key = c['key']!;
      _available[key] = await InferenceService.isAvailable(key);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<void> _pick(ImageSource src) async {
    final x =
        await _picker.pickImage(source: src, maxWidth: 1600, imageQuality: 88);
    if (x == null) return;
    setState(() {
      _image = File(x.path);
      _error = false;
      _result = null;
    });
  }

  Future<void> _diagnose() async {
    if (_image == null || _cropKey == null) return;
    setState(() {
      _loading = true;
      _error = false;
    });
    try {
      final d = await InferenceService.classify(
        image: _image!,
        cropKey: _cropKey!,
        lang: widget.lang,
      );
      await Storage.addToHistory(d);
      if (!mounted) return;
      setState(() {
        _result = d;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = true;
        _loading = false;
      });
    }
  }

  Future<void> _toggleSpeak() async {
    if (_speaking) {
      await _tts.stop();
      setState(() => _speaking = false);
      return;
    }
    await _tts.setLanguage(widget.lang == 'lg' ? 'sw' : 'en-GB');
    await _tts.setSpeechRate(0.46);
    setState(() => _speaking = true);
    await _tts.speak(
        _result!.spoken.isNotEmpty ? _result!.spoken : _result!.diagnosis);
  }

  void _resetToCapture() {
    _tts.stop();
    setState(() {
      _image = null;
      _result = null;
      _error = false;
      _speaking = false;
    });
  }

  void _changeCrop() {
    _tts.stop();
    setState(() {
      _cropKey = null;
      _image = null;
      _result = null;
      _error = false;
      _speaking = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_cropKey == null) return _buildCropPicker();
    if (_result != null) return _buildResult();
    return _buildCapture();
  }

  // ---------- CROP PICKER ----------
  Widget _buildCropPicker() {
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: t.get('chooseCrop'), onBack: () => Navigator.pop(context)),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(t.get('chooseCropSub'),
                  style: AppText.body(14, color: AppColors.creamDim)),
            ),
          ),
          Expanded(
            child: GridView.count(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              crossAxisCount: 2,
              mainAxisSpacing: 14,
              crossAxisSpacing: 14,
              childAspectRatio: 1.05,
              children: InferenceService.crops.map((c) {
                final key = c['key']!;
                return _CropTile(
                  name: widget.lang == 'lg' ? (c['luganda'] ?? c['name']!) : c['name']!,
                  cropKey: key,
                  available: _available[key] ?? false,
                  comingSoon: t.get('comingSoon'),
                  onTap: () {
                    if (_available[key] == true) {
                      setState(() => _cropKey = key);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(t.get('cropUnavailable'),
                            style: AppText.body(14)),
                        backgroundColor: AppColors.card,
                      ));
                    }
                  },
                );
              }).toList(),
            ),
          ),
        ]),
      ),
    );
  }

  // ---------- CAPTURE ----------
  Widget _buildCapture() {
    final cropName = InferenceService.crops
        .firstWhere((c) => c['key'] == _cropKey)[widget.lang == 'lg' ? 'luganda' : 'name'];
    return Scaffold(
      body: SafeArea(
        child: Column(children: [
          TopBar(title: cropName ?? t.get('scan'), onBack: _changeCrop),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
              child: Column(children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _pick(ImageSource.camera),
                    child: Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: _image == null ? AppColors.card : null,
                        borderRadius: BorderRadius.circular(24),
                        border: _image == null
                            ? Border.all(color: AppColors.line, width: 2)
                            : null,
                      ),
                      child: _image == null
                          ? _emptyState()
                          : ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              child: Image.file(_image!,
                                  fit: BoxFit.cover, width: double.infinity),
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                if (_error) _errorBanner(),
                if (_error) const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: _SmallBtn(
                      icon: Icons.photo_camera,
                      label: t.get('takePhoto'),
                      onTap: () => _pick(ImageSource.camera),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _SmallBtn(
                      icon: Icons.photo_library_outlined,
                      label: t.get('gallery'),
                      onTap: () => _pick(ImageSource.gallery),
                    ),
                  ),
                ]),
                const SizedBox(height: 12),
                BigButton(
                  label: _loading ? t.get('analyzing') : t.get('diagnose'),
                  icon: Icons.eco,
                  loading: _loading,
                  onTap: _image == null ? null : _diagnose,
                ),
              ]),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _emptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: AppColors.leaf,
            borderRadius: BorderRadius.circular(26),
            boxShadow: [
              BoxShadow(
                  color: AppColors.leaf.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10))
            ],
          ),
          child: const Icon(Icons.photo_camera, size: 40, color: AppColors.soil),
        ),
        const SizedBox(height: 16),
        Text(t.get('takePhoto'),
            style: AppText.display(19, weight: FontWeight.w700)),
        const SizedBox(height: 4),
        SizedBox(
          width: 240,
          child: Text(t.get('scanSub'),
              textAlign: TextAlign.center,
              style: AppText.body(13.5, color: AppColors.creamDim)),
        ),
      ],
    );
  }

  Widget _errorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.rust.withOpacity(0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.rust.withOpacity(0.33)),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.warning_amber_rounded, color: AppColors.rust, size: 20),
        const SizedBox(width: 11),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(t.get('errTitle'),
                style: AppText.body(14.5,
                    weight: FontWeight.w700, color: AppColors.cream)),
            const SizedBox(height: 2),
            Text(t.get('errBody'),
                style: AppText.body(13, color: AppColors.creamDim)),
          ]),
        ),
      ]),
    );
  }

  // ---------- RESULT ----------
  Widget _buildResult() {
    final d = _result!;
    return Scaffold(
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          SafeArea(
            bottom: false,
            child: TopBar(title: t.get('diagnose'), onBack: _resetToCapture),
          ),
          Stack(children: [
            SizedBox(
              height: 220,
              width: double.infinity,
              child: _image != null
                  ? Image.file(_image!, fit: BoxFit.cover)
                  : Container(color: AppColors.card),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [AppColors.soil, Colors.transparent],
                    stops: [0.04, 0.6],
                  ),
                ),
              ),
            ),
          ]),
          Transform.translate(
            offset: const Offset(0, -20),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 13, vertical: 6),
                    decoration: BoxDecoration(
                      color: d.healthy ? AppColors.leaf : AppColors.rust,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(
                          d.healthy
                              ? Icons.check_circle
                              : Icons.warning_amber_rounded,
                          size: 15,
                          color: d.healthy ? AppColors.soil : AppColors.cream),
                      const SizedBox(width: 7),
                      Text(d.crop.isEmpty ? 'Crop' : d.crop,
                          style: AppText.body(13,
                              weight: FontWeight.w700,
                              color: d.healthy
                                  ? AppColors.soil
                                  : AppColors.cream)),
                    ]),
                  ),
                  const SizedBox(height: 14),
                  Text(d.diagnosis, style: AppText.display(30, spacing: -1)),
                  const SizedBox(height: 14),
                  Row(children: [
                    ConfidenceRing(pct: d.confidence),
                    const SizedBox(width: 12),
                    Text(t.get('confidence'),
                        style: AppText.body(13, color: AppColors.creamDim)),
                    const Spacer(),
                    GestureDetector(
                      onTap: _toggleSpeak,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 11),
                        decoration: BoxDecoration(
                          color: _speaking ? AppColors.gold : AppColors.card,
                          borderRadius: BorderRadius.circular(13),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Row(children: [
                          Icon(_speaking ? Icons.stop : Icons.volume_up,
                              size: 17,
                              color: _speaking
                                  ? AppColors.soil
                                  : AppColors.cream),
                          const SizedBox(width: 7),
                          Text(_speaking ? t.get('stop') : t.get('listen'),
                              style: AppText.body(14,
                                  weight: FontWeight.w700,
                                  color: _speaking
                                      ? AppColors.soil
                                      : AppColors.cream)),
                        ]),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 18),
                  InfoBlock(
                      icon: Icons.eco, label: t.get('cause'), text: d.cause),
                  if (!d.healthy)
                    InfoBlock(
                        icon: Icons.spa,
                        label: t.get('organic'),
                        text: d.organic,
                        tint: AppColors.leaf),
                  if (!d.healthy)
                    InfoBlock(
                        icon: Icons.science,
                        label: t.get('chemical'),
                        text: d.chemical,
                        tint: AppColors.gold),
                  InfoBlock(
                      icon: Icons.check_circle_outline,
                      label: t.get('prevent'),
                      text: d.prevent),
                  const SizedBox(height: 8),
                  BigButton(
                    label: t.get('newScan'),
                    icon: Icons.photo_camera,
                    onTap: _resetToCapture,
                  ),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CropTile extends StatelessWidget {
  final String name;
  final String cropKey;
  final bool available;
  final String comingSoon;
  final VoidCallback onTap;
  const _CropTile(
      {required this.name,
      required this.cropKey,
      required this.available,
      required this.comingSoon,
      required this.onTap});

  static const _icons = {
    'cassava': Icons.grass,
    'maize': Icons.spa,
    'beans': Icons.eco,
    'matooke': Icons.park,
  };

  @override
  Widget build(BuildContext context) {
    final accent = available ? AppColors.leafBright : AppColors.creamDim;
    return GestureDetector(
      onTap: onTap,
      child: Opacity(
        opacity: available ? 1 : 0.55,
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
                color: available ? AppColors.line : AppColors.line),
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                        color: (available ? AppColors.leaf : AppColors.creamDim)
                            .withOpacity(0.15),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(_icons[cropKey] ?? Icons.eco,
                          size: 30, color: accent),
                    ),
                    const SizedBox(height: 12),
                    Text(name,
                        style: AppText.display(17, weight: FontWeight.w700)),
                  ],
                ),
              ),
              if (!available)
                Positioned(
                  top: 10,
                  right: 10,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.soil2,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: AppColors.line),
                    ),
                    child: Text(comingSoon,
                        style: AppText.body(10.5,
                            weight: FontWeight.w700,
                            color: AppColors.creamDim)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SmallBtn extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _SmallBtn(
      {required this.icon, required this.label, required this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 18, color: AppColors.leafBright),
          const SizedBox(width: 8),
          Text(label,
              style: AppText.body(14,
                  weight: FontWeight.w600, color: AppColors.cream)),
        ]),
      ),
    );
  }
}
