import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';
import '../models/models.dart';
import 'treatment_db.dart';

/// Runs crop-disease classification fully ON-DEVICE using bundled TFLite models.
/// No internet required. One model per crop, selected by the user.
///
/// Each crop needs two asset files:
///   assets/models/<crop>.tflite
///   assets/models/<crop>_labels.txt   (one class name per line)
class InferenceService {
  static const int imgSize = 224; // must match training (configs/crops.py)

  // Cache loaded interpreters so we don't reload on every scan.
  static final Map<String, Interpreter> _interpreters = {};
  static final Map<String, List<String>> _labels = {};

  /// Crops available offline. Add a crop here once its assets are bundled.
  /// 'name' is shown in the picker; 'key' matches the asset filenames.
  static const List<Map<String, String>> crops = [
    {'key': 'cassava', 'name': 'Cassava', 'luganda': 'Muwogo'},
    {'key': 'maize', 'name': 'Maize', 'luganda': 'Kasooli'},
    {'key': 'beans', 'name': 'Beans', 'luganda': 'Bijanjaalo'},
    {'key': 'matooke', 'name': 'Matooke', 'luganda': 'Matooke'},
  ];

  /// Load (and cache) the interpreter + labels for a crop.
  static Future<void> _ensureLoaded(String cropKey) async {
    if (_interpreters.containsKey(cropKey)) return;
    final interpreter =
        await Interpreter.fromAsset('assets/models/$cropKey.tflite');
    _interpreters[cropKey] = interpreter;

    final raw = await rootBundle.loadString('assets/models/${cropKey}_labels.txt');
    _labels[cropKey] = raw
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
  }

  /// Whether a crop's model is actually bundled (so the UI can hide missing ones).
  static Future<bool> isAvailable(String cropKey) async {
    try {
      await rootBundle.load('assets/models/$cropKey.tflite');
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Below this, we don't trust the model's answer enough to show it.
  static const double _minConfidence = 0.55;

  /// Classify [image] for [cropKey], returning a full Diagnosis with treatment
  /// text pulled from the offline TreatmentDB in the chosen [lang].
  ///
  /// Throws [NotAPlantException] if the photo doesn't look like a leaf at all,
  /// or [LowConfidenceException] if the model isn't confident enough to trust.
  /// Both are caught by the UI and shown as a friendly "try again" message
  /// instead of a wrong diagnosis.
  static Future<Diagnosis> classify({
    required File image,
    required String cropKey,
    required String lang,
  }) async {
    await _ensureLoaded(cropKey);
    final interpreter = _interpreters[cropKey]!;
    final labels = _labels[cropKey]!;

    final bytes = await image.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not read image');
    }
    final resized = img.copyResize(decoded, width: imgSize, height: imgSize);

    // Sanity check BEFORE running the model: does this even look like a
    // natural leaf photo? Screenshots, documents, and plain walls are mostly
    // white/gray/neutral with low colour saturation - real leaf photos
    // (healthy green, or diseased yellow/brown/orange) are not.
    if (!_looksLikePlant(resized)) {
      throw NotAPlantException();
    }

    final input = _tensorFrom(resized);
    // Output buffer: [1, numClasses]
    final output =
        List.filled(labels.length, 0.0).reshape([1, labels.length]);
    interpreter.run(input, output);

    final scores = (output[0] as List)
        .map((e) => (e as num).toDouble())
        .toList();
    // softmax already applied in-model; pick the top class.
    int best = 0;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    final topScore = scores[best];
    if (topScore < _minConfidence) {
      throw LowConfidenceException();
    }

    final label = labels[best];
    final confidence = (topScore * 100).round().clamp(0, 100);

    final cropName = crops.firstWhere((c) => c['key'] == cropKey,
        orElse: () => {'name': cropKey})['name']!;
    final tr = TreatmentDB.lookup(label, lang);
    final healthy = TreatmentDB.isHealthy(label);
    final pretty = _prettyLabel(label, cropName);

    return Diagnosis(
      crop: cropName,
      diagnosis: pretty,
      confidence: confidence,
      healthy: healthy,
      cause: tr.cause,
      organic: tr.organic,
      chemical: tr.chemical,
      prevent: tr.prevent,
      spoken: '$pretty. ${tr.cause} ${healthy ? '' : tr.organic}',
      imagePath: image.path,
    );
  }

  /// Rough, cheap check for "is this a natural plant photo at all". We look
  /// at colour saturation and brightness across a sample of pixels. Screens,
  /// documents and screenshots are dominated by near-white/near-gray/near-black
  /// low-saturation pixels; leaf photos (any disease colour) are not.
  static bool _looksLikePlant(img.Image resized) {
    int naturalish = 0;
    int sampled = 0;
    for (int y = 0; y < resized.height; y += 4) {
      for (int x = 0; x < resized.width; x += 4) {
        final p = resized.getPixel(x, y);
        final r = p.r.toDouble(), g = p.g.toDouble(), b = p.b.toDouble();
        final maxC = math.max(r, math.max(g, b));
        final minC = math.min(r, math.min(g, b));
        final saturation = maxC <= 0 ? 0.0 : (maxC - minC) / maxC;
        final tooBright = maxC > 245 && saturation < 0.12; // near-white
        final tooDark = maxC < 30; // near-black (plain text)
        if (saturation > 0.15 && !tooBright && !tooDark) {
          naturalish++;
        }
        sampled++;
      }
    }
    if (sampled == 0) return false;
    return (naturalish / sampled) > 0.18;
  }

  /// Resize, convert to RGB float tensor matching the training preprocessing.
  /// MobileNetV2/EfficientNet preprocessing is folded into the model graph
  /// (we added preprocess_input inside build_model), so here we only need to
  /// provide raw 0..255 RGB floats shaped [1, H, W, 3].
  static List<List<List<List<double>>>> _tensorFrom(img.Image resized) {
    return List.generate(1, (_) {
      return List.generate(imgSize, (y) {
        return List.generate(imgSize, (x) {
          final p = resized.getPixel(x, y);
          return <double>[
            p.r.toDouble(),
            p.g.toDouble(),
            p.b.toDouble(),
          ];
        });
      });
    });
  }

  static String _prettyLabel(String label, String cropName) {
    if (TreatmentDB.isHealthy(label)) return 'Healthy';
    // Strip a leading crop prefix and title-case the rest.
    var s = label;
    final prefix = cropName.toLowerCase();
    if (s.toLowerCase().startsWith(prefix)) {
      s = s.substring(prefix.length);
    }
    s = s.replaceAll('_', ' ').trim();
    return s.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  static void disposeAll() {
    for (final i in _interpreters.values) {
      i.close();
    }
    _interpreters.clear();
    _labels.clear();
  }
}

/// Thrown when the photo doesn't look like a natural leaf photo at all
/// (e.g. a screenshot, document, or plain wall).
class NotAPlantException implements Exception {}

/// Thrown when the model ran but wasn't confident enough in any class to
/// trust the result.
class LowConfidenceException implements Exception {}