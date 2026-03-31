import 'package:shared_preferences/shared_preferences.dart';

class DoctorSessionCache {
  static const String _kDoctorRefIdKey = 'doctor_ref_id';

  static Future<void> saveDoctorRefId(String doctorRefId) async {
    final id = doctorRefId.trim();
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDoctorRefIdKey, id);
  }

  static Future<String?> readDoctorRefId() async {
    final prefs = await SharedPreferences.getInstance();
    final id = prefs.getString(_kDoctorRefIdKey)?.trim() ?? '';
    if (id.isEmpty) return null;
    return id;
  }

  static Future<void> clearDoctorRefId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kDoctorRefIdKey);
  }
}
