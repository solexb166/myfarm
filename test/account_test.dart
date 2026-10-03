import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_farm/models/models.dart';
import 'package:my_farm/screens/app_gate.dart';
import 'package:my_farm/screens/home_screen.dart';
import 'package:my_farm/screens/sign_in_screen.dart';
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

  test('phone check accepts Ugandan mobile numbers however they are typed', () {
    for (final ok in [
      '0772123456',
      '0772 123 456',
      '772123456',
      '+256772123456',
      '256 772-123-456',
      ' (0)772 123456 '.replaceAll('(0)', ''),
    ]) {
      expect(Backend.ugandaPhone(ok), '+256772123456', reason: ok);
    }
    for (final bad in [
      '',
      '0414123456', // landline: can't get an SMS
      '077212345', // too short
      '07721234567', // too long
      '+254712345678', // Kenya
      '0772abc456',
    ]) {
      expect(Backend.ugandaPhone(bad), isNull, reason: bad);
    }
    expect(Backend.formatPhone('256772123456'), '+256 772 123456');
    expect(Backend.formatPhone('+256772123456'), '+256 772 123456');
    expect(Backend.formatPhone('447700900123'), '+447700900123');
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
    await Storage.setDataOwner('user-1');
    await Storage.setDisplayName('Nakato');

    await Storage.clearAccountData();

    expect(await Storage.getHistory(), isEmpty);
    expect(await Storage.getPlan(), isNull);
    expect(await Storage.getDataOwner(), isNull);
    expect(await Storage.getDisplayName(), isNull);
    expect(await Storage.getPlanRev(), await Storage.getPlanSyncedRev());
    expect(await Storage.getLang(), 'lg');
    expect(await Storage.getTreatmentOverrides(), hasLength(1));
  });

  testWidgets('sign-in screen rejects an invalid phone number offline',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
        MaterialApp(home: SignInScreen(lang: 'en', onLang: (_) {})));
    await tester.pump();

    // Phone is the default way to sign in.
    expect(find.text('Phone number'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '0414 123456');
    await tester.tap(find.text('Send sign-in code'));
    await tester.pump();

    expect(find.text('Enter a Ugandan mobile number, like 0772 123456.'),
        findsOneWidget);
  });

  testWidgets('sign-in screen rejects an invalid email without a network call',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester.pumpWidget(
        MaterialApp(home: SignInScreen(lang: 'en', onLang: (_) {})));
    await tester.pump();

    expect(find.text('Sign in to get started'), findsOneWidget);
    await tester.tap(find.text('Email'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'nakato@gmail');
    await tester.tap(find.text('Send sign-in code'));
    await tester.pump();

    expect(find.text('Enter a valid email address.'), findsOneWidget);
    expect(find.text('Code from the email'), findsNothing);
  });

  testWidgets('a build without Supabase settings opens straight to home',
      (tester) async {
    GoogleFonts.config.allowRuntimeFetching = false;
    await tester
        .pumpWidget(const MaterialApp(home: AppGate(initialLang: 'en')));
    await tester.pump();

    expect(find.byType(HomeScreen), findsOneWidget);
    expect(find.byType(SignInScreen), findsNothing);
  });
}
