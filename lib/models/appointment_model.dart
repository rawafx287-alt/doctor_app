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
  });

  final String id;
  final String doctorId;
  final String patientName;
  final String? patientId;
  final String status;

  /// Daily ticket # (persisted). May be null on legacy documents.
  final int? queueNumber;

  /// Alias for [queueNumber] — daily ticket / پسوولە index for that date.
  int? get ticketNumber => queueNumber;

  /// Local calendar day for this booking, if [AppointmentFields.date] parses.
  final DateTime? localDate;

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

    return AppointmentModel(
      id: doc.id,
      doctorId: (m[AppointmentFields.doctorId] ?? '').toString(),
      patientId: (m[AppointmentFields.patientId] ?? '').toString().trim().isEmpty
          ? null
          : (m[AppointmentFields.patientId] ?? '').toString().trim(),
      patientName: (m[AppointmentFields.patientName] ?? '—').toString(),
      status: (m[AppointmentFields.status] ?? 'pending').toString(),
      queueNumber: qn,
      localDate: appointmentLocalDateOnlyFromData(m),
    );
  }
}
