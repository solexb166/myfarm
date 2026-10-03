import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/models/models.dart';
import 'package:my_farm/screens/area_screen.dart';
import 'package:my_farm/services/backend.dart';
import 'package:my_farm/services/inference_service.dart';
import 'package:my_farm/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

AreaReport _report(String district) => AreaReport(
      districtId: district,
      days: 90,
      farmers: 31,
      diseases: const [
        AreaDisease(
            crop: 'Cassava',
            label: 'cassava_mosaic_disease',
            farmers: 14,
            scans: 23,
            lastSeen: '2026-10-01'),
      ],
      fetchedAt: 1,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('area report survives the round trip through storage', () async {
    await Storage.saveAreaReport(_report('mbale'));
    final saved = (await Storage.getAreaReport())!;
    expect(saved.districtId, 'mbale');
    expect(saved.farmers, 31);
    expect(saved.diseases.single.label, 'cassava_mosaic_disease');
    expect(saved.diseases.single.farmers, 14);
    expect(saved.diseases.single.lastSeen, '2026-10-01');
  });

  test('server rows parse, including numbers sent as strings', () {
    final d = AreaDisease.fromJson({
      'crop': 'Beans',
      'label': 'bean_rust',
      'farmers': '6',
      'scans': 9,
      'last_seen': '2026-09-28',
    });
    expect(d.farmers, 6);
    expect(d.scans, 9);
  });

  test('offline, the saved report is shown only for the same district',
      () async {
    await Storage.saveAreaReport(_report('mbale'));
    // Backend is off in tests, so this can't download.
    expect((await Backend.areaReport('mbale')).farmers, 31);
    await expectLater(Backend.areaReport('gulu'), throwsA(isA<AccountError>()));
  });

  test('district: picked one, then home area, then last scan', () async {
    expect(await nearYouDistrict(), isNull);
    await Storage.addToHistory(Diagnosis(
      crop: 'Beans',
      diagnosis: 'Rust',
      confidence: 80,
      healthy: false,
      cause: '',
      organic: '',
      chemical: '',
      prevent: '',
      spoken: '',
      timestamp: 1,
      districtId: 'gulu',
    ));
    expect(await nearYouDistrict(), 'gulu');
    await Storage.setLocation(mode: 'manual', district: 'mbale');
    expect(await nearYouDistrict(), 'mbale');
    await Storage.setAreaDistrict('kabale');
    expect(await nearYouDistrict(), 'kabale');
    // Signing out forgets the picked district and the downloaded report.
    await Storage.saveAreaReport(_report('kabale'));
    await Storage.clearAccountData();
    expect(await Storage.getAreaDistrict(), isNull);
    expect(await Storage.getAreaReport(), isNull);
  });

  test('crop names show in the chosen language', () {
    expect(InferenceService.cropDisplayName('Cassava', 'lg'), 'Muwogo');
    expect(InferenceService.cropDisplayName('Cassava', 'en'), 'Cassava');
    expect(InferenceService.cropDisplayName('Coffee', 'lg'), 'Coffee');
  });
}
