import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_farm/screens/app_gate.dart';
import 'package:my_farm/screens/language_screen.dart';
import 'package:my_farm/services/languages.dart';
import 'package:my_farm/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  test('only translated languages can be picked', () {
    final ready = Languages.all.where((l) => l.ready).map((l) => l.code);
    expect(ready, ['en', 'lg']);
    expect(Languages.all, hasLength(7));
    expect(Languages.of('xx').code, 'en');
  });

  test('language counts as chosen once saved', () async {
    expect(await Storage.hasLang(), isFalse);
    await Storage.setLang('lg');
    expect(await Storage.hasLang(), isTrue);
  });

  testWidgets('first launch asks for the language, then moves on',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: AppGate(initialLang: 'en', langChosen: false)));
    await tester.pump();
    expect(find.byType(LanguageScreen), findsOneWidget);

    // Untranslated languages are listed but can't be chosen.
    await tester.tap(find.text('Kiswahili'));
    await tester.pump();
    expect(find.text('Choose your language'), findsOneWidget);

    await tester.tap(find.text('Luganda'));
    await tester.pump();
    expect(find.text('Londa olulimi lwo'), findsOneWidget);
    await tester.tap(find.text('Weeyongereyo'));
    await tester.pump();

    expect(find.byType(LanguageScreen), findsNothing);
    expect(await Storage.getLang(), 'lg');
  });
}
