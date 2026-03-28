import 'package:cloud_firestore/cloud_firestore.dart';

/// Reads optional patient profile fields from Firestore `users` documents.
String patientPhoneFromUserData(Map<String, dynamic>? data) {
  if (data == null) return '';
  return (data['phone'] ?? '').toString().trim();
}

String patientEmailFromUserData(Map<String, dynamic>? data) {
  if (data == null) return '';
  return (data['email'] ?? '').toString().trim();
}

/// Returns years from [age], [dateOfBirth], or [birthDate] (Timestamp), else null.
int? patientAgeYearsFromUserData(Map<String, dynamic>? data) {
  if (data == null) return null;
  final a = data['age'];
  if (a is int) return a;
  if (a is double) return a.round();
  if (a is String) {
    final p = int.tryParse(a.trim());
    if (p != null) return p;
  }
  Timestamp? ts;
  final dob = data['dateOfBirth'];
  if (dob is Timestamp) ts = dob;
  final bd = data['birthDate'];
  if (bd is Timestamp) ts = bd;
  if (ts != null) {
    final birth = ts.toDate();
    final now = DateTime.now();
    var years = now.year - birth.year;
    if (now.month < birth.month ||
        (now.month == birth.month && now.day < birth.day)) {
      years--;
    }
    return years >= 0 ? years : null;
  }
  return null;
}

String patientGenderRawFromUserData(Map<String, dynamic>? data) {
  if (data == null) return '';
  return (data['gender'] ?? '').toString().trim();
}

/// Free-text medical notes if the patient app stores them later.
String patientMedicalHistoryFromUserData(Map<String, dynamic>? data) {
  if (data == null) return '';
  for (final key in ['medicalHistory', 'healthNotes', 'medical_notes', 'notes']) {
    final v = data[key];
    if (v != null) {
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
  }
  return '';
}
