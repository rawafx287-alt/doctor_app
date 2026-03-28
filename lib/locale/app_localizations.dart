import 'package:flutter/material.dart';

import 'app_locale.dart';

/// All HR Nora UI strings: [key] → `ckb` | `ar` | `en`.
const Map<String, Map<String, String>> kAppStrings = {
  'home': {
    'ckb': 'سەرەتا',
    'ar': 'الرئيسية',
    'en': 'Home',
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
    'ckb': 'تکایە زانیارییەکانت بنووسە بۆ بەردەوامبوون',
    'ar': 'أدخل بياناتك للمتابعة',
    'en': 'Enter your details to continue',
  },
  'hint_email_or_phone': {
    'ckb': 'ئیمەیڵ یان ژمارەی مۆبایل',
    'ar': 'البريد أو رقم الجوال',
    'en': 'Email or mobile number',
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
    'ckb': 'وشەی نهێنی (لانیکەم ٦ پیت)',
    'ar': 'كلمة المرور (٦ أحرف على الأقل)',
    'en': 'Password (at least 6 characters)',
  },
  'register': {
    'ckb': 'تۆماربوون',
    'ar': 'تسجيل',
    'en': 'Register',
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
    'ckb': 'ئیمەیڵەکە دروست نییە',
    'ar': 'البريد غير صالح',
    'en': 'Invalid email',
  },
  'validation_password_required': {
    'ckb': 'وشەی نهێنی پێویستە',
    'ar': 'كلمة المرور مطلوبة',
    'en': 'Password is required',
  },
  'validation_password_short': {
    'ckb': 'وشەی نهێنی لانیکەم ٦ پیت بێت',
    'ar': 'كلمة المرور ٦ أحرف على الأقل',
    'en': 'Password must be at least 6 characters',
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
  'app_display_name': {
    'ckb': 'HR Nora',
    'ar': 'HR Nora',
    'en': 'HR Nora',
  },
  'about_description': {
    'ckb':
        'ئەم ئەپە یارمەتی تۆ دەدات بۆ دۆزینەوەی پزیشک و بەڕێوەبردنی نۆرەکان.',
    'ar': 'يساعدك هذا التطبيق على إيجاد الأطباء وإدارة مواعيدك.',
    'en': 'This app helps you find doctors and manage your appointments.',
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
  'search_doctors_hint': {
    'ckb': 'گەڕان بە پزیشک یان پسپۆڕی...',
    'ar': 'ابحث عن طبيب أو تخصص...',
    'en': 'Search for doctors or specialty...',
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
  'working_days_title': {
    'ckb': 'ڕۆژەکانی کار (تەنها ئەوانەی پزیشک چالاکی کردووە)',
    'ar': 'أيام العمل (المفعّلة من الطبيب فقط)',
    'en': 'Working days (enabled by doctor)',
  },
  'no_schedule_yet': {
    'ckb':
        'ئەم پزیشکە هێشتا خشتەی کار تۆمار نەکردووە. دواتر هەوڵ بدەرەوە.',
    'ar': 'لم يضف الطبيب جدولاً بعد. حاول لاحقاً.',
    'en': 'This doctor has not set a schedule yet. Try again later.',
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
  'confirm_booking': {
    'ckb': 'دوپاتکردنەوەی نۆرە',
    'ar': 'تأكيد الحجز',
    'en': 'Confirm booking',
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
