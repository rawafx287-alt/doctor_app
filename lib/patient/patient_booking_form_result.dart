/// Patient-completed fields from [BookingDetailsPage], persisted on the appointment.
class PatientBookingFormResult {
  const PatientBookingFormResult({
    required this.fullName,
    required this.age,
    required this.bloodGroup,
    required this.phoneDigits,
    required this.isMale,
    this.medicalNotes,
    this.cityArea,
  });

  final String fullName;
  final int age;
  final String bloodGroup;
  final String phoneDigits;
  final bool isMale;
  final String? medicalNotes;
  final String? cityArea;

  Map<String, dynamic> toAppointmentExtras() {
    return <String, dynamic>{
      'bookingAge': age,
      'bloodGroup': bloodGroup,
      'bookingPhone': phoneDigits,
      'bookingGender': isMale ? 'male' : 'female',
      if (medicalNotes != null && medicalNotes!.trim().isNotEmpty)
        'bookingMedicalNotes': medicalNotes!.trim(),
      if (cityArea != null && cityArea!.trim().isNotEmpty)
        'bookingCityArea': cityArea!.trim(),
    };
  }
}
