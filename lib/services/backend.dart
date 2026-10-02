import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'storage.dart';
import 'treatment_db.dart';

/// Optional cloud backend (Supabase). The app stays fully offline-first:
/// everything is saved on the phone first, and [sync] pushes scans + the crop
/// plan up and pulls updated treatment text down whenever there's a network.
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
  static bool _running = false;
  static bool _again = false;

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
  /// made while a sync is running are folded into one more pass. Never
  /// throws - if the phone is offline, the next call picks up where it left.
  static Future<void> sync() async {
    if (!_enabled) return;
    if (_running) {
      _again = true;
      return;
    }
    _running = true;
    try {
      do {
        _again = false;
        await _step('treatments', _pullTreatments);
        if (!await _signIn()) break;
        await _step('scans', _pushScans);
        await _step('plan', _pushPlan);
      } while (_again);
    } finally {
      _running = false;
    }
  }

  static Future<void> _step(String name, Future<void> Function() run) async {
    try {
      await run().timeout(_timeout);
    } catch (e) {
      debugPrint('Sync $name failed: $e');
    }
  }

  /// Each phone gets an anonymous account the first time it's online, so its
  /// rows are private to it. (It can be upgraded to phone/email login later.)
  static Future<bool> _signIn() async {
    if (_db.auth.currentUser != null) return true;
    try {
      await _db.auth.signInAnonymously().timeout(_timeout);
      return true;
    } catch (e) {
      debugPrint('Sign-in failed: $e');
      return false;
    }
  }

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
