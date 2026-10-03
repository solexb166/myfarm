import 'dart:convert';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Local persistence so the calendar + scan history work OFFLINE.
/// Built on shared_preferences. This is the source of truth on the phone;
/// Backend pushes it to Supabase when there is a connection.
class Storage {
  static const _kPlan = 'crop_plan';
  static const _kPlanRev = 'crop_plan_rev';
  static const _kPlanSyncedRev = 'crop_plan_synced_rev';
  static const _kHistory = 'scan_history';
  static const _kLang = 'lang';
  static const _kTreatments = 'treatment_overrides';
  static const _kDisplayName = 'display_name';
  static const _kOwner = 'data_owner';
  static const _kLocationMode = 'location_mode';
  static const _kHomeDistrict = 'home_district';
  static const _kHomeSubcounty = 'home_subcounty';
  static const _kProfileDirty = 'profile_dirty';
  static const _kAreaDistrict = 'area_district';
  static const _kAreaReport = 'area_report';

  // ---- language preference ----
  static Future<String> getLang() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kLang) ?? 'en';
  }

  static Future<void> setLang(String lang) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLang, lang);
  }

  // ---- crop plan (single active plan) ----
  // Every local change bumps the plan revision; Backend records the revision
  // it last pushed, so it knows whether the server copy is stale.
  static Future<void> savePlan(CropPlan plan) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPlan, jsonEncode(plan.toJson()));
    await _bumpPlanRev(p);
  }

  static Future<CropPlan?> getPlan() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kPlan);
    if (raw == null) return null;
    try {
      return CropPlan.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  static Future<void> clearPlan() async {
    final p = await SharedPreferences.getInstance();
    await p.remove(_kPlan);
    await _bumpPlanRev(p);
  }

  /// Make the next sync push the local plan even if it hasn't changed
  /// (e.g. after signing in to a different account).
  static Future<void> markPlanUnsynced() async {
    final p = await SharedPreferences.getInstance();
    await _bumpPlanRev(p);
  }

  static Future<void> _bumpPlanRev(SharedPreferences p) =>
      p.setInt(_kPlanRev, (p.getInt(_kPlanRev) ?? 0) + 1);

  static Future<int> getPlanRev() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kPlanRev) ?? 0;
  }

  static Future<int> getPlanSyncedRev() async {
    final p = await SharedPreferences.getInstance();
    return p.getInt(_kPlanSyncedRev) ?? 0;
  }

  static Future<void> setPlanSyncedRev(int rev) async {
    final p = await SharedPreferences.getInstance();
    await p.setInt(_kPlanSyncedRev, rev);
  }

  // ---- scan history ----
  static Future<List<Diagnosis>> getHistory() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kHistory);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return list.map((e) => Diagnosis.fromJson(e)).toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> addToHistory(Diagnosis d) async {
    final p = await SharedPreferences.getInstance();
    final list = await getHistory();
    list.insert(0, d);
    // keep last 30
    final trimmed = list.take(30).toList();
    await _saveHistory(p, trimmed);
  }

  /// Mark the scans with these timestamps as uploaded. Re-reads the history
  /// so scans added while a sync was running are kept.
  static Future<void> markSynced(Set<int> timestamps) async {
    final p = await SharedPreferences.getInstance();
    final list = await getHistory();
    await _saveHistory(
        p,
        list
            .map((d) =>
                timestamps.contains(d.timestamp) ? d.copyWith(synced: true) : d)
            .toList());
  }

  static Future<int> pendingScanCount() async =>
      (await getHistory()).where((d) => !d.synced).length;

  static Future<void> _saveHistory(SharedPreferences p, List<Diagnosis> list) =>
      p.setString(_kHistory, jsonEncode(list.map((e) => e.toJson()).toList()));

  // ---- treatment text downloaded from the backend ----
  static Future<List<Map<String, dynamic>>> getTreatmentOverrides() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kTreatments);
    if (raw == null) return [];
    try {
      return (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }

  static Future<void> saveTreatmentOverrides(
      List<Map<String, dynamic>> rows) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kTreatments, jsonEncode(rows));
  }

  // ---- location consent + home area ----
  // Saving any of these marks the profile for upload on the next sync.
  static Future<String?> getLocationMode() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kLocationMode);
  }

  static Future<String?> getHomeDistrict() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kHomeDistrict);
  }

  static Future<String?> getHomeSubcounty() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kHomeSubcounty);
  }

  /// Save the farmer's location choice and home area (null clears).
  static Future<void> setLocation({
    required String mode,
    String? district,
    String? subcounty,
  }) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kLocationMode, mode);
    for (final (key, value) in [
      (_kHomeDistrict, district),
      (_kHomeSubcounty, subcounty),
    ]) {
      if (value == null) {
        await p.remove(key);
      } else {
        await p.setString(key, value);
      }
    }
    await p.setBool(_kProfileDirty, true);
  }

  static Future<bool> isProfileDirty() async {
    final p = await SharedPreferences.getInstance();
    return p.getBool(_kProfileDirty) ?? false;
  }

  static Future<void> setProfileDirty(bool dirty) async {
    final p = await SharedPreferences.getInstance();
    await p.setBool(_kProfileDirty, dirty);
  }

  // ---- diseases near you ----
  /// District picked on the "Diseases near you" screen, for farmers who
  /// didn't share a home area. Stays on the phone; it is not uploaded.
  static Future<String?> getAreaDistrict() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kAreaDistrict);
  }

  static Future<void> setAreaDistrict(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAreaDistrict, id);
  }

  /// The last area report downloaded (one district), for offline use.
  static Future<AreaReport?> getAreaReport() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kAreaReport);
    if (raw == null) return null;
    try {
      return AreaReport.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveAreaReport(AreaReport report) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kAreaReport, jsonEncode(report.toJson()));
  }

  /// Replace the history with scans downloaded from the account (used when
  /// signing in on a phone with no scans yet).
  static Future<void> restoreHistory(List<Diagnosis> scans) async {
    final p = await SharedPreferences.getInstance();
    await _saveHistory(p, scans.take(30).toList());
  }

  // ---- account ----
  /// Account id the scans and plan on this phone belong to.
  static Future<String?> getDataOwner() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kOwner);
  }

  static Future<void> setDataOwner(String id) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kOwner, id);
  }

  static Future<String?> getDisplayName() async {
    final p = await SharedPreferences.getInstance();
    return p.getString(_kDisplayName);
  }

  static Future<void> setDisplayName(String? name) async {
    final p = await SharedPreferences.getInstance();
    if (name == null || name.isEmpty) {
      await p.remove(_kDisplayName);
    } else {
      await p.setString(_kDisplayName, name);
    }
  }

  /// Remove the signed-in farmer's records from this phone (on sign-out or
  /// account deletion), including the copies of their scan photos.
  /// Language and downloaded treatment text are not personal, so they stay.
  static Future<void> clearAccountData() async {
    final p = await SharedPreferences.getInstance();
    for (final d in await getHistory()) {
      if (d.imagePath == null) continue;
      try {
        final f = File(d.imagePath!);
        if (await f.exists()) await f.delete();
      } catch (_) {
        // Not ours to delete, or already gone.
      }
    }
    for (final k in [
      _kHistory,
      _kPlan,
      _kPlanRev,
      _kPlanSyncedRev,
      _kDisplayName,
      _kOwner,
      _kLocationMode,
      _kHomeDistrict,
      _kHomeSubcounty,
      _kProfileDirty,
      _kAreaDistrict,
      _kAreaReport,
    ]) {
      await p.remove(k);
    }
  }
}
