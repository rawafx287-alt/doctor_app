import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../auth/doctor_session_cache.dart';
import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_profile_fields.dart';
import '../specialty_categories.dart';
import '../widgets/doctor_city_dropdown.dart';
import '../theme/staff_premium_theme.dart';
import 'doctor_premium_shell.dart';

const Color _kDoctorProfileGold = kStaffLuxGold;
const Color _kDoctorProfileBronze = kStaffLuxGoldDark;

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameKuController = TextEditingController();
  final TextEditingController _consultationFeeController =
      TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _yearsExperienceController =
      TextEditingController();

  final TextEditingController _bioKuController = TextEditingController();

  final TextEditingController _addressKuController = TextEditingController();

  /// Shown on patient home doctor cards (`users.hospitalName`).
  final TextEditingController _hospitalNameCardController =
      TextEditingController();

  /// Google Maps link for clinic (`users.googleMapsUrl`).
  final TextEditingController _googleMapsUrlController =
      TextEditingController();

  final TextEditingController _experienceKuController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _selectedSpecialty;
  String? _selectedCity;

  String _profileImageUrl = '';

  static String _firstOf(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final t = (data[k] ?? '').toString().trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }

  /// Firestore `users` doc id: [FirebaseAuth] user when present, else [DoctorSessionCache]
  /// (doctor phone/password login does not create a Firebase session).
  Future<String?> _resolveUsersCollectionDocId({
    required bool showErrorSnack,
  }) async {
    final s = S.of(context);
    final user = FirebaseAuth.instance.currentUser;

    if (user != null) {
      try {
        await user.reload();
      } on FirebaseAuthException catch (e) {
        if (!mounted) return null;
        if (showErrorSnack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                s.translate(
                  'profile_error_auth_refresh',
                  params: {'code': e.code},
                ),
                style: const TextStyle(fontFamily: kPatientPrimaryFont),
              ),
            ),
          );
        }
        return null;
      } catch (_) {
        // Offline / transient — keep using current snapshot.
      }

      var id = firestoreUserDocId(user).trim();
      if (id.isEmpty) {
        id = user.uid.trim();
      }
      if (id.isEmpty) {
        if (mounted && showErrorSnack) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                s.translate('profile_error_resolve_empty_doc_id'),
                style: const TextStyle(fontFamily: kPatientPrimaryFont),
              ),
            ),
          );
        }
        return null;
      }
      return id;
    }

    final cached = (await DoctorSessionCache.readDoctorRefId())?.trim() ?? '';
    if (cached.isNotEmpty) return cached;

    if (mounted && showErrorSnack) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_error_resolve_no_firebase_or_cache'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    }
    return null;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadProfile();
    });
  }

  @override
  void dispose() {
    _fullNameKuController.dispose();
    _consultationFeeController.dispose();
    _phoneController.dispose();
    _yearsExperienceController.dispose();
    _bioKuController.dispose();
    _addressKuController.dispose();
    _hospitalNameCardController.dispose();
    _googleMapsUrlController.dispose();
    _experienceKuController.dispose();
    super.dispose();
  }

  Future<void> _loadProfile() async {
    final docId = await _resolveUsersCollectionDocId(showErrorSnack: true);
    if (docId == null || docId.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .get();
      final data = doc.data() ?? <String, dynamic>{};

      _fullNameKuController.text = _firstOf(data, ['fullName_ku', 'fullName']);
      final spec = (data['specialty'] ?? '').toString().trim();
      _selectedSpecialty = kDoctorSpecialtyOptions.contains(spec) ? spec : null;
      final cityRaw = doctorCityFromUserData(data);
      _selectedCity = cityRaw.isEmpty ? null : cityRaw;
      _profileImageUrl = (data['profileImageUrl'] ?? '').toString().trim();
      _consultationFeeController.text = (data['consultationFee'] ?? '')
          .toString();
      _phoneController.text = (data['phone'] ?? '').toString();

      _bioKuController.text = _firstOf(data, ['bio_ku', 'biography', 'about']);

      _addressKuController.text = _firstOf(data, [
        'address_ku',
        'clinicAddress',
      ]);

      _hospitalNameCardController.text = _firstOf(data, [
        'hospitalName',
        'hospital_name_ku',
        'clinicName',
      ]);

      _googleMapsUrlController.text =
          (data[kDoctorGoogleMapsUrlField] ?? '').toString();

      _experienceKuController.text = (data['experience_ku'] ?? '').toString();

      final rawY = data['yearsExperience'];
      if (rawY is int) {
        _yearsExperienceController.text = rawY > 0 ? '$rawY' : '';
      } else if (rawY is num) {
        final i = rawY.toInt();
        _yearsExperienceController.text = i > 0 ? '$i' : '';
      } else {
        _yearsExperienceController.text = '';
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('profile_load_error'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    final s = S.of(context);
    final docId = await _resolveUsersCollectionDocId(showErrorSnack: true);
    if (docId == null || docId.isEmpty) return;

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      final bioKu = _bioKuController.text.trim();
      final addressKu = _addressKuController.text.trim();
      final nameKu = _fullNameKuController.text.trim();
      final hospitalDisplay = _hospitalNameCardController.text.trim();

      final payload = <String, dynamic>{
        'fullName_ku': nameKu,
        'fullName': nameKu,
        'specialty': (_selectedSpecialty ?? '').trim(),
        'consultationFee': _consultationFeeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'payment_fib_number': FieldValue.delete(),
        'payment_fastpay_number': FieldValue.delete(),
        'bio_ku': bioKu,
        'address_ku': addressKu,
        'hospital_name_ku': hospitalDisplay,
        'hospitalName': hospitalDisplay,
        'experience_ku': _experienceKuController.text.trim(),
        'biography': bioKu,
        'clinicAddress': addressKu,
        kDoctorGoogleMapsUrlField: _googleMapsUrlController.text.trim(),
        kDoctorCityField: (_selectedCity ?? '').trim(),
      };

      final yParsed = int.tryParse(_yearsExperienceController.text.trim());
      if (yParsed != null && yParsed > 0) {
        payload['yearsExperience'] = yParsed;
      } else {
        payload['yearsExperience'] = 0;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(docId)
          .set(payload, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_saved_ok'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _uploadProfileImageToFirebase(XFile file) async {
    final s = S.of(context);
    final user = FirebaseAuth.instance.currentUser;
    final docId = await _resolveUsersCollectionDocId(showErrorSnack: true);
    if (docId == null || docId.isEmpty) return;

    setState(() => _isUploadingImage = true);
    try {
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('profile_pictures')
          .child('$docId.jpg');

      await storageRef.putData(await file.readAsBytes());
      final downloadUrl = await storageRef.getDownloadURL();

      final uid = user?.uid.trim() ?? '';
      if (uid.isNotEmpty && uid != docId) {
        await FirebaseFirestore.instance.collection('users').doc(uid).set({
          'profileImageUrl': downloadUrl,
        }, SetOptions(merge: true));
      }
      await FirebaseFirestore.instance.collection('users').doc(docId).set({
        'profileImageUrl': downloadUrl,
      }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() => _profileImageUrl = downloadUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_image_upload_ok'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${S.of(context).translate('profile_image_upload_error')}: $e',
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
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
      backgroundColor: Colors.black.withValues(alpha: 0.35),
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
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: _kDoctorProfileGold,
                ),
                title: Text(
                  s.translate('image_source_gallery'),
                  style: const TextStyle(
                    fontFamily: kPatientPrimaryFont,
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
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: _kDoctorProfileGold,
                ),
                title: Text(
                  s.translate('image_source_camera'),
                  style: const TextStyle(
                    fontFamily: kPatientPrimaryFont,
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

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: kDoctorPremiumGradientBottom,
        extendBodyBehindAppBar: false,
        appBar: doctorPremiumAppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded),
            onPressed: () => Navigator.pop(context),
            tooltip: s.translate('tooltip_back'),
          ),
          title: Text(
            s.translate('doctor_profile_settings_title'),
            style: const TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              color: Colors.white,
              fontSize: 17,
            ),
          ),
        ),
        body: _isLoading
            ? const Stack(
                fit: StackFit.expand,
                children: [
                  DoctorPremiumBackground(),
                  Center(
                    child: CircularProgressIndicator(color: kStaffLuxGold),
                  ),
                ],
              )
            : Stack(
                fit: StackFit.expand,
                children: [
                  const DoctorPremiumBackground(),
                  SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      16,
                      20,
                      16,
                      24 + MediaQuery.paddingOf(context).bottom,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: 12),
                          Center(
                            child: SizedBox(
                              width: 88,
                              height: 88,
                              child: Stack(
                                clipBehavior: Clip.none,
                                alignment: Alignment.center,
                                children: [
                                  CircleAvatar(
                                    radius: 42,
                                    backgroundColor: kDoctorPremiumGradientTop,
                                    backgroundImage: _profileImageUrl.isNotEmpty
                                        ? NetworkImage(_profileImageUrl)
                                        : null,
                                    child: _profileImageUrl.isEmpty
                                        ? const Icon(
                                            Icons.medical_services_rounded,
                                            color: kStaffLuxGold,
                                            size: 28,
                                          )
                                        : null,
                                  ),
                                  if (_isUploadingImage)
                                    Positioned.fill(
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.black54,
                                          borderRadius: BorderRadius.circular(
                                            42,
                                          ),
                                        ),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: kStaffLuxGold,
                                          ),
                                        ),
                                      ),
                                    ),
                                  PositionedDirectional(
                                    bottom: -2,
                                    end: -2,
                                    child: Material(
                                      color: _kDoctorProfileBronze,
                                      shape: const CircleBorder(),
                                      elevation: 2,
                                      child: InkWell(
                                        customBorder: const CircleBorder(),
                                        onTap: _isUploadingImage
                                            ? null
                                            : _showImageSourceSheet,
                                        child: Padding(
                                          padding: const EdgeInsets.all(7),
                                          child: Icon(
                                            _profileImageUrl.isEmpty
                                                ? Icons.camera_alt_rounded
                                                : Icons.edit_rounded,
                                            color: const Color(0xFF102A43),
                                            size: 20,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          KurdishDoctorSpecialtyDropdown(
                            dense: true,
                            accentColor: _kDoctorProfileGold,
                            value: _selectedSpecialty,
                            onChanged: (v) =>
                                setState(() => _selectedSpecialty = v),
                            validator: (v) => v == null || v.isEmpty
                                ? s.translate('validation_specialty_required')
                                : null,
                          ),
                          const SizedBox(height: 12),
                          DoctorCityDropdown(
                            dense: true,
                            accentColor: _kDoctorProfileGold,
                            value: _selectedCity,
                            onChanged: (v) =>
                                setState(() => _selectedCity = v),
                            validator: (v) => v == null || v.isEmpty
                                ? s.translate('validation_city_required')
                                : null,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _hospitalNameCardController,
                            label: s.translate(
                              'doctor_field_hospital_display_simple',
                            ),
                            icon: Icons.local_hospital_rounded,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _googleMapsUrlController,
                            label: s.translate(
                              'doctor_field_google_maps_link',
                            ),
                            hintText:
                                'لینکی لۆکەیشنی کلینیک (Google Maps)',
                            icon: Icons.link_rounded,
                            keyboardType: TextInputType.url,
                            suffixIcon: Icon(
                              Icons.location_on_rounded,
                              color: _kDoctorProfileGold,
                            ),
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
                          _field(
                            controller: _fullNameKuController,
                            label: s.translate('doctor_field_full_name'),
                            icon: Icons.person_rounded,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _bioKuController,
                            label: s.translate('doctor_field_bio'),
                            icon: Icons.info_outline_rounded,
                            maxLines: 4,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _addressKuController,
                            label: s.translate('doctor_field_address'),
                            icon: Icons.location_on_rounded,
                            maxLines: 2,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _experienceKuController,
                            label: s.translate('doctor_field_experience'),
                            icon: Icons.work_history_rounded,
                            maxLines: 3,
                          ),
                          const SizedBox(height: 12),
                          _field(
                            controller: _yearsExperienceController,
                            label: s.translate('doctor_field_years_numeric'),
                            icon: Icons.numbers_rounded,
                            keyboardType: TextInputType.number,
                          ),
                          const SizedBox(height: 16),
                          StaffGoldGradientButton(
                            label: s.translate('profile_save_changes'),
                            onPressed: _isSaving ? null : _saveChanges,
                            isLoading: _isSaving,
                            fontSize: 16,
                            borderRadius: 16,
                            minHeight: 52,
                            padding: const EdgeInsets.symmetric(
                              vertical: 14,
                              horizontal: 24,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    String? hintText,
    TextInputType keyboardType = TextInputType.text,
    int maxLines = 1,
    Widget? suffixIcon,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: kStaffSilverBorder,
          width: kStaffCardOutlineWidth,
        ),
      ),
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        style: const TextStyle(
          color: Color(0xFFD9E2EC),
          fontFamily: kPatientPrimaryFont,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: hintText ?? label,
          hintStyle: const TextStyle(
            color: Color(0xFF829AB1),
            fontFamily: kPatientPrimaryFont,
          ),
          prefixIcon: Icon(icon, color: _kDoctorProfileGold),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 16,
          ),
        ),
      ),
    );
  }
}
