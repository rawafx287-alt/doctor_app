import 'package:flutter/material.dart';

import 'app_locale.dart';

/// All HR Nora UI strings: [key] → `ckb` | `ar` | `en`.
const Map<String, Map<String, String>> kAppStrings = {
  'home': {
    'ckb': 'سەرەتا',
    'ar': 'الرئيسية',
    'en': 'Home',
  },
  /// App brand shown in the patient home app bar.
  'app_display_name': {
    'ckb': 'HR Nora',
    'ar': 'HR Nora',
    'en': 'HR Nora',
  },
  'appointments': {
    'ckb': 'نۆرەکانم',
    'ar': 'مواعيدي',
    'en': 'My appointments',
  },
  'profile': {
    'ckb': 'پڕۆفایل',
    'ar': 'الملف الشخصي',
    'en': 'Profile',
  },
  'login': {
    'ckb': 'بچۆ ژوورەوە',
    'ar': 'تسجيل الدخول',
    'en': 'Log in',
  },
  'sign_in': {
    'ckb': 'چوونە ژوورەوە',
    'ar': 'دخول',
    'en': 'Sign in',
  },
  'login_subtitle': {
    'ckb': 'ئیمەیڵ و وشەی نهێنیت بنووسە',
    'ar': 'أدخل بريدك وكلمة المرور',
    'en': 'Enter your email and password',
  },
  'hint_email_or_phone': {
    'ckb': 'ئیمەیڵ یان ژمارەی مۆبایل',
    'ar': 'البريد أو رقم الجوال',
    'en': 'Email or mobile number',
  },
  'hint_email_login': {
    'ckb': 'ئیمەیڵ',
    'ar': 'البريد الإلكتروني',
    'en': 'Email',
  },
  'auth_err_email_not_verified': {
    'ckb': 'تکایە سەرەتا ئیمەیڵەکەت دڵنیا بکەرەوە',
    'ar': 'يرجى تأكيد بريدك الإلكتروني أولاً.',
    'en': 'Please verify your email first.',
  },
  'auth_verify_email_title': {
    'ckb': 'ئیمەیڵەکەت پشتڕاست بکەرەوە',
    'ar': 'تأكيد بريدك الإلكتروني',
    'en': 'Verify your email',
  },
  'auth_verify_email_body': {
    'ckb':
        'ئیمەیڵێکی دڵنیابوونەوەمان بۆ ناردوویت، تکایە کلیک لەو لینکە بکە کە لە ناو ئیمەیڵەکەدایە',
    'ar':
        'أرسلنا بريد تحقق. يرجى النقر على الرابط داخل البريد.',
    'en':
        'We sent a verification email. Please tap the link inside the email.',
  },
  'auth_resend_verification': {
    'ckb': 'دووبارە ناردنی ئیمەیڵی پشتڕاستکردنەوە',
    'ar': 'إعادة إرسال بريد التحقق',
    'en': 'Resend verification email',
  },
  'auth_verify_email_recheck': {
    'ckb': 'من لینکەکەم چالاک کرد',
    'ar': 'لقد فعّلت الرابط',
    'en': 'I have verified',
  },
  'auth_verify_email_link_not_active': {
    'ckb': 'تکایە سەرەتا لینکەکە چالاک بکە',
    'ar': 'يرجى تفعيل الرابط أولاً.',
    'en': 'Please activate the link in your email first.',
  },
  'auth_resend_in_seconds': {
    'ckb': 'دووبارە ناردن لە {n} چرکە',
    'ar': 'إعادة الإرسال خلال {n} ث',
    'en': 'Resend in {n}s',
  },
  'auth_verify_email_resent': {
    'ckb': 'ئیمەیڵی پشتڕاستکردنەوە دووبارە نێردرا',
    'ar': 'تم إعادة إرسال بريد التحقق',
    'en': 'Verification email sent again',
  },
  'verify_email_sent_heading': {
    'ckb': 'ئیمەیڵ نێردرا',
    'ar': 'تم إرسال البريد',
    'en': 'Email sent',
  },
  'verify_email_activate_prompt': {
    'ckb': 'تکایە ئیمەیڵەکەت چالاک بکە',
    'ar': 'يرجى تفعيل بريدك الإلكتروني',
    'en': 'Please verify your email',
  },
  'verify_email_check_again': {
    'ckb': 'دووبارە پشکنین',
    'ar': 'تحقق مرة أخرى',
    'en': 'Check again',
  },
  'verify_email_open_email_app': {
    'ckb': 'کردنەوەی ئیمەیڵ',
    'ar': 'فتح البريد',
    'en': 'Open email (Gmail)',
  },
  'verify_email_launch_failed': {
    'ckb': 'نەتوانرا ئیمەیڵ بکرێتەوە',
    'ar': 'تعذر فتح التطبيق',
    'en': 'Could not open email',
  },
  'auth_email_not_activated_snack': {
    'ckb': 'ئیمەیڵەکەت چالاک نەکراوە',
    'ar': 'لم يتم تفعيل بريدك الإلكتروني',
    'en': 'Your email has not been verified',
  },
  'signup_verify_email_dialog_title': {
    'ckb': 'سندوقی نامەکەت بپشکنە',
    'ar': 'تحقق من بريدك',
    'en': 'Check your inbox',
  },
  'signup_verify_email_dialog_body': {
    'ckb':
        'ئیمەیڵێکی پشتڕاستکردنەوەمان نارد. تکایە سندوقی نامەکەت بکەرەوە و لینکەکە کرتە بکە، پاشان بچۆرە ژوورەوە.',
    'ar':
        'أرسلنا رسالة تحقق. افتح بريدك واضغط الرابط، ثم سجّل الدخول.',
    'en':
        'We sent a verification email. Open it, tap the link, then sign in.',
  },
  'hint_password': {
    'ckb': 'وشەی نهێنی',
    'ar': 'كلمة المرور',
    'en': 'Password',
  },
  'forgot_password': {
    'ckb': 'وشەی نهێنیت لەبیرچووە؟',
    'ar': 'نسيت كلمة المرور؟',
    'en': 'Forgot password?',
  },
  'no_account': {
    'ckb': 'هەژمارت نییە؟ ',
    'ar': 'ليس لديك حساب؟ ',
    'en': "Don't have an account? ",
  },
  'sign_up': {
    'ckb': 'هەژمار دروست بکە',
    'ar': 'إنشاء حساب',
    'en': 'Sign up',
  },
  'sign_up_title': {
    'ckb': 'دروستکردنی هەژمار',
    'ar': 'إنشاء حساب',
    'en': 'Create account',
  },
  'sign_up_subtitle': {
    'ckb': 'ڕۆڵی خۆت هەڵبژێرە',
    'ar': 'اختر نوع الحساب',
    'en': 'Choose your role',
  },
  'role_patient': {
    'ckb': 'من نەخۆشم',
    'ar': 'أنا مريض',
    'en': 'I am a patient',
  },
  'role_doctor': {
    'ckb': 'من پزیشکم',
    'ar': 'أنا طبيب',
    'en': 'I am a doctor',
  },
  'role_patient_short': {
    'ckb': 'Patient',
    'ar': 'مريض',
    'en': 'Patient',
  },
  'role_doctor_short': {
    'ckb': 'Doctor',
    'ar': 'طبيب',
    'en': 'Doctor',
  },
  'full_name': {
    'ckb': 'ناوی تەواو',
    'ar': 'الاسم الكامل',
    'en': 'Full name',
  },
  'signup_first_name': {
    'ckb': 'ناوی یەکەم',
    'ar': 'الاسم الأول',
    'en': 'First name',
  },
  'signup_last_name': {
    'ckb': 'ناوی دووەم',
    'ar': 'اسم العائلة',
    'en': 'Last name',
  },
  'signup_mobile': {
    'ckb': 'ژمارەی مۆبایل',
    'ar': 'رقم الجوال',
    'en': 'Mobile number',
  },
  'signup_mobile_optional': {
    'ckb': 'ژمارەی مۆبایل (ئارەزوومەندانە)',
    'ar': 'رقم الجوال (اختياري)',
    'en': 'Mobile number (optional)',
  },
  'signup_mobile_mandatory': {
    'ckb': 'ژمارەی مۆبایل (ناچاری)',
    'ar': 'رقم الجوال (إلزامي)',
    'en': 'Mobile number (required)',
  },
  'signup_address': {
    'ckb': 'شوێنی نیشتەجێبوون',
    'ar': 'عنوان السكن / المدينة',
    'en': 'Address / city',
  },
  'password_confirm': {
    'ckb': 'دووپاتکردنەوەی وشەی نهێنی',
    'ar': 'تأكيد كلمة المرور',
    'en': 'Confirm password',
  },
  'email': {
    'ckb': 'ئیمەیڵ',
    'ar': 'البريد الإلكتروني',
    'en': 'Email',
  },
  'password': {
    'ckb': 'وشەی نهێنی',
    'ar': 'كلمة المرور',
    'en': 'Password',
  },
  'password_hint_signup': {
    'ckb': 'وشەی نهێنی (لانیکەم ٨ پیت)',
    'ar': 'كلمة المرور (٨ أحرف على الأقل)',
    'en': 'Password (at least 8 characters)',
  },
  'register': {
    'ckb': 'تۆماربوون',
    'ar': 'تسجيل',
    'en': 'Register',
  },
  'registration_success_message': {
    'ckb': 'هەژمارەکەت بە سەرکەوتوویی دروستکرا',
    'ar': 'تم إنشاء حسابك بنجاح',
    'en': 'Your account was created successfully',
  },
  'registration_success_next': {
    'ckb': 'دواتر',
    'ar': 'التالي',
    'en': 'Next',
  },
  'registration_success_instruction': {
    'ckb':
        'تکایە لە پەڕەی داهاتوو ئەو ژمارەی مۆبایل و وشەی نهێنییە بەکاربهێنەوە کە لە کاتی تۆماربوون نووسیبووت.',
    'ar':
        'يُرجى استخدام رقم الجوال وكلمة المرور التي أدخلتها عند التسجيل في الصفحة التالية.',
    'en':
        'On the next screen, use the same mobile number and password you entered when you registered.',
  },
  'login_hint_after_registration': {
    'ckb':
        'تکایە ژمارەی مۆبایل و وشەی نهێنییە بەکاربهێنەوە کە لە کاتی تۆماربوون نووسیبووت.',
    'ar': 'استخدم رقم الجوال وكلمة المرور التي سجّلت بها.',
    'en': 'Sign in with the phone number and password you used when you registered.',
  },
  'forgot_password_title': {
    'ckb': 'لەبیرکردنەوەی وشەی نهێنی',
    'ar': 'نسيت كلمة المرور',
    'en': 'Forgot password',
  },
  'forgot_password_body': {
    'ckb':
        'ئیمەیڵ یان ژمارەی تەلەفۆن بنووسە بۆ ناردنی کۆدی پشتڕاستکردنەوە.',
    'ar': 'أدخل بريدك أو هاتفك لإرسال رمز التحقق.',
    'en': 'Enter your email or phone to receive a verification code.',
  },
  'hint_contact_forgot': {
    'ckb': 'ئیمەیڵ یان ژمارەی تەلەفۆن',
    'ar': 'البريد أو الهاتف',
    'en': 'Email or phone',
  },
  'send_code': {
    'ckb': 'ناردنی کۆد',
    'ar': 'إرسال الرمز',
    'en': 'Send code',
  },
  'fill_fields': {
    'ckb': 'تکایە زانیارییەکان پڕ بکەرەوە',
    'ar': 'يرجى تعبئة الحقول',
    'en': 'Please fill in all fields',
  },
  'account_not_found': {
    'ckb': 'هەژمار نەدۆزرایەوە',
    'ar': 'الحساب غير موجود',
    'en': 'Account not found',
  },
  'error_generic': {
    'ckb': 'هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە',
    'ar': 'حدث خطأ، حاول مرة أخرى',
    'en': 'Something went wrong, try again',
  },
  'validation_email_required': {
    'ckb': 'ئیمەیڵ پێویستە',
    'ar': 'البريد مطلوب',
    'en': 'Email is required',
  },
  'validation_email_invalid': {
    'ckb': 'ئیمەیڵێکی دروست بنووسە (@ و کۆتایی .com)',
    'ar': 'أدخل بريدًا صالحًا (@ وينتهي بـ .com)',
    'en': 'Enter a valid email (@ and a .com address)',
  },
  'validation_password_required': {
    'ckb': 'وشەی نهێنی پێویستە',
    'ar': 'كلمة المرور مطلوبة',
    'en': 'Password is required',
  },
  'validation_password_short': {
    'ckb': 'وشەی نهێنی لانیکەم ٨ پیت بێت',
    'ar': 'كلمة المرور ٨ أحرف على الأقل',
    'en': 'Password must be at least 8 characters',
  },
  'validation_password_mismatch': {
    'ckb': 'وشەکانی نهێنی یەک ناگرنەوە',
    'ar': 'كلمتا المرور غير متطابقتين',
    'en': 'Passwords do not match',
  },
  'validation_phone_required': {
    'ckb': 'تکایە ژمارەی مۆبایل بنووسە',
    'ar': 'يرجى إدخال رقم الجوال',
    'en': 'Please enter your mobile number',
  },
  'validation_phone_digits_only': {
    'ckb': 'تەنها ژمارە بنووسە',
    'ar': 'أدخل أرقامًا فقط',
    'en': 'Digits only',
  },
  'validation_phone_short': {
    'ckb': 'ژمارەی مۆبایل کورتە',
    'ar': 'رقم الجوال قصير جدًا',
    'en': 'Mobile number is too short',
  },
  'validation_phone_must_be_11': {
    'ckb': 'تکایە ١١ ژمارە بنووسە',
    'ar': 'يرجى إدخال ١١ رقمًا',
    'en': 'Please enter 11 digits',
  },
  'validation_phone_leading_zero': {
    'ckb': 'ژمارە دەبێت بە ٠ دەست پێبکات (١١ ژمارە)',
    'ar': 'يجب أن يبدأ الرقم بـ 0 (١١ رقمًا)',
    'en': 'Number must start with 0 (11 digits)',
  },
  'signup_otp_title': {
    'ckb': 'پشتڕاستکردنەوەی ژمارە',
    'ar': 'التحقق من الرقم',
    'en': 'Verify phone number',
  },
  'signup_otp_subtitle': {
    'ckb': 'کۆدی ٦ ژمارەیی بنووسە کە بۆ ژمارەی ({phone}) نێردراوە.',
    'ar': 'أدخل الرمز المكوّن من ٦ أرقام المرسل إلى ({phone}).',
    'en': 'Enter the 6-digit code sent to ({phone}).',
  },
  'signup_otp_verify': {
    'ckb': 'پشتڕاستکردنەوە',
    'ar': 'تحقق',
    'en': 'Verify',
  },
  'signup_otp_resend': {
    'ckb': 'دووبارە ناردنەوەی کۆد',
    'ar': 'إعادة إرسال الرمز',
    'en': 'Resend code',
  },
  'signup_otp_resend_wait': {
    'ckb': 'دووبارە ناردن لە {seconds} چرکە',
    'ar': 'إعادة الإرسال خلال {seconds} ث',
    'en': 'Resend in {seconds}s',
  },
  'signup_otp_resend_hint': {
    'ckb': 'کۆد نەگەیشت؟',
    'ar': 'لم يصلك الرمز؟',
    'en': "Didn't get a code?",
  },
  'signup_otp_wrong_code': {
    'ckb': 'کۆدەکە هەڵەیە، تکایە دووبارە تاقی بکەرەوە',
    'ar': 'الرمز غير صحيح، حاول مرة أخرى',
    'en': 'The code is wrong, please try again',
  },
  'signup_otp_incomplete': {
    'ckb': 'تکایە کۆدی ٦ ژمارەیی بە تەواوی بنووسە',
    'ar': 'أدخل الرمز المكوّن من ٦ أرقام',
    'en': 'Enter all 6 digits',
  },
  'signup_otp_no_verification_id': {
    'ckb': 'هەڵە لە ناردنی کۆد، دووبارە هەوڵ بدەرەوە',
    'ar': 'خطأ في الجلسة، أعد المحاولة',
    'en': 'Session error, try again',
  },
  'signup_otp_resent': {
    'ckb': 'کۆدێکی نوێ نێردرا',
    'ar': 'تم إرسال رمز جديد',
    'en': 'A new code was sent',
  },
  'signup_phone_send_failed': {
    'ckb': 'ناردنی کۆد سەرکەوتوو نەبوو',
    'ar': 'فشل إرسال الرمز',
    'en': 'Failed to send verification code',
  },
  'validation_address_required': {
    'ckb': 'شوێنی نیشتەجێبوون پێویستە',
    'ar': 'عنوان السكن مطلوب',
    'en': 'Address is required',
  },
  'validation_name_required': {
    'ckb': 'ناو پێویستە',
    'ar': 'الاسم مطلوب',
    'en': 'Name is required',
  },
  'validation_field_required': {
    'ckb': 'ئەم خانەیە پڕ بکەرەوە',
    'ar': 'املأ هذا الحقل',
    'en': 'Fill in this field',
  },
  'validation_contact_required': {
    'ckb': 'تکایە ئیمەیڵ یان ژمارەی تەلەفۆن بنووسە',
    'ar': 'أدخل البريد أو الهاتف',
    'en': 'Enter email or phone',
  },
  'validation_specialty_required': {
    'ckb': 'پسپۆڕی هەڵبژێرە لە لیستەکە',
    'ar': 'اختر التخصص من القائمة',
    'en': 'Select a specialty from the list',
  },
  'validation_city_required': {
    'ckb': 'شار هەڵبژێرە لە لیستەکە',
    'ar': 'اختر المدينة من القائمة',
    'en': 'Select a city from the list',
  },
  'validation_gender_required': {
    'ckb': 'تکایە ڕەگەز هەڵبژێرە',
    'ar': 'يرجى اختيار الجنس',
    'en': 'Please select your gender',
  },
  'signup_gender_title': {
    'ckb': 'ڕەگەز',
    'ar': 'الجنس',
    'en': 'Gender',
  },
  'signup_gender_male': {
    'ckb': 'نێر',
    'ar': 'ذكر',
    'en': 'Male',
  },
  'signup_gender_female': {
    'ckb': 'مێ',
    'ar': 'أنثى',
    'en': 'Female',
  },
  'book_now': {
    'ckb': 'کرتە بکە بۆ نۆرە ووردەکاری',
    'ar': 'اضغط للحجز أو التفاصيل',
    'en': 'Tap to book or view details',
  },
  'click_for_details': {
    'ckb': 'کرتە بکە بۆ ووردەکاری',
    'ar': 'اضغط للتفاصيل',
    'en': 'Click for details',
  },
  'patient_doctor_card_book_cta': {
    'ckb': 'نۆرە بگرە',
    'ar': 'احجز موعداً',
    'en': 'Book an appointment',
  },
  /// Compact label for doctor card details chip (avoids overflow next to book CTA).
  'patient_doctor_card_details_short': {
    'ckb': 'وردەکاری',
    'ar': 'التفاصيل',
    'en': 'Details',
  },
  'language': {
    'ckb': 'زمان',
    'ar': 'اللغة',
    'en': 'Language',
  },
  'close': {
    'ckb': 'داخستن',
    'ar': 'إغلاق',
    'en': 'Close',
  },
  'choose_language': {
    'ckb': 'زمانەکەت هەڵبژێرە',
    'ar': 'اختر لغتك',
    'en': 'Choose your language',
  },
  'language_current': {
    'ckb': 'ئێستا چالاکە',
    'ar': 'مفعّل حالياً',
    'en': 'Currently selected',
  },
  'edit_profile': {
    'ckb': 'گۆڕینی زانیارییەکان',
    'ar': 'تعديل البيانات',
    'en': 'Edit info',
  },
  'edit_profile_subtitle': {
    'ckb': 'ناو و ژمارەی مۆبایل',
    'ar': 'الاسم ورقم الجوال',
    'en': 'Name and mobile',
  },
  'about_app': {
    'ckb': 'دەربارەی ئەپ',
    'ar': 'عن التطبيق',
    'en': 'About app',
  },
  'about_app_subtitle': {
    'ckb': 'وەشان و زانیاری',
    'ar': 'الإصدار والمعلومات',
    'en': 'Version and info',
  },
  'logout': {
    'ckb': 'چوونەدەرەوە',
    'ar': 'تسجيل الخروج',
    'en': 'Log out',
  },
  'ticket_date': {
    'ckb': 'بەروار',
    'ar': 'التاريخ',
    'en': 'Date',
  },
  'ticket_time': {
    'ckb': 'کات',
    'ar': 'الوقت',
    'en': 'Time',
  },
  'ticket_patient': {
    'ckb': 'نەخۆش',
    'ar': 'المريض',
    'en': 'Patient',
  },
  'ticket_doctor_label': {
    'ckb': 'پزیشک',
    'ar': 'الطبيب',
    'en': 'Doctor',
  },
  'status_pending': {
    'ckb': 'چاوەڕوان',
    'ar': 'قيد الانتظار',
    'en': 'Pending',
  },
  'status_completed': {
    'ckb': 'تەواو',
    'ar': 'مكتمل',
    'en': 'Completed',
  },
  'status_cancelled': {
    'ckb': 'هەڵوەشاوە',
    'ar': 'ملغى',
    'en': 'Cancelled',
  },
  'day_expired': {
    'ckb': 'کاتی بەسەرچووە',
    'ar': 'انتهى الموعد',
    'en': 'Expired',
  },
  'day_today': {
    'ckb': 'ئەمڕۆ',
    'ar': 'اليوم',
    'en': 'Today',
  },
  'day_tomorrow': {
    'ckb': 'بەیانی',
    'ar': 'غداً',
    'en': 'Tomorrow',
  },
  'day_n_days_left': {
    'ckb': '{n} ڕۆژی ماوە',
    'ar': 'متبقي {n} يوم',
    'en': '{n} days left',
  },
  'appointments_need_login': {
    'ckb': 'چوونەژوورەوە پێویستە',
    'ar': 'يجب تسجيل الدخول',
    'en': 'Sign in required',
  },
  'appointments_empty': {
    'ckb': 'هێشتا نۆرەیەک تۆمار نەکردووە.',
    'ar': 'لا توجد مواعيد بعد.',
    'en': 'No appointments yet.',
  },
  'appointments_empty_today': {
    'ckb': 'هیچ نۆرەیەکت بۆ ئەمڕۆ نییە',
    'ar': 'ليس لديك مواعيد اليوم.',
    'en': 'You have no appointments for today.',
  },
  'appointments_show_all': {
    'ckb': 'هەموو نۆرەکان',
    'ar': 'كل المواعيد',
    'en': 'All appointments',
  },
  'appointments_show_today': {
    'ckb': 'تەنها ئەمڕۆ',
    'ar': 'اليوم فقط',
    'en': 'Today only',
  },
  'back': {
    'ckb': 'گەڕانەوە',
    'ar': 'رجوع',
    'en': 'Back',
  },
  'error_with_details': {
    'ckb': 'هەڵە ({detail})',
    'ar': 'خطأ ({detail})',
    'en': 'Error ({detail})',
  },
  'auth_err_invalid_email': {
    'ckb': 'ئیمەیڵەکە دروست نییە',
    'ar': 'البريد غير صالح',
    'en': 'Invalid email',
  },
  'auth_err_wrong_credential': {
    'ckb':
        'ئیمەیڵ یان وشەی نهێنی هەڵەیە، تکایە دووبارە هەوڵ بدەرەوە',
    'ar': 'البريد أو كلمة المرور غير صحيحة',
    'en': 'Wrong email or password, try again',
  },
  'auth_err_user_disabled': {
    'ckb': 'ئەم هەژمارە ناچالاک کراوە',
    'ar': 'هذا الحساب معطّل',
    'en': 'This account is disabled',
  },
  'auth_err_too_many_requests': {
    'ckb': 'هەوڵی زۆر، دواتر تاقی بکەرەوە',
    'ar': 'محاولات كثيرة، حاول لاحقاً',
    'en': 'Too many attempts, try later',
  },
  'auth_err_network': {
    'ckb': 'پەیوەندی ئینتەرنێتەکەت تاقیکەرەوە',
    'ar': 'تحقق من الاتصال بالإنترنت',
    'en': 'Check your internet connection',
  },
  'auth_err_generic': {
    'ckb': 'هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە',
    'ar': 'حدث خطأ، حاول مرة أخرى',
    'en': 'Something went wrong, try again',
  },
  'about_description': {
    'ckb':
        'ئەم ئەپڵیکەیشنە پلاتفۆرمێکی پێشکەوتووی تەندروستییە کە کار ئاسانی دەکات بۆ دۆزینەوەی باشترین پزیشکانی پسپۆڕ و وەرگرتنی نۆرە بە شێوازێکی خێرا و مۆدێرن. ئامانجی ئێمە دابینکردنی سیستەمێکی ڕێکخراوە بۆ بەڕێوەبردنی کاتەکانی نۆرەگرتن و دروستکردنی پەیوەندییەکی ئاسان لە نێوان پزیشک و نەخۆشدا، تاوەکو باشترین خزمەتگوزاری تەندروستی بگاتە هەمووان.',
    'ar':
        'هذا التطبيق منصة صحية متطورة تسهّل العثور على أفضل الأطباء الاختصاصيين وحجز المواعيد بسرعة وبطريقة عصرية. هدفنا توفير نظام منظم لإدارة أوقات الحجز وبناء رابطة سهلة بين الطبيب والمريض، حتى تصل أفضل خدمات الرعاية الصحية للجميع.',
    'en':
        'This app is an advanced health platform that makes it easy to find top specialist doctors and book appointments quickly and in a modern way. We provide an organized system for managing bookings and a smooth connection between doctor and patient, so quality healthcare can reach everyone.',
  },
  'profile_guest': {
    'ckb': 'هیچ هەژمارێک نییە',
    'ar': 'لا يوجد حساب',
    'en': 'No account',
  },
  'patient_default': {
    'ckb': 'نەخۆش',
    'ar': 'مريض',
    'en': 'Patient',
  },
  'signup_doctor_security_title': {
    'ckb': 'کۆدی چالاککردنی ئاسایش',
    'ar': 'رمز تفعيل الأمان',
    'en': 'Security activation code',
  },
  'signup_doctor_security_warning': {
    'ckb':
        'ئاگاداری: ئەم کۆدە تایبەتە بە پزیشکانی ڕێپێدراو. بڵاوکردنەوەی ئەم کۆدە بەرپرسیارێتی یاسایی لەسەرە و دەبێتە هۆی سڕینەوەی هەژمارەکەت.',
    'ar':
        'تحذير: هذا الرمز مخصص للأطباء المصرّح لهم. نشره ينطوي على مسؤولية قانونية وقد يؤدي إلى حذف حسابك.',
    'en':
        'Warning: This code is for authorized physicians only. Sharing it may carry legal liability and can result in deletion of your account.',
  },
  'signup_doctor_security_hint': {
    'ckb': 'کۆدی چالاککردن بنووسە',
    'ar': 'أدخل رمز التفعيل',
    'en': 'Enter activation code',
  },
  'signup_doctor_security_wrong': {
    'ckb': 'کۆدەکە هەڵەیە، تکایە پەیوەندی بە بەڕێوەبەر بکە.',
    'ar': 'الرمز غير صحيح، يرجى التواصل مع المشرف.',
    'en': 'The code is incorrect. Please contact the administrator.',
  },
  'signup_doctor_security_confirm': {
    'ckb': 'پشتڕاستکردنەوە',
    'ar': 'تأكيد',
    'en': 'Verify',
  },
  'signup_err_email_in_use': {
    'ckb': 'ئەم ئیمەیڵە پێشتر بەکارهاتووە',
    'ar': 'البريد مستخدم مسبقاً',
    'en': 'This email is already in use',
  },
  'signup_err_generic': {
    'ckb': 'هەڵەیەک ڕوویدا',
    'ar': 'حدث خطأ',
    'en': 'Something went wrong',
  },
  'signup_err_firestore': {
    'ckb': 'هەڵەی Firebase',
    'ar': 'خطأ في Firebase',
    'en': 'Firebase error',
  },
  'splash_loading': {
    'ckb': 'کەمێک چاوەڕوان بن...',
    'ar': 'يرجى الانتظار...',
    'en': 'Please wait...',
  },
  'welcome_user': {
    'ckb': 'بەخێربێیت، {name}',
    'ar': 'مرحباً، {name}',
    'en': 'Welcome, {name}',
  },
  'patient_home_greeting': {
    'ckb': 'سڵاو، {name}',
    'ar': 'مرحباً، {name}',
    'en': 'Hello, {name}',
  },
  'search_doctors_hint': {
    'ckb': 'گەڕان بە پزیشک یان پسپۆڕی...',
    'ar': 'ابحث عن طبيب أو تخصص...',
    'en': 'Search for doctors or specialty...',
  },
  'search_hospitals_hint': {
    'ckb': 'گەڕان بە نەخۆشخانە یان شوێن...',
    'ar': 'ابحث عن مستشفى أو موقع...',
    'en': 'Search hospitals or location...',
  },
  'home_tab_doctors': {
    'ckb': 'پزیشکەکان',
    'ar': 'الأطباء',
    'en': 'Doctors',
  },
  'home_tab_hospitals': {
    'ckb': 'نەخۆشخانەکان',
    'ar': 'المستشفيات',
    'en': 'Hospitals',
  },
  'hospitals_browse_empty': {
    'ckb': 'هیچ نەخۆشخانەیەک نەدۆزرایەوە',
    'ar': 'لم يتم العثور على مستشفيات',
    'en': 'No hospitals match your search',
  },
  'hospitals_section': {
    'ckb': 'نەخۆشخانەکان',
    'ar': 'المستشفيات',
    'en': 'Hospitals',
  },
  'hospitals_load_error': {
    'ckb': 'نەتوانرا نەخۆشخانەکان بخوێنرێنەوە: {error}',
    'ar': 'تعذر تحميل المستشفيات: {error}',
    'en': 'Could not load hospitals: {error}',
  },
  'hospital_doctors_section': {
    'ckb': 'پزیشکەکانی ئەم نەخۆشخانەیە',
    'ar': 'أطباء هذا المستشفى',
    'en': 'Doctors at this hospital',
  },
  'hospital_doctors_empty': {
    'ckb': 'هیچ پزیشکێک بۆ ئەم نەخۆشخانەیە تۆمار نەکراوە.',
    'ar': 'لا يوجد أطباء مسجلون في هذه المستشفى.',
    'en': 'No doctors are linked to this hospital yet.',
  },
  'hospital_doctors_load_error': {
    'ckb': 'نەتوانرا پزیشکان بخوێنرێنەوە: {error}',
    'ar': 'تعذر تحميل الأطباء: {error}',
    'en': 'Could not load doctors: {error}',
  },
  'doctor_field_hospital_registry': {
    'ckb': 'نەخۆشخانە (لیست)',
    'ar': 'المستشفى (من القائمة)',
    'en': 'Hospital (from list)',
  },
  'hospital_registry_none': {
    'ckb': 'هیچ (پەیوەندی نەکراوە)',
    'ar': 'بدون (غير مرتبط)',
    'en': 'None (not linked)',
  },
  'patient_home_cities_title': {
    'ckb': 'شارەکان',
    'ar': 'المدن',
    'en': 'Cities',
  },
  'patient_home_city_all': {
    'ckb': 'هەموو',
    'ar': 'الكل',
    'en': 'All',
  },
  'patient_home_pick_city_sheet_title': {
    'ckb': 'شار هەڵبژێرە',
    'ar': 'اختر المدينة',
    'en': 'Choose a city',
  },
  'specialties': {
    'ckb': 'پسپۆڕییەکان',
    'ar': 'التخصصات',
    'en': 'Specialties',
  },
  'specialties_all': {
    'ckb': 'هەمووی',
    'ar': 'الكل',
    'en': 'All',
  },
  'dentist_specialty': {
    'ckb': 'ددان',
    'ar': 'أسنان',
    'en': 'Dentist',
  },
  'cardiology_specialty': {
    'ckb': 'دڵ',
    'ar': 'قلب',
    'en': 'Cardiology',
  },
  'orthopedics_specialty': {
    'ckb': 'فەقەڕات',
    'ar': 'عظام',
    'en': 'Orthopedics',
  },
  'pediatrics_specialty': {
    'ckb': 'منداڵان',
    'ar': 'أطفال',
    'en': 'Pediatrics',
  },
  'ent_specialty': {
    'ckb': 'قورگ و لوت و گوێ',
    'ar': 'أنف وأذن وحنجرة',
    'en': 'ENT',
  },
  'ophthalmology_specialty': {
    'ckb': 'چاو',
    'ar': 'عيون',
    'en': 'Ophthalmology',
  },
  'dermatology_specialty': {
    'ckb': 'پێست و جوانکاری',
    'ar': 'جلدية وتجميل',
    'en': 'Dermatology',
  },
  'neurology_specialty': {
    'ckb': 'دەمار و مێشک',
    'ar': 'أعصاب',
    'en': 'Neurology',
  },
  'obgyn_specialty': {
    'ckb': 'ژنان و منداڵبوون',
    'ar': 'نساء وتوليد',
    'en': 'Obstetrics & gynecology',
  },
  'gastroenterology_specialty': {
    'ckb': 'هەناوی',
    'ar': 'جهاز هضمي',
    'en': 'Gastroenterology',
  },
  'dropdown_specialty_label': {
    'ckb': 'لیستی هەڵبژاردن',
    'ar': 'قائمة الاختيار',
    'en': 'Select from list',
  },
  'dropdown_specialty_hint': {
    'ckb': 'پسپۆڕی هەڵبژێرە',
    'ar': 'اختر التخصص',
    'en': 'Choose specialty',
  },
  'dropdown_city_label': {
    'ckb': 'شار',
    'ar': 'المدينة',
    'en': 'City',
  },
  'dropdown_city_hint': {
    'ckb': 'شار هەڵبژێرە',
    'ar': 'اختر المدينة',
    'en': 'Choose city',
  },
  'recommended_doctors': {
    'ckb': 'پزیشکە پەسەندکراوەکان',
    'ar': 'أطباء موصى بهم',
    'en': 'Recommended doctors',
  },
  'recommended_doctors_sub': {
    'ckb': 'پزیشکەکان کە لەلایەن بەڕێوەبەرەوە قبوڵکراون',
    'ar': 'أطباء معتمدون من الإدارة',
    'en': 'Doctors approved by the clinic',
  },
  'doctors_load_error': {
    'ckb': 'هەڵە لە بارکردنی لیست',
    'ar': 'خطأ في تحميل القائمة',
    'en': 'Error loading list',
  },
  'doctors_load_error_detail': {
    'ckb': 'هەڵە لە بارکردنی لیست ({error})',
    'ar': 'خطأ في تحميل القائمة ({error})',
    'en': 'Error loading list ({error})',
  },
  'doctors_empty_search': {
    'ckb': 'هیچ پزیشکێک بەم ناوە نەدۆزرایەوە',
    'ar': 'لم يتم العثور على أطباء',
    'en': 'No doctors match your search',
  },
  'tooltip_support': {
    'ckb': 'پشتگیری',
    'ar': 'الدعم',
    'en': 'Support',
  },
  'patient_home_menu_feedback': {
    'ckb': 'بۆچوونەکان',
    'ar': 'ملاحظات',
    'en': 'Feedback',
  },
  'patient_home_menu_notifications': {
    'ckb': 'ئاگادارکردنەوەکان',
    'ar': 'الإشعارات',
    'en': 'Notifications',
  },
  'patient_notifications_screen_title': {
    'ckb': 'ئاگادارکردنەوەکان',
    'ar': 'الإشعارات',
    'en': 'Notifications',
  },
  'patient_notifications_empty': {
    'ckb': 'هێشتا ئاگادارکردنەوەیەک نییە',
    'ar': 'لا توجد إشعارات بعد',
    'en': 'No notifications yet',
  },
  'patient_notifications_login': {
    'ckb': 'تکایە بچۆ ژوورەوە',
    'ar': 'يرجى تسجيل الدخول',
    'en': 'Please sign in',
  },
  'patient_notifications_empty_modern': {
    'ckb': 'هێشتا هیچ هەواڵێکی نوێ نییە',
    'ar': 'لا يوجد جديد بعد',
    'en': 'No news yet',
  },
  'patient_notif_headline_doctor_rejected': {
    'ckb': 'دکتۆر {name} نۆرەکەی ڕەتکردیتەوە',
    'ar': 'رفض الدكتور {name} موعدك',
    'en': 'Dr. {name} rejected your appointment',
  },
  'patient_notif_badge_rejected': {
    'ckb': 'ڕەتکرایەوە',
    'ar': 'مرفوض',
    'en': 'Rejected',
  },
  'patient_notif_badge_clinic': {
    'ckb': 'داخراوە',
    'ar': 'مغلق',
    'en': 'Closed',
  },
  'patient_notif_badge_doctor_closed': {
    'ckb': 'هەڵوەشاوە',
    'ar': 'ملغى',
    'en': 'Cancelled',
  },
  'patient_notif_badge_update': {
    'ckb': 'ئاگاداری',
    'ar': 'تنبيه',
    'en': 'Notice',
  },
  'patient_notif_time_today': {
    'ckb': 'ئەمڕۆ',
    'ar': 'اليوم',
    'en': 'Today',
  },
  'patient_notif_time_yesterday': {
    'ckb': 'دوێنێ',
    'ar': 'أمس',
    'en': 'Yesterday',
  },
  'patient_notif_delete': {
    'ckb': 'سڕینەوە',
    'ar': 'حذف',
    'en': 'Delete',
  },
  'patient_notif_delete_confirm': {
    'ckb': 'ئەم ئاگادارکردنەوەیە بسڕدرێتەوە؟',
    'ar': 'حذف هذا الإشعار؟',
    'en': 'Delete this notification?',
  },
  /// Stored on Firestore [notifications].message when staff cancels a slot.
  'root_notif_body_slot_cancelled': {
    'ckb': 'نۆرەکەت ڕەتکرایەوە',
    'ar': 'تم رفض موعدك',
    'en': 'Your appointment was rejected.',
  },
  'tooltip_logout': {
    'ckb': 'چوونەدەرەوە',
    'ar': 'تسجيل الخروج',
    'en': 'Log out',
  },
  'field_name': {
    'ckb': 'ناو',
    'ar': 'الاسم',
    'en': 'Name',
  },
  'field_specialty': {
    'ckb': 'پسپۆڕی',
    'ar': 'التخصص',
    'en': 'Specialty',
  },
  'notifications': {
    'ckb': 'ئاگاداری',
    'ar': 'إشعارات',
    'en': 'Notifications',
  },
  'support_title': {
    'ckb': 'بۆچوون',
    'ar': 'ملاحظات',
    'en': 'Feedback',
  },
  'support_hint': {
    'ckb': 'بۆچوونەکەت لێرە بنووسە...',
    'ar': 'اكتب رسالتك هنا...',
    'en': 'Type your message...',
  },
  'support_send': {
    'ckb': 'ناردن',
    'ar': 'إرسال',
    'en': 'Send',
  },
  'support_empty': {
    'ckb': 'تکایە بۆچوونەکەت بنووسە',
    'ar': 'يرجى كتابة رسالتك',
    'en': 'Please enter your message',
  },
  'support_need_login': {
    'ckb': 'تکایە بچۆ ژوورەوە',
    'ar': 'يرجى تسجيل الدخول',
    'en': 'Please sign in',
  },
  'support_sent': {
    'ckb': 'نامەکەت نێردرا',
    'ar': 'تم إرسال رسالتك',
    'en': 'Your message was sent',
  },
  'support_thanks_received': {
    'ckb': 'سوپاس، بۆچوونەکەت وەرگیرا',
    'ar': 'شكراً، تم استلام رسالتك',
    'en': 'Thanks, your message was received',
  },
  'support_error': {
    'ckb': 'هەڵە لە ناردن',
    'ar': 'خطأ في الإرسال',
    'en': 'Failed to send',
  },
  'support_error_retry': {
    'ckb': 'هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە',
    'ar': 'حدث خطأ، حاول مرة أخرى',
    'en': 'Something went wrong, please try again',
  },
  'support_intro': {
    'ckb':
        'بۆچوون یان پێشنیارەکەت لێرە بنووسە. پشتیوانیەکەمان ئاگادار دەکەینەوە.',
    'ar': 'اكتب ملاحظتك أو اقتراحك هنا. سنُبلغ فريق الدعم.',
    'en': 'Write your feedback or suggestion here. We will notify support.',
  },
  'doctor_default': {
    'ckb': 'پزیشک',
    'ar': 'طبيب',
    'en': 'Doctor',
  },
  'doctor_specialty_prefix': {
    'ckb': 'پسپۆڕی',
    'ar': 'التخصص',
    'en': 'Specialty',
  },
  'doctor_profile_about': {
    'ckb': 'دەربارە',
    'ar': 'نبذة',
    'en': 'About',
  },
  'doctor_profile_experience': {
    'ckb': 'ئەزموون',
    'ar': 'الخبرة',
    'en': 'Experience',
  },
  'doctor_profile_location': {
    'ckb': 'شوێن',
    'ar': 'الموقع',
    'en': 'Location',
  },
  'doctor_profile_hospital_label': {
    'ckb': 'نەخۆشخانە / کلینیک',
    'ar': 'المستشفى / العيادة',
    'en': 'Hospital / clinic',
  },
  'doctor_profile_address_label': {
    'ckb': 'ناونیشان',
    'ar': 'العنوان',
    'en': 'Address',
  },
  'doctor_rating_section_title': {
    'ckb': 'ئەم پزیشکە بەرز بکەرەوە',
    'ar': 'قيّم هذا الطبيب',
    'en': 'Rate this doctor',
  },
  'doctor_rating_tap_stars': {
    'ckb': '١ بۆ ٥ ئەستێرە هەڵبژێرە',
    'ar': 'اختر من ١ إلى ٥ نجوم',
    'en': 'Tap 1–5 stars',
  },
  'doctor_rating_comment_hint': {
    'ckb': 'پێداچوونەوە (دڵخواز)',
    'ar': 'مراجعة نصية (اختياري)',
    'en': 'Written review (optional)',
  },
  'doctor_rating_submit': {
    'ckb': 'ناردن',
    'ar': 'إرسال',
    'en': 'Submit',
  },
  'doctor_rating_thanks': {
    'ckb': 'سوپاس! هەڵسەنگاندنەکەت تۆمار کرا',
    'ar': 'شكرًا! تم حفظ تقييمك',
    'en': 'Thanks! Your rating was saved',
  },
  'doctor_rating_already': {
    'ckb': 'تۆ پێشتر ئەم پزیشکەت هەڵسەنگاندووە',
    'ar': 'لقد قيّمت هذا الطبيب مسبقًا',
    'en': 'You already rated this doctor',
  },
  'doctor_rating_need_visit': {
    'ckb':
        'تەنها دوای تەواوبوونی نۆرەیەک لەگەڵ ئەم پزیشکە دەتوانیت نرخاندن بکەیت',
    'ar': 'يمكنك التقييم بعد إكمال موعد مع هذا الطبيب',
    'en': 'You can rate after a completed appointment with this doctor',
  },
  'doctor_rating_error': {
    'ckb': 'نەتوانرا نرخاندن بنێردرێت، دووبارە هەوڵ بدەرەوە',
    'ar': 'تعذر إرسال التقييم',
    'en': 'Could not submit rating',
  },
  'doctor_card_rating_none': {
    'ckb': 'هێشتا نرخاندن نییە',
    'ar': 'لا تقييمات بعد',
    'en': 'No ratings yet',
  },
  'doctor_experience_years': {
    'ckb': '{years} ساڵ ئەزموون',
    'ar': '{years} سنوات خبرة',
    'en': '{years} years experience',
  },
  'editor_section_kurdish': {
    'ckb': 'کوردی (سەرەکی)',
    'ar': 'الكردية (أساسية)',
    'en': 'Kurdish (primary)',
  },
  'editor_section_arabic': {
    'ckb': 'عەرەبی',
    'ar': 'العربية',
    'en': 'Arabic',
  },
  'editor_section_english': {
    'ckb': 'ئینگلیزی',
    'ar': 'الإنجليزية',
    'en': 'English',
  },
  'doctor_field_bio': {
    'ckb': 'دەربارەی پزیشک',
    'ar': 'نبذة عن الطبيب',
    'en': 'Bio / about',
  },
  'doctor_field_address': {
    'ckb': 'ناونیشانی نۆرینگە',
    'ar': 'عنوان العيادة',
    'en': 'Clinic address',
  },
  'doctor_field_hospital': {
    'ckb': 'ناوی نەخۆشخانە یان کلینیک',
    'ar': 'اسم المستشفى أو العيادة',
    'en': 'Hospital or clinic name',
  },
  /// Doctor profile editor: single manual clinic/hospital name (replaces duplicate hospital text field).
  'doctor_field_hospital_display_simple': {
    'ckb': 'ناوی کلینیک یان نەخۆشخانە',
    'ar': 'اسم العيادة أو المستشفى',
    'en': 'Clinic or hospital name',
  },
  'doctor_field_experience': {
    'ckb': 'ئەزموون (دەق)',
    'ar': 'الخبرة (نص)',
    'en': 'Experience (text)',
  },
  'doctor_field_years_numeric': {
    'ckb': 'ژمارەی ساڵەکانی ئەزموون (ئیختیاری)',
    'ar': 'سنوات الخبرة (رقم، اختياري)',
    'en': 'Years of experience (optional number)',
  },
  'doctor_consultation_fee_label': {
    'ckb': 'نرخی بینین',
    'ar': 'سعر الاستشارة',
    'en': 'Consultation fee',
  },
  'doctor_phone_label': {
    'ckb': 'ژمارەی مۆبایل',
    'ar': 'رقم الجوال',
    'en': 'Mobile number',
  },
  'doctor_field_full_name': {
    'ckb': 'ناوی تەواو',
    'ar': 'الاسم الكامل',
    'en': 'Full name',
  },
  'doctor_nav_appointments': {
    'ckb': 'نۆرەکانی ئەمڕۆ',
    'ar': 'مواعيد اليوم',
    'en': "Today's appointments",
  },
  'doctor_nav_schedule': {
    'ckb': 'خشتەی کات',
    'ar': 'الجدول',
    'en': 'Schedule',
  },
  'doctor_nav_history': {
    'ckb': 'مێژوو',
    'ar': 'السجل',
    'en': 'History',
  },
  'doctor_nav_profile': {
    'ckb': 'پڕۆفایل',
    'ar': 'الملف',
    'en': 'Profile',
  },
  'doctor_archive_title': {
    'ckb': 'ئەرشیفی نەخۆشەکان',
    'ar': 'أرشيف المرضى',
    'en': 'Patient archive',
  },
  'doctor_archive_subtitle': {
    'ckb': 'نۆرە تەواوکراوەکان و تێبینی پزیشکی',
    'ar': 'المواعيد المكتملة والملاحظات',
    'en': 'Completed visits and medical notes',
  },
  'doctor_archive_month_total': {
    'ckb': 'کۆی گشتی نەخۆشەکان لەم مانگەدا: {count}',
    'ar': 'إجمالي المرضى هذا الشهر: {count}',
    'en': 'Total patients this month: {count}',
  },
  'doctor_archive_filter_month': {
    'ckb': 'مانگ',
    'ar': 'الشهر',
    'en': 'Month',
  },
  'doctor_archive_filter_year': {
    'ckb': 'ساڵ',
    'ar': 'السنة',
    'en': 'Year',
  },
  'doctor_archive_view_notes': {
    'ckb': 'بینینی تێبینی پزیشکی',
    'ar': 'عرض الملاحظات الطبية',
    'en': 'View medical notes',
  },
  'doctor_archive_notes_dialog_title': {
    'ckb': 'تێبینی پزیشکی',
    'ar': 'ملاحظات طبية',
    'en': 'Medical notes',
  },
  'doctor_archive_no_notes': {
    'ckb': 'هیچ تێبینییەک تۆمار نەکراوە.',
    'ar': 'لا توجد ملاحظات مسجلة.',
    'en': 'No notes were recorded for this visit.',
  },
  'doctor_archive_empty': {
    'ckb': 'لەم مانگەدا هیچ نۆرەیەکی تەواوکراو نییە.',
    'ar': 'لا مواعيد مكتملة لهذا الشهر.',
    'en': 'No completed appointments for this month.',
  },
  'doctor_archive_visit_date': {
    'ckb': 'بەروار',
    'ar': 'التاريخ',
    'en': 'Date',
  },
  'doctor_archive_unavailable': {
    'ckb': 'ناتوانرێت ئەرشیف بکرێت — هەژماری پزیشک دیاری نەکراوە.',
    'ar': 'تعذر فتح الأرشيف — لم يُحدد حساب الطبيب.',
    'en': 'Archive unavailable — doctor account is not set.',
  },
  'doctor_archive_period_daily': {
    'ckb': 'ڕۆژانە',
    'ar': 'يومي',
    'en': 'Daily',
  },
  'doctor_archive_period_weekly': {
    'ckb': 'حەفتانە',
    'ar': 'أسبوعي',
    'en': 'Weekly',
  },
  'doctor_archive_period_monthly': {
    'ckb': 'مانگانە',
    'ar': 'شهري',
    'en': 'Monthly',
  },
  'doctor_archive_period_yearly': {
    'ckb': 'ساڵانە',
    'ar': 'سنوي',
    'en': 'Yearly',
  },
  'doctor_archive_total_period_daily': {
    'ckb': 'کۆی گشتی ئەم ڕۆژە: {count}',
    'ar': 'إجمالي المرضى اليوم: {count}',
    'en': 'Total for this day: {count}',
  },
  'doctor_archive_total_period_weekly': {
    'ckb': 'کۆی گشتی ئەم حەفتەیە: {count}',
    'ar': 'إجمالي المرضى هذا الأسبوع: {count}',
    'en': 'Total for this week: {count}',
  },
  'doctor_archive_total_period_monthly': {
    'ckb': 'کۆی گشتی ئەم مانگە: {count}',
    'ar': 'إجمالي المرضى هذا الشهر: {count}',
    'en': 'Total for this month: {count}',
  },
  'doctor_archive_total_period_yearly': {
    'ckb': 'کۆی گشتی ئەم ساڵە: {count}',
    'ar': 'إجمالي المرضى هذا العام: {count}',
    'en': 'Total for this year: {count}',
  },
  'doctor_archive_pick_date': {
    'ckb': 'بەروار هەڵبژێرە',
    'ar': 'اختر التاريخ',
    'en': 'Choose date',
  },
  'doctor_archive_calendar_jump': {
    'ckb': 'گۆڕینی مانگ',
    'ar': 'انتقال سريع',
    'en': 'Jump to date',
  },
  'doctor_archive_select_day_button': {
    'ckb': 'ڕۆژێک هەڵبژێرە',
    'ar': 'اختر يوماً',
    'en': 'Select a day',
  },
  'doctor_archive_week_caption': {
    'ckb': 'شەممە — هەینی',
    'ar': 'السبت — الجمعة',
    'en': 'Sat — Fri',
  },
  'doctor_archive_empty_period': {
    'ckb': 'لەم ماوەیەدا هیچ نۆرەیەکی تەواوکراو نییە.',
    'ar': 'لا مواعيد مكتملة في هذه الفترة.',
    'en': 'No completed appointments in this period.',
  },
  'doctor_archive_field_full_name': {
    'ckb': 'ناوی تەواو',
    'ar': 'الاسم الكامل',
    'en': 'Full name',
  },
  'doctor_archive_field_phone': {
    'ckb': 'ژمارەی مۆبایل',
    'ar': 'رقم الهاتف',
    'en': 'Phone',
  },
  'doctor_archive_field_age': {
    'ckb': 'تەمەن',
    'ar': 'العمر',
    'en': 'Age',
  },
  'doctor_archive_field_gender': {
    'ckb': 'ڕەگەز',
    'ar': 'الجنس',
    'en': 'Gender',
  },
  'doctor_archive_field_blood': {
    'ckb': 'گرووپی خوێن',
    'ar': 'فصيلة الدم',
    'en': 'Blood group',
  },
  'doctor_archive_field_notes': {
    'ckb': 'تێبینی پزیشکی',
    'ar': 'ملاحظات طبية',
    'en': 'Medical notes',
  },
  'doctor_archive_detail_visit': {
    'ckb': 'کاتی نۆرە',
    'ar': 'موعد الزيارة',
    'en': 'Visit',
  },
  'doctor_tooltip_patient_list': {
    'ckb': 'لیستی نەخۆشەکان',
    'ar': 'قائمة المرضى',
    'en': 'Patient list',
  },
  'doctor_title_appointments_list': {
    'ckb': 'نۆرەکانی داواکراو',
    'ar': 'المواعيد المطلوبة',
    'en': 'Requested appointments',
  },
  'doctor_appointments_empty': {
    'ckb': 'هیچ نۆرەیەکی نوێ نییە',
    'ar': 'لا توجد مواعيد جديدة',
    'en': 'No appointments yet',
  },
  'doctor_appointments_empty_today': {
    'ckb': 'بۆ ئەمڕۆ هیچ نۆرەیەک نییە',
    'ar': 'لا مواعيد اليوم',
    'en': 'No appointments scheduled for today',
  },
  'doctor_today_stats_heading': {
    'ckb': 'ئامارەکانی ئەمڕۆ',
    'ar': 'إحصائيات اليوم',
    'en': "Today's stats",
  },
  'doctor_today_stat_total': {
    'ckb': 'کۆی گشتی',
    'ar': 'الإجمالي',
    'en': 'Total',
  },
  'doctor_today_stat_remaining': {
    'ckb': 'ماوە',
    'ar': 'المتبقي',
    'en': 'Remaining',
  },
  'doctor_today_stat_completed': {
    'ckb': 'تەواوبوو',
    'ar': 'مكتمل',
    'en': 'Done',
  },
  'doctor_today_timeline': {
    'ckb': 'خشتەی کاتی ئەمڕۆ',
    'ar': 'جدول اليوم',
    'en': "Today's timeline",
  },
  /// Doctor appointments tab: main list section title.
  'doctor_today_slots_heading': {
    'ckb': 'نۆرەکانی ئەمڕۆ',
    'ar': 'مواعيد اليوم',
    'en': "Today's appointments",
  },
  /// Badge next to [doctor_today_slots_heading]: total booked count ({count} = English numerals).
  'doctor_today_booked_count_badge': {
    'ckb': '{count} نەخۆش',
    'ar': '{count} مرضى',
    'en': '{count} patients',
  },
  /// Doctor dashboard: day has hours but zero booked slots (list hidden).
  'doctor_today_no_bookings_empty': {
    'ckb': 'هیچ نۆرەیەک بۆ ئەمڕۆ تومار نەکراوە',
    'ar': 'لم يُسجَّل أي موعد لهذا اليوم',
    'en': 'No appointments recorded for today',
  },
  /// Doctor dashboard: no working hours / closed day / zero generated slots.
  'doctor_today_no_slots_message': {
    'ckb': 'هیچ نۆرەیەک بۆ ئەمڕۆ بوونی نییە',
    'ar': 'لا توجد مواعيد لهذا اليوم',
    'en': 'There are no slots for today',
  },
  /// Doctor dashboard: clinic has hours but no booked appointments to list.
  'doctor_today_no_booked_list_message': {
    'ckb': 'هیچ نۆرەیەکی تۆمارکراو بۆ ئەمڕۆ نییە',
    'ar': 'لا توجد مواعيد مسجلة لهذا اليوم',
    'en': 'No booked appointments for today',
  },
  /// Label between active and finished (completed/rejected) groups on the doctor dashboard.
  'doctor_today_completed_section_label': {
    'ckb': 'نۆرە تەواوبووەکان',
    'ar': 'مكتملة / منتهية',
    'en': 'Completed appointments',
  },
  'doctor_appointments_update_error': {
    'ckb': 'هەڵە لە نوێکردنەوە',
    'ar': 'خطأ في التحديث',
    'en': 'Update failed',
  },
  'doctor_appointment_done_snack': {
    'ckb': 'وەک تەواوبوو تۆمارکرا',
    'ar': 'تم التسجيل كمكتمل',
    'en': 'Marked as completed',
  },
  'doctor_appointment_cancelled_snack': {
    'ckb': 'وەک هەڵوەشاوە تۆمارکرا',
    'ar': 'تم التسجيل كملغى',
    'en': 'Marked as cancelled',
  },
  'doctor_appt_status_pending': {
    'ckb': 'چاوەڕێ',
    'ar': 'قيد الانتظار',
    'en': 'Pending',
  },
  'doctor_appt_status_completed': {
    'ckb': 'تەواوبوو',
    'ar': 'مكتمل',
    'en': 'Completed',
  },
  'doctor_appt_status_cancelled': {
    'ckb': 'هەڵوەشاوە',
    'ar': 'ملغى',
    'en': 'Cancelled',
  },
  'doctor_appt_patient_name_label': {
    'ckb': 'ناوی نەخۆش',
    'ar': 'اسم المريض',
    'en': 'Patient name',
  },
  'doctor_appt_datetime_label': {
    'ckb': 'بەروار و کات',
    'ar': 'التاريخ والوقت',
    'en': 'Date & time',
  },
  'doctor_appt_action_decline': {
    'ckb': 'ڕەتکردنەوە',
    'ar': 'رفض',
    'en': 'Decline',
  },
  'doctor_appt_action_complete': {
    'ckb': 'تەواوبوو',
    'ar': 'إكمال',
    'en': 'Complete',
  },
  'appt_action_confirm_title': {
    'ckb': 'دڵنیای لە ئەنجامدانی ئەم کردارە؟',
    'ar': 'هل أنت متأكد من تنفيذ هذا الإجراء؟',
    'en': 'Are you sure you want to do this?',
  },
  'appt_action_confirm_yes': {
    'ckb': 'بەڵێ، دڵنیام',
    'ar': 'نعم، أنا متأكد',
    'en': "Yes, I'm sure",
  },
  'appt_action_confirm_no': {
    'ckb': 'نەخێر، پەشیمانم',
    'ar': 'لا، تراجعت',
    'en': 'No, go back',
  },
  'doctor_appt_cancel_confirm_title': {
    'ckb': 'دڵنیای لە هەڵوەشاندنەوەی ئەم چاوەڕوانییە؟',
    'ar': 'هل أنت متأكد أنك تريد إلغاء هذا الموعد؟',
    'en': 'Are you sure you want to cancel this appointment?',
  },
  'doctor_appt_action_cancel_appointment': {
    'ckb': 'هەڵوەشاندنەوە',
    'ar': 'إلغاء الموعد',
    'en': 'Cancel appointment',
  },
  'doctor_appt_more_actions': {
    'ckb': 'کردارەکان',
    'ar': 'المزيد',
    'en': 'More actions',
  },
  'doctor_appt_tag_clinic_closed': {
    'ckb': 'داخراو',
    'ar': 'مغلق',
    'en': 'Closed',
  },
  'schedule_close_day_bulk_title': {
    'ckb': 'داخستنی ڕۆژ',
    'ar': 'إغلاق اليوم',
    'en': 'Close day',
  },
  'schedule_close_day_bulk_body': {
    'ckb':
        'ئەم ڕۆژە {count} چاوەڕوانی چالاکی هەیە. داخستنی ڕۆژ هەموویان ڕەتدەکاتەوە. بەردەوام بیت؟',
    'ar':
        'يحتوي هذا اليوم على {count} حجوزات نشطة. إغلاق اليوم سيلغيها جميعاً. هل تريد المتابعة؟',
    'en':
        'This day has {count} active bookings. Closing the day will reject all of them. Proceed?',
  },
  'patient_appt_status_cancelled_clinic_closed': {
    'ckb': 'هەڵوەشاوە — کلینیک داخراوە',
    'ar': 'ملغى — العيادة مغلقة',
    'en': 'Cancelled — clinic closed',
  },
  'patient_appt_status_cancelled_by_doctor': {
    'ckb': 'هەڵوەشاوە — لەلایەن پزیشک',
    'ar': 'ملغى — من قبل الطبيب',
    'en': 'Cancelled — by doctor',
  },
  'patient_appt_cancelled_by_doctor_alert': {
    'ckb': 'ببورە، ئەم بەروارە لەلایەن پزیشکەوە داخراوە و نۆرەکەت هەڵوەشایەوە.',
    'ar': 'عذراً، تم إغلاق هذا التاريخ من قبل الطبيب وتم إلغاء موعدك.',
    'en': 'Sorry, this date was closed by the doctor and your appointment was cancelled.',
  },
  'status_expired': {
    'ckb': 'بەسەرچوو',
    'ar': 'منتهي',
    'en': 'Expired',
  },
  'patient_appt_expired_label': {
    'ckb': 'ئەم نۆرەیە کاتەکەی بەسەرچووە',
    'ar': 'انتهى وقت هذا الموعد',
    'en': 'This appointment has expired.',
  },
  'doctor_appt_label_age': {
    'ckb': 'تەمەن',
    'ar': 'العمر',
    'en': 'Age',
  },
  'doctor_appt_label_gender': {
    'ckb': 'ڕەگەز',
    'ar': 'الجنس',
    'en': 'Gender',
  },
  'doctor_appt_label_phone': {
    'ckb': 'مۆبایل',
    'ar': 'الهاتف',
    'en': 'Phone',
  },
  'doctor_appt_label_email': {
    'ckb': 'ئیمەیڵ',
    'ar': 'البريد الإلكتروني',
    'en': 'Email',
  },
  'doctor_appt_label_appointment_status': {
    'ckb': 'دۆخی چاوەڕوانکراو',
    'ar': 'حالة الموعد',
    'en': 'Appointment status',
  },
  'doctor_appt_gender_male': {
    'ckb': 'نێر',
    'ar': 'ذكر',
    'en': 'Male',
  },
  'doctor_appt_gender_female': {
    'ckb': 'مێ',
    'ar': 'أنثى',
    'en': 'Female',
  },
  'doctor_appt_patient_profile_title': {
    'ckb': 'زانیارییەکانی نەخۆش',
    'ar': 'ملف المريض',
    'en': 'Patient profile',
  },
  'doctor_appt_medical_history_section': {
    'ckb': 'مێژووی پزیشکی',
    'ar': 'التاريخ الطبي',
    'en': 'Medical history',
  },
  'doctor_appt_no_medical_history': {
    'ckb': 'هیچ تۆمارێک نییە',
    'ar': 'لا يوجد سجل',
    'en': 'No records on file',
  },
  'doctor_appt_not_available': {
    'ckb': '—',
    'ar': '—',
    'en': '—',
  },
  'doctor_appt_call_failed': {
    'ckb': 'نەتوانرا پەیوەندی پێوە بکرێت',
    'ar': 'تعذر إجراء المكالمة',
    'en': 'Could not start the call',
  },
  'doctor_appt_close': {
    'ckb': 'داخستن',
    'ar': 'إغلاق',
    'en': 'Close',
  },
  'schedule_screen_title': {
    'ckb': 'بەڕێوەبردنی کاتەکان',
    'ar': 'إدارة الجدول',
    'en': 'HR Nora Schedule',
  },
  /// Label above the live “today” date line on the doctor/secretary schedule calendar.
  'schedule_today_heading': {
    'ckb': 'ئەمڕۆ:',
    'ar': 'اليوم:',
    'en': 'Today:',
  },
  /// Starts the large “today” headline on the schedule screen (before weekday + date).
  'schedule_today_prominent_prefix': {
    'ckb': 'ئەمڕۆ،',
    'ar': 'اليوم،',
    'en': 'Today,',
  },
  /// Section title under the horizontal day strip (today’s bookings area).
  'schedule_today_appointments_title': {
    'ckb': 'نۆرەکانی ئەمڕۆ',
    'ar': 'مواعيد اليوم',
    'en': "Today's appointments",
  },
  'schedule_calendar_hint': {
    'ckb': 'ڕۆژێک هەڵبژێرە بۆ دەستکاری کات یان داخستنی تەواوی ڕۆژەکە.',
    'ar': 'اختر تاريخًا لتعديل ساعات العمل أو إغلاق اليوم بالكامل.',
    'en': 'Tap a date to set hours for that day or block it (e.g. holiday).',
  },
  'schedule_day_blocked': {
    'ckb': 'داخستنی ئەم ڕۆژە (نۆرە نییە)',
    'ar': 'إغلاق هذا اليوم بالكامل',
    'en': 'Block / close this day',
  },
  'schedule_custom_hours': {
    'ckb': 'کاتەکانی تایبەت بۆ ئەم ڕۆژە',
    'ar': 'ساعات مخصصة لهذا اليوم',
    'en': 'Custom hours for this date',
  },
  'schedule_use_weekday_default_hint': {
    'ckb': 'کات ناچالاک بکە بۆ بەکارهێنانی خشتەی هەفتانە.',
    'ar': 'عطّل لاستخدام جدول أيام الأسبوع الافتراضي.',
    'en': 'Turn off to use your default weekday pattern below.',
  },
  'schedule_day_appointment_duration': {
    'ckb': 'ماوەی نێوان نۆرەکان',
    'ar': 'مدة الموعد لهذا اليوم',
    'en': 'Appointment duration (this day)',
  },
  'schedule_day_appointment_duration_hint': {
    'ckb':
        'کاتەکانی بەردەست لەسەر ئەم ژمارەیە دابەش دەکرێن. ئەگەر هەمان ڕێکخستنی پرۆفایل بێت، تەنها پاشکەوتکردنی گشتی بەکاربهێنە.',
    'ar':
        'تُقسَّم الفترات حسب هذه القيمة. إذا طابقت إعداد الملف الشخصي، لا حاجة لتغييرها هنا.',
    'en':
        'Patient slots use this step for this date. If it matches your profile default, leave it or clear the day override when saving.',
  },
  'schedule_day_slot_minutes_option': {
    'ckb': '{minutes} خولەک',
    'ar': '{minutes} دقيقة',
    'en': '{minutes} min',
  },
  'schedule_apply_day': {
    'ckb': 'پاشکەوتکردنی ئەم ڕۆژە',
    'ar': 'تطبيق على هذا اليوم',
    'en': 'Apply for this day',
  },
  'schedule_weekday_defaults_title': {
    'ckb': 'خشتەی هەفتانە (بنەڕەت)',
    'ar': 'جدول أيام الأسبوع (الافتراضي)',
    'en': 'Default weekly pattern',
  },
  'schedule_weekday_slot_label': {
    'ckb': 'ماوەی نۆرە',
    'ar': 'مدة الموعد',
    'en': 'Appointment slot length',
  },
  'schedule_save_button': {
    'ckb': 'پاشکەوتکردن',
    'ar': 'حفظ',
    'en': 'Save',
  },
  'schedule_saving': {
    'ckb': 'ناردن بۆ Firebase…',
    'ar': 'جارٍ الإرسال…',
    'en': 'Saving to Firebase…',
  },
  'schedule_sheet_tab_settings': {
    'ckb': 'ڕێکخستنی کات',
    'ar': 'إعدادات الوقت',
    'en': 'Time settings',
  },
  'schedule_sheet_tab_patients': {
    'ckb': 'لیستى نەخۆشەکان',
    'ar': 'قائمة المرضى',
    'en': 'Patient list',
  },
  'schedule_sheet_no_appointments_day': {
    'ckb': 'هیچ نۆرەیەک بۆ ئەم ڕۆژە نییە',
    'ar': 'لا مواعيد لهذا اليوم',
    'en': 'No appointments for this day',
  },
  'schedule_slot_available': {
    'ckb': 'بەتاڵە',
    'ar': 'متاح',
    'en': 'Available',
  },
  'schedule_timeline_no_hours': {
    'ckb': 'ئەم ڕۆژە کاتژمێری کار نییە (داخراو یان پشوو)',
    'ar': 'لا ساعات عمل لهذا اليوم (مغلق أو عطلة)',
    'en': 'No working hours for this day (closed or off).',
  },
  'schedule_timeline_no_slots': {
    'ckb': 'هیچ کاتێک دروست ناکرێت (کاتی دەستپێکردن/کۆتایی نادروستە)',
    'ar': 'لا فترات زمنية (نافذة غير صالحة)',
    'en': 'No time slots could be generated for this window.',
  },
  'schedule_timeline_other_bookings': {
    'ckb': 'نۆرەکانی دیکە (کات ناناسراو)',
    'ar': 'مواعيد أخرى (وقت غير مطابق للفترات)',
    'en': 'Other bookings (time outside slot grid)',
  },
  'schedule_patient_details_title': {
    'ckb': 'زانیاری نەخۆش',
    'ar': 'تفاصيل المريض',
    'en': 'Patient details',
  },
  'schedule_timeline_more_same_slot': {
    'ckb': 'هێشتا +{count}',
    'ar': 'و +{count} آخر',
    'en': '+{count} more',
  },
  'schedule_save_ok': {
    'ckb': 'پاشەکەوتکردن بە سەرکەوتوویی تەواو بوو',
    'ar': 'تم الحفظ بنجاح',
    'en': 'Schedule saved',
  },
  'schedule_load_error': {
    'ckb': 'هەڵە لە هێنانی خشتەی کار',
    'ar': 'خطأ في تحميل الجدول',
    'en': 'Could not load schedule',
  },
  'schedule_save_error_generic': {
    'ckb': 'هەڵە لە پاشکەوتکردنی خشتە',
    'ar': 'خطأ في حفظ الجدول',
    'en': 'Could not save schedule',
  },
  'schedule_day_enabled': {
    'ckb': 'چالاک',
    'ar': 'مفعّل',
    'en': 'On',
  },
  'schedule_day_disabled': {
    'ckb': 'ناچالاک',
    'ar': 'غير مفعّل',
    'en': 'Off',
  },
  'schedule_time_start': {
    'ckb': 'دەستپێک',
    'ar': 'البداية',
    'en': 'Start',
  },
  'schedule_time_end': {
    'ckb': 'کۆتایی',
    'ar': 'النهاية',
    'en': 'End',
  },
  'doctor_patients_title': {
    'ckb': 'لیستی نەخۆشەکان',
    'ar': 'قائمة المرضى',
    'en': 'Patients',
  },
  'doctor_patients_search_hint': {
    'ckb': 'گەڕان بە ناوی نەخۆش...',
    'ar': 'ابحث باسم المريض...',
    'en': 'Search by patient name...',
  },
  'doctor_patients_empty': {
    'ckb': 'هیچ نەخۆشێک نەدۆزرایەوە',
    'ar': 'لم يتم العثور على مرضى',
    'en': 'No patients found',
  },
  'doctor_patients_last_visit': {
    'ckb': 'دوایین سەردان: {date}',
    'ar': 'آخر زيارة: {date}',
    'en': 'Last visit: {date}',
  },
  'doctor_patients_no_date': {
    'ckb': 'بەرواری نۆرە نییە',
    'ar': 'لا تاريخ للموعد',
    'en': 'No appointment date',
  },
  'doctor_patient_age_line': {
    'ckb': 'تەمەن: {age} ساڵ',
    'ar': 'العمر: {age}',
    'en': 'Age: {age}',
  },
  /// Word after numeric age in secretary appointment cards (e.g. "25 ساڵ").
  'doctor_appt_years_suffix': {
    'ckb': 'ساڵ',
    'ar': 'سنة',
    'en': 'yrs',
  },
  'doctor_patient_history_placeholder': {
    'ckb': 'بەزوویی: مێژووی نەخۆش',
    'ar': 'قريباً: سجل المريض',
    'en': 'Coming soon: patient history',
  },
  'doctor_patient_view_button': {
    'ckb': 'بینین',
    'ar': 'عرض',
    'en': 'View',
  },
  'doctor_profile_tile_edit': {
    'ckb': 'گۆڕینی زانیارییەکان',
    'ar': 'تعديل البيانات',
    'en': 'Edit profile',
  },
  'doctor_profile_tile_edit_sub': {
    'ckb': 'وێنە، ناو، ناونیشان، پسپۆڕی، ژمارە',
    'ar': 'صورة، الاسم، العنوان، التخصص، الجوال',
    'en': 'Photo, name, address, specialty, phone',
  },
  'doctor_profile_no_session': {
    'ckb': 'هیچ هەژمارێک نییە',
    'ar': 'لا يوجد حساب',
    'en': 'No account session',
  },
  'doctor_about_description': {
    'ckb':
        'ئەم ئەپڵیکەیشنە پلاتفۆرمێکی پێشکەوتووی تەندروستییە کە کار ئاسانی دەکات بۆ دۆزینەوەی باشترین پزیشکانی پسپۆڕ و وەرگرتنی نۆرە بە شێوازێکی خێرا و مۆدێرن. ئامانجی ئێمە دابینکردنی سیستەمێکی ڕێکخراوە بۆ بەڕێوەبردنی کاتەکانی نۆرەگرتن و دروستکردنی پەیوەندییەکی ئاسان لە نێوان پزیشک و نەخۆشدا، تاوەکو باشترین خزمەتگوزاری تەندروستی بگاتە هەمووان.',
    'ar':
        'هذا التطبيق منصة صحية متطورة تسهّل العثور على أفضل الأطباء الاختصاصيين وحجز المواعيد بسرعة وبطريقة عصرية. هدفنا توفير نظام منظم لإدارة أوقات الحجز وبناء رابطة سهلة بين الطبيب والمريض، حتى تصل أفضل خدمات الرعاية الصحية للجميع.',
    'en':
        'This app is an advanced health platform that makes it easy to find top specialist doctors and book appointments quickly and in a modern way. We provide an organized system for managing bookings and a smooth connection between doctor and patient, so quality healthcare can reach everyone.',
  },
  'auth_doctor_pending_title': {
    'ckb': 'هەژمارەکەت چاوەڕێی قبوڵکردنی بەڕێوەبەرە',
    'ar': 'حسابك بانتظار موافقة الإدارة',
    'en': 'Your account is waiting for admin approval',
  },
  'auth_doctor_pending_hint': {
    'ckb': 'دواتر دووبارە هەوڵ بدەرەوە',
    'ar': 'حاول مرة أخرى لاحقاً',
    'en': 'Please try again later',
  },
  'auth_back_to_login': {
    'ckb': 'گەڕانەوە بۆ چوونەژوورەوە',
    'ar': 'العودة لتسجيل الدخول',
    'en': 'Back to sign in',
  },
  'auth_unknown_role': {
    'ckb': 'ڕۆڵی هەژمارەکەت نەناسراوە',
    'ar': 'نوع الحساب غير معروف',
    'en': 'Unknown account role',
  },
  'auth_back': {
    'ckb': 'گەڕانەوە',
    'ar': 'رجوع',
    'en': 'Back',
  },
  'auth_snack_doctor_not_approved': {
    'ckb': 'هەژمارەکەت هێشتا لەلایەن بەڕێوەبەرەوە قبوڵ نەکراوە',
    'ar': 'لم تتم الموافقة على حسابك بعد',
    'en': 'Your account has not been approved yet',
  },
  'auth_snack_unknown_role': {
    'ckb': 'ڕۆڵی هەژمارەکەت نەناسراوە',
    'ar': 'نوع الحساب غير معروف',
    'en': 'Unknown account role',
  },
  'doctor_profile_settings_title': {
    'ckb': 'ڕێکخستنەکانی پڕۆفایل',
    'ar': 'إعدادات الملف',
    'en': 'Profile settings',
  },
  'image_source_gallery': {
    'ckb': 'گەلەری',
    'ar': 'المعرض',
    'en': 'Gallery',
  },
  'image_source_camera': {
    'ckb': 'کامێرا',
    'ar': 'الكاميرا',
    'en': 'Camera',
  },
  'booking_receipt_gallery_permission_denied': {
    'ckb':
        'مۆڵەتی گەلەری پێویستە بۆ بارکردنی وێنەی پسوڵە. تکایە لە ڕێکخستنەکاندا چالاکی بکە.',
    'ar': 'يلزم إذن معرض الصور لرفع إيصال الدفع. فعّله من الإعدادات.',
    'en': 'Photo library access is required to upload a receipt. Enable it in Settings.',
  },
  'booking_receipt_camera_permission_denied': {
    'ckb':
        'مۆڵەتی کامێرا پێویستە. تکایە لە ڕێکخستنەکاندا چالاکی بکە.',
    'ar': 'يلزم إذن الكاميرا. فعّله من الإعدادات.',
    'en': 'Camera access is required. Enable it in Settings.',
  },
  'booking_receipt_pick_failed': {
    'ckb': 'هەڵە لە هەڵبژاردنی وێنە: {detail}',
    'ar': 'تعذر اختيار الصورة: {detail}',
    'en': 'Could not pick image: {detail}',
  },
  'booking_receipt_attached': {
    'ckb': 'وێنەی پسوڵە هەڵبژێردرا',
    'ar': 'تم اختيار صورة الإيصال',
    'en': 'Receipt image selected',
  },
  'booking_receipt_need_before_confirm': {
    'ckb': 'دووبارەکردنەوە تەنها دوای بارکردنی وێنەی پسوڵە دەردەکەوێت.',
    'ar': 'يظهر زر التأكيد بعد رفع صورة الإيصال.',
    'en': 'Confirm appears after you upload a receipt photo.',
  },
  'booking_receipt_required_confirm': {
    'ckb': 'تکایە سەرەتا وێنەی پسوڵە بار بکە.',
    'ar': 'يرجى رفع صورة الإيصال أولاً.',
    'en': 'Please upload a receipt image first.',
  },
  'booking_receipt_upload_failed': {
    'ckb': 'بارکردنی وێنەی پسوڵە سەرکەوتوو نەبوو: {detail}',
    'ar': 'فشل رفع صورة الإيصال: {detail}',
    'en': 'Could not upload receipt image: {detail}',
  },
  'booking_receipt_upload_retry': {
    'ckb':
        'کێشە لە بارکردنی وێنەکە هەیە، تکایە دووبارە هەوڵ بدەرەوە',
    'ar': 'تعذر رفع الصورة. يرجى المحاولة مرة أخرى.',
    'en': 'There was a problem uploading the image. Please try again.',
  },
  'booking_receipt_upload_issue': {
    'ckb': 'کێشە لە بارکردنی وێنە هەیە',
    'ar': 'تعذر رفع الصورة',
    'en': 'Could not upload the image',
  },
  'booking_doctor_missing': {
    'ckb': 'زانیاری دکتۆر بەردەست نییە. پەڕەکە نوێ بکەرەوە و دووبارە هەوڵ بدەرەوە.',
    'ar': 'بيانات الطبيب غير متوفرة. حدّث الصفحة وحاول مرة أخرى.',
    'en': 'Doctor information is missing. Refresh and try again.',
  },
  'profile_save_changes': {
    'ckb': 'پاشکەوتکردنی گۆڕانکارییەکان',
    'ar': 'حفظ التغييرات',
    'en': 'Save changes',
  },
  'profile_saved_ok': {
    'ckb': 'گۆڕانکارییەکان بە سەرکەوتوویی پاشەکەوتکران',
    'ar': 'تم حفظ التغييرات',
    'en': 'Changes saved',
  },
  'profile_load_error': {
    'ckb': 'هەڵە لە هێنانی زانیارییەکان',
    'ar': 'خطأ في تحميل البيانات',
    'en': 'Could not load profile',
  },
  'profile_user_missing': {
    'ckb': 'بەکارهێنەر نەدۆزرایەوە',
    'ar': 'المستخدم غير موجود',
    'en': 'User not found',
  },
  /// Doctor phone login has no Firebase Auth user; need cached Firestore doc id.
  'profile_error_resolve_no_firebase_or_cache': {
    'ckb':
        'هیچ چوونەژوورەوەی Firebase نییە و ناسنامەی پڕۆفایل لە یادکردنەوە نییە. تکایە دووبارە بچۆ ژوورەوە.',
    'ar': 'لا يوجد جلسة Firebase ولا مُعرّف ملف محفوظ. يرجى تسجيل الدخول مرة أخرى.',
    'en':
        'No Firebase sign-in and no saved profile id. Please log in again.',
  },
  'profile_error_resolve_empty_doc_id': {
    'ckb':
        'نەتوانرا ناسنامەی پڕۆفایل دیاری بکرێت (UID بەتاڵە). تکایە دووبارە بچۆ ژوورەوە.',
    'ar': 'تعذر تحديد معرف الملف (المعرّف فارغ). يرجى تسجيل الدخول مرة أخرى.',
    'en': 'Could not resolve profile id (empty UID). Please sign in again.',
  },
  'profile_error_auth_refresh': {
    'ckb':
        'کاتی چوونەژوورەوە تەواو بووە یان هەژمار نوێ نەکراوەتەوە ({code}). تکایە دووبارە بچۆ ژوورەوە.',
    'ar': 'انتهت الجلسة أو فشل التحديث ({code}). يرجى تسجيل الدخول مرة أخرى.',
    'en': 'Session expired or account refresh failed ({code}). Please sign in again.',
  },
  'profile_image_upload_ok': {
    'ckb': 'وێنەی پڕۆفایل بە سەرکەوتوویی بارکرا',
    'ar': 'تم رفع صورة الملف',
    'en': 'Profile photo uploaded',
  },
  'profile_image_upload_error': {
    'ckb': 'هەڵە لە بارکردنی وێنە',
    'ar': 'خطأ في رفع الصورة',
    'en': 'Image upload failed',
  },
  'booking_select_datetime': {
    'ckb': 'تکایە ڕۆژ و کات هەڵبژێرە',
    'ar': 'اختر التاريخ والوقت',
    'en': 'Please select date and time',
  },
  'booking_success_title': {
    'ckb': 'سەرکەوتوو',
    'ar': 'تم بنجاح',
    'en': 'Success',
  },
  'booking_success_body': {
    'ckb': 'نۆرەکەت بە سەرکەوتوویی تۆمارکرا',
    'ar': 'تم حجز موعدك بنجاح',
    'en': 'Your appointment was booked',
  },
  'booking_active_warning_title': {
    'ckb': 'ئاگاداری',
    'ar': 'تنبيه',
    'en': 'Warning',
  },
  'booking_active_warning_body': {
    'ckb':
        'ببورە، تۆ نۆرەیەکی چالاکت هەیە. ناتوانی نۆرەی تر بگریت تا نۆرەکەی پێشووت تەواو دەبێت.',
    'ar':
        'عذراً، لديك موعد نشط. لا يمكنك حجز موعد آخر حتى يكتمل موعدك السابق.',
    'en':
        'Sorry, you already have an active appointment. You cannot book another one until the previous one is completed.',
  },
  'booking_active_warning_ok': {
    'ckb': 'تێگەیشتم',
    'ar': 'فهمت',
    'en': 'I Understand',
  },
  'ok': {
    'ckb': 'باشە',
    'ar': 'حسناً',
    'en': 'OK',
  },
  'booking_title': {
    'ckb': 'نۆرەگرتن',
    'ar': 'حجز موعد',
    'en': 'Book appointment',
  },
  'booking_date_closed': {
    'ckb': 'ببورە، دکتۆر لەم ڕێکەوتەدا دەوام ناکات',
    'ar': 'عذراً، الطبيب لا يعمل في هذا الموعد.',
    'en': 'Sorry, the doctor is not working on this date.',
  },
  /// Doctor explicitly set `isOpen: false` on this calendar day (server-verified tap).
  'booking_doctor_closed_day': {
    'ckb': 'ببۆره دکتۆر لەم ڕێکەوتە دەوام ناکات',
    'ar': 'عذراً، الطبيب لا يعمل في هذا الموعد.',
    'en': 'Sorry, the doctor is not available at this time.',
  },
  'booking_date_fully_booked': {
    'ckb': 'ئەم ڕۆژە هەموو کاتەکان گیراون. ڕۆژێکی تر هەڵبژێرە.',
    'ar': 'هذا اليوم ممتلئ. اختر يوماً آخر.',
    'en': 'This day is fully booked. Please pick another date.',
  },
  'booking_calendar_legend_patient': {
    'ckb': 'سەوز = ڕۆژی کار · نارەنجی = هەموو کاتەکان گیراون · سوور = پشوو/داخراو',
    'ar': 'أخضر = يوم عمل · برتقالي = ممتلئ · أحمر = عطلة/مغلق',
    'en': 'Green = working day · Orange = fully booked · Red = off / closed',
  },
  'booking_pick_day_hint': {
    'ckb': 'بۆ بینینی کاتەکان، ڕۆژێکی سەوز داوە بکە.',
    'ar': 'اضغط على يوم أخضر لاختيار الوقت.',
    'en': 'Tap a green day to choose a time.',
  },
  'working_days_title': {
    'ckb': 'ڕۆژەکانی کار (تەنها ئەوانەی پزیشک چالاکی کردووە)',
    'ar': 'أيام العمل (المفعّلة من الطبيب فقط)',
    'en': 'Working days (enabled by doctor)',
  },
  'no_schedule_yet': {
    'ckb':
        'ببوورە، ئەم پزیشکە هێشتا خشتەی کاری بۆ ئەم مانگە دیاری نەکردووە.',
    'ar':
        'عذراً، لم يحدد هذا الطبيب أوقات عمل لهذا الشهر بعد.',
    'en':
        'Sorry — this doctor has not set working hours for this month yet.',
  },
  'label_date': {
    'ckb': 'بەروار',
    'ar': 'التاريخ',
    'en': 'Date',
  },
  'no_dates_available': {
    'ckb': 'بەروارێکی بەردەست نییە',
    'ar': 'لا توجد تواريخ متاحة',
    'en': 'No dates available',
  },
  'label_times': {
    'ckb': 'کاتەکان',
    'ar': 'الأوقات',
    'en': 'Times',
  },
  'time_window': {
    'ckb': 'ناوچە: {start} — {end}',
    'ar': 'الفترة: {start} — {end}',
    'en': 'Window: {start} — {end}',
  },
  'no_times_set': {
    'ckb': 'کاتێک دیاری نەکراوە',
    'ar': 'لم يُحدد وقت',
    'en': 'No time set',
  },
  'booking_slot_legend': {
    'ckb': 'سەوز = بەردەست · خۆڵەمێشی = گیراوە (ناتوانیت هەڵیبژێریت)',
    'ar': 'أخضر = متاح · رمادي = محجوز',
    'en': 'Green = available · Gray = booked (disabled)',
  },
  'booking_sequential_queue_hint': {
    'ckb': 'تەنها یەکەم کاتی بەتاڵ (تەسەلسول) دەتوانیت هەڵیبژێریت.',
    'ar': 'يمكنك اختيار أول موعد فارغ فقط (بالتسلسل).',
    'en': 'Only the first free slot can be booked (sequential queue).',
  },
  'booking_slot_legend_sequential': {
    'ckb': 'سەوز (گلۆپ) = نۆرەی تۆ · تۆخم = کاتەکانی دیکە بەتاڵ (چاوەڕوان) · خۆڵەمێش = گیراوە',
    'ar': 'أخضر (وميض) = دورك · باهت = أوقات لاحقة فارغة (انتظر) · رمادي = محجوز',
    'en': 'Pulsing green = your turn · Dim = later free slots (wait) · Gray = booked',
  },
  'booking_sequential_future_slot_hint': {
    'ckb': 'ئەم کاتە بەتاڵە؛ تەنها یەکەم کاتی بەتاڵ هەڵبژێرە.',
    'ar': 'هذا الوقت فارغ لاحقاً؛ اختر أول فراغ في الجدول.',
    'en': 'This slot is free later; book the first free slot in order.',
  },
  'booking_sequential_must_pick_first': {
    'ckb': 'تەنها یەکەم کاتی بەتاڵ دەتوانیت بگریت (تەسەلسول).',
    'ar': 'يجب اختيار أول موعد فارغ فقط (تسلسل).',
    'en': 'You can only book the first available slot (sequential queue).',
  },
  'booking_slot_just_taken': {
    'ckb': 'ئەم کاتە ئێستا کەسێک وەرگرت. تکایە کاتێکی تر هەڵبژێرە.',
    'ar': 'تم حجز هذا الوقت للتو. اختر وقتاً آخر.',
    'en': 'This time was just booked. Please choose another slot.',
  },
  'booking_slot_booked_hint': {
    'ckb': 'ئەم کاتە گیراوە',
    'ar': 'هذا الوقت محجوز',
    'en': 'This slot is taken',
  },
  'booking_slot_conflict': {
    'ckb': 'ئەم کاتە لە پێشدا گیراوە. کاتێکی تر هەڵبژێرە.',
    'ar': 'هذا الوقت محجوز مسبقاً. اختر وقتاً آخر.',
    'en': 'This slot is no longer available. Please pick another time.',
  },
  'booking_slot_invalid': {
    'ckb':
        'ئەم کاتە لەگەڵ ماوەی نۆرەکانی دکتۆر ناکۆکە. تکایە دووبارە هەڵبژێرە یان پەڕەکە نوێ بکەرەوە.',
    'ar':
        'هذا الوقت لا يطابق فترات المواعيد الحالية للطبيب. أعد الاختيار أو حدّث الصفحة.',
    'en':
        'This time does not match the doctor’s current slot length. Refresh the page or pick another slot.',
  },
  'confirm_booking': {
    'ckb': 'دووپاتکردنەوەی نۆرە',
    'ar': 'تأكيد الحجز',
    'en': 'Confirm booking',
  },
  'booking_details_title': {
    'ckb': 'زانیارییەکانی نۆرە',
    'ar': 'تفاصيل الحجز',
    'en': 'Booking details',
  },
  'booking_form_full_name': {
    'ckb': 'ناوی سیانی',
    'ar': 'الاسم الكامل',
    'en': 'Full name',
  },
  'booking_form_full_name_hint': {
    'ckb': 'ناوی سیانیت لێرە بنووسە...',
    'ar': 'اكتب اسمك الكامل هنا...',
    'en': 'Type your full name here…',
  },
  'booking_form_age': {
    'ckb': 'تەمەن',
    'ar': 'العمر',
    'en': 'Age',
  },
  'booking_form_blood': {
    'ckb': 'گروپی خوێن',
    'ar': 'فصيلة الدم',
    'en': 'Blood group',
  },
  'booking_form_blood_hint': {
    'ckb': 'هەڵبژاردن',
    'ar': 'اختر',
    'en': 'Select',
  },
  'booking_form_phone': {
    'ckb': 'ژمارە مۆبایل',
    'ar': 'رقم الهاتف',
    'en': 'Phone number',
  },
  'booking_form_gender': {
    'ckb': 'ڕەگەز',
    'ar': 'الجنس',
    'en': 'Gender',
  },
  'booking_form_gender_male': {
    'ckb': 'نێر',
    'ar': 'ذكر',
    'en': 'Male',
  },
  'booking_form_gender_female': {
    'ckb': 'مێ',
    'ar': 'أنثى',
    'en': 'Female',
  },
  'booking_form_medical_notes': {
    'ckb': 'تێبینی پزیشکی',
    'ar': 'ملاحظات طبية',
    'en': 'Medical notes',
  },
  'booking_form_medical_hint': {
    'ckb': 'هەستیاری، نەخۆشی درێژخایەن...',
    'ar': 'الحساسية، الأمراض المزمنة...',
    'en': 'Allergies, chronic conditions…',
  },
  'booking_form_city': {
    'ckb': 'ناونیشان (شار/ناوچە)',
    'ar': 'العنوان (المدينة)',
    'en': 'City / area',
  },
  'booking_form_city_hint': {
    'ckb': 'هەڵبژاردن (ئارەزوومەندانە)',
    'ar': 'اختياري',
    'en': 'Optional',
  },
  'booking_form_submit': {
    'ckb': 'ناردنی زانیاری و گرتنی نۆرە',
    'ar': 'إرسال البيانات وتأكيد الموعد',
    'en': 'Submit details & confirm booking',
  },
  'booking_form_name_required': {
    'ckb': 'تکایە ناوی سیانی پڕ بکەرەوە.',
    'ar': 'يرجى إدخال الاسم الكامل.',
    'en': 'Please enter your full name.',
  },
  'booking_form_phone_required': {
    'ckb': 'تکایە ژمارەی مۆبایل پڕ بکەرەوە.',
    'ar': 'يرجى إدخال رقم الهاتف.',
    'en': 'Please enter your phone number.',
  },
  'booking_form_age_required': {
    'ckb': 'تکایە تەمەنێکی دروست بنووسە.',
    'ar': 'يرجى إدخال عمر صالح.',
    'en': 'Please enter a valid age.',
  },
  'booking_form_blood_required': {
    'ckb': 'تکایە گروپی خوێن هەڵبژێرە.',
    'ar': 'يرجى اختيار فصيلة الدم.',
    'en': 'Please select a blood group.',
  },
  'booking_detail_not_recorded': {
    'ckb': 'تۆمار نەکراوە',
    'ar': 'غير مسجل',
    'en': 'Not recorded',
  },
  'doctor_appt_label_blood': {
    'ckb': 'گروپی خوێن',
    'ar': 'فصيلة الدم',
    'en': 'Blood group',
  },
  'doctor_appt_label_resident_place': {
    'ckb': 'شوێنی نیشتەجێبوون',
    'ar': 'مكان الإقامة',
    'en': 'Resident place',
  },
  'doctor_appt_no_booking_notes': {
    'ckb': 'هیچ تێبینییەک نییە',
    'ar': 'لا توجد ملاحظات طبية',
    'en': 'No medical notes',
  },
  'action_cancel': {
    'ckb': 'پاشگەزبوونەوە',
    'ar': 'إلغاء',
    'en': 'Cancel',
  },
  'action_save': {
    'ckb': 'پاشکەوتکردن',
    'ar': 'حفظ',
    'en': 'Save',
  },
  'action_delete': {
    'ckb': 'سڕینەوە',
    'ar': 'حذف',
    'en': 'Delete',
  },
  'available_days_add_title': {
    'ckb': 'ڕۆژی بەردەست زیاد بکە',
    'ar': 'إضافة يوم متاح',
    'en': 'Add available day',
  },
  'available_days_max_label': {
    'ckb': 'زۆرترین ژمارەی نۆرە',
    'ar': 'أقصى عدد للمواعيد',
    'en': 'Max appointments',
  },
  'available_days_opening_time_label': {
    'ckb': 'کاتی کردنەوەی کلینیک',
    'ar': 'وقت فتح العيادة',
    'en': 'Clinic opening time',
  },
  'available_days_closing_time_label': {
    'ckb': 'کاتی داخستنی کلینیک',
    'ar': 'وقت إغلاق العيادة',
    'en': 'Clinic closing time',
  },
  'day_mgmt_tab_settings': {
    'ckb': 'ڕێخستنی کاتەکان',
    'ar': 'إعدادات الوقت',
    'en': 'Time settings',
  },
  'day_mgmt_tab_patients': {
    'ckb': 'لیستی نەخۆشەکان',
    'ar': 'قائمة المرضى',
    'en': 'Patient list',
  },
  'day_mgmt_update_settings': {
    'ckb': 'نوێکردنەوەی ڕێکخستن',
    'ar': 'تحديث الإعدادات',
    'en': 'Update settings',
  },
  'day_mgmt_update_saved': {
    'ckb': 'ڕێکخستنەکان پاشکەوتکران',
    'ar': 'تم حفظ الإعدادات',
    'en': 'Settings saved',
  },
  'day_mgmt_no_slots': {
    'ckb': 'هیچ نۆرەیەک لە نێوان ئەم کاتانەدا دانەمەزراندووە.',
    'ar': 'لا توجد فترات زمنية ضمن هذه الإعدادات.',
    'en': 'No slots fit between these times and duration.',
  },
  'available_days_duration_label': {
    'ckb': 'ماوەی هەر نۆرەیەک',
    'ar': 'مدة كل موعد',
    'en': 'Appointment duration',
  },
  'duration_minutes_option': {
    'ckb': '{n} خولەک',
    'ar': '{n} دقيقة',
    'en': '{n} min',
  },
  'available_days_list_schedule': {
    'ckb': 'دەستپێک {time} · {minutes} خولەک',
    'ar': 'يبدأ {time} · {minutes} د',
    'en': 'Starts {time} · {minutes} min slots',
  },
  'schedule_management_title': {
    'ckb': 'بەڕێوەبردنی خشتەی کات',
    'ar': 'إدارة الجدول',
    'en': 'Schedule management',
  },
  'schedule_manage_past_disabled': {
    'ckb': 'ناتوانیت ڕۆژی ڕابردوو دەستکاری بکەیت.',
    'ar': 'لا يمكن تعديل الأيام الماضية.',
    'en': 'Past days cannot be edited.',
  },
  'schedule_sheet_open_toggle': {
    'ckb': 'ڕۆژەکە بکەرەوە بۆ نۆرە',
    'ar': 'فتح اليوم للحجز',
    'en': 'Open day for booking',
  },
  'schedule_toggle_status': {
    'ckb': 'گۆڕینی دۆخ',
    'ar': 'تبديل الحالة',
    'en': 'Toggle status',
  },
  'schedule_edit_times': {
    'ckb': 'دەستکاری کاتەکان',
    'ar': 'تعديل الأوقات',
    'en': 'Edit times',
  },
  'schedule_time_row_tap_hint': {
    'ckb': 'دەست لێدە بۆ گۆڕینی کات',
    'ar': 'اضغط لتغيير الوقت',
    'en': 'Tap to change time',
  },
  'schedule_panel_tap_hint': {
    'ckb': 'دەست لێدە بۆ دەستکاری',
    'ar': 'اضغط للتعديل',
    'en': 'Tap to edit schedule',
  },
  'schedule_select_day_first': {
    'ckb': 'ڕۆژێک لە کاڵێندەر هەڵبژێرە.',
    'ar': 'اختر يوماً من التقويم.',
    'en': 'Select a day on the calendar.',
  },
  'schedule_today_shifts_title': {
    'ckb': 'نۆرەکانی ئەمڕۆ',
    'ar': 'نوبات اليوم',
    'en': "Today's shifts",
  },
  'schedule_future_day_sheet_title': {
    'ckb': 'وردەکاری ڕۆژ',
    'ar': 'تفاصيل اليوم',
    'en': 'Day overview',
  },
  'schedule_detail_total_patients': {
    'ckb': 'کۆی نەخۆش',
    'ar': 'إجمالي المرضى',
    'en': 'Total patients',
  },
  'schedule_detail_working_hours': {
    'ckb': 'کاتژمێری کار',
    'ar': 'ساعات العمل',
    'en': 'Working hours',
  },
  'schedule_detail_patient_list': {
    'ckb': 'لیستی نەخۆشەکان',
    'ar': 'قائمة المرضى',
    'en': 'Patient list',
  },
  'schedule_detail_no_appointments': {
    'ckb': 'هیچ نۆرەیەک نییە.',
    'ar': 'لا توجد مواعيد.',
    'en': 'No appointments.',
  },
  'schedule_detail_patients_count': {
    'ckb': '{n} نەخۆش',
    'ar': '{n} مريض',
    'en': '{n} patients',
  },
  'schedule_detail_day_closed': {
    'ckb': 'داخراو',
    'ar': 'مغلق',
    'en': 'Closed',
  },
  'schedule_dashboard_section_control': {
    'ckb': 'کۆنتڕۆڵ',
    'ar': 'التحكم',
    'en': 'Control',
  },
  'schedule_dashboard_working_hours': {
    'ckb': 'کاتژمێری کار',
    'ar': 'ساعات العمل',
    'en': 'Working hours',
  },
  'schedule_slot_booked': {
    'ckb': 'گیراوە',
    'ar': 'محجوز',
    'en': 'Booked',
  },
  'schedule_slot_cancel_confirm_title': {
    'ckb': 'ئایا دڵنیای لە هەڵوەشاندنەوەی ئەم نۆرەیە؟',
    'ar': 'هل أنت متأكد من إلغاء هذا الموعد؟',
    'en': 'Are you sure you want to cancel this booking?',
  },
  'schedule_slot_cancel_yes': {
    'ckb': 'بەڵێ',
    'ar': 'نعم',
    'en': 'Yes',
  },
  'schedule_slot_cancel_no': {
    'ckb': 'نەخێر',
    'ar': 'لا',
    'en': 'No',
  },
  'schedule_slot_cancel_ok_snack': {
    'ckb': 'نۆرەکە هەڵوەشایەوە و نەخۆش ئاگادار دەکرێتەوە.',
    'ar': 'تم إلغاء الموعد وسيُبلَغ المريض.',
    'en': 'Booking cancelled; the patient will be notified.',
  },
  'schedule_slot_cancel_error_snack': {
    'ckb': 'نەتوانرا نۆرەکە هەڵبوەشێنرێتەوە.',
    'ar': 'تعذر إلغاء الموعد.',
    'en': 'Could not cancel this booking.',
  },
  'schedule_appointment_detail_time': {
    'ckb': 'کات',
    'ar': 'الوقت',
    'en': 'Time',
  },
  'schedule_appointment_detail_date': {
    'ckb': 'بەروار',
    'ar': 'التاريخ',
    'en': 'Date',
  },
  'schedule_appointment_detail_no_notes': {
    'ckb': 'تێبینی نییە',
    'ar': 'لا توجد ملاحظات',
    'en': 'No notes',
  },
  'schedule_slot_available_sheet_hint': {
    'ckb': 'ئەم کاتە بەردەستە بۆ نۆرەی نوێ.',
    'ar': 'هذا الوقت متاح لموعد جديد.',
    'en': 'This slot is open for booking.',
  },
  'schedule_booking_staff_only': {
    'ckb': 'تەنها نەخۆشەکان دەتوانن لەم شوێنەوە نۆرە بگرن؛ کارمەندەکان نەخۆش بە دەست زیاد ناکەن.',
    'ar': 'يمكن للمرضى فقط حجز الموعد من هنا؛ لا يضيف الموظفون المرضى يدوياً.',
    'en': 'Only patients can book from here; staff no longer add patients manually.',
  },
  'schedule_booking_past_slot': {
    'ckb': 'ناتوانیت بۆ کاتی ڕابردوو نۆرە بگریت.',
    'ar': 'لا يمكن حجز موعد في وقت مضى.',
    'en': 'You cannot book a time that has already passed.',
  },
  'schedule_dashboard_save_hint': {
    'ckb': 'پاشکەوتکردن لە تابی ڕێکخستن',
    'ar': 'احفظ من تبويب الإعدادات',
    'en': 'Save changes from the Settings tab.',
  },
  'schedule_today_focus_tab_time': {
    'ckb': 'ڕێکخستنی کات',
    'ar': 'إعداد الوقت',
    'en': 'Time settings',
  },
  'schedule_today_focus_tab_list': {
    'ckb': 'لیستی نۆرەکان',
    'ar': 'قائمة المواعيد',
    'en': 'Patient list',
  },
  'schedule_slot_available_ku': {
    'ckb': 'بەردەستە',
    'ar': 'متاح',
    'en': 'Available',
  },
  'schedule_slot_passed_ku': {
    'ckb': 'ئەم کاتە بەسەرچووە',
    'ar': 'انتهى وقت هذا الموعد',
    'en': 'This time has passed',
  },
  'schedule_slot_closed_ku': {
    'ckb': 'داخراوە',
    'ar': 'مغلق',
    'en': 'Closed',
  },
  'schedule_slot_close_confirm_title': {
    'ckb': 'ئایا دڵنیای لە داخستنی ئەم نۆرەیە؟',
    'ar': 'هل أنت متأكد من إغلاق هذا الموعد؟',
    'en': 'Are you sure you want to close this slot?',
  },
  'schedule_appointment_duration_ku': {
    'ckb': 'ماوەی نۆرە',
    'ar': 'مدة الموعد',
    'en': 'Slot length',
  },
  'schedule_clinic_status_title': {
    'ckb': 'بارودۆخی کلینیک',
    'ar': 'حالة العيادة',
    'en': 'Clinic status',
  },
  'schedule_control_start_time_label': {
    'ckb': 'کاتی دەستپێک',
    'ar': 'وقت البدء',
    'en': 'Start time',
  },
  'schedule_control_end_time_label': {
    'ckb': 'کاتی کۆتایی',
    'ar': 'وقت الانتهاء',
    'en': 'End time',
  },
  'schedule_duration_per_appointment_label': {
    'ckb': 'ماوەی هەر نۆرەیەک',
    'ar': 'مدة كل موعد',
    'en': 'Duration per patient',
  },
  'schedule_duration_minutes_field_title': {
    'ckb': 'ماوەی هەر نۆرەیەک (بە خولەک)',
    'ar': 'مدة كل موعد (بالدقائق)',
    'en': 'Duration per patient (minutes)',
  },
  'schedule_duration_custom_chip': {
    'ckb': 'ئارەزوومەندانە',
    'ar': 'مخصص',
    'en': 'Custom',
  },
  'schedule_minutes_suffix': {
    'ckb': 'خولەک',
    'ar': 'دقيقة',
    'en': 'min',
  },
  'schedule_custom_duration_invalid': {
    'ckb': 'ماوەی بەدڵی خۆت دروست نییە. تکایە ژمارەیەکی دروست بنووسە.',
    'ar': 'المدة المخصصة غير صحيحة. الرجاء إدخال رقم صحيح.',
    'en': 'Custom duration is invalid. Please enter a valid number.',
  },
  'schedule_custom_duration_field_label': {
    'ckb': 'خولەکەکان بنووسە',
    'ar': 'اكتب الدقائق',
    'en': 'Enter minutes',
  },
  'schedule_custom_duration_required': {
    'ckb': 'تکایە ماوەی نۆرە دیاری بکە',
    'ar': 'يرجى تحديد مدة الموعد',
    'en': 'Please set the appointment duration.',
  },
  'secretary_nav_calendar': {
    'ckb': 'کاڵێندەر',
    'ar': 'التقويم',
    'en': 'Calendar',
  },
  'secretary_nav_available_days': {
    'ckb': 'ڕۆژە بەردەستەکان',
    'ar': 'الأيام المتاحة',
    'en': 'Available days',
  },
  'secretary_nav_bookings': {
    'ckb': 'نۆرەکان',
    'ar': 'المواعيد',
    'en': 'Bookings',
  },
  'secretary_nav_schedule': {
    'ckb': 'خشتەی کات',
    'ar': 'الجدول',
    'en': 'Schedule',
  },
  'secretary_nav_clinic': {
    'ckb': 'کلینیک',
    'ar': 'العيادة',
    'en': 'Clinic',
  },
  'secretary_clinic_settings_title': {
    'ckb': 'ڕێکخستنی کلینیک',
    'ar': 'إعدادات العيادة',
    'en': 'Clinic settings',
  },
  'secretary_clinic_settings_card_hint': {
    'ckb':
        'ناوی نەخۆشخانە لە کارتەکانی پزیشک لە لایەن نەخۆشەکاندا دەردەکەوێت.',
    'ar': 'يظهر اسم المستشفى في بطاقات الطبيب لدى المرضى.',
    'en': 'This name appears on doctor cards for patients.',
  },
  'secretary_bookings_title': {
    'ckb': 'بەڕێوەبردنی نۆرەکان',
    'ar': 'إدارة المواعيد',
    'en': 'Appointment management',
  },
  'secretary_bookings_empty': {
    'ckb': 'هیچ نۆرەیەک نییە',
    'ar': 'لا توجد مواعيد',
    'en': 'No appointments',
  },
  'secretary_payment_cash': {
    'ckb': 'کاش',
    'ar': 'نقدي',
    'en': 'Cash',
  },
  'secretary_payment_route_label': {
    'ckb': 'ڕێگای پارەدان: {method}',
    'ar': 'طريقة الدفع: {method}',
    'en': 'Payment method: {method}',
  },
  'secretary_payment_digital': {
    'ckb': 'پارەدانی ئۆنلاین',
    'ar': 'دفع إلكتروني',
    'en': 'Online payment',
  },
  'secretary_view_receipt': {
    'ckb': 'بینینی پسوڵە',
    'ar': 'عرض الإيصال',
    'en': 'View receipt',
  },
  'secretary_action_confirm': {
    'ckb': 'دڵنیاکردنەوە',
    'ar': 'تأكيد',
    'en': 'Confirm',
  },
  'secretary_action_arrived': {
    'ckb': 'هات',
    'ar': 'وصل',
    'en': 'Arrived',
  },
  'secretary_action_completed': {
    'ckb': 'تەواو',
    'ar': 'مكتمل',
    'en': 'Completed',
  },
  'secretary_action_cancel': {
    'ckb': 'پاشگەزبوونەوە',
    'ar': 'إلغاء',
    'en': 'Cancel',
  },
  'secretary_receipt_view_tooltip': {
    'ckb': 'بینینی وێنەی پسوڵە',
    'ar': 'عرض إيصال الدفع',
    'en': 'View payment receipt',
  },
  'secretary_payment_fib': {
    'ckb': 'FIB',
    'ar': 'FIB',
    'en': 'FIB',
  },
  'secretary_payment_fastpay': {
    'ckb': 'فاستپەی',
    'ar': 'FastPay',
    'en': 'FastPay',
  },
  'secretary_payment_fib_fastpay': {
    'ckb': 'FIB / فاستپەی',
    'ar': 'FIB / FastPay',
    'en': 'FIB / FastPay',
  },
  'secretary_verify_payment': {
    'ckb': 'دڵنیاکردنەوەی پارەدان',
    'ar': 'تأكيد استلام الدفع',
    'en': 'Verify payment',
  },
  'secretary_payment_verified_ok': {
    'ckb': 'پارەدان دڵنیاکرایەوە',
    'ar': 'تم تأكيد الدفع',
    'en': 'Payment verified',
  },
  'secretary_receipt_need_image': {
    'ckb': 'هیچ وێنەی پسوڵە نییە',
    'ar': 'لا توجد صورة إيصال',
    'en': 'No receipt image',
  },
  'secretary_ticket_number': {
    'ckb': 'ژمارەی پسوولە',
    'ar': 'رقم الدور',
    'en': 'Ticket #',
  },
  'status_confirmed': {
    'ckb': 'دڵنیاکراوە',
    'ar': 'مؤكد',
    'en': 'Confirmed',
  },
  'status_arrived': {
    'ckb': 'لە کلینیک',
    'ar': 'في العيادة',
    'en': 'Arrived',
  },
  'secretary_available_days_title': {
    'ckb': 'ڕۆژە بەردەستەکان',
    'ar': 'الأيام المتاحة',
    'en': 'Available days',
  },
  'available_days_open_day_title': {
    'ckb': 'کردنەوەی ڕۆژ',
    'ar': 'فتح اليوم',
    'en': 'Open day',
  },
  'available_days_open_day_save': {
    'ckb': 'کردنەوە',
    'ar': 'فتح',
    'en': 'Open',
  },
  'available_days_calendar_legend': {
    'ckb':
        'سووری تۆخ = داخراو · سەوزی پزیشکی قووڵ = کراوە · ژمارە = ژمارەی نۆرە تۆمارکراوەکان',
    'ar': 'أحمر غامق = مغلق · أزرق أردوازي داكن = مفتوح · الرقم = عدد الحجوزات',
    'en':
        'Deep red = closed · Slate blue = open · Number = bookings count',
  },
  'available_day_manage_tab_time': {
    'ckb': 'کات',
    'ar': 'الوقت',
    'en': 'Time',
  },
  'available_day_manage_tab_patients': {
    'ckb': 'نەخۆشەکان',
    'ar': 'المرضى',
    'en': 'Patients',
  },
  'available_day_settings_saved': {
    'ckb': 'پاشکەوتکرا',
    'ar': 'تم الحفظ',
    'en': 'Saved',
  },
  'available_days_close_confirm_title': {
    'ckb': 'داخستنی ڕۆژ',
    'ar': 'إغلاق اليوم',
    'en': 'Close day',
  },
  'available_days_close_confirm_body': {
    'ckb': 'دڵنیایت؟ نەخۆشەکان ناتوانن نۆرە نوێ تۆمار بکەن.',
    'ar': 'هل أنت متأكد؟ لن يتمكن المرضى من حجز مواعيد جديدة.',
    'en': 'Patients will not be able to book new slots for this day.',
  },
  'available_days_close_day_action': {
    'ckb': 'داخستنی ڕۆژ',
    'ar': 'إغلاق اليوم',
    'en': 'Close day',
  },
  'available_day_manage_patient_count': {
    'ckb': 'کۆی گشتی: {n}',
    'ar': 'الإجمالي: {n}',
    'en': 'Total: {n}',
  },
  'available_day_manage_no_patients': {
    'ckb': 'هێشتا هیچ نەخۆشێک تۆمار نەکراوە.',
    'ar': 'لا يوجد مرضى بعد.',
    'en': 'No bookings yet.',
  },
  'available_day_closed': {
    'ckb': 'ئەم ڕۆژە کراوە نییە.',
    'ar': 'هذا اليوم غير مفتوح للحجز.',
    'en': 'This day is not open for booking.',
  },
  'available_day_closed_banner': {
    'ckb': 'ئەم ڕۆژە لەلایەن کلینیکەوە داخراوەتەوە. ناتوانیت نۆرە تۆمار بکەیت.',
    'ar': 'أُغلق هذا اليوم. لا يمكن إتمام الحجز.',
    'en': 'This day was closed. Booking is disabled.',
  },
  'available_days_patient_hint_calendar': {
    'ckb':
        'تکایە یەکێک لە ڕۆژە بەردەستەکان (سەوز) هەڵبژێرە بۆ نۆرەگرتن.',
    'ar':
        'يُرجى اختيار أحد الأيام المتاحة (الخضراء) لحجز موعدك.',
    'en':
        'Please choose one of the available (mint) days to book your appointment.',
  },
  'available_days_patient_past_day': {
    'ckb': 'ناتوانیت بۆ ڕۆژی ڕابردوو نۆرە بگری.',
    'ar': 'لا يمكن الحجز ليوم مضى.',
    'en': 'You cannot book a past date.',
  },
  'available_days_patient_closed_day': {
    'ckb': 'ئەم ڕۆژە کراوە نییە.',
    'ar': 'هذا اليوم غير متاح.',
    'en': 'This day is closed.',
  },
  'booking_summary_existing_bookings': {
    'ckb': 'نۆرە پێش ئێستا',
    'ar': 'مواعيد مسجلة مسبقاً',
    'en': 'Bookings already today',
  },
  'daily_slots_title': {
    'ckb': 'نۆرەکانی ڕۆژ',
    'ar': 'مواعيد اليوم',
    'en': 'Daily appointments',
  },
  'daily_slots_no_capacity': {
    'ckb': 'ئەم ڕۆژە نۆرەی تێدا دانەمەزراندووە.',
    'ar': 'لا توجد سعة محددة لهذا اليوم.',
    'en': 'No slots configured for this day.',
  },
  'daily_slots_slot_number': {
    'ckb': 'نۆرە {n}',
    'ar': 'موعد {n}',
    'en': 'Slot {n}',
  },
  'daily_slots_status_available': {
    'ckb': 'بەتاڵە',
    'ar': 'متاح',
    'en': 'Available',
  },
  'daily_slots_status_booked': {
    'ckb': 'تۆمارکراو',
    'ar': 'محجوز',
    'en': 'Booked',
  },
  'daily_slots_call': {
    'ckb': 'پەیوەندی',
    'ar': 'اتصال',
    'en': 'Call',
  },
  'available_days_max_invalid': {
    'ckb': 'تکایە ژمارەیەکی دروست بنووسە (لانیکەم ١)',
    'ar': 'أدخل رقماً صالحاً (1 على الأقل)',
    'en': 'Enter a valid number (at least 1)',
  },
  'available_days_doctor_empty': {
    'ckb': 'بۆ کردنەوەی ڕۆژێک، لەسەر کاتژمێرەکە دایبگرە و کات و ماوە دیاری بکە.',
    'ar': 'اضغط على يوم في التقويم لفتحه وتحديد الوقت والمدة.',
    'en': 'Tap a day on the calendar to open it and set time and duration.',
  },
  'available_days_spots_subtitle': {
    'ckb': 'نۆرە: {current} لە {max}',
    'ar': 'المواعيد: {current} من {max}',
    'en': 'Spots: {current} / {max}',
  },
  'available_days_delete_title': {
    'ckb': 'سڕینەوەی ڕۆژ',
    'ar': 'حذف اليوم',
    'en': 'Remove day',
  },
  'available_days_delete_body': {
    'ckb': 'دڵنیایت لە سڕینەوەی ئەم ڕۆژە؟',
    'ar': 'هل تريد حذف هذا اليوم؟',
    'en': 'Remove this available day?',
  },
  'available_days_patient_title': {
    'ckb': 'ڕۆژە بەردەستەکان',
    'ar': 'الأيام المتاحة',
    'en': 'Available days',
  },
  'available_days_patient_hint': {
    'ckb': 'ڕۆژێک هەڵبژێرە بۆ تۆمارکردنی نۆرە.',
    'ar': 'اختر يوماً لحجز موعد.',
    'en': 'Tap a day to book an appointment.',
  },
  'available_days_patient_empty': {
    'ckb': 'ببوورە، لە ئێستادا هیچ کاتێکی بەردەست نییە',
    'ar': 'عذراً، لا توجد أوقات متاحة حالياً.',
    'en': 'Sorry — no appointment times are available right now.',
  },
  'available_days_slots_remaining_line': {
    'ckb': '{count} نۆرە ماوە',
    'ar': '{count} موعد متبقٍ',
    'en': '{count} spots left',
  },
  'booking_summary_title': {
    'ckb': 'پوختەی نۆرە',
    'ar': 'ملخص الحجز',
    'en': 'Booking summary',
  },
  'booking_summary_doctor': {
    'ckb': 'پزیشک',
    'ar': 'الطبيب',
    'en': 'Doctor',
  },
  'booking_summary_slots': {
    'ckb': 'نۆرەکان',
    'ar': 'المواعيد',
    'en': 'Capacity',
  },
  'booking_summary_remaining': {
    'ckb': 'ماوە',
    'ar': 'المتبقي',
    'en': 'Remaining',
  },
  'booking_summary_assigned_time': {
    'ckb': 'کاتی نۆرەکەت',
    'ar': 'وقت موعدك',
    'en': 'Your appointment time',
  },
  'booking_summary_day_mismatch': {
    'ckb': 'ئەم ڕۆژە لەگەڵ زانیاری ڕۆژەکە ناکۆکە. تکایە دووبارە هەڵبژاردن بکەرەوە.',
    'ar': 'لا يتطابق هذا اليوم مع بيانات التقويم. يرجى اختيار التاريخ مرة أخرى.',
    'en': 'This day does not match the calendar data. Please pick the date again.',
  },
  'booking_summary_date_label': {
    'ckb': 'بەروار',
    'ar': 'التاريخ',
    'en': 'Date',
  },
  'booking_summary_status_label': {
    'ckb': 'دۆخ',
    'ar': 'الحالة',
    'en': 'Status',
  },
  'booking_summary_status_open': {
    'ckb': 'کراوە بۆ نۆرە',
    'ar': 'مفتوح للحجز',
    'en': 'Open for booking',
  },
  'booking_summary_status_closed': {
    'ckb': 'داخراوە',
    'ar': 'مغلق',
    'en': 'Closed',
  },
  'booking_summary_only_spots_left': {
    'ckb': 'تەنها جێگەی ({x}) نەخۆش ماوە',
    'ar': 'يتبقى فقط مكان لـ ({x}) مريضاً',
    'en': 'Only ({x}) patient spots left',
  },
  'booking_time_confirm_prompt': {
    'ckb': 'نۆرەکەت کاتژمێر ({time}) دەبێت، دڵنیای لە جێگیرکردنی؟',
    'ar': 'سيكون موعدك في الساعة ({time}). هل تؤكد الحجز؟',
    'en': 'Your slot will be at {time}. Confirm booking?',
  },
  'booking_confirm_legal_notice_prefix': {
    'ckb':
        'تێبینی: تۆمارکردنی نۆرەی وەهمی و بێمانا بە سیستەمەکە، دەبێتە هۆی بلۆککردنی هەمیشەیی ژمارەکەت و ڕووبەڕووی ',
    'ar':
        'ملاحظة: إن حجز موعد وهمي وبلا مبرر عبر النظام قد يؤدي إلى حظر رقمك نهائيًا ومواجهة ',
    'en':
        'Note: Booking a fraudulent or meaningless appointment through the system may result in permanent blocking of your number and facing ',
  },
  'booking_confirm_legal_notice_emphasis': {
    'ckb': 'لێپرسینەوەی یاسایی',
    'ar': 'المساءلة القانونية',
    'en': 'legal consequences',
  },
  'booking_confirm_legal_notice_suffix': {
    'ckb': ' دەبیتەوە.',
    'ar': '.',
    'en': '.',
  },
  'patient_booking_slots_privacy_title': {
    'ckb': 'کاتەکان — تەنها بەتاڵ / گیراوە',
    'ar': 'المواعيد — متاح أو محجوز فقط',
    'en': 'Time slots — available or booked only',
  },
  'patient_slot_label_booked': {
    'ckb': 'گیراوە',
    'ar': 'محجوز',
    'en': 'Booked',
  },
  'patient_slot_label_available': {
    'ckb': 'بەتاڵە',
    'ar': 'متاح',
    'en': 'Available',
  },
  'patient_slot_label_unavailable': {
    'ckb': 'نابەردەستە',
    'ar': 'غير متاح',
    'en': 'Unavailable',
  },
  'patient_slot_label_past': {
    'ckb': 'کات تێپەڕیوە',
    'ar': 'انتهى الوقت',
    'en': 'Time has passed',
  },
  'patient_slot_label_yours': {
    'ckb': 'نۆرەی تۆیە',
    'ar': 'نوبتك',
    'en': "It's your turn",
  },
  'booking_summary_selected_slot_hint': {
    'ckb': 'کاتی دیاریکراو بە ڕەنگی جیاواز نیشان دراوە',
    'ar': 'الوقت المحدد مميز بلون مختلف',
    'en': 'Your assigned time is highlighted below',
  },
  'available_days_tap_to_book': {
    'ckb': 'داوە بکە',
    'ar': 'احجز',
    'en': 'Book',
  },
  'available_day_full': {
    'ckb': 'پڕ',
    'ar': 'ممتلئ',
    'en': 'Full',
  },
  'available_day_missing': {
    'ckb': 'ئەم ڕۆژە لە سیستەمەکەدا نییە.',
    'ar': 'هذا اليوم غير موجود.',
    'en': 'This day is no longer available.',
  },
  'available_day_mismatch': {
    'ckb': 'هەڵە لە هاوتاکردنی پزیشک.',
    'ar': 'خطأ في بيانات الطبيب.',
    'en': 'Doctor data mismatch.',
  },
  'available_day_tx_failed': {
    'ckb': 'نەتوانرا نۆرە تۆمار بکرێت. دووبارە هەوڵ بدەرەوە.',
    'ar': 'تعذر إتمام الحجز. حاول مرة أخرى.',
    'en': 'Could not complete booking. Try again.',
  },
  'master_calendar_subtitle': {
    'ckb': 'بەروار و کاتەکانی نۆرە',
    'ar': 'المواعيد والأوقات',
    'en': 'Appointments overview',
  },
  'master_calendar_no_doctors': {
    'ckb': 'هیچ پزیشکێکی بەردەست نییە',
    'ar': 'لا يوجد أطباء',
    'en': 'No doctors available',
  },
  'master_calendar_pick_doctor': {
    'ckb': 'پزیشک هەڵبژێرە',
    'ar': 'اختر طبيباً',
    'en': 'Select a doctor',
  },
  'secretary_calendar_selected_heading': {
    'ckb': 'ڕۆژی هەڵبژاردوو:',
    'ar': 'اليوم المحدد:',
    'en': 'Selected day:',
  },
  'secretary_calendar_manage_appointments': {
    'ckb': 'بەڕێوەبردنی نۆرەکان',
    'ar': 'إدارة المواعيد',
    'en': 'Manage appointments',
  },
  'secretary_calendar_no_appointments_day': {
    'ckb': 'هیچ نۆرەیەک بۆ ئەم ڕۆژە نییە.',
    'ar': 'لا مواعيد لهذا اليوم.',
    'en': 'No appointments on this day.',
  },
  'secretary_calendar_select_day_hint': {
    'ckb': 'ڕۆژێک لە ڕۆژژمێرەوە هەڵبژێرە بۆ بینینی وردەکاری و بەڕێوەبردنی نۆرەکان.',
    'ar': 'اختر يوماً من التقويم لعرض التفاصيل وإدارة المواعيد.',
    'en': 'Select a day on the calendar to view details and manage appointments.',
  },
  'master_calendar_legend_green': {
    'ckb': 'سەوز = کاتی بەردەست',
    'ar': 'أزرق داكن = يوجد وقت متاح',
    'en': 'Slate blue = slots open',
  },
  'master_calendar_legend_amber': {
    'ckb': 'نارەنجی = هەموو کاتەکان گیراون',
    'ar': 'برتقالي = ممتلئ بالكامل',
    'en': 'Orange = fully booked',
  },
  'master_calendar_legend_red_off': {
    'ckb': 'سوور = پشوو / کارناکات',
    'ar': 'أحمر = عطلة / لا يعمل',
    'en': 'Red = day off / not working',
  },
  'master_calendar_block_day_off': {
    'ckb': 'پشووی تەواوی ڕۆژ (داخراو)',
    'ar': 'إغلاق يوم كامل (عطلة)',
    'en': 'Close whole day (off)',
  },
  'master_calendar_block_day_emergency': {
    'ckb': 'داخستنی ناگەهی (فریاکەوتن)',
    'ar': 'إغلاق طارئ',
    'en': 'Emergency closure (whole day)',
  },
  'master_calendar_blocked_off': {
    'ckb': 'داخراو — پشوو',
    'ar': 'مغلق — عطلة',
    'en': 'Blocked — off',
  },
  'master_calendar_blocked_emergency': {
    'ckb': 'داخراو — فریاکەوتن',
    'ar': 'مغلق — طوارئ',
    'en': 'Blocked — emergency',
  },
  'master_calendar_block_slot_off': {
    'ckb': 'داخستنی ئەم کاتە (پشوو)',
    'ar': 'حظر هذا الوقت (عطلة)',
    'en': 'Block this slot (off)',
  },
  'master_calendar_block_slot_emergency': {
    'ckb': 'داخستنی ئەم کاتە (فریاکەوتن)',
    'ar': 'حظر هذا الوقت (طوارئ)',
    'en': 'Block this slot (emergency)',
  },
  'profile_appointment_duration_label': {
    'ckb': 'ماوەی نۆرە (خولەک)',
    'ar': 'مدة الموعد (دقائق)',
    'en': 'Appointment duration (minutes)',
  },
  'profile_appointment_duration_unit': {
    'ckb': 'خولەک',
    'ar': 'دقيقة',
    'en': 'min',
  },
  'profile_appointment_duration_hint': {
    'ckb': 'کاتەکانی نۆرە لەسەر ئەم ژمارەیە دروست دەکرێن (١٥، ٢٠ یان ٣٠).',
    'ar': 'تُبنى الفترات الزمنية على هذه القيمة (15 أو 20 أو 30).',
    'en': 'Time slots are generated using this step (15, 20, or 30 minutes).',
  },
  'master_calendar_day_off': {
    'ckb': 'ئەم ڕۆژە لە خشتەی کاردا نییە',
    'ar': 'هذا اليوم خارج أيام العمل',
    'en': 'This day is off the doctor schedule',
  },
  'master_calendar_slot_blocked': {
    'ckb': 'بلۆککراوە (پشوو یان داخراو)',
    'ar': 'محظور (عطلة / مغلق)',
    'en': 'Blocked (holiday / closed)',
  },
  'master_calendar_slot_free': {
    'ckb': 'بەردەستە',
    'ar': 'متاح',
    'en': 'Available',
  },
  'master_calendar_booked': {
    'ckb': 'نۆرە',
    'ar': 'محجوز',
    'en': 'Booked',
  },
  'master_calendar_unblock': {
    'ckb': 'لابردنی بلۆک',
    'ar': 'إلغاء الحظر',
    'en': 'Remove block',
  },
  'master_calendar_mark_complete': {
    'ckb': 'وەک تەواوبوو',
    'ar': 'تعليم كمكتمل',
    'en': 'Mark completed',
  },
  'master_calendar_cancel_appt': {
    'ckb': 'هەڵوەشاندنەوەی نۆرە',
    'ar': 'إلغاء الموعد',
    'en': 'Cancel appointment',
  },
  'master_calendar_add_walkin': {
    'ckb': 'زیادکردنی نەخۆش (سەرەڕا)',
    'ar': 'إضافة زيارة (مباشر)',
    'en': 'Add walk-in appointment',
  },
  'master_calendar_block_slot': {
    'ckb': 'بلۆکی ئەم کاتە',
    'ar': 'حظر هذا الوقت',
    'en': 'Block this slot',
  },
  'master_calendar_block_day': {
    'ckb': 'بلۆکی هەموو ڕۆژەکە',
    'ar': 'حظر اليوم كاملاً',
    'en': 'Block entire day',
  },
  'master_calendar_block_saved': {
    'ckb': 'بلۆک پاشکەوت کرا',
    'ar': 'تم حفظ الحظر',
    'en': 'Block saved',
  },
  'master_calendar_saved': {
    'ckb': 'پاشکەوت کرا',
    'ar': 'تم الحفظ',
    'en': 'Saved',
  },
  'master_calendar_tooltip': {
    'ckb': 'کالێنداری مانگ',
    'ar': 'تقويم الشهر',
    'en': 'Month calendar',
  },
  'master_calendar_patient_tooltip': {
    'ckb': 'کالێندار',
    'ar': 'التقويم',
    'en': 'Calendar',
  },
  'admin_dashboard_page_title': {
    'ckb': 'بەشی ئەدمین',
    'ar': 'لوحة المشرف',
    'en': 'Admin',
  },
  'admin_dashboard_welcome': {
    'ckb': 'بەخێربێیت، ئەدمین',
    'ar': 'مرحباً، المشرف',
    'en': 'Welcome, Admin',
  },
  'admin_dashboard_welcome_hint': {
    'ckb': 'بەڕێوەبردنی پزیشکان، نەخۆشخانەکان و کالێندار',
    'ar': 'إدارة الأطباء والمستشفيات والتقويم',
    'en': 'Manage doctors, hospitals & schedules',
  },
  'admin_card_feedback_title': {
    'ckb': 'بۆچوونەکان',
    'ar': 'الملاحظات',
    'en': 'Feedback',
  },
  'admin_card_feedback_subtitle': {
    'ckb': 'بۆچوون و پێشنیارەکانی نەخۆشەکان',
    'ar': 'ملاحظات واقتراحات المرضى',
    'en': 'Patient comments and suggestions',
  },
  'admin_card_hospitals_title': {
    'ckb': 'نەخۆشخانەکان',
    'ar': 'المستشفيات',
    'en': 'Hospitals',
  },
  'admin_card_hospitals_subtitle': {
    'ckb': 'زیادکردن و سڕینەوەی نەخۆشخانە لە داتابەیس',
    'ar': 'إضافة وحذف المستشفيات في قاعدة البيانات',
    'en': 'Add or remove hospitals in the database',
  },
  'admin_card_approvals_title': {
    'ckb': 'داواکارییەکان',
    'ar': 'طلبات الموافقة',
    'en': 'Approvals',
  },
  'admin_card_approvals_subtitle': {
    'ckb': 'پزیشکەکان کە چاوەڕێی قبوڵکردنن',
    'ar': 'أطباء بانتظار الموافقة',
    'en': 'Doctors awaiting approval',
  },
  'admin_card_doctors_title': {
    'ckb': 'لیستی پزیشکان',
    'ar': 'قائمة الأطباء',
    'en': 'Doctors list',
  },
  'admin_card_doctors_subtitle': {
    'ckb': 'پزیشکە قبوڵکراوەکان و سڕینەوە',
    'ar': 'الأطباء المعتمدون والحذف',
    'en': 'Approved doctors and removal',
  },
  'admin_card_add_doctor_title': {
    'ckb': 'زیادکردنی پزیشک',
    'ar': 'إضافة طبيب',
    'en': 'Add doctor',
  },
  'admin_card_add_doctor_subtitle': {
    'ckb': 'زیادکردنی پزیشک بە دەستی',
    'ar': 'إضافة طبيب يدوياً',
    'en': 'Manually add a doctor account',
  },
  'admin_card_ads_title': {
    'ckb': 'ڕیکلامەکان',
    'ar': 'الإعلانات',
    'en': 'Ads',
  },
  'admin_card_ads_subtitle': {
    'ckb': 'بەڕێوەبردنی وێنەی ڕیکلام لە سەرەتا',
    'ar': 'إدارة صور الإعلانات في الصفحة الرئيسية',
    'en': 'Manage home promo banner images',
  },
  'admin_ads_page_title': {
    'ckb': 'ڕیکلامەکان',
    'ar': 'الإعلانات',
    'en': 'Manage ads',
  },
  'admin_ads_intro': {
    'ckb':
        'وێنەکان لە نێوان گەڕان و پسپۆڕییەکان دەردەکەون. دەتوانیت چەند وێنە هەڵبژێریت یان ڕیکلام بسڕیتەوە.',
    'ar':
        'تظهر الصور بين البحث والتخصصات. يمكنك اختيار عدة صور أو حذف إعلان.',
    'en':
        'Banners appear between search and specialties. Select multiple images or remove ads.',
  },
  'admin_ads_upload': {
    'ckb': 'بارکردنی وێنە (یان چەند وێنە)',
    'ar': 'رفع صورة أو عدة صور',
    'en': 'Upload image(s)',
  },
  'admin_ads_uploading': {
    'ckb': 'باردەکرێت...',
    'ar': 'جاري الرفع...',
    'en': 'Uploading...',
  },
  'admin_ads_upload_ok': {
    'ckb': 'وێنەکە پاشەکەوت کرا',
    'ar': 'تم حفظ الصورة',
    'en': 'Image saved',
  },
  'admin_ads_upload_ok_batch': {
    'ckb': '{count} وێنە بە سەرکەوتوویی بارکران',
    'ar': 'تم رفع {count} صورة',
    'en': 'Uploaded {count} images',
  },
  'admin_ads_active_list_title': {
    'ckb': 'ڕیکلامە چالاکەکان',
    'ar': 'الإعلانات النشطة',
    'en': 'Active ads',
  },
  'admin_ads_deleted_ok': {
    'ckb': 'ڕیکلامەکە سڕایەوە',
    'ar': 'تم حذف الإعلان',
    'en': 'Ad removed',
  },
  'admin_ads_delete': {
    'ckb': 'سڕینەوە',
    'ar': 'حذف',
    'en': 'Delete',
  },
  'admin_ads_empty': {
    'ckb': 'هیچ ڕیکلامێک نییە — وێنە بار بکە بۆ پیشاندان لە سەرەتا.',
    'ar': 'لا توجد إعلانات — ارفع صورة لعرضها في الصفحة الرئيسية.',
    'en': 'No ads yet — upload an image to show on home.',
  },
  'admin_ads_error': {
    'ckb': 'هەڵە',
    'ar': 'خطأ',
    'en': 'Error',
  },
  'admin_ads_delete_confirm_title': {
    'ckb': 'سڕینەوەی ڕیکلام',
    'ar': 'حذف الإعلان',
    'en': 'Remove ad',
  },
  'admin_ads_delete_confirm_body': {
    'ckb': 'دڵنیایت لە سڕینەوەی ئەم ڕیکلامە؟',
    'ar': 'هل تريد حذف هذا الإعلان؟',
    'en': 'Remove this ad from the slider?',
  },
  'admin_logout': {
    'ckb': 'چوونەدەرەوە',
    'ar': 'تسجيل الخروج',
    'en': 'Log out',
  },
  'error_code': {
    'ckb': 'هەڵە ({code})',
    'ar': 'خطأ ({code})',
    'en': 'Error ({code})',
  },
  'save_error': {
    'ckb': 'هەڵە لە پاشەکەوتکردن',
    'ar': 'خطأ في الحفظ',
    'en': 'Save error',
  },
  'save_error_detail': {
    'ckb': 'هەڵە لە پاشەکەوتکردن: {error}',
    'ar': 'خطأ في الحفظ: {error}',
    'en': 'Save error: {error}',
  },
  'login_required': {
    'ckb': 'چوونەژوورەوە پێویستە',
    'ar': 'يجب تسجيل الدخول',
    'en': 'Sign in required',
  },
  'tooltip_back': {
    'ckb': 'گەڕانەوە',
    'ar': 'رجوع',
    'en': 'Back',
  },
  'specialty_colon': {
    'ckb': 'پسپۆڕی: {value}',
    'ar': 'التخصص: {value}',
    'en': 'Specialty: {value}',
  },
  'patient_calendar_selected_heading': {
    'ckb': 'ڕۆژی هەڵبژێردراو',
    'ar': 'التاريخ المحدد',
    'en': 'Selected date',
  },
  'patient_calendar_date_subline': {
    'ckb': '{weekday}، {day}ی {month}',
    'ar': '{weekday}، {day} {month}',
    'en': '{weekday}, {month} {day}',
  },
  'patient_calendar_no_selection': {
    'ckb': 'ڕۆژێک لە ڕۆژژمێر هەڵبژێرە',
    'ar': 'اختر يوماً من التقويم',
    'en': 'Pick a day on the calendar',
  },
  'patient_calendar_pick_open_day': {
    'ckb': 'تکایە ڕۆژێکی بەردەست (سەوز) هەڵبژێرە، پاشان دووپات بکەرەوە',
    'ar': 'اختر يوماً متاحاً (أخضر) ثم أكّد الحجز',
    'en': 'Choose an available (green) day, then confirm',
  },
  'patient_calendar_closed_professional_title': {
    'ckb': 'داوای لێبوردن دەکەین، پزیشک لەم ڕێکەوتەدا بەردەست نییە',
    'ar': 'نعتذر، الطبيب غير متاح في هذا التاريخ.',
    'en': 'We apologize, the doctor is not available on this date.',
  },
  'patient_calendar_closed_professional_subtitle': {
    'ckb': 'تکایە ڕۆژێکی تر (سەوز) هەڵبژێرە',
    'ar': 'يرجى اختيار يوم آخر (أخضر).',
    'en': 'Please select another day (green).',
  },
  'patient_calendar_closed_professional_snackbar': {
    'ckb': 'داوای لێبوردن دەکەین، ئەم ڕۆژە داخراوە',
    'ar': 'نعتذر، هذا اليوم مغلق.',
    'en': 'We apologize, this day is closed.',
  },
  'patient_calendar_view_schedule': {
    'ckb': 'بینینی خشتە',
    'ar': 'عرض الجدول',
    'en': 'View schedule',
  },
  'patient_calendar_status_available': {
    'ckb': 'دۆخی ڕۆژ: بەردەستە',
    'ar': 'حالة اليوم: متاح',
    'en': 'Day status: Available',
  },
  'patient_calendar_status_unavailable': {
    'ckb': 'دۆخی ڕۆژ: داخراوە',
    'ar': 'حالة اليوم: غير متاح',
    'en': 'Day status: Unavailable',
  },
  'patient_calendar_status_pick': {
    'ckb': 'دۆخی ڕۆژ: —',
    'ar': 'حالة اليوم: —',
    'en': 'Day status: —',
  },
  'cal_month_1': {
    'ckb': 'کانوونی دووەم',
    'ar': 'يناير',
    'en': 'January',
  },
  'cal_month_2': {
    'ckb': 'شوبات',
    'ar': 'فبراير',
    'en': 'February',
  },
  'cal_month_3': {
    'ckb': 'ئازار',
    'ar': 'مارس',
    'en': 'March',
  },
  'cal_month_4': {
    'ckb': 'نیسان',
    'ar': 'أبريل',
    'en': 'April',
  },
  'cal_month_5': {
    'ckb': 'ئایار',
    'ar': 'مايو',
    'en': 'May',
  },
  'cal_month_6': {
    'ckb': 'حوزەیران',
    'ar': 'يونيو',
    'en': 'June',
  },
  'cal_month_7': {
    'ckb': 'تەممووز',
    'ar': 'يوليو',
    'en': 'July',
  },
  'cal_month_8': {
    'ckb': 'ئاب',
    'ar': 'أغسطس',
    'en': 'August',
  },
  'cal_month_9': {
    'ckb': 'ئەیلوول',
    'ar': 'سبتمبر',
    'en': 'September',
  },
  'cal_month_10': {
    'ckb': 'تشرینی یەکەم',
    'ar': 'أكتوبر',
    'en': 'October',
  },
  'cal_month_11': {
    'ckb': 'تشرینی دووەم',
    'ar': 'نوفمبر',
    'en': 'November',
  },
  'cal_month_12': {
    'ckb': 'کانوونی یەکەم',
    'ar': 'ديسمبر',
    'en': 'December',
  },
  'weekday_sat': {
    'ckb': 'شەممە',
    'ar': 'السبت',
    'en': 'Saturday',
  },
  'weekday_sun': {
    'ckb': 'یەکشەممە',
    'ar': 'الأحد',
    'en': 'Sunday',
  },
  'weekday_mon': {
    'ckb': 'دووشەممە',
    'ar': 'الاثنين',
    'en': 'Monday',
  },
  'weekday_tue': {
    'ckb': 'سێشەممە',
    'ar': 'الثلاثاء',
    'en': 'Tuesday',
  },
  'weekday_wed': {
    'ckb': 'چوارشەممە',
    'ar': 'الأربعاء',
    'en': 'Wednesday',
  },
  'weekday_thu': {
    'ckb': 'پێنجشەممە',
    'ar': 'الخميس',
    'en': 'Thursday',
  },
  'weekday_fri': {
    'ckb': 'هەینی',
    'ar': 'الجمعة',
    'en': 'Friday',
  },
};

/// HR Nora strings for the current or a fixed [HrNoraLanguage].
///
/// Use globally: `S.of(context).translate('login')`.
class AppLocalizations {
  AppLocalizations._(this._lang);

  final HrNoraLanguage _lang;

  /// Strings for the signed-in / selected app language (from [AppLocaleScope]).
  static AppLocalizations of(BuildContext context) {
    return AppLocalizations._(AppLocaleScope.of(context).effectiveLanguage);
  }

  /// Lookup without a [BuildContext] (e.g. tests, background).
  static AppLocalizations forLang(HrNoraLanguage lang) =>
      AppLocalizations._(lang);

  String translate(
    String key, {
    Map<String, String> params = const {},
  }) {
    final row = kAppStrings[key];
    if (row == null) return key;
    var text = row[_lang.storageCode] ??
        row['en'] ??
        (row.isNotEmpty ? row.values.first : null) ??
        key;
    params.forEach((k, v) {
      text = text.replaceAll('{$k}', v);
    });
    return text;
  }
}

/// Short alias: `S.of(context).translate('key')`.
abstract final class S {
  static AppLocalizations of(BuildContext context) =>
      AppLocalizations.of(context);
}

extension HrNoraTr on BuildContext {
  /// Same as [S.of(this).translate].
  String tr(String key, {Map<String, String> params = const {}}) =>
      S.of(this).translate(key, params: params);
}

/// Backward-compatible static [t] for a given [HrNoraLanguage].
abstract final class HrNoraStrings {
  static String t(HrNoraLanguage language, String key) =>
      AppLocalizations.forLang(language).translate(key);
}
