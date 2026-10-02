import 'package:flutter_test/flutter_test.dart';
import 'package:my_farm/services/calendar_service.dart';
import 'package:my_farm/services/inference_service.dart';

void main() {
  test('disease names drop the crop prefix the model uses', () {
    expect(InferenceService.prettyLabel('bean_rust'), 'Rust');
    expect(InferenceService.prettyLabel('bean_angular_leaf_spot'),
        'Angular Leaf Spot');
    expect(InferenceService.prettyLabel('banana_black_sigatoka'),
        'Black Sigatoka');
    expect(InferenceService.prettyLabel('cassava_mosaic_disease'),
        'Mosaic Disease');
    expect(InferenceService.prettyLabel('healthy'), 'Healthy');
    // A one-word label isn't mistaken for a crop prefix.
    expect(InferenceService.prettyLabel('rust'), 'Rust');
  });

  test('crop names in either language map to their key', () {
    expect(InferenceService.cropKeyFor('Cassava'), 'cassava');
    expect(InferenceService.cropKeyFor('Muwogo'), 'cassava');
    expect(InferenceService.cropKeyFor(' bijanjaalo '), 'beans');
    expect(InferenceService.cropKeyFor('Coffee'), isNull);
  });

  test('calendar recognises matooke and banana names', () {
    for (final name in ['Matooke', 'banana', 'Gonja', 'Ebitooke']) {
      expect(CalendarService.cropKeyFor(name), 'matooke', reason: name);
    }
    expect(CalendarService.cropKeyFor('Kasooli'), 'maize');
    expect(CalendarService.cropKeyFor('Coffee'), 'generic');
  });

  test('matooke plan runs from planting to harvest in both languages', () {
    for (final lang in ['en', 'lg']) {
      final plan = CalendarService.generate(
        cropKey: 'matooke',
        cropName: 'Matooke',
        planted: DateTime(2026, 3, 1),
        region: 'Mbarara',
        lang: lang,
      );
      expect(plan.tasks.first.date, '2026-03-01');
      expect(plan.tasks.last.type, 'harvest');
      expect(plan.region, 'Mbarara');
      expect(plan.tasks.every((t) => t.title.isNotEmpty && t.detail.isNotEmpty),
          isTrue);
    }
  });
}
