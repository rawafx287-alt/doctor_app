/// Firestore field on `users` documents for doctor profiles (`city`).
const String kDoctorCityField = 'city';

/// Patient home: no city filter (show doctors from every city).
const String kPatientCityFilterAll = 'All';

/// Canonical English labels stored in Firestore.
const List<String> kDoctorCityOptions = [
  'Erbil',
  'Sulaymaniyah',
  'Duhok',
  'Kirkuk',
  'Halabja',
  'Zakho',
  'Soran',
  'Ranya',
  'Kalar',
];

/// Reads [kDoctorCityField] from a Firestore user map.
String doctorCityFromUserData(Map<String, dynamic>? data) {
  if (data == null) return '';
  return (data[kDoctorCityField] ?? '').toString().trim();
}

/// Items for a dropdown: known cities, plus [currentValue] if it is non-empty and not in the list (legacy data).
List<String> doctorCityDropdownItems(String? currentValue) {
  final c = (currentValue ?? '').trim();
  final base = List<String>.from(kDoctorCityOptions);
  if (c.isNotEmpty && !base.contains(c)) {
    return [c, ...base];
  }
  return base;
}

/// Cities listed in the home screen modal (vertical picker).
const List<String> kPatientHomeModalCityIds = [
  'Erbil',
  'Sulaymaniyah',
  'Duhok',
  'Kirkuk',
  'Halabja',
];
