import 'dart:io';
import 'dart:math' as math;
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

  /// Classify [image] for [cropKey], returning a full Diagnosis with treatment
  /// text pulled from the offline TreatmentDB in the chosen [lang].
  static Future<Diagnosis> classify({
    required File image,
    required String cropKey,
    required String lang,
  }) async {
    await _ensureLoaded(cropKey);
    final interpreter = _interpreters[cropKey]!;
    final labels = _labels[cropKey]!;

    final input = await _preprocess(image);
    // Output buffer: [1, numClasses]
    final output =
        List.filled(labels.length, 0.0).reshape([1, labels.length]);
    interpreter.run(input, output);

    final scores = (output[0] as List).cast<double>();
    // softmax already applied in-model; pick the top class.
    int best = 0;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > scores[best]) best = i;
    }
    final label = labels[best];
    final confidence = (scores[best] * 100).round().clamp(0, 100);

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

  /// Resize, convert to RGB float tensor matching the training preprocessing.
  /// MobileNetV2/EfficientNet preprocessing is folded into the model graph
  /// (we added preprocess_input inside build_model), so here we only need to
  /// provide raw 0..255 RGB floats shaped [1, H, W, 3].
  static Future<List<List<List<List<double>>>>> _preprocess(File file) async {
    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      throw Exception('Could not read image');
    }
    final resized =
        img.copyResize(decoded, width: imgSize, height: imgSize);

    return [
      List.generate(imgSize, (y) {
        return List.generate(imgSize, (x) {
          final p = resized.getPixel(x, y);
          return [p.r.toDouble(), p.g.toDouble(), p.b.toDouble()];
        });
      })
    ];
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
