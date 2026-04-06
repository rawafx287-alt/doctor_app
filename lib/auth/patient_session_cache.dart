import 'package:shared_preferences/shared_preferences.dart';

class PatientSessionCache {
  static const String _kPatientRefIdKey = 'patient_ref_id';

  static Future<void> savePatientRefId(String patientRefId) async {
    final id = patientRefId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPatientRefIdKey, id);
  }

  static Future<String?> readPatientRefId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kPatientRefIdKey)?.trim() ?? '';
    if (id.isEmpty) return null;
    return id;
  }

  static Future<void> clearPatientRefId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPatientRefIdKey);
  }
}
