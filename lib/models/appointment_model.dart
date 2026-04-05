import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/appointment_queries.dart';

/// Firestore [appointments] document — read model for UI and helpers.
class AppointmentModel {
  const AppointmentModel({
    required this.id,
    required this.doctorId,
    required this.patientName,
    required this.status,
    this.patientId,
    this.queueNumber,
    this.localDate,
    this.fullName,
    this.age,
    this.bloodGroup,
    this.phoneNumber,
    this.gender,
    this.medicalNotes,
  });

  final String id;
  final String doctorId;
  /// Display name on the appointment ([AppointmentFields.patientName]).
  final String patientName;
  final String? patientId;
  final String status;

  /// Daily ticket # (persisted). May be null on legacy documents.
  final int? queueNumber;

  /// Alias for [queueNumber] — daily ticket / پسوولە index for that date.
  int? get ticketNumber => queueNumber;

  /// Local calendar day for this booking, if [AppointmentFields.date] parses.
  final DateTime? localDate;

  /// Same as [patientName] when set; kept for explicit “full name” reads.
  final String? fullName;

  /// From [AppointmentFields.bookingAge] (patient booking form).
  final int? age;

  /// [AppointmentFields.bloodGroup].
  final String? bloodGroup;

  /// [AppointmentFields.bookingPhone] (digits as stored).
  final String? phoneNumber;

  /// [AppointmentFields.bookingGender] e.g. `male` / `female`.
  final String? gender;

  /// [AppointmentFields.bookingMedicalNotes] only (not merged with profile).
  final String? medicalNotes;

  factory AppointmentModel.fromFirestore(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final m = doc.data();
    final rawQ = m[AppointmentFields.queueNumber];
    int? qn;
    if (rawQ is int) {
      qn = rawQ;
    } else if (rawQ is num) {
      qn = rawQ.round();
    } else if (rawQ != null) {
      qn = int.tryParse(rawQ.toString().trim());
    }

    final pn = (m[AppointmentFields.patientName] ?? '—').toString();
    final ba = m[AppointmentFields.bookingAge];
    int? age;
    if (ba is int) {
      age = ba;
    } else if (ba is num) {
      age = ba.round();
    } else if (ba != null) {
      age = int.tryParse(ba.toString().trim());
    }
    final bg =
        (m[AppointmentFields.bloodGroup] ?? '').toString().trim();
    final bp =
        (m[AppointmentFields.bookingPhone] ?? '').toString().trim();
    final g =
        (m[AppointmentFields.bookingGender] ?? '').toString().trim();
    final mn =
        (m[AppointmentFields.bookingMedicalNotes] ?? '').toString().trim();

    return AppointmentModel(
      id: doc.id,
      doctorId: (m[AppointmentFields.doctorId] ?? '').toString(),
      patientId: (m[AppointmentFields.patientId] ?? '').toString().trim().isEmpty
          ? null
          : (m[AppointmentFields.patientId] ?? '').toString().trim(),
      patientName: pn,
      status: (m[AppointmentFields.status] ?? 'pending').toString(),
      queueNumber: qn,
      localDate: appointmentLocalDateOnlyFromData(m),
      fullName: pn.isEmpty || pn == '—' ? null : pn,
      age: age,
      bloodGroup: bg.isEmpty ? null : bg,
      phoneNumber: bp.isEmpty ? null : bp,
      gender: g.isEmpty ? null : g,
      medicalNotes: mn.isEmpty ? null : mn,
    );
  }
}
