import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_farm/models/models.dart';
import 'package:my_farm/screens/account_screen.dart';
import 'package:my_farm/services/backend.dart';
import 'package:my_farm/services/storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Diagnosis _scan(int ts, {bool synced = false}) => Diagnosis(
      crop: 'Beans',
      diagnosis: 'Rust',
      confidence: 80,
      healthy: false,
      cause: '',
      organic: '',
      chemical: '',
      prevent: '',
      spoken: '',
      timestamp: ts,
      synced: synced,
    );

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('email check accepts real addresses and rejects typos', () {
    expect(Backend.looksLikeEmail('nakato@gmail.com'), isTrue);
    expect(Backend.looksLikeEmail(' farmer.one@mail.co.ug '), isTrue);
    for (final bad in ['', 'nakato', 'nakato@', 'nakato@gmail', 'a b@c.com']) {
      expect(Backend.looksLikeEmail(bad), isFalse, reason: bad);
    }
  });

  test('auth failures map to messages a farmer can act on', () {
    expect(AccountError.from(const SocketException('no route')),
        AccountError.offline);
    expect(AccountError.from(AuthRetryableFetchException(message: 'x')),
        AccountError.offline);
    expect(
        AccountError.from(const AuthApiException('Token has expired',
            statusCode: '403', code: 'otp_expired')),
        AccountError.wrongCode);
    expect(
        AccountError.from(const AuthApiException('slow down',
            statusCode: '429', code: 'over_email_send_rate_limit')),
        AccountError.tooManyTries);
    expect(AccountError.from(const PostgrestException(message: 'denied')),
        AccountError.failed);
  });

  test('pending count only includes scans not yet uploaded', () async {
    await Storage.addToHistory(_scan(1, synced: true));
    await Storage.addToHistory(_scan(2));
    await Storage.addToHistory(_scan(3));
    expect(await Storage.pendingScanCount(), 2);
  });

  test('sign-out data wipe keeps language and treatment text', () async {
    await Storage.setLang('lg');
    await Storage.saveTreatmentOverrides([
      {'label': 'bean_rust', 'lang': 'en'}
    ]);
    await Storage.addToHistory(_scan(1));
    await Storage.savePlan(CropPlan(
        crop: 'Maize', summary: '', plantedDate: '2026-09-01', tasks: []));
    await Storage.setMergeTicket('ticket');
    await Storage.setDisplayName('Nakato');

    await Storage.clearAccountData();

    expect(await Storage.getHistory(), isEmpty);
    expect(await Storage.getPlan(), isNull);
    expect(await Storage.getMergeTicket(), isNull);
    expect(await Storage.getDisplayName(), isNull);
    expect(await Storage.getPlanRev(), await Storage.getPlanSyncedRev());
    expect(await Storage.getLang(), 'lg');
    expect(await Storage.getTreatmentOverrides(), hasLength(1));
  });

  testWidgets('sign-in screen rejects an invalid email without a network call',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(const MaterialApp(home: AccountScreen(lang: 'en')));
    await tester.pump();

    expect(find.text('Back up your farm records'), findsOneWidget);
    await tester.enterText(find.byType(TextField), 'nakato@gmail');
    await tester.tap(find.text('Send sign-in code'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Code from the email'), findsNothing);
  });
}
