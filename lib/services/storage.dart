import 'dart:convert';
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

  static Future<void> _saveHistory(
          SharedPreferences p, List<Diagnosis> list) =>
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
}
