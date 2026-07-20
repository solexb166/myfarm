import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';

/// Local persistence so the calendar + scan history work OFFLINE
/// once they've been fetched. Built on shared_preferences (no server).
class Storage {
  static const _kPlan = 'crop_plan';
  static const _kHistory = 'scan_history';
  static const _kLang = 'lang';

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
  static Future<void> savePlan(CropPlan plan) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(_kPlan, jsonEncode(plan.toJson()));
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
    await p.setString(
        _kHistory, jsonEncode(trimmed.map((e) => e.toJson()).toList()));
  }
}
