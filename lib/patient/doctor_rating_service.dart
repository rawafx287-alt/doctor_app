import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore/appointment_queries.dart';

/// Firestore: `users/{doctorUserId}/doctorRatings/{patientUserDocId}`.
abstract final class DoctorRatingFirestore {
  static const String subcollection = 'doctorRatings';

  static const String stars = 'stars';
  static const String comment = 'comment';
  static const String createdAt = 'createdAt';
  static const String raterAuthUid = 'raterAuthUid';

  /// Denormalized on `users/{doctorId}`.
  static const String ratingSum = 'ratingSum';
  static const String ratingCount = 'ratingCount';
  static const String ratingAverage = 'ratingAverage';
}

/// Reads aggregate rating from doctor user document fields.
double doctorRatingAverageFromData(Map<String, dynamic> data) {
  final avg = data[DoctorRatingFirestore.ratingAverage];
  if (avg is num) return avg.toDouble().clamp(0, 5);
  final sum = data[DoctorRatingFirestore.ratingSum];
  final count = doctorRatingCountFromData(data);
  if (sum is num && count > 0) {
    return (sum.toDouble() / count).clamp(0, 5);
  }
  return 0;
}

int doctorRatingCountFromData(Map<String, dynamic> data) {
  final c = data[DoctorRatingFirestore.ratingCount];
  if (c is int) return c < 0 ? 0 : c;
  if (c is num) return c.toInt().clamp(0, 1 << 30);
  return 0;
}

DocumentReference<Map<String, dynamic>> doctorRatingDocRef({
  required String doctorUserId,
  required String patientUserDocId,
}) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(doctorUserId.trim())
      .collection(DoctorRatingFirestore.subcollection)
      .doc(patientUserDocId.trim());
}

/// True if this patient has at least one **completed** appointment with [doctorUserId].
/// Checks [AppointmentFields.userId] against both [patientUserDocId] and [authUid] (legacy rows).
Future<bool> patientHasCompletedAppointmentWithDoctor({
  required String doctorUserId,
  required String patientUserDocId,
  required String authUid,
}) async {
  final did = doctorUserId.trim();
  if (did.isEmpty) return false;
  final col = FirebaseFirestore.instance.collection(AppointmentFields.collection);
  for (final uid in <String>{patientUserDocId.trim(), authUid.trim()}..removeWhere((e) => e.isEmpty)) {
    final snap = await col
        .where(AppointmentFields.userId, isEqualTo: uid)
        .limit(40)
        .get();
    for (final d in snap.docs) {
      final m = d.data();
      if ((m[AppointmentFields.doctorId] ?? '').toString().trim() != did) {
        continue;
      }
      final st = (m[AppointmentFields.status] ?? '').toString().trim().toLowerCase();
      if (st == 'completed') return true;
    }
  }
  return false;
}

/// One rating per patient doc per doctor. Requires a completed visit.
/// Updates `users/{doctorId}` aggregate fields in the same transaction.
Future<void> submitDoctorRating({
  required String doctorUserId,
  required String patientUserDocId,
  required String authUid,
  required int stars,
  String comment = '',
}) async {
  final did = doctorUserId.trim();
  final pid = patientUserDocId.trim();
  if (did.isEmpty || pid.isEmpty) {
    throw StateError('missing_doctor_or_patient_id');
  }
  final s = stars.clamp(1, 5);
  final can = await patientHasCompletedAppointmentWithDoctor(
    doctorUserId: did,
    patientUserDocId: pid,
    authUid: authUid,
  );
  if (!can) {
    throw StateError('no_completed_appointment');
  }

  final doctorRef = FirebaseFirestore.instance.collection('users').doc(did);
  final ratingRef = doctorRatingDocRef(doctorUserId: did, patientUserDocId: pid);

  await FirebaseFirestore.instance.runTransaction((tx) async {
    final existing = await tx.get(ratingRef);
    if (existing.exists) {
      throw StateError('already_rated');
    }
    final docSnap = await tx.get(doctorRef);
    if (!docSnap.exists) {
      throw StateError('doctor_not_found');
    }
    final d = docSnap.data() ?? {};
    final oldSum = (d[DoctorRatingFirestore.ratingSum] is num)
        ? (d[DoctorRatingFirestore.ratingSum] as num).toDouble()
        : 0.0;
    final oldCount = doctorRatingCountFromData(d);
    final newSum = oldSum + s;
    final newCount = oldCount + 1;
    final newAvg = newSum / newCount;

    tx.set(ratingRef, <String, dynamic>{
      DoctorRatingFirestore.stars: s,
      DoctorRatingFirestore.comment: comment.trim(),
      DoctorRatingFirestore.createdAt: FieldValue.serverTimestamp(),
      DoctorRatingFirestore.raterAuthUid: authUid.trim(),
    });

    tx.update(doctorRef, <String, dynamic>{
      DoctorRatingFirestore.ratingSum: newSum,
      DoctorRatingFirestore.ratingCount: newCount,
      DoctorRatingFirestore.ratingAverage: newAvg,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  });
}
