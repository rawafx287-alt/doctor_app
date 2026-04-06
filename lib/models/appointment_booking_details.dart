import '../firestore/appointment_queries.dart';
import 'patient_profile_read.dart';

/// Reads booking-time fields saved on [AppointmentFields.collection] documents.
/// Prefer appointment values over `users/{patientId}` when both exist.

String appointmentBookingPhoneRaw(
  Map<String, dynamic>? appointmentData,
  Map<String, dynamic>? userData,
) {
  final fromAppt =
      (appointmentData?[AppointmentFields.bookingPhone] ?? '').toString().trim();
  if (fromAppt.isNotEmpty) return fromAppt;
  return patientPhoneFromUserData(userData);
}

int? appointmentBookingAgeYears(
  Map<String, dynamic>? appointmentData,
  Map<String, dynamic>? userData,
) {
  final v = appointmentData?[AppointmentFields.bookingAge];
  if (v is int) return v;
  if (v is num) return v.round();
  if (v != null) {
    final p = int.tryParse(v.toString().trim());
    if (p != null && p > 0 && p <= 130) return p;
  }
  return patientAgeYearsFromUserData(userData);
}

/// Raw gender token: `male` / `female` from booking, or profile [gender] string.
String appointmentBookingGenderRaw(
  Map<String, dynamic>? appointmentData,
  Map<String, dynamic>? userData,
) {
  final g =
      (appointmentData?[AppointmentFields.bookingGender] ?? '').toString().trim();
  if (g.isNotEmpty) return g;
  return patientGenderRawFromUserData(userData);
}

String appointmentBloodGroupRaw(Map<String, dynamic>? appointmentData) {
  return (appointmentData?[AppointmentFields.bloodGroup] ?? '')
      .toString()
      .trim();
}

/// City / area from the patient booking form ([AppointmentFields.bookingCityArea]).
String appointmentResidentPlaceRaw(Map<String, dynamic>? appointmentData) {
  return (appointmentData?[AppointmentFields.bookingCityArea] ?? '')
      .toString()
      .trim();
}

/// Medical notes saved on the appointment at booking time only.
String appointmentBookingMedicalNotesRaw(
  Map<String, dynamic>? appointmentData,
) {
  return (appointmentData?[AppointmentFields.bookingMedicalNotes] ?? '')
      .toString()
      .trim();
}

/// Medical notes from booking form plus optional profile history.
String appointmentMedicalNotesCombined(
  Map<String, dynamic>? appointmentData,
  Map<String, dynamic>? userData,
) {
  final a =
      (appointmentData?[AppointmentFields.bookingMedicalNotes] ?? '')
          .toString()
          .trim();
  final u = patientMedicalHistoryFromUserData(userData);
  if (a.isNotEmpty && u.isNotEmpty) {
    return '$a\n\n$u';
  }
  if (a.isNotEmpty) return a;
  return u;
}
