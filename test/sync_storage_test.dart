import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/models/models.dart';
import 'package:my_farm/services/storage.dart';
import 'package:my_farm/services/treatment_db.dart';
import 'package:shared_preferences/shared_preferences.dart';

Diagnosis _scan(int ts) => Diagnosis(
      crop: 'Cassava',
      label: 'cassava_mosaic_disease',
      diagnosis: 'Mosaic Disease',
      confidence: 90,
      healthy: false,
      cause: '',
      organic: '',
      chemical: '',
      prevent: '',
      spoken: '',
      lang: 'lg',
      timestamp: ts,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Diagnosis keeps label, lang and synced through JSON', () {
    final d = Diagnosis.fromJson(_scan(1).copyWith(synced: true).toJson());
    expect(d.label, 'cassava_mosaic_disease');
    expect(d.lang, 'lg');
    expect(d.synced, isTrue);
  });

  test('history saved before this change loads as unsynced English', () {
    final d = Diagnosis.fromJson({'crop': 'Beans', 'timestamp': 5});
    expect(d.synced, isFalse);
    expect(d.lang, 'en');
    expect(d.label, isNull);
  });

  test('markSynced keeps scans added during a sync', () async {
    await Storage.addToHistory(_scan(1));
    await Storage.addToHistory(_scan(2)); // arrived while uploading scan 1
    await Storage.markSynced({1});
    final h = await Storage.getHistory();
    expect(h.map((d) => (d.timestamp, d.synced)), [(2, false), (1, true)]);
  });

  test('plan revision tracks unsynced changes', () async {
    expect(await Storage.getPlanRev(), await Storage.getPlanSyncedRev());
    await Storage.savePlan(CropPlan(
        crop: 'Maize', summary: '', plantedDate: '2026-09-01', tasks: []));
    final rev = await Storage.getPlanRev();
    expect(rev, isNot(await Storage.getPlanSyncedRev()));
    await Storage.setPlanSyncedRev(rev);
    await Storage.clearPlan();
    expect(await Storage.getPlanRev(), isNot(await Storage.getPlanSyncedRev()));
  });

  test('downloaded treatment text overrides the bundled text', () {
    final bundled = TreatmentDB.lookup('bean_rust', 'lg');
    TreatmentDB.setOverrides([
      {
        'label': 'bean_rust',
        'lang': 'en',
        'cause': 'Updated cause',
        'organic': 'o',
        'chemical': 'c',
        'prevent': 'p',
      }
    ]);
    expect(TreatmentDB.lookup('bean_rust', 'en').cause, 'Updated cause');
    // Luganda has no override, so the bundled Luganda text still wins.
    expect(TreatmentDB.lookup('bean_rust', 'lg').cause, bundled.cause);
    TreatmentDB.setOverrides([]);
    expect(TreatmentDB.lookup('bean_rust', 'en').cause, isNot('Updated cause'));
  });
}
