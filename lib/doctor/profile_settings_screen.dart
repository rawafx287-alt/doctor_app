import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../calendar/calendar_slot_logic.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../specialty_categories.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameKuController = TextEditingController();
  final TextEditingController _fullNameArController = TextEditingController();
  final TextEditingController _fullNameEnController = TextEditingController();
  final TextEditingController _consultationFeeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _yearsExperienceController = TextEditingController();

  final TextEditingController _bioKuController = TextEditingController();
  final TextEditingController _bioArController = TextEditingController();
  final TextEditingController _bioEnController = TextEditingController();

  final TextEditingController _addressKuController = TextEditingController();
  final TextEditingController _addressArController = TextEditingController();
  final TextEditingController _addressEnController = TextEditingController();

  final TextEditingController _hospitalKuController = TextEditingController();
  final TextEditingController _hospitalArController = TextEditingController();
  final TextEditingController _hospitalEnController = TextEditingController();

  final TextEditingController _experienceKuController = TextEditingController();
  final TextEditingController _experienceArController = TextEditingController();
  final TextEditingController _experienceEnController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  int _appointmentSlotMinutes = 30;
  String? _selectedSpecialty;
  String _profileImageUrl = '';
  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  static String _firstOf(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final t = (data[k] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameKuController.dispose();
    _fullNameArController.dispose();
    _fullNameEnController.dispose();
    _consultationFeeController.dispose();
    _phoneController.dispose();
    _yearsExperienceController.dispose();
    _bioKuController.dispose();
    _bioArController.dispose();
    _bioEnController.dispose();
    _addressKuController.dispose();
    _addressArController.dispose();
    _addressEnController.dispose();
    _hospitalKuController.dispose();
    _hospitalArController.dispose();
    _hospitalEnController.dispose();
    _experienceKuController.dispose();
    _experienceArController.dispose();
    _experienceEnController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final data = doc.data() ?? <String, dynamic>{};

      _fullNameKuController.text = _firstOf(data, ['fullName_ku', 'fullName']);
      _fullNameArController.text = (data['fullName_ar'] ?? '').toString();
      _fullNameEnController.text = (data['fullName_en'] ?? '').toString();
      final spec = (data['specialty'] ?? '').toString().trim();
      _selectedSpecialty = kDoctorSpecialtyOptions.contains(spec) ? spec : null;
      _profileImageUrl = (data['profileImageUrl'] ?? '').toString().trim();
      _consultationFeeController.text = (data['consultationFee'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();

      _bioKuController.text = _firstOf(data, ['bio_ku', 'biography', 'about']);
      _bioArController.text = (data['bio_ar'] ?? '').toString();
      _bioEnController.text = (data['bio_en'] ?? '').toString();

      _addressKuController.text = _firstOf(data, ['address_ku', 'clinicAddress']);
      _addressArController.text = (data['address_ar'] ?? '').toString();
      _addressEnController.text = (data['address_en'] ?? '').toString();

      _hospitalKuController.text =
          _firstOf(data, ['hospital_name_ku', 'clinicName', 'hospitalName']);
      _hospitalArController.text = (data['hospital_name_ar'] ?? '').toString();
      _hospitalEnController.text = (data['hospital_name_en'] ?? '').toString();

      _experienceKuController.text = (data['experience_ku'] ?? '').toString();
      _experienceArController.text = (data['experience_ar'] ?? '').toString();
      _experienceEnController.text = (data['experience_en'] ?? '').toString();

      final rawY = data['yearsExperience'];
      if (rawY is int) {
        _yearsExperienceController.text = rawY > 0 ? '$rawY' : '';
      } else if (rawY is num) {
        final i = rawY.toInt();
        _yearsExperienceController.text = i > 0 ? '$i' : '';
      } else {
        _yearsExperienceController.text = '';
      }

      _appointmentSlotMinutes =
          appointmentSlotMinutesFromUserData(data);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('profile_load_error'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    final s = S.of(context);
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_user_missing'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final bioKu = _bioKuController.text.trim();
      final addressKu = _addressKuController.text.trim();
      final nameKu = _fullNameKuController.text.trim();

      final payload = <String, dynamic>{
        'fullName_ku': nameKu,
        'fullName_ar': _fullNameArController.text.trim(),
        'fullName_en': _fullNameEnController.text.trim(),
        'fullName': nameKu,
        'specialty': (_selectedSpecialty ?? '').trim(),
        'consultationFee': _consultationFeeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'bio_ku': bioKu,
        'bio_ar': _bioArController.text.trim(),
        'bio_en': _bioEnController.text.trim(),
        'address_ku': addressKu,
        'address_ar': _addressArController.text.trim(),
        'address_en': _addressEnController.text.trim(),
        'hospital_name_ku': _hospitalKuController.text.trim(),
        'hospital_name_ar': _hospitalArController.text.trim(),
        'hospital_name_en': _hospitalEnController.text.trim(),
        'experience_ku': _experienceKuController.text.trim(),
        'experience_ar': _experienceArController.text.trim(),
        'experience_en': _experienceEnController.text.trim(),
        'biography': bioKu,
        'clinicAddress': addressKu,
      };

      final yParsed = int.tryParse(_yearsExperienceController.text.trim());
      if (yParsed != null && yParsed > 0) {
        payload['yearsExperience'] = yParsed;
      } else {
        payload['yearsExperience'] = 0;
      }

      payload[kAppointmentSlotMinutesField] = _appointmentSlotMinutes;

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
            payload,
            SetOptions(merge: true),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_saved_ok'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadProfileImageToFirebase(XFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    final s = S.of(context);
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_user_missing'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      return;
    }

    setState(() => _isUploadingImage = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('${user.uid}.jpg');

      await storageRef.putData(await file.readAsBytes());
      final downloadUrl = await storageRef.getDownloadURL();

      await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
        {'profileImageUrl': downloadUrl},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => _profileImageUrl = downloadUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_image_upload_ok'),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${S.of(context).translate('profile_image_upload_error')}: $e',
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploadingImage = false);
    }
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: source,
      imageQuality: 80,
      maxWidth: 1200,
    );
    if (picked == null) return;
    await _uploadProfileImageToFirebase(picked);
  }

  Future<void> _showImageSourceSheet() async {
    final s = S.of(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: const Color(0xFF1D1E33),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) => SafeArea(
        child: Directionality(
          textDirection: AppLocaleScope.of(context).textDirection,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.photo_library_rounded, color: Color(0xFF42A5F5)),
                title: Text(
                  s.translate('image_source_gallery'),
                  style: const TextStyle(
                    fontFamily: 'KurdishFont',
                    color: Color(0xFFD9E2EC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.gallery);
                },
              ),
              ListTile(
                leading: const Icon(Icons.camera_alt_rounded, color: Color(0xFF42A5F5)),
                title: Text(
                  s.translate('image_source_camera'),
                  style: const TextStyle(
                    fontFamily: 'KurdishFont',
                    color: Color(0xFFD9E2EC),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  _pickImage(ImageSource.camera);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String translationKey) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Text(
        S.of(context).translate(translationKey),
        style: const TextStyle(
          color: Color(0xFF42A5F5),
          fontSize: 14,
          fontWeight: FontWeight.w800,
          fontFamily: 'KurdishFont',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: const Color(0xFFD9E2EC),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: s.translate('tooltip_back'),
          ),
          title: Text(
            s.translate('doctor_profile_settings_title'),
            style: const TextStyle(
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 6),
                      Center(
                        child: SizedBox(
                          width: 100,
                          height: 100,
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              CircleAvatar(
                                radius: 48,
                                backgroundColor: const Color(0xFF1D1E33),
                                backgroundImage: NetworkImage(
                                  _profileImageUrl.isNotEmpty
                                      ? _profileImageUrl
                                      : _placeholderImageUrl,
                                ),
                                child: _profileImageUrl.isEmpty
                                    ? const Icon(
                                        Icons.medical_services_rounded,
                                        color: Color(0xFF42A5F5),
                                        size: 30,
                                      )
                                    : null,
                              ),
                              if (_isUploadingImage)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(48),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: Color(0xFF42A5F5),
                                      ),
                                    ),
                                  ),
                                ),
                              PositionedDirectional(
                                bottom: -2,
                                end: -2,
                                child: Material(
                                  color: const Color(0xFF42A5F5),
                                  shape: const CircleBorder(),
                                  elevation: 2,
                                  child: InkWell(
                                    customBorder: const CircleBorder(),
                                    onTap: _isUploadingImage ? null : _showImageSourceSheet,
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Icon(
                                        _profileImageUrl.isEmpty
                                            ? Icons.camera_alt_rounded
                                            : Icons.edit_rounded,
                                        color: const Color(0xFF102A43),
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      KurdishDoctorSpecialtyDropdown(
                        dense: true,
                        value: _selectedSpecialty,
                        onChanged: (v) => setState(() => _selectedSpecialty = v),
                        validator: (v) => v == null || v.isEmpty
                            ? s.translate('validation_specialty_required')
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _consultationFeeController,
                        label: s.translate('doctor_consultation_fee_label'),
                        icon: Icons.payments_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      _field(
                        controller: _phoneController,
                        label: s.translate('doctor_phone_label'),
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: Text(
                          s.translate('profile_appointment_duration_label'),
                          style: const TextStyle(
                            color: Color(0xFF829AB1),
                            fontSize: 12,
                            fontFamily: 'KurdishFont',
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<int>(
                        value: _appointmentSlotMinutes,
                        dropdownColor: const Color(0xFF1D1E33),
                        style: const TextStyle(
                          color: Color(0xFFD9E2EC),
                          fontFamily: 'KurdishFont',
                        ),
                        decoration: InputDecoration(
                          prefixIcon: const Icon(
                            Icons.schedule_rounded,
                            color: Color(0xFF42A5F5),
                          ),
                          filled: true,
                          fillColor: const Color(0xFF1D1E33),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Colors.white24),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: const BorderSide(color: Color(0xFF42A5F5)),
                          ),
                        ),
                        items: [15, 20, 30]
                            .map(
                              (m) => DropdownMenuItem(
                                value: m,
                                child: Text(
                                  '$m ${s.translate('profile_appointment_duration_unit')}',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _appointmentSlotMinutes = v);
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          s.translate('profile_appointment_duration_hint'),
                          style: const TextStyle(
                            color: Color(0xFF64748B),
                            fontSize: 11,
                            fontFamily: 'KurdishFont',
                            height: 1.35,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _sectionTitle('editor_section_kurdish'),
                      _field(
                        controller: _fullNameKuController,
                        label: s.translate('doctor_field_full_name'),
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _bioKuController,
                        label: s.translate('doctor_field_bio'),
                        icon: Icons.info_outline_rounded,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _addressKuController,
                        label: s.translate('doctor_field_address'),
                        icon: Icons.location_on_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _hospitalKuController,
                        label: s.translate('doctor_field_hospital'),
                        icon: Icons.local_hospital_rounded,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _experienceKuController,
                        label: s.translate('doctor_field_experience'),
                        icon: Icons.work_history_rounded,
                        maxLines: 3,
                      ),
                      _sectionTitle('editor_section_arabic'),
                      _field(
                        controller: _fullNameArController,
                        label: s.translate('doctor_field_full_name'),
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _bioArController,
                        label: s.translate('doctor_field_bio'),
                        icon: Icons.info_outline_rounded,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _addressArController,
                        label: s.translate('doctor_field_address'),
                        icon: Icons.location_on_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _hospitalArController,
                        label: s.translate('doctor_field_hospital'),
                        icon: Icons.local_hospital_rounded,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _experienceArController,
                        label: s.translate('doctor_field_experience'),
                        icon: Icons.work_history_rounded,
                        maxLines: 3,
                      ),
                      _sectionTitle('editor_section_english'),
                      _field(
                        controller: _fullNameEnController,
                        label: s.translate('doctor_field_full_name'),
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _bioEnController,
                        label: s.translate('doctor_field_bio'),
                        icon: Icons.info_outline_rounded,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _addressEnController,
                        label: s.translate('doctor_field_address'),
                        icon: Icons.location_on_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _hospitalEnController,
                        label: s.translate('doctor_field_hospital'),
                        icon: Icons.local_hospital_rounded,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _experienceEnController,
                        label: s.translate('doctor_field_experience'),
                        icon: Icons.work_history_rounded,
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      _field(
                        controller: _yearsExperienceController,
                        label: s.translate('doctor_field_years_numeric'),
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 18),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF42A5F5),
                          foregroundColor: const Color(0xFF102A43),
                          minimumSize: const Size(double.infinity, 56),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(strokeWidth: 2.2),
                              )
                            : Text(
                                s.translate('profile_save_changes'),
                                style: const TextStyle(
                                  fontFamily: 'KurdishFont',
                                  fontWeight: FontWeight.w700,
                                  fontSize: 16,
                                ),
                              ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          color: Color(0xFFD9E2EC),
          fontFamily: 'KurdishFont',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(
            color: Color(0xFF829AB1),
            fontFamily: 'KurdishFont',
          ),
          prefixIcon: Icon(icon, color: const Color(0xFF42A5F5)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}
