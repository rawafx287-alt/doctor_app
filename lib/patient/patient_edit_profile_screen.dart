import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';
import '../theme/patient_premium_theme.dart';

const Color _kPersonalInfoGold = Color(0xFFC9A227);
const Color _kPersonalInfoGoldDeep = Color(0xFFB8860B);
const Color _kPersonalInfoPrimaryBlue = Color(0xFF1976D2);
const Color _kFieldFillTint = Color(0xFFF0F7FF);
const Color _kGenderCardGreyBorder = Color(0xFFD1D9E0);
const Color _kGenderCardGreyIcon = Color(0xFF94A3B8);
const Color _kGenderSelectedFill = Color(0xFFE3F2FD);
const Color _kGradientSkyTop = Color(0xFFB3E5FC);
const Color _kGradientWhiteBottom = Color(0xFFFFFFFF);

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
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  /// Mirrors gender label (نێر / مێ) for the same data as [_genderValue].
  final _genderController = TextEditingController();
  final _dobController = TextEditingController();
  final _ageController = TextEditingController();
  final _bloodController = TextEditingController();

  String? _genderValue;
  DateTime? _dob;

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _addressFocus = FocusNode();
  final _dobFocus = FocusNode();
  final _ageFocus = FocusNode();
  final _bloodFocus = FocusNode();
  final _passwordMaskController = TextEditingController(text: '••••••••');
  final _passwordMaskFocus = FocusNode();

  bool _loading = true;
  bool _saving = false;
  /// True when email is auto-style (e.g. phone@…) — show read-only line, not a TextField.
  bool _syntheticEmailDisplay = false;
  /// Brief scale pulse on tap: `'male'` | `'female'`.
  String? _genderTapAnim;

  bool _editingName = false;
  bool _editingEmail = false;
  bool _editingPhone = false;

  void _onFocusChanged() {
    if (!_nameFocus.hasFocus && _editingName) _editingName = false;
    if (!_emailFocus.hasFocus && _editingEmail) _editingEmail = false;
    if (!_phoneFocus.hasFocus && _editingPhone) _editingPhone = false;
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    _nameFocus.addListener(_onFocusChanged);
    _emailFocus.addListener(_onFocusChanged);
    _phoneFocus.addListener(_onFocusChanged);
    _addressFocus.addListener(_onFocusChanged);
    _dobFocus.addListener(_onFocusChanged);
    _ageFocus.addListener(_onFocusChanged);
    _bloodFocus.addListener(_onFocusChanged);
    _load();
  }

  static String _usersDocId(User? user) {
    if (user == null) return '';
    final id = firestoreUserDocId(user).trim();
    return id.isNotEmpty ? id : user.uid.trim();
  }

  Future<void> _load() async {
    final user = FirebaseAuth.instance.currentUser;
    final docId = _usersDocId(user);
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
      _emailController.text = dbEmail.isNotEmpty ? dbEmail : authEmail;
      _syntheticEmailDisplay = _isSyntheticAuthEmail(_emailController.text);
      _phoneController.text = _normalizePhoneForField(
        dbPhone.isNotEmpty ? dbPhone : authPhone,
      );
      _addressController.text = dbAddress;
      _genderValue = _normalizeGenderValue(dbGender);
      _syncGenderControllerFromValue();
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

      final ageRaw = data['ageYears'] ?? data['age'];
      if (ageRaw is int) {
        _ageController.text = '$ageRaw';
      } else if (ageRaw is num) {
        _ageController.text = '${ageRaw.round()}';
      } else {
        final as = ageRaw?.toString().trim() ?? '';
        _ageController.text = as;
      }

      _bloodController.text =
          (data['bloodGroup'] ?? data['blood'] ?? '').toString().trim();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  void dispose() {
    _nameFocus.removeListener(_onFocusChanged);
    _emailFocus.removeListener(_onFocusChanged);
    _phoneFocus.removeListener(_onFocusChanged);
    _addressFocus.removeListener(_onFocusChanged);
    _dobFocus.removeListener(_onFocusChanged);
    _ageFocus.removeListener(_onFocusChanged);
    _bloodFocus.removeListener(_onFocusChanged);
    _nameFocus.dispose();
    _emailFocus.dispose();
    _phoneFocus.dispose();
    _addressFocus.dispose();
    _dobFocus.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _genderController.dispose();
    _dobController.dispose();
    _ageController.dispose();
    _bloodController.dispose();
    _passwordMaskController.dispose();
    _passwordMaskFocus.dispose();
    _ageFocus.dispose();
    _bloodFocus.dispose();
    super.dispose();
  }

  static String _digitsOnly(String s) =>
      s.replaceAll(RegExp(r'\D'), '');

  /// Prefer local 11-digit form (e.g. 0750…) for display when possible.
  static String _normalizePhoneForField(String raw) {
    final d = _digitsOnly(raw);
    if (d.isEmpty) return '';
    if (d.length == 11) return d;
    if (d.length == 13 && d.startsWith('964')) {
      final rest = d.substring(3);
      if (rest.length == 10 && rest.startsWith('7')) return '0$rest';
    }
    if (d.length == 12 && d.startsWith('964')) {
      final rest = d.substring(3);
      if (rest.length == 9 && rest.startsWith('7')) return '0$rest';
    }
    return d;
  }

  void _syncGenderControllerFromValue() {
    _genderController.text = switch (_genderValue) {
      'male' => 'نێر',
      'female' => 'مێ',
      _ => '',
    };
  }

  /// Hides messy Firebase-style emails (phone local part, hrnora placeholder, etc.).
  static bool _isSyntheticAuthEmail(String email) {
    final s = email.trim().toLowerCase();
    if (s.isEmpty) return false;
    if (s.contains('hrnora')) return true;
    final parts = s.split('@');
    if (parts.length != 2) return false;
    final local = parts[0].trim();
    if (local.isEmpty) return false;
    final digitsOnly = _digitsOnly(local);
    if (digitsOnly.length >= 10 && digitsOnly == local.replaceAll(RegExp(r'\D'), '')) {
      return true;
    }
    return false;
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

  static bool _isValidEmail(String email) {
    final s = email.trim();
    if (s.isEmpty) return false;
    return RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    ).hasMatch(s);
  }

  static String? _validateEmailField(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'تکایە ئیمەیڵ بنووسە';
    if (!_isValidEmail(s)) return 'شێوازی ئیمەیڵ هەڵەیە';
    return null;
  }

  static String? _validateAgeOptional(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return null;
    final n = int.tryParse(s);
    if (n == null || n < 1 || n > 130) {
      return 'تەمەن دەبێت لە نێوان ١ بۆ ١٣٠ بێت';
    }
    return null;
  }

  static String? _validatePhoneField(String? v) {
    final digits = _digitsOnly(v ?? '');
    if (digits.isEmpty) return 'تکایە ژمارەی مۆبایل بنووسە';
    if (digits.length != 11) {
      return 'ژمارەی مۆبایل دەبێت تەنها ١١ ژمارە بێت';
    }
    return null;
  }

  Future<void> _onGenderCardTap(String value) async {
    if (_saving) return;
    await HapticFeedback.selectionClick();
    setState(() {
      _genderValue = value;
      _genderTapAnim = value;
      _syncGenderControllerFromValue();
    });
    await Future<void>.delayed(const Duration(milliseconds: 220));
    if (mounted) {
      setState(() => _genderTapAnim = null);
    }
  }

  Widget _buildGenderSelectableCards() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ڕەگەز',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 13,
            color: kPatientNavyText.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          textDirection: TextDirection.rtl,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _genderSelectableCard(
                value: 'male',
                label: 'نێر',
                icon: Icons.male_rounded,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _genderSelectableCard(
                value: 'female',
                label: 'مێ',
                icon: Icons.female_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _genderSelectableCard({
    required String value,
    required String label,
    required IconData icon,
  }) {
    final selected = _genderValue == value;
    final pulsing = _genderTapAnim == value;
    final scale = pulsing ? 1.04 : (selected ? 1.02 : 1.0);

    return AnimatedScale(
      scale: scale,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _saving ? null : () => unawaited(_onGenderCardTap(value)),
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 76,
            width: double.infinity,
            child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            decoration: BoxDecoration(
              color: selected ? _kGenderSelectedFill : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: selected
                    ? _kPersonalInfoGold
                    : _kGenderCardGreyBorder,
                width: selected ? 2.2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: selected ? 0.05 : 0.03),
                  blurRadius: selected ? 8 : 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      icon,
                      size: 22,
                      color: selected
                          ? _kPersonalInfoGoldDeep
                          : _kGenderCardGreyIcon,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: selected
                            ? kPatientNavyText.withValues(alpha: 0.92)
                            : kPatientNavyText.withValues(alpha: 0.58),
                      ),
                    ),
                  ],
                ),
                if (selected)
                  PositionedDirectional(
                    top: -2,
                    end: -2,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: _kPersonalInfoGold,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: _kPersonalInfoGold.withValues(alpha: 0.45),
                            blurRadius: 5,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                      child: const Padding(
                        padding: EdgeInsets.all(2.5),
                        child: Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  static const BorderRadius _fieldRadius = BorderRadius.all(
    Radius.circular(14),
  );

  InputDecoration _fieldDecoration({
    required String label,
    required IconData icon,
    required bool focused,
  }) {
    final iconColor = focused
        ? _kPersonalInfoGoldDeep
        : _kPersonalInfoGold.withValues(alpha: 0.72);
    final subtleBorder = const Color(0xFFD6E8F5);
    return InputDecoration(
      labelText: label,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w600,
        fontSize: 14,
        color: kPatientNavyText.withValues(alpha: 0.52),
      ),
      floatingLabelStyle: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w700,
        fontSize: 12.5,
        color: focused
            ? _kPersonalInfoGoldDeep
            : kPatientNavyText.withValues(alpha: 0.55),
      ),
      // In RTL, "start" is the right side — gold icon on the right.
      prefixIcon: Padding(
        padding: const EdgeInsetsDirectional.only(start: 10, end: 6),
        child: Icon(icon, size: 21, color: iconColor),
      ),
      prefixIconConstraints: const BoxConstraints(minWidth: 44, minHeight: 48),
      filled: true,
      fillColor: _kFieldFillTint,
      isDense: false,
      contentPadding: const EdgeInsets.fromLTRB(12, 18, 14, 16),
      border: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(color: subtleBorder.withValues(alpha: 0.65), width: 1),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(
          color: subtleBorder.withValues(alpha: 0.85),
          width: 1,
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _fieldRadius,
        borderSide: BorderSide(
          color: _kPersonalInfoGold.withValues(alpha: 0.85),
          width: 1.6,
        ),
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
    List<TextInputFormatter>? inputFormatters,
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
      inputFormatters: inputFormatters,
      validator: validator,
      style: TextStyle(
        fontFamily: kPatientPrimaryFont,
        fontWeight: FontWeight.w600,
        fontSize: 15,
        color: kPatientNavyText.withValues(alpha: 0.92),
      ),
      decoration: base.copyWith(suffixIcon: suffixIcon),
    );
  }

  /// Non-editable account email when it is a system-generated placeholder.
  Widget _syntheticEmailReadOnlyRow() {
    final email = _emailController.text.trim();
    if (email.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'ئیمەیڵی هەژمار',
          textAlign: TextAlign.right,
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w700,
            fontSize: 12.5,
            color: kPatientNavyText.withValues(alpha: 0.5),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            color: _kFieldFillTint,
            borderRadius: _fieldRadius,
            border: Border.all(
              color: const Color(0xFFD6E8F5).withValues(alpha: 0.9),
            ),
          ),
          child: Row(
            textDirection: TextDirection.rtl,
            children: [
              Icon(
                Icons.alternate_email_rounded,
                size: 20,
                color: _kPersonalInfoGold.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  email,
                  textAlign: TextAlign.right,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w600,
                    fontSize: 13.5,
                    height: 1.35,
                    color: kPatientNavyText.withValues(alpha: 0.72),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
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
    final firstDate = DateTime(1920, 1, 1);
    final initial = _clampDobForPicker(_dob, firstDate, now);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      barrierColor: Colors.black.withValues(alpha: 0.45),
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _PatientDobPickerSheet(
          initialDate: initial,
          firstDate: firstDate,
          lastDate: now,
          onSelect: (picked) {
            if (!mounted) return;
            setState(() {
              _dob = picked;
              _dobController.text = DateFormat('yyyy/MM/dd').format(picked);
            });
            Navigator.of(ctx).pop();
          },
        );
      },
    );
  }

  /// Default to year **2000** when no DOB yet (less scrolling from 2026).
  static DateTime _clampDobForPicker(
    DateTime? existing,
    DateTime first,
    DateTime last,
  ) {
    final base = existing ?? DateTime(2000, 6, 15);
    var d = DateTime(base.year, base.month, base.day);
    if (d.isBefore(first)) return first;
    if (d.isAfter(last)) return last;
    return d;
  }

  Future<void> _save() async {
    if (_saving) return;
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final user = FirebaseAuth.instance.currentUser;
    final docId = _usersDocId(user);
    if (docId.isEmpty) return;

    setState(() => _saving = true);
    try {
      final avatarUrl = await _uploadAvatarIfNeeded(docId);
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _digitsOnly(_phoneController.text);
      final address = _addressController.text.trim();
      final gender = (_genderValue ?? '').trim();

      final ageText = _ageController.text.trim();
      final bloodText = _bloodController.text.trim();

      final update = <String, dynamic>{
        'fullName': name,
        'email': email,
        'phone': phone,
        'address': address,
        if (gender.isNotEmpty) 'gender': gender,
        if (_dob != null) 'dateOfBirth': Timestamp.fromDate(_dob!),
        if (avatarUrl != null && avatarUrl.trim().isNotEmpty)
          'profileImageUrl': avatarUrl.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (ageText.isEmpty) {
        update['ageYears'] = FieldValue.delete();
      } else {
        final n = int.tryParse(ageText);
        if (n != null) update['ageYears'] = n;
      }
      if (bloodText.isEmpty) {
        update['bloodGroup'] = FieldValue.delete();
      } else {
        update['bloodGroup'] = bloodText;
      }
      await FirebaseFirestore.instance.collection('users').doc(docId).set(
            update,
            SetOptions(merge: true),
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            content: const Text(
              'زانیارییەکان بە سەرکەوتوویی نوێکرانەوە',
              style: TextStyle(
                fontFamily: kPatientPrimaryFont,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 450));
        if (mounted) Navigator.of(context).maybePop();
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _editPencilIcon({
    required bool enabled,
    required bool focused,
    required VoidCallback onPressed,
  }) {
    return IconButton(
      tooltip: 'Edit',
      onPressed: enabled && !_saving ? onPressed : null,
      icon: Icon(
        Icons.edit_rounded,
        size: 20,
        color: (focused ? _kPersonalInfoGoldDeep : _kPersonalInfoGold)
            .withValues(alpha: enabled ? 0.85 : 0.35),
      ),
    );
  }

  Future<void> _showPasswordChangeDialog() async {
    if (_saving) return;
    final currentCtrl = TextEditingController();
    final newCtrl = TextEditingController();
    final confirmCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();
    var submitting = false;

    Future<void> submit(StateSetter setLocalState) async {
      if (submitting) return;
      final ok = formKey.currentState?.validate() ?? false;
      if (!ok) return;

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final email = (user.email ?? '').trim();
      if (email.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'نەتوانرا وشەی نهێنی بگۆڕدرێت (ئەم هەژمارە بە ئیمەیڵ/پاسوۆرد نییە).',
              style: TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
        return;
      }

      setLocalState(() => submitting = true);
      try {
        final credential = EmailAuthProvider.credential(
          email: email,
          password: currentCtrl.text.trim(),
        );
        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newCtrl.text.trim());
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'وشەی نهێنی بە سەرکەوتوویی گۆڕدرا',
              style: TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      } on FirebaseAuthException catch (e) {
        if (!mounted) return;
        final msg = switch (e.code) {
          'wrong-password' => 'پاسوۆردی ئێستا هەڵەیە',
          'invalid-credential' => 'پاسوۆردی ئێستا هەڵەیە',
          'too-many-requests' => 'هەوڵ زۆرە، تکایە دواتر هەوڵبدەرەوە',
          _ => 'نەتوانرا وشەی نهێنی بگۆڕدرێت (${e.code})',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              msg,
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      } finally {
        if (mounted) setLocalState(() => submitting = false);
      }
    }

    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setLocalState) {
            return Directionality(
              textDirection: TextDirection.rtl,
              child: AlertDialog(
                backgroundColor: Colors.white,
                surfaceTintColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                title: const Text(
                  'گۆڕینی وشەی نهێنی',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0F172A),
                  ),
                ),
                content: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: currentCtrl,
                        obscureText: true,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'پاسوۆردی ئێستا',
                          prefixIcon: Icon(
                            Icons.lock_outline_rounded,
                            color: _kPersonalInfoGold.withValues(alpha: 0.85),
                          ),
                          filled: true,
                          fillColor: _kFieldFillTint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFFD6E8F5)
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        validator: (v) {
                          if ((v ?? '').trim().isEmpty) {
                            return 'تکایە پاسوۆردی ئێستا بنووسە';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: newCtrl,
                        obscureText: true,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'پاسوۆردی نوێ',
                          prefixIcon: Icon(
                            Icons.lock_rounded,
                            color: _kPersonalInfoGold.withValues(alpha: 0.85),
                          ),
                          filled: true,
                          fillColor: _kFieldFillTint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFFD6E8F5)
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'تکایە پاسوۆردی نوێ بنووسە';
                          if (s.length < 6) return 'پاسوۆرد دەبێت لانیکەم ٦ پیت بێت';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: confirmCtrl,
                        obscureText: true,
                        textAlign: TextAlign.right,
                        decoration: InputDecoration(
                          labelText: 'دووبارەکردنەوەی پاسوۆردی نوێ',
                          prefixIcon: Icon(
                            Icons.verified_user_rounded,
                            color: _kPersonalInfoGold.withValues(alpha: 0.85),
                          ),
                          filled: true,
                          fillColor: _kFieldFillTint,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(14),
                            borderSide: BorderSide(
                              color: const Color(0xFFD6E8F5)
                                  .withValues(alpha: 0.9),
                            ),
                          ),
                        ),
                        validator: (v) {
                          final s = (v ?? '').trim();
                          if (s.isEmpty) return 'تکایە دووبارەی بکەوە';
                          if (s != newCtrl.text.trim()) {
                            return 'پاسوۆردی نوێ و دووبارەکردنەوەکە یەک ناگرن';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  TextButton(
                    onPressed: submitting ? null : () => Navigator.of(ctx).pop(),
                    child: Text(
                      'داخستن',
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w700,
                        color: kPatientNavyText.withValues(alpha: 0.75),
                      ),
                    ),
                  ),
                  FilledButton(
                    onPressed: submitting ? null : () => submit(setLocalState),
                    style: FilledButton.styleFrom(
                      backgroundColor: _kPersonalInfoPrimaryBlue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      textDirection: TextDirection.rtl,
                      children: [
                        const Text(
                          'گۆڕین',
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        if (submitting) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

    currentCtrl.dispose();
    newCtrl.dispose();
    confirmCtrl.dispose();
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
        backgroundColor: _kGradientSkyTop,
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
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                _kGradientSkyTop,
                Color(0xFFE1F5FE),
                _kGradientWhiteBottom,
              ],
              stops: [0.0, 0.45, 1.0],
            ),
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
                                      width: 112,
                                      height: 112,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                        boxShadow: [
                                          BoxShadow(
                                            color:
                                                Colors.black.withValues(alpha: 0.1),
                                            blurRadius: 20,
                                            offset: const Offset(0, 10),
                                          ),
                                        ],
                                        border: Border.all(
                                          color: _kPersonalInfoGold,
                                          width: 5,
                                        ),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(3),
                                        child: CircleAvatar(
                                          radius: 48,
                                          backgroundImage: avatarImage,
                                          backgroundColor: const Color(0xFFE8F4FC),
                                          child: avatarImage == null
                                              ? Icon(
                                                  Icons.person_rounded,
                                                  size: 44,
                                                  color: kPatientNavyText
                                                      .withValues(alpha: 0.35),
                                                )
                                              : null,
                                        ),
                                      ),
                                    ),
                                    PositionedDirectional(
                                      bottom: 0,
                                      end: 0,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: _kPersonalInfoGold,
                                          border: Border.all(
                                            color: Colors.white,
                                            width: 2,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: _kPersonalInfoGold
                                                  .withValues(alpha: 0.45),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: Icon(
                                          Icons.photo_camera_rounded,
                                          color: Colors.white.withValues(alpha: 0.95),
                                          size: 14,
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
                                color: Colors.white.withValues(alpha: 0.94),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.05),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              padding: const EdgeInsets.fromLTRB(18, 20, 18, 22),
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
                                      readOnly: !_editingName,
                                      onTap: () {
                                        if (_editingName || _saving) return;
                                        setState(() => _editingName = true);
                                        _nameFocus.requestFocus();
                                      },
                                      suffixIcon: _editPencilIcon(
                                        enabled: true,
                                        focused: _nameFocus.hasFocus,
                                        onPressed: () {
                                          setState(() => _editingName = true);
                                          _nameFocus.requestFocus();
                                        },
                                      ),
                                      validator: (v) {
                                        if ((v ?? '').trim().isEmpty) {
                                          return 'تکایە ناوی تەواوت بنووسە';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 14),
                                    if (_syntheticEmailDisplay) ...[
                                      _syntheticEmailReadOnlyRow(),
                                    ] else ...[
                                      _miniCardField(
                                        controller: _emailController,
                                        focusNode: _emailFocus,
                                        label: 'ئیمەیڵ',
                                        icon: Icons.alternate_email_rounded,
                                        keyboardType: TextInputType.emailAddress,
                                        readOnly: !_editingEmail,
                                        onTap: () {
                                          if (_editingEmail || _saving) return;
                                          setState(() => _editingEmail = true);
                                          _emailFocus.requestFocus();
                                        },
                                        suffixIcon: _editPencilIcon(
                                          enabled: true,
                                          focused: _emailFocus.hasFocus,
                                          onPressed: () {
                                            setState(() => _editingEmail = true);
                                            _emailFocus.requestFocus();
                                          },
                                        ),
                                        validator: _validateEmailField,
                                      ),
                                    ],
                                    const SizedBox(height: 14),
                                    _miniCardField(
                                      controller: _phoneController,
                                      focusNode: _phoneFocus,
                                      label: 'ژمارەی مۆبایل',
                                      icon: Icons.phone_android_rounded,
                                      keyboardType: TextInputType.phone,
                                      readOnly: !_editingPhone,
                                      onTap: () {
                                        if (_editingPhone || _saving) return;
                                        setState(() => _editingPhone = true);
                                        _phoneFocus.requestFocus();
                                      },
                                      suffixIcon: _editPencilIcon(
                                        enabled: true,
                                        focused: _phoneFocus.hasFocus,
                                        onPressed: () {
                                          setState(() => _editingPhone = true);
                                          _phoneFocus.requestFocus();
                                        },
                                      ),
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(11),
                                      ],
                                      validator: _validatePhoneField,
                                    ),
                                    const SizedBox(height: 14),
                                    _miniCardField(
                                      controller: _passwordMaskController,
                                      focusNode: _passwordMaskFocus,
                                      label: 'وشەی نهێنی',
                                      icon: Icons.lock_rounded,
                                      readOnly: true,
                                      obscureText: false,
                                      onTap: _showPasswordChangeDialog,
                                      suffixIcon: _editPencilIcon(
                                        enabled: true,
                                        focused: _passwordMaskFocus.hasFocus,
                                        onPressed: _showPasswordChangeDialog,
                                      ),
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
                                    _buildGenderSelectableCards(),
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
                                              ? _kPersonalInfoGoldDeep
                                              : _kPersonalInfoGold
                                                  .withValues(alpha: 0.65),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 14),
                                    _miniCardField(
                                      controller: _ageController,
                                      focusNode: _ageFocus,
                                      label: 'تەمەن (ساڵ)',
                                      icon: Icons.cake_outlined,
                                      keyboardType: TextInputType.number,
                                      inputFormatters: [
                                        FilteringTextInputFormatter.digitsOnly,
                                        LengthLimitingTextInputFormatter(3),
                                      ],
                                      validator: _validateAgeOptional,
                                    ),
                                    const SizedBox(height: 14),
                                    _miniCardField(
                                      controller: _bloodController,
                                      focusNode: _bloodFocus,
                                      label: 'گرووپی خوێن (وەک A+)',
                                      icon: Icons.bloodtype_rounded,
                                    ),
                                    const SizedBox(height: 22),
                                    SizedBox(
                                      height: 56,
                                      child: ElevatedButton(
                                        onPressed: _saving ? null : _save,
                                        style: ElevatedButton.styleFrom(
                                          padding: EdgeInsets.zero,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(18),
                                          ),
                                          backgroundColor: Colors.transparent,
                                          elevation: 0,
                                        ),
                                        child: Ink(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(18),
                                            gradient: const LinearGradient(
                                              begin: Alignment.topLeft,
                                              end: Alignment.bottomRight,
                                              colors: [
                                                Color(0xFFE8C547),
                                                _kPersonalInfoGold,
                                                _kPersonalInfoGoldDeep,
                                              ],
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: _kPersonalInfoGoldDeep
                                                    .withValues(alpha: 0.35),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: Center(
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              textDirection: TextDirection.rtl,
                                              children: [
                                                const Text(
                                                  'Update Info',
                                                  style: TextStyle(
                                                    fontFamily:
                                                        kPatientPrimaryFont,
                                                    fontWeight: FontWeight.w800,
                                                    fontSize: 16,
                                                    color: Colors.white,
                                                    letterSpacing: 0.3,
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

/// Glass-style bottom sheet with [CupertinoDatePicker] wheels (no Material OK/Cancel).
class _PatientDobPickerSheet extends StatefulWidget {
  const _PatientDobPickerSheet({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    required this.onSelect,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final ValueChanged<DateTime> onSelect;

  @override
  State<_PatientDobPickerSheet> createState() => _PatientDobPickerSheetState();
}

class _PatientDobPickerSheetState extends State<_PatientDobPickerSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
  }

  LinearGradient get _primaryGradient => const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0xFFE8C547),
          _kPersonalInfoGold,
          _kPersonalInfoGoldDeep,
        ],
      );

  @override
  Widget build(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    final pickerStyle = TextStyle(
      fontFamily: kPatientPrimaryFont,
      fontWeight: FontWeight.w600,
      fontSize: 17,
      height: 1.2,
      color: kPatientNavyText.withValues(alpha: 0.88),
    );

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Padding(
        padding: EdgeInsets.only(bottom: bottomSafe > 0 ? bottomSafe : 8),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 22, sigmaY: 22),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.82),
                border: Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.7),
                    width: 1,
                  ),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.14),
                    blurRadius: 28,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: kPatientNavyText.withValues(alpha: 0.16),
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'بەرواری لەدایکبوون',
                      style: TextStyle(
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w800,
                        fontSize: 17.5,
                        color: kPatientNavyText.withValues(alpha: 0.92),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 216,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                            child: Container(
                              height: 42,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(14),
                                gradient: LinearGradient(
                                  colors: [
                                    _kPersonalInfoGold.withValues(alpha: 0.22),
                                    const Color(0xFFE1F5FE)
                                        .withValues(alpha: 0.65),
                                    _kPersonalInfoGold.withValues(alpha: 0.18),
                                  ],
                                ),
                                border: Border.all(
                                  color: _kPersonalInfoGold.withValues(alpha: 0.55),
                                  width: 1.4,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _kPersonalInfoGold
                                        .withValues(alpha: 0.18),
                                    blurRadius: 12,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          CupertinoTheme(
                            data: CupertinoThemeData(
                              brightness: Brightness.light,
                              primaryColor: _kPersonalInfoGold,
                              textTheme: CupertinoTextThemeData(
                                dateTimePickerTextStyle: pickerStyle,
                              ),
                            ),
                            child: CupertinoDatePicker(
                              mode: CupertinoDatePickerMode.date,
                              initialDateTime: _selected,
                              minimumDate: widget.firstDate,
                              maximumDate: widget.lastDate,
                              backgroundColor: Colors.transparent,
                              onDateTimeChanged: (d) {
                                setState(() => _selected = d);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: _primaryGradient,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.14),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(18),
                            onTap: () => widget.onSelect(_selected),
                            child: Center(
                              child: Text(
                                'هەڵبژاردن',
                                style: TextStyle(
                                  fontFamily: kPatientPrimaryFont,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16,
                                  color: Colors.white,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(alpha: 0.22),
                                      blurRadius: 6,
                                      offset: const Offset(0, 1),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
