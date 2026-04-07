import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../locale/app_locale.dart';
import '../theme/patient_premium_theme.dart';

const Color _kPersonalInfoGold = Color(0xFFD4AF37);
const Color _kPersonalInfoBorderGrey = Color(0xFFE2E8F0);
const Color _kPersonalInfoPrimaryBlue = Color(0xFF1976D2);
const Color _kPersonalInfoBg = Color(0xFFF6FAFF);

/// Edit patient personal info in Firestore `users`.
class PatientEditProfileScreen extends StatefulWidget {
  const PatientEditProfileScreen({super.key});

  @override
  State<PatientEditProfileScreen> createState() =>
      _PatientEditProfileScreenState();
}

class _PatientEditProfileScreenState extends State<PatientEditProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _picker = ImagePicker();
  XFile? _pickedAvatar;
  String _existingAvatarUrl = '';

  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailController = TextEditingController();
  final _addressController = TextEditingController();
  final _dobController = TextEditingController();

  String? _genderValue;
  DateTime? _dob;

  final _nameFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _dobFocus = FocusNode();

  bool _loading = true;
  bool _saving = false;
  bool _genderFocused = false;

  void _onFocusChanged() {
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onFocusChanged);
    _passwordFocus.addListener(_onFocusChanged);
    _emailFocus.addListener(_onFocusChanged);
    _addressFocus.addListener(_onFocusChanged);
    _dobFocus.addListener(_onFocusChanged);
    _load();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    final docId = user?.uid.trim() ?? '';
    if (docId.isEmpty) {
      setState(() => _loading = false);
      return;
    }
    try {
      final snap =
          await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final data = snap.data() ?? const <String, dynamic>{};

      final dbName = (data['fullName'] ?? '').toString().trim();
      final dbEmail = (data['email'] ?? '').toString().trim();
      final dbPhone = (data['phone'] ?? '').toString().trim();
      final dbAddress = (data['address'] ?? '').toString().trim();
      final dbGender = (data['gender'] ?? '').toString().trim();
      final dbAvatar = (data['profileImageUrl'] ?? '').toString().trim();
      final dbDobRaw = data['dateOfBirth'];

      final authName = (user?.displayName ?? '').trim();
      final authPhone = (user?.phoneNumber ?? '').trim();
      final authEmail = (user?.email ?? '').trim();

      _nameController.text = dbName.isNotEmpty
          ? dbName
          : authName;
      // Password is never loaded from Firestore.
      _passwordController.text = '';
      // "Email or phone" field: prefer email; fallback to phone; fallback to auth.
      final contact = dbEmail.isNotEmpty
          ? dbEmail
          : (dbPhone.isNotEmpty
              ? dbPhone
              : (authEmail.isNotEmpty ? authEmail : authPhone));
      _emailController.text = contact;
      _addressController.text = dbAddress;
      _genderValue = _normalizeGenderValue(dbGender);
      _existingAvatarUrl = dbAvatar;

      DateTime? parsedDob;
      if (dbDobRaw is Timestamp) {
        parsedDob = dbDobRaw.toDate();
      } else if (dbDobRaw is DateTime) {
        parsedDob = dbDobRaw;
      } else if (dbDobRaw != null) {
        final s = dbDobRaw.toString().trim();
        parsedDob = DateTime.tryParse(s);
      }
      _dob = parsedDob;
      _dobController.text =
          parsedDob == null ? '' : DateFormat('yyyy/MM/dd').format(parsedDob);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChanged);
    _passwordFocus.removeListener(_onFocusChanged);
    _emailFocus.removeListener(_onFocusChanged);
    _addressFocus.removeListener(_onFocusChanged);
    _dobFocus.removeListener(_onFocusChanged);
    _nameFocus.dispose();
    _passwordFocus.dispose();
    _emailFocus.dispose();
    _addressFocus.dispose();
    _dobFocus.dispose();
    _nameController.dispose();
    _passwordController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    _dobController.dispose();
    super.dispose();
  }

  static String? _normalizeGenderValue(String raw) {
    final s = raw.trim();
    if (s.isEmpty) return null;
    final lower = s.toLowerCase();
    if (lower == 'male' || lower == 'm') return 'male';
    if (lower == 'female' || lower == 'f') return 'female';
    if (s == 'نێر') return 'male';
    if (s == 'مێ') return 'female';
    return null;
  }

  static const BorderRadius _fieldRadius = BorderRadius.all(
    Radius.circular(16),
  );

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required bool focused,
    bool isAction = false,
  }) {
    final iconColor = focused
        ? _kPersonalInfoPrimaryBlue
        : kPatientNavyText.withValues(alpha: 0.55);
    return InputDecoration(
      labelText: label,
      labelStyle: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: kPatientNavyText.withValues(alpha: 0.58),
      ),
      floatingLabelStyle: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
        color: _kPersonalInfoPrimaryBlue.withValues(alpha: 0.92),
      ),
      // In RTL, "start" is the right side.
      prefixIcon: Padding(
        padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
        child: Icon(icon, size: 20, color: iconColor),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 48),
      suffixIcon: isAction
          ? Icon(
              Icons.keyboard_arrow_down_rounded,
              color: iconColor.withValues(alpha: 0.9),
            )
          : null,
      filled: true,
      fillColor: Colors.white,
      isDense: false,
      contentPadding: const EdgeInsets.fromLTRB(14, 16, 16, 16),
      border: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: _kPersonalInfoBorderGrey, width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(
          color: _kPersonalInfoBorderGrey.withValues(alpha: 0.95),
          width: 1,
        ),
      ),
      focusedBorder: const OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: _kPersonalInfoPrimaryBlue, width: 1.4),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.9)),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: Colors.redAccent, width: 1.4),
      ),
    );
  }

  Widget _miniCardField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    String? Function(String?)? validator,
    bool readOnly = false,
    VoidCallback? onTap,
    Widget? suffixIcon,
  }) {
    final focused = focusNode.hasFocus;
    final base = _fieldDecoration(label: label, icon: icon, focused: focused);
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: obscureText,
      readOnly: readOnly,
      onTap: onTap,
      textAlign: TextAlign.right,
      keyboardType: keyboardType,
      validator: validator,
      style: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: kPatientNavyText.withValues(alpha: 0.9),
      ),
      decoration: base.copyWith(suffixIcon: suffixIcon),
    );
  }

  Future<void> _pickAvatar() async {
    try {
      final img = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
        maxWidth: 1200,
      );
      if (!mounted) return;
      if (img == null) return;
      setState(() => _pickedAvatar = img);
    } catch (_) {
      // Best-effort: ignore picker errors.
    }
  }

  Future<String?> _uploadAvatarIfNeeded(String userId) async {
    final picked = _pickedAvatar;
    if (picked == null) return null;
    final file = File(picked.path);
    final ref = FirebaseStorage.instance
        .ref()
        .child('users')
        .child(userId)
        .child('profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
    final task = await ref.putFile(
      file,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    return await task.ref.getDownloadURL();
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 22, now.month, now.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'بەرواری لەدایکبوون',
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: _kPersonalInfoPrimaryBlue,
                ),
          ),
          child: child!,
        );
      },
    );
    if (!mounted) return;
    if (picked == null) return;
    setState(() {
      _dob = picked;
      _dobController.text = DateFormat('yyyy/MM/dd').format(picked);
    });
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final user = FirebaseAuth.instance.currentUser;
    final docId = user?.uid.trim() ?? '';
    if (docId.isEmpty) return;

    setState(() => _saving = true);
    try {
      final avatarUrl = await _uploadAvatarIfNeeded(docId);
      final name = _nameController.text.trim();
      final contact = _emailController.text.trim();
      final address = _addressController.text.trim();
      final password = _passwordController.text.trim();
      final gender = (_genderValue ?? '').trim();

      final contactLooksEmail = contact.contains('@');
      final update = <String, dynamic>{
        'fullName': name,
        if (contactLooksEmail) 'email': contact else 'phone': contact,
        'address': address,
        if (gender.isNotEmpty) 'gender': gender,
        if (_dob != null) 'dateOfBirth': Timestamp.fromDate(_dob!),
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          'profileImageUrl': avatarUrl.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };
      await FirebaseFirestore.instance.collection('users').doc(docId).set(
            update,
            SetOptions(merge: true),
          );

      if (password.isNotEmpty && user != null) {
        try {
          await user.updatePassword(password);
        } catch (_) {
          // If re-auth is required, we still keep Firestore changes.
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'نەتوانرا وشەی نهێنی بگۆڕدرێت (پێویستە دووبارە بچیتە ژوورەوە).',
                  style: TextStyle(fontFamily: kPatientPrimaryFont),
                ),
              ),
            );
          }
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'گۆڕانکارییەکان پاشکەوت کران',
              style: TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
        Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final pageRtl =
        AppLocaleScope.of(context).textDirection == TextDirection.rtl;
    final topH = ((MediaQuery.sizeOf(context).height * 0.25).clamp(170.0, 220.0))
        .toDouble();
    final ImageProvider<Object>? avatarImage = _pickedAvatar != null
        ? FileImage(File(_pickedAvatar!.path))
        : (_existingAvatarUrl.trim().isNotEmpty
            ? NetworkImage(_existingAvatarUrl.trim())
            : null);

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: _kPersonalInfoBg,
        appBar: AppBar(
          systemOverlayStyle: SystemUiOverlayStyle.light,
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          iconTheme: const IconThemeData(
            color: Colors.white,
            size: 22,
          ),
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(
              pageRtl
                  ? Icons.arrow_forward_ios_rounded
                  : Icons.arrow_back_ios_new_rounded,
            ),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(
            'زانیارییە کەسییەکان',
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w700,
              fontSize: 17.5,
              color: Colors.white,
              letterSpacing: 0.2,
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.22),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: const BoxDecoration(
            color: _kPersonalInfoBg,
          ),
          child: _loading
              ? const SafeArea(
                  child: Center(
                    child: CircularProgressIndicator(color: Color(0xFF1565C0)),
                  ),
                )
              : Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: topH,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topRight,
                            end: Alignment.bottomLeft,
                            colors: [
                              _kPersonalInfoPrimaryBlue,
                              _kPersonalInfoPrimaryBlue.withValues(alpha: 0.72),
                              const Color(0xFF64B5F6).withValues(alpha: 0.65),
                            ],
                            stops: const [0.0, 0.55, 1.0],
                          ),
                        ),
                      ),
                    ),
                    SafeArea(
                      top: false,
                      child: SingleChildScrollView(
                        padding: EdgeInsets.fromLTRB(
                          20,
                          (topH - 68).clamp(
                            MediaQuery.paddingOf(context).top +
                                kToolbarHeight -
                                24,
                            topH,
                          ),
                          20,
                          24,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: GestureDetector(
                                onTap: _saving ? null : _pickAvatar,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    Container(
                                      width: 106,
                                      height: 106,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.12),
                                            blurRadius: 18,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 4,
                                        ),
                                      ),
                                      child: CircleAvatar(
                                        backgroundImage: avatarImage,
                                        backgroundColor: const Color(0xFFE9F2FF),
                                        child: avatarImage == null
                                            ? Icon(
                                                Icons.person_rounded,
                                                size: 46,
                                                color: _kPersonalInfoPrimaryBlue
                                                    .withValues(alpha: 0.45),
                                              )
                                            : null,
                                      ),
                                    ),
                                    PositionedDirectional(
                                      bottom: -2,
                                      end: -2,
                                      child: Container(
                                        width: 34,
                                        height: 34,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          gradient: const LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Color(0xFFFFD54F),
                                              _kPersonalInfoGold,
                                            ],
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withValues(alpha: 0.18),
                                              blurRadius: 10,
                                              offset: const Offset(0, 5),
                                            ),
                                          ],
                                        ),
                                        child: const Icon(
                                          Icons.photo_camera_rounded,
                                          color: Colors.white,
                                          size: 18,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                color: Colors.white,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.08),
                                    blurRadius: 18,
                                    offset: const Offset(0, 8),
                                  ),
                                  BoxShadow(
                                    color: Colors.white.withValues(alpha: 0.55),
                                    blurRadius: 10,
                                    offset: const Offset(0, -2),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                              child: Form(
                                key: _formKey,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _miniCardField(
                                      controller: _nameController,
                                      focusNode: _nameFocus,
                                      label: 'ناوی تەواو',
                                      icon: Icons.person_outline_rounded,
                                      validator: (v) {
                                        if ((v ?? '').trim().isEmpty) {
                                          return 'تکایە ناوی تەواوت بنووسە';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _miniCardField(
                                      controller: _passwordController,
                                      focusNode: _passwordFocus,
                                      label: 'وشەی نهێنی',
                                      icon: Icons.lock_rounded,
                                      obscureText: true,
                                    ),
                                    const SizedBox(height: 14),
                                    _miniCardField(
                                      controller: _emailController,
                                      focusNode: _emailFocus,
                                      label: 'ئیمەیڵ یان ژمارەی مۆبایل',
                                      icon: Icons.alternate_email_rounded,
                                      keyboardType: TextInputType.emailAddress,
                                      validator: (v) {
                                        if ((v ?? '').trim().isEmpty) {
                                          return 'تکایە ئیمەیڵ یان ژمارەی مۆبایل بنووسە';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    _miniCardField(
                                      controller: _addressController,
                                      focusNode: _addressFocus,
                                      label: 'ناونیشان',
                                      icon: Icons.location_on_outlined,
                                      keyboardType: TextInputType.streetAddress,
                                    ),
                                    const SizedBox(height: 14),
                                    DropdownButtonFormField<String>(
                                      key: ValueKey(_genderValue ?? 'unset'),
                                      initialValue: _genderValue,
                                      items: const [
                                        DropdownMenuItem(
                                          value: 'male',
                                          child: Text(
                                            'نێر',
                                            style: TextStyle(
                                              fontFamily: kPatientPrimaryFont,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                        DropdownMenuItem(
                                          value: 'female',
                                          child: Text(
                                            'مێ',
                                            style: TextStyle(
                                              fontFamily: kPatientPrimaryFont,
                                              fontWeight: FontWeight.w700,
                                            ),
                                          ),
                                        ),
                                      ],
                                      onChanged: (v) {
                                        setState(() {
                                          _genderValue = v;
                                          _genderFocused = false;
                                        });
                                      },
                                      onTap: () => setState(() => _genderFocused = true),
                                      icon: Icon(
                                        Icons.expand_more_rounded,
                                        color: _genderFocused
                                            ? _kPersonalInfoPrimaryBlue
                                            : kPatientNavyText.withValues(alpha: 0.55),
                                      ),
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: kPatientNavyText.withValues(alpha: 0.9),
                                      ),
                                      decoration: _fieldDecoration(
                                        label: 'ڕەگەز',
                                        icon: Icons.wc_rounded,
                                        focused: _genderFocused,
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _miniCardField(
                                      controller: _dobController,
                                      focusNode: _dobFocus,
                                      label: 'بەرواری لەدایکبوون',
                                      icon: Icons.calendar_month_rounded,
                                      readOnly: true,
                                      onTap: _pickDob,
                                      suffixIcon: IconButton(
                                        onPressed: _pickDob,
                                        icon: Icon(
                                          Icons.edit_calendar_rounded,
                                          color: _dobFocus.hasFocus
                                              ? _kPersonalInfoPrimaryBlue
                                              : kPatientNavyText
                                                  .withValues(alpha: 0.55),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    SizedBox(
                                      height: 54,
                                      child: ElevatedButton(
                                        onPressed: _saving ? null : _save,
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(20),
                                          ),
                                          backgroundColor: Colors.transparent,
                                          elevation: 0,
                                        ),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(20),
                                            gradient: LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                _kPersonalInfoPrimaryBlue,
                                                const Color(0xFF42A5F5),
                                                _kPersonalInfoGold.withValues(alpha: 0.92),
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.14),
                                                blurRadius: 12,
                                                offset: const Offset(0, 7),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              textDirection: TextDirection.rtl,
                                              children: [
                                                const Text(
                                                  'پاشکەوتکردنی گۆڕانکارییەکان',
                                                  style: TextStyle(
                                                    fontFamily:
                                                        kPatientPrimaryFont,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 15.5,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                                if (_saving) ...[
                                                  const SizedBox(width: 12),
                                                  const SizedBox(
                                                    width: 20,
                                                    height: 20,
                                                    child:
                                                        CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ],
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
