import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Persists last-used gains + preamp + selected preset name.
class PresetRepository {
  PresetRepository(this._prefs);

  final SharedPreferences _prefs;

  static const _gainsKey = 'eq_gains_db';
  static const _presetKey = 'eq_preset_name';
  static const _preampKey = 'eq_preamp_db';

  static Future<PresetRepository> load() async {
    final prefs = await SharedPreferences.getInstance();
    return PresetRepository(prefs);
  }

  List<double>? loadGains() {
    final raw = _prefs.getString(_gainsKey);
    if (raw == null) return null;
    final list = (jsonDecode(raw) as List).map((e) => (e as num).toDouble()).toList();
    return list;
  }

  Future<void> saveGains(List<double> gains) =>
      _prefs.setString(_gainsKey, jsonEncode(gains));

  String? loadPresetName() => _prefs.getString(_presetKey);

  Future<void> savePresetName(String name) =>
      _prefs.setString(_presetKey, name);

  double loadPreamp() => _prefs.getDouble(_preampKey) ?? 0;

  Future<void> savePreamp(double preampDb) =>
      _prefs.setDouble(_preampKey, preampDb);
}
