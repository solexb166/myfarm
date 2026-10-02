import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/models/models.dart';
import 'package:my_farm/services/areas.dart';
import 'package:my_farm/services/backend.dart';
import 'package:my_farm/services/location.dart';
import 'package:my_farm/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('bundled districts and sub-counties load', () async {
    final all = await Areas.districts();
    expect(all.length, greaterThan(130));
    expect(all.map((d) => d.name), isNot(contains('Lake Victoria')));
    final mbale = await Areas.byId('mbale');
    expect(mbale?.name, 'Mbale');
    expect(mbale?.subcounties, isNotEmpty);
  });

  test('GPS positions of towns map to their district', () async {
    const towns = {
      'Gulu': (2.7746, 32.2990),
      'Mbarara': (-0.6072, 30.6545),
      'Mbale': (1.0827, 34.1750),
      'Arua': (3.0201, 30.9111),
      'Masaka': (-0.3411, 31.7361),
      'Jinja': (0.4479, 33.2026),
      'Kabale': (-1.2486, 29.9899),
    };
    for (final e in towns.entries) {
      final d = await Areas.districtAt(e.value.$1, e.value.$2);
      expect(d?.name, e.key, reason: '${e.value}');
    }
  });

  test('GPS also finds the sub-county', () async {
    final mbarara = await Areas.districtAt(-0.6072, 30.6545);
    expect(mbarara?.subcountyAt(-0.6072, 30.6545), 'Kamukuzi Division');
  });

  test('places outside Uganda have no district', () async {
    expect(await Areas.districtAt(-1.2921, 36.8219), isNull); // Nairobi
    expect(await Areas.districtAt(-2.5164, 32.9175), isNull); // Mwanza
    expect(await Areas.districtAt(-1.9441, 30.0619), isNull); // Kigali
  });

  test('Kampala and Wakiso are told apart', () async {
    expect((await Areas.districtAt(0.3136, 32.5811))?.name, 'Kampala');
    expect((await Areas.districtAt(0.4044, 32.4594))?.name, 'Wakiso');
  });

  test('coordinates are rounded to about 1 km', () {
    expect(LocationService.round2(1.082734), 1.08);
    expect(LocationService.round2(34.175012), 34.18);
    expect(LocationService.round2(-0.607249), -0.61);
  });

  test('location choice is saved, marked for upload, cleared on sign-out',
      () async {
    await Storage.setLocation(
        mode: 'manual', district: 'mbale', subcounty: 'Bufumbo');
    expect(await Storage.getLocationMode(), 'manual');
    expect(await Storage.getHomeDistrict(), 'mbale');
    expect(await Storage.isProfileDirty(), isTrue);

    await Storage.setLocation(mode: 'none');
    expect(await Storage.getHomeDistrict(), isNull);

    await Storage.clearAccountData();
    expect(await Storage.getLocationMode(), isNull);
  });

  test('manual choice is used for scans when GPS is not chosen', () async {
    await Storage.setLocation(
        mode: 'manual', district: 'gulu', subcounty: 'Awach');
    final place = await LocationService.placeForScan();
    expect(place?.districtId, 'gulu');
    expect(place?.subcounty, 'Awach');
    expect(place?.source, 'manual');
    expect(place?.lat, isNull);

    await Storage.setLocation(mode: 'none');
    expect(await LocationService.placeForScan(), isNull);
  });

  test('scan location survives saving on the phone', () {
    final d = Diagnosis.fromJson(Diagnosis(
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
    )
        .copyWith(
            districtId: 'mbale', locationSource: 'gps', lat: 1.08, lng: 34.18)
        .toJson());
    expect(d.districtId, 'mbale');
    expect(d.locationSource, 'gps');
    expect(d.lat, 1.08);
    expect(d.lng, 34.18);
  });

  test('scans restored from the account get advice and location', () {
    final d = Backend.scanFromRow({
      'taken_at': '2026-09-30T10:00:00+00:00',
      'crop': 'Beans',
      'label': 'bean_rust',
      'diagnosis': 'Rust',
      'confidence': 84,
      'healthy': false,
      'lang': 'lg',
      'district_id': 'mbale',
      'subcounty': null,
      'location_source': 'gps',
      'lat': 1.08,
      'lng': 34.18,
    });
    expect(d.synced, isTrue);
    expect(d.cause, isNotEmpty);
    expect(d.lang, 'lg');
    expect(d.districtId, 'mbale');
    expect(d.timestamp, DateTime.utc(2026, 9, 30, 10).millisecondsSinceEpoch);
  });
}
