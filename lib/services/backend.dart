import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage.dart';
import 'treatment_db.dart';

/// Cloud backend (Supabase). The app stays offline-first: everything is
/// saved on the phone first, and [sync] pushes the signed-in farmer's scans +
/// crop plan up and pulls updated treatment text down whenever there's a
/// network. Farmers sign in once (needs internet); the session is kept on the
/// phone, so the app keeps working offline afterwards.
///
/// Configure at build time (see supabase/README.md):
///   flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co \
///               --dart-define=SUPABASE_PUBLISHABLE_KEY=<publishable key>
/// Without them the backend is disabled and every call is a no-op.
class Backend {
  static const _url = String.fromEnvironment('SUPABASE_URL');
  static const _key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  static const _photoBucket = 'scan-photos';
  static const _timeout = Duration(seconds: 60);

  static bool _enabled = false;
  static Future<void>? _running;
  static bool _again = false;

  static bool get enabled => _enabled;
  static SupabaseClient get _db => Supabase.instance.client;

  static Future<void> init() async {
    if (_url.isEmpty || _key.isEmpty) return;
    try {
      await Supabase.initialize(url: _url, publishableKey: _key);
      _enabled = true;
    } catch (e) {
      debugPrint('Backend disabled: $e');
    }
  }

  /// Sync in the background. Safe to call often (after every change): calls
  /// made while a sync is running are folded into one more pass, and the
  /// returned future completes when it's done. Never throws - if the phone is
  /// offline, the next call picks up where it left off.
  static Future<void> sync() {
    if (!_enabled) return Future.value();
    if (_running != null) {
      _again = true;
      return _running!;
    }
    return _running = _syncLoop().whenComplete(() => _running = null);
  }

  static Future<void> _syncLoop() async {
    do {
      _again = false;
      await _step('treatments', _pullTreatments);
      if (account == null) break;
      await _step('scans', _pushScans);
      await _step('plan', _pushPlan);
    } while (_again);
  }

  static Future<void> _step(String name, Future<void> Function() run) async {
    try {
      await run().timeout(_timeout);
    } catch (e) {
      debugPrint('Sync $name failed: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Email accounts
  // ---------------------------------------------------------------------------

  /// The signed-in farmer, or null (also when the backend is off). Stays set
  /// while offline, even after the access token expires; it is only cleared
  /// by signing out or if the server rejects the session.
  static User? get account {
    if (!_enabled) return null;
    final u = _db.auth.currentUser;
    return (u == null || u.isAnonymous) ? null : u;
  }

  /// Fires when the farmer signs in or out (not on routine token refreshes).
  static Stream<void> get accountChanges => _enabled
      ? _db.auth.onAuthStateChange
          .where((s) =>
              s.event == AuthChangeEvent.signedIn ||
              s.event == AuthChangeEvent.signedOut)
          .map((_) {})
      : const Stream.empty();

  static bool looksLikeEmail(String s) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$').hasMatch(s.trim());

  /// Step 1 of signing in: email the farmer a code. Creates the account if
  /// this email is new.
  static Future<void> sendEmailCode(String email) async {
    try {
      await _db.auth.signInWithOtp(email: email).timeout(_timeout);
    } catch (e) {
      throw AccountError.from(e);
    }
  }

  /// Step 2 of signing in: check the code from the email.
  static Future<void> verifyEmailCode(String email, String code) async {
    final AuthResponse res;
    try {
      res = await _db.auth
          .verifyOTP(type: OtpType.email, email: email, token: code)
          .timeout(_timeout);
    } catch (e) {
      throw AccountError.from(e);
    }
    // Records left on the phone by a different farmer (e.g. their session
    // was ended by the server) must not show up in, or upload to, this
    // account.
    final owner = await Storage.getDataOwner();
    if (owner != null && owner != res.user?.id) {
      await Storage.clearAccountData();
    }
    if (res.user != null) await Storage.setDataOwner(res.user!.id);
    // A phone updated from a version without accounts may already hold a
    // plan; make sure it reaches the account. (Old scans are unsynced, so
    // they upload anyway.)
    if (await Storage.getPlan() != null) await Storage.markPlanUnsynced();
    unawaited(sync());
  }

  /// Sign out and remove the farmer's records from this phone. The caller
  /// should warn first if [Storage.pendingScanCount] is not zero.
  static Future<void> signOut() async {
    if (_enabled) {
      try {
        await _db.auth.signOut();
      } catch (e) {
        // Offline: the session is already removed from the phone.
        debugPrint('Sign-out request failed: $e');
      }
    }
    await Storage.clearAccountData();
  }

  /// The farmer's name, from the server when online, else the cached copy.
  static Future<String?> loadDisplayName() async {
    final u = account;
    if (u == null) return null;
    try {
      final row = await _db
          .from('profiles')
          .select('display_name')
          .eq('id', u.id)
          .maybeSingle()
          .timeout(_timeout);
      final name = row?['display_name'] as String?;
      await Storage.setDisplayName(name);
      return name;
    } catch (e) {
      return Storage.getDisplayName();
    }
  }

  static Future<void> saveDisplayName(String name) async {
    final u = account;
    if (u == null) return;
    try {
      await _db
          .from('profiles')
          .upsert({'id': u.id, 'display_name': name}).timeout(_timeout);
    } catch (e) {
      throw AccountError.from(e);
    }
    await Storage.setDisplayName(name);
  }

  // ---------------------------------------------------------------------------
  // Sync steps
  // ---------------------------------------------------------------------------

  static Future<void> _pullTreatments() async {
    final rows = await _db
        .from('treatments')
        .select('label, lang, cause, organic, chemical, prevent');
    TreatmentDB.setOverrides(rows);
    await Storage.saveTreatmentOverrides(rows);
  }

  static Future<void> _pushScans() async {
    final uid = _db.auth.currentUser!.id;
    final pending =
        (await Storage.getHistory()).where((d) => !d.synced).toList();
    final done = <int>{};
    try {
      // Oldest first, so a partial sync leaves a clean "everything before X"
      // state on the server.
      for (final d in pending.reversed) {
        String? photoPath;
        final photo = d.imagePath == null ? null : File(d.imagePath!);
        if (photo != null && await photo.exists()) {
          final ext = _extension(photo.path);
          photoPath = '$uid/${d.timestamp}.$ext';
          await _db.storage.from(_photoBucket).upload(
                photoPath,
                photo,
                fileOptions:
                    FileOptions(upsert: true, contentType: _contentType(ext)),
              );
        }
        await _db.from('scans').upsert({
          'user_id': uid,
          'taken_at':
              DateTime.fromMillisecondsSinceEpoch(d.timestamp, isUtc: true)
                  .toIso8601String(),
          'crop': d.crop,
          'label': d.label,
          'diagnosis': d.diagnosis,
          'confidence': d.confidence,
          'healthy': d.healthy,
          'lang': d.lang,
          'photo_path': photoPath,
        }, onConflict: 'user_id,taken_at');
        done.add(d.timestamp);
      }
    } finally {
      // Keep whatever made it up, even if a later scan failed.
      if (done.isNotEmpty) await Storage.markSynced(done);
    }
  }

  static Future<void> _pushPlan() async {
    final rev = await Storage.getPlanRev();
    if (rev == await Storage.getPlanSyncedRev()) return;

    final uid = _db.auth.currentUser!.id;
    final plan = await Storage.getPlan();
    if (plan == null) {
      await _db.from('crop_plans').delete().eq('user_id', uid);
    } else {
      final json = plan.toJson();
      await _db.from('crop_plans').upsert({
        'user_id': uid,
        'crop': plan.crop,
        'region': plan.region.isEmpty ? null : plan.region,
        'summary': plan.summary,
        'planted_date': plan.plantedDate,
        'tasks': json['tasks'],
      });
    }
    // If the plan changed again meanwhile, rev no longer matches the stored
    // one and the next sync pushes it.
    await Storage.setPlanSyncedRev(rev);
  }

  static String _extension(String path) {
    final dot = path.lastIndexOf('.');
    final ext = dot < 0 ? '' : path.substring(dot + 1).toLowerCase();
    return const {'jpg', 'jpeg', 'png', 'webp', 'heic'}.contains(ext)
        ? ext
        : 'jpg';
  }

  static String _contentType(String ext) => switch (ext) {
        'png' => 'image/png',
        'webp' => 'image/webp',
        'heic' => 'image/heic',
        _ => 'image/jpeg',
      };
}

/// Why an account action failed, in terms the UI can explain to a farmer.
enum AccountError implements Exception {
  offline,
  wrongCode,
  tooManyTries,
  failed;

  static AccountError from(Object e) {
    if (e is AccountError) return e;
    if (e is AuthRetryableFetchException) return offline;
    if (e is AuthException) {
      if (e.statusCode == '429' || (e.code ?? '').contains('rate_limit')) {
        return tooManyTries;
      }
      if (e.code == 'otp_expired' || e.statusCode == '403') return wrongCode;
      return failed;
    }
    if (e is PostgrestException) return failed;
    // SocketException, TimeoutException, http ClientException, ...
    return offline;
  }
}
