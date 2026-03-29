import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore collection for hospital entities (logo, names, descriptions).
///
/// Document fields (typical):
/// - `name`, `name_ku`, `name_ar`, `name_en`
/// - `logoUrl` (https image)
/// - `location` (address / city; shown on hospital detail)
/// - `description`, `description_ku`, `description_ar`, `description_en` (optional)
/// - `sortOrder` (int, optional; lower first when sorting client-side)
///
/// Link doctors via `users.hospitalId` == hospital document id.
///
/// **Composite index** for filtered doctor list:
/// Collection `users` — `role` (Ascending), `isApproved` (Ascending), `hospitalId` (Ascending).
abstract final class HospitalFields {
  static const collection = 'hospitals';
}

/// All hospital documents (sort client-side by [sortOrder] then name).
Stream<QuerySnapshot<Map<String, dynamic>>> hospitalsSnapshotStream() {
  return FirebaseFirestore.instance
      .collection(HospitalFields.collection)
      .snapshots();
}

/// Approved doctors at a given hospital.
Query<Map<String, dynamic>> approvedDoctorsAtHospitalQuery(String hospitalId) {
  return FirebaseFirestore.instance
      .collection('users')
      .where('role', isEqualTo: 'Doctor')
      .where('isApproved', isEqualTo: true)
      .where('hospitalId', isEqualTo: hospitalId);
}

/// Client-side order: [sortOrder] ascending (missing last), then [name].
List<QueryDocumentSnapshot<Map<String, dynamic>>> sortHospitalDocuments(
  List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
) {
  final copy = List<QueryDocumentSnapshot<Map<String, dynamic>>>.from(docs);
  copy.sort((a, b) {
    final ao = (a.data()['sortOrder'] as num?)?.toInt() ?? 999999;
    final bo = (b.data()['sortOrder'] as num?)?.toInt() ?? 999999;
    final c = ao.compareTo(bo);
    if (c != 0) return c;
    final an = (a.data()['name'] ?? a.id).toString();
    final bn = (b.data()['name'] ?? b.id).toString();
    return an.compareTo(bn);
  });
  return copy;
}
