/// Firestore [appointments] collection: canonical field paths and range queries.
///
/// Always persist and read the doctor reference with [AppointmentFields.doctorId]
/// (**`doctorId`**, capital **I**), matching composite indexes.
library;

export '../firestore/appointment_queries.dart' show AppointmentFields, appointmentsForDoctorDateRange;
