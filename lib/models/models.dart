/// Plain data models. All JSON-serialisable so they can be cached to disk
/// (shared_preferences) and synced to the backend when online.

class Diagnosis {
  final String crop;
  final String? label; // raw model class, e.g. 'cassava_mosaic_disease'
  final String diagnosis;
  final int confidence;
  final bool healthy;
  final String cause;
  final String organic;
  final String chemical;
  final String prevent;
  final String spoken;
  final String lang; // language the advice was given in: 'en' | 'lg'
  final String? imagePath; // local file path of the photo
  final int timestamp;
  final bool synced; // uploaded to the backend yet?
  // Where the scan was made (only with the farmer's consent).
  final String? districtId;
  final String? subcounty;
  final String? locationSource; // 'gps' | 'manual'
  final double? lat; // rounded to 2 decimals (about 1 km)
  final double? lng;

  Diagnosis({
    required this.crop,
    this.label,
    required this.diagnosis,
    required this.confidence,
    required this.healthy,
    required this.cause,
    required this.organic,
    required this.chemical,
    required this.prevent,
    required this.spoken,
    this.lang = 'en',
    this.imagePath,
    int? timestamp,
    this.synced = false,
    this.districtId,
    this.subcounty,
    this.locationSource,
    this.lat,
    this.lng,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  factory Diagnosis.fromJson(Map<String, dynamic> j) => Diagnosis(
        crop: (j['crop'] ?? '').toString(),
        label: j['label']?.toString(),
        diagnosis: (j['diagnosis'] ?? 'Unknown').toString(),
        confidence: _toInt(j['confidence']),
        healthy: j['healthy'] == true,
        cause: (j['cause'] ?? '').toString(),
        organic: (j['organic'] ?? '').toString(),
        chemical: (j['chemical'] ?? '').toString(),
        prevent: (j['prevent'] ?? '').toString(),
        spoken: (j['spoken'] ?? '').toString(),
        lang: (j['lang'] ?? 'en').toString(),
        imagePath: j['imagePath']?.toString(),
        timestamp: j['timestamp'] is int ? j['timestamp'] : null,
        synced: j['synced'] == true,
        districtId: j['districtId']?.toString(),
        subcounty: j['subcounty']?.toString(),
        locationSource: j['locationSource']?.toString(),
        lat: (j['lat'] as num?)?.toDouble(),
        lng: (j['lng'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        'crop': crop,
        'label': label,
        'diagnosis': diagnosis,
        'confidence': confidence,
        'healthy': healthy,
        'cause': cause,
        'organic': organic,
        'chemical': chemical,
        'prevent': prevent,
        'spoken': spoken,
        'lang': lang,
        'imagePath': imagePath,
        'timestamp': timestamp,
        'synced': synced,
        'districtId': districtId,
        'subcounty': subcounty,
        'locationSource': locationSource,
        'lat': lat,
        'lng': lng,
      };

  Diagnosis copyWith({
    String? imagePath,
    bool? synced,
    String? districtId,
    String? subcounty,
    String? locationSource,
    double? lat,
    double? lng,
  }) =>
      Diagnosis(
        crop: crop,
        label: label,
        diagnosis: diagnosis,
        confidence: confidence,
        healthy: healthy,
        cause: cause,
        organic: organic,
        chemical: chemical,
        prevent: prevent,
        spoken: spoken,
        lang: lang,
        imagePath: imagePath ?? this.imagePath,
        timestamp: timestamp,
        synced: synced ?? this.synced,
        districtId: districtId ?? this.districtId,
        subcounty: subcounty ?? this.subcounty,
        locationSource: locationSource ?? this.locationSource,
        lat: lat ?? this.lat,
        lng: lng ?? this.lng,
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
  final String region;
  final List<CropTask> tasks;

  CropPlan({
    required this.crop,
    required this.summary,
    required this.plantedDate,
    this.region = '',
    required this.tasks,
  });

  factory CropPlan.fromJson(Map<String, dynamic> j) => CropPlan(
        crop: (j['crop'] ?? '').toString(),
        summary: (j['summary'] ?? '').toString(),
        plantedDate: (j['plantedDate'] ?? '').toString(),
        region: (j['region'] ?? '').toString(),
        tasks: ((j['tasks'] ?? []) as List)
            .map((e) => CropTask.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  Map<String, dynamic> toJson() => {
        'crop': crop,
        'summary': summary,
        'plantedDate': plantedDate,
        'region': region,
        'tasks': tasks.map((t) => t.toJson()).toList(),
      };
}

int _toInt(dynamic v) {
  if (v is int) return v;
  if (v is double) return v.round();
  if (v is String) return int.tryParse(v) ?? 0;
  return 0;
}
