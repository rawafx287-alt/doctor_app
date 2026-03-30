/// Synthetic Firebase Auth email domain for phone-number registration (doc id = phone).
const String kPhoneAuthEmailDomain = 'phone.hrnora.app';

String phoneAuthEmail(String normalizedPhoneDigits) =>
    '$normalizedPhoneDigits@$kPhoneAuthEmailDomain';
