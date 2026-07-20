/// Plain data models. All JSON-serialisable so they can be cached to disk
/// (shared_preferences) and work offline once fetched.

class Diagnosis {
  final String crop;
  final String diagnosis;
  final int confidence;
  final bool healthy;
  final String cause;
  final String organic;
  final String chemical;
  final String prevent;
  final String spoken;
  final String? imagePath; // local file path of the photo
  final int timestamp;

  Diagnosis({
    required this.crop,
    required this.diagnosis,
    required this.confidence,
    required this.healthy,
    required this.cause,
    required this.organic,
    required this.chemical,
    required this.prevent,
    required this.spoken,
    this.imagePath,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        crop: (j['crop'] ?? '').toString(),
        diagnosis: (j['diagnosis'] ?? 'Unknown').toString(),
        confidence: _toInt(j['confidence']),
        healthy: j['healthy'] == true,
        cause: (j['cause'] ?? '').toString(),
        organic: (j['organic'] ?? '').toString(),
        chemical: (j['chemical'] ?? '').toString(),
        prevent: (j['prevent'] ?? '').toString(),
        spoken: (j['spoken'] ?? '').toString(),
        imagePath: j['imagePath']?.toString(),
        timestamp: j['timestamp'] is int ? j['timestamp'] : null,
      );

  Map<String, dynamic> toJson() => {
        'crop': crop,
        'diagnosis': diagnosis,
        'confidence': confidence,
        'healthy': healthy,
        'cause': cause,
        'organic': organic,
        'chemical': chemical,
        'prevent': prevent,
        'spoken': spoken,
        'imagePath': imagePath,
        'timestamp': timestamp,
      };

  Diagnosis copyWith({String? imagePath}) => Diagnosis(
        crop: crop,
        diagnosis: diagnosis,
        confidence: confidence,
        healthy: healthy,
        cause: cause,
        organic: organic,
        chemical: chemical,
        prevent: prevent,
        spoken: spoken,
        imagePath: imagePath ?? this.imagePath,
        timestamp: timestamp,
      );
}

class CropTask {
  final String title;
  final String detail;
  final String date; // YYYY-MM-DD
  final String type; // fertilizer | spray | water | harvest | scout
  final String stage;
  bool done;

  CropTask({
    required this.title,
    required this.detail,
    required this.date,
    required this.type,
    required this.stage,
    this.done = false,
  });

  factory CropTask.fromJson(Map<String, dynamic> j) => CropTask(
        title: (j['title'] ?? '').toString(),
        detail: (j['detail'] ?? '').toString(),
        date: (j['date'] ?? '').toString(),
        type: (j['type'] ?? 'scout').toString(),
        stage: (j['stage'] ?? '').toString(),
        done: j['done'] == true,
      );

  Map<String, dynamic> toJson() => {
        'title': title,
        'detail': detail,
        'date': date,
        'type': type,
        'stage': stage,
        'done': done,
      };
}

class CropPlan {
  final String crop;
  final String summary;
  final String plantedDate;
  final List<CropTask> tasks;

  CropPlan({
    required this.crop,
    required this.summary,
    required this.plantedDate,
    required this.tasks,
  });

  factory CropPlan.fromJson(Map<String, dynamic> j) => CropPlan(
        crop: (j['crop'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        plantedDate: (j['plantedDate'] ?? '').toString(),
        tasks: ((j['tasks'] ?? []) as List)
            .map((e) => CropTask.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'crop': crop,
        'summary': summary,
        'plantedDate': plantedDate,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
