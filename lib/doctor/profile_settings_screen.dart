import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../firestore/hospital_queries.dart';
import '../auth/firestore_user_doc_id.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/hospital_localized_content.dart';
import '../specialty_categories.dart';

const Color _kDoctorProfileGold = Color(0xFFD4AF37);
const Color _kDoctorProfileBronze = Color(0xFFB8860B);

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
  final TextEditingController _fibNumberController = TextEditingController();
  final TextEditingController _fastPayNumberController = TextEditingController();

  final TextEditingController _bioKuController = TextEditingController();
  final TextEditingController _bioArController = TextEditingController();
  final TextEditingController _bioEnController = TextEditingController();

  final TextEditingController _addressKuController = TextEditingController();
  final TextEditingController _addressArController = TextEditingController();
  final TextEditingController _addressEnController = TextEditingController();

  final TextEditingController _hospitalKuController = TextEditingController();
  final TextEditingController _hospitalArController = TextEditingController();
  final TextEditingController _hospitalEnController = TextEditingController();
  /// Shown on patient home doctor cards (`users.hospitalName`).
  final TextEditingController _hospitalNameCardController =
      TextEditingController();

  final TextEditingController _experienceKuController = TextEditingController();
  final TextEditingController _experienceArController = TextEditingController();
  final TextEditingController _experienceEnController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _selectedSpecialty;
  /// Firestore `hospitals` document id; shown in patient app hospital filter.
  String? _selectedHospitalId;
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
    _fibNumberController.dispose();
    _fastPayNumberController.dispose();
    _bioKuController.dispose();
    _bioArController.dispose();
    _bioEnController.dispose();
    _addressKuController.dispose();
    _addressArController.dispose();
    _addressEnController.dispose();
    _hospitalKuController.dispose();
    _hospitalArController.dispose();
    _hospitalEnController.dispose();
    _hospitalNameCardController.dispose();
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

    final docId = firestoreUserDocId(user).trim();
    if (docId.isEmpty) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final data = doc.data() ?? <String, dynamic>{};

      _fullNameKuController.text = _firstOf(data, ['fullName_ku', 'fullName']);
      _fullNameArController.text = (data['fullName_ar'] ?? '').toString();
      _fullNameEnController.text = (data['fullName_en'] ?? '').toString();
      final spec = (data['specialty'] ?? '').toString().trim();
      _selectedSpecialty = kDoctorSpecialtyOptions.contains(spec) ? spec : null;
      final hid = (data['hospitalId'] ?? '').toString().trim();
      _selectedHospitalId = hid.isEmpty ? null : hid;
      _profileImageUrl = (data['profileImageUrl'] ?? '').toString().trim();
      _consultationFeeController.text = (data['consultationFee'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      _fibNumberController.text = (data['payment_fib_number'] ?? '').toString();
      _fastPayNumberController.text =
          (data['payment_fastpay_number'] ?? '').toString();

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

      _hospitalNameCardController.text =
          (data['hospitalName'] ?? '').toString().trim();
      if (_hospitalNameCardController.text.isEmpty) {
        _hospitalNameCardController.text =
            _firstOf(data, ['hospital_name_ku', 'clinicName']);
      }

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
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('profile_load_error'),
            style: const TextStyle(fontFamily: 'NRT'),
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
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
      return;
    }

    final docId = firestoreUserDocId(user).trim();
    if (docId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_user_missing'),
            style: const TextStyle(fontFamily: 'NRT'),
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
        'payment_fib_number': _fibNumberController.text.trim(),
        'payment_fastpay_number': _fastPayNumberController.text.trim(),
        'bio_ku': bioKu,
        'bio_ar': _bioArController.text.trim(),
        'bio_en': _bioEnController.text.trim(),
        'address_ku': addressKu,
        'address_ar': _addressArController.text.trim(),
        'address_en': _addressEnController.text.trim(),
        'hospital_name_ku': _hospitalKuController.text.trim(),
        'hospital_name_ar': _hospitalArController.text.trim(),
        'hospital_name_en': _hospitalEnController.text.trim(),
        'hospitalName': _hospitalNameCardController.text.trim(),
        'experience_ku': _experienceKuController.text.trim(),
        'experience_ar': _experienceArController.text.trim(),
        'experience_en': _experienceEnController.text.trim(),
        'biography': bioKu,
        'clinicAddress': addressKu,
      };

      final hid = (_selectedHospitalId ?? '').trim();
      if (hid.isEmpty) {
        payload['hospitalId'] = FieldValue.delete();
      } else {
        payload['hospitalId'] = hid;
      }

      final yParsed = int.tryParse(_yearsExperienceController.text.trim());
      if (yParsed != null && yParsed > 0) {
        payload['yearsExperience'] = yParsed;
      } else {
        payload['yearsExperience'] = 0;
      }

      await FirebaseFirestore.instance.collection('users').doc(docId).set(
            payload,
            SetOptions(merge: true),
          );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_saved_ok'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'NRT'),
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
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
      return;
    }

    final docId = firestoreUserDocId(user).trim();
    if (docId.isEmpty) return;

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
      await FirebaseFirestore.instance.collection('users').doc(docId).set(
        {'profileImageUrl': downloadUrl},
        SetOptions(merge: true),
      );

      if (!mounted) return;
      setState(() => _profileImageUrl = downloadUrl);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('profile_image_upload_ok'),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            S.of(context).translate('error_code', params: {'code': e.code}),
            style: const TextStyle(fontFamily: 'NRT'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${S.of(context).translate('profile_image_upload_error')}: $e',
            style: const TextStyle(fontFamily: 'NRT'),
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
                leading: const Icon(
                  Icons.photo_library_rounded,
                  color: _kDoctorProfileGold,
                ),
                title: Text(
                  s.translate('image_source_gallery'),
                  style: const TextStyle(
                    fontFamily: 'NRT',
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
                    fontFamily: 'NRT',
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
      padding: const EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        S.of(context).translate(translationKey),
        style: const TextStyle(
          color: _kDoctorProfileGold,
          fontSize: 14,
          fontWeight: FontWeight.w800,
          fontFamily: 'NRT',
        ),
      ),
    );
  }

  Widget _hospitalRegistryDropdown() {
    final s = S.of(context);
    final lang = AppLocaleScope.of(context).effectiveLanguage;
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: hospitalsSnapshotStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            s.translate('hospitals_load_error', params: {'error': '${snap.error}'}),
            style: const TextStyle(
              color: Colors.redAccent,
              fontFamily: 'NRT',
              fontSize: 12,
            ),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: _kDoctorProfileBronze,
                ),
              ),
            ),
          );
        }
        final sorted = sortHospitalDocuments(snap.data?.docs ?? const []);
        String? value = _selectedHospitalId;
        if (value != null &&
            value.isNotEmpty &&
            !sorted.any((d) => d.id == value)) {
          value = null;
        }
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
          child: DropdownButtonFormField<String?>(
            // Controlled selection via rebuild + onChanged; `value` still required here.
            // ignore: deprecated_member_use
            value: value,
            isExpanded: true,
            iconEnabledColor: _kDoctorProfileGold,
            dropdownColor: const Color(0xFF1D1E33),
            style: const TextStyle(
              color: Color(0xFFD9E2EC),
              fontFamily: 'NRT',
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: s.translate('doctor_field_hospital_registry'),
              labelStyle: const TextStyle(
                color: Color(0xFF829AB1),
                fontFamily: 'NRT',
              ),
              prefixIcon: const Icon(
                Icons.local_hospital_rounded,
                color: _kDoctorProfileGold,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            items: [
              DropdownMenuItem<String?>(
                value: null,
                child: Text(s.translate('hospital_registry_none')),
              ),
              ...sorted.map(
                (d) => DropdownMenuItem<String?>(
                  value: d.id,
                  child: Text(
                    localizedHospitalName(d.data(), lang),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: (v) => setState(() => _selectedHospitalId = v),
          ),
        );
      },
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
              fontFamily: 'NRT',
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: _isLoading
            ? const Center(
                child: CircularProgressIndicator(color: _kDoctorProfileBronze),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 4),
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
                                backgroundColor: const Color(0xFF1D1E33),
                                backgroundImage: NetworkImage(
                                  _profileImageUrl.isNotEmpty
                                      ? _profileImageUrl
                                      : _placeholderImageUrl,
                                ),
                                child: _profileImageUrl.isEmpty
                                    ? const Icon(
                                        Icons.medical_services_rounded,
                                        color: _kDoctorProfileGold,
                                        size: 28,
                                      )
                                    : null,
                              ),
                              if (_isUploadingImage)
                                Positioned.fill(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(42),
                                    ),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        color: _kDoctorProfileBronze,
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
                                    onTap: _isUploadingImage ? null : _showImageSourceSheet,
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
                      const SizedBox(height: 10),
                      KurdishDoctorSpecialtyDropdown(
                        dense: true,
                        accentColor: _kDoctorProfileGold,
                        value: _selectedSpecialty,
                        onChanged: (v) => setState(() => _selectedSpecialty = v),
                        validator: (v) => v == null || v.isEmpty
                            ? s.translate('validation_specialty_required')
                            : null,
                      ),
                      const SizedBox(height: 8),
                      _hospitalRegistryDropdown(),
                      const SizedBox(height: 8),
                      _field(
                        controller: _hospitalNameCardController,
                        label: s.translate('doctor_field_hospital_display_simple'),
                        icon: Icons.local_hospital_rounded,
                      ),
                      const SizedBox(height: 8),
                      _field(
                        controller: _consultationFeeController,
                        label: s.translate('doctor_consultation_fee_label'),
                        icon: Icons.payments_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 8),
                      _field(
                        controller: _phoneController,
                        label: s.translate('doctor_phone_label'),
                        icon: Icons.phone_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      _field(
                        controller: _fibNumberController,
                        label: 'FIB Number',
                        icon: Icons.account_balance_wallet_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 8),
                      _field(
                        controller: _fastPayNumberController,
                        label: 'FastPay Number',
                        icon: Icons.phone_android_rounded,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 4),
                      _sectionTitle('editor_section_kurdish'),
                      _field(
                        controller: _fullNameKuController,
                        label: s.translate('doctor_field_full_name'),
                        icon: Icons.person_rounded,
                      ),
                      const SizedBox(height: 6),
                      _field(
                        controller: _bioKuController,
                        label: s.translate('doctor_field_bio'),
                        icon: Icons.info_outline_rounded,
                        maxLines: 4,
                      ),
                      const SizedBox(height: 6),
                      _field(
                        controller: _addressKuController,
                        label: s.translate('doctor_field_address'),
                        icon: Icons.location_on_rounded,
                        maxLines: 2,
                      ),
                      const SizedBox(height: 6),
                      _field(
                        controller: _hospitalKuController,
                        label: s.translate('doctor_field_hospital'),
                        icon: Icons.local_hospital_rounded,
                      ),
                      const SizedBox(height: 6),
                      _field(
                        controller: _experienceKuController,
                        label: s.translate('doctor_field_experience'),
                        icon: Icons.work_history_rounded,
                        maxLines: 3,
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          listTileTheme: const ListTileThemeData(
                            iconColor: _kDoctorProfileBronze,
                          ),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 2),
                          initiallyExpanded: false,
                          backgroundColor: const Color(0xFF121826),
                          collapsedBackgroundColor: const Color(0xFF121826),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          iconColor: _kDoctorProfileBronze,
                          collapsedIconColor: _kDoctorProfileBronze,
                          title: Text(
                            s.translate('editor_section_arabic'),
                            style: const TextStyle(
                              color: _kDoctorProfileGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'NRT',
                            ),
                          ),
                          children: [
                            _field(
                              controller: _fullNameArController,
                              label: s.translate('doctor_field_full_name'),
                              icon: Icons.person_rounded,
                            ),
                            const SizedBox(height: 6),
                            _field(
                              controller: _bioArController,
                              label: s.translate('doctor_field_bio'),
                              icon: Icons.info_outline_rounded,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 6),
                            _field(
                              controller: _addressArController,
                              label: s.translate('doctor_field_address'),
                              icon: Icons.location_on_rounded,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 6),
                            _field(
                              controller: _hospitalArController,
                              label: s.translate('doctor_field_hospital'),
                              icon: Icons.local_hospital_rounded,
                            ),
                            const SizedBox(height: 6),
                            _field(
                              controller: _experienceArController,
                              label: s.translate('doctor_field_experience'),
                              icon: Icons.work_history_rounded,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Theme(
                        data: Theme.of(context).copyWith(
                          dividerColor: Colors.transparent,
                          listTileTheme: const ListTileThemeData(
                            iconColor: _kDoctorProfileBronze,
                          ),
                        ),
                        child: ExpansionTile(
                          tilePadding: const EdgeInsets.symmetric(horizontal: 2),
                          initiallyExpanded: false,
                          backgroundColor: const Color(0xFF121826),
                          collapsedBackgroundColor: const Color(0xFF121826),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          collapsedShape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(
                              color: Colors.white.withValues(alpha: 0.06),
                            ),
                          ),
                          iconColor: _kDoctorProfileBronze,
                          collapsedIconColor: _kDoctorProfileBronze,
                          title: Text(
                            s.translate('editor_section_english'),
                            style: const TextStyle(
                              color: _kDoctorProfileGold,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              fontFamily: 'NRT',
                            ),
                          ),
                          children: [
                            _field(
                              controller: _fullNameEnController,
                              label: s.translate('doctor_field_full_name'),
                              icon: Icons.person_rounded,
                            ),
                            const SizedBox(height: 6),
                            _field(
                              controller: _bioEnController,
                              label: s.translate('doctor_field_bio'),
                              icon: Icons.info_outline_rounded,
                              maxLines: 4,
                            ),
                            const SizedBox(height: 6),
                            _field(
                              controller: _addressEnController,
                              label: s.translate('doctor_field_address'),
                              icon: Icons.location_on_rounded,
                              maxLines: 2,
                            ),
                            const SizedBox(height: 6),
                            _field(
                              controller: _hospitalEnController,
                              label: s.translate('doctor_field_hospital'),
                              icon: Icons.local_hospital_rounded,
                            ),
                            const SizedBox(height: 6),
                            _field(
                              controller: _experienceEnController,
                              label: s.translate('doctor_field_experience'),
                              icon: Icons.work_history_rounded,
                              maxLines: 3,
                            ),
                            const SizedBox(height: 6),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      _field(
                        controller: _yearsExperienceController,
                        label: s.translate('doctor_field_years_numeric'),
                        icon: Icons.numbers_rounded,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                        onPressed: _isSaving ? null : _saveChanges,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _kDoctorProfileBronze,
                          foregroundColor: const Color(0xFF102A43),
                          minimumSize: const Size(double.infinity, 52),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.2,
                                  color: Color(0xFF102A43),
                                ),
                              )
                            : Text(
                                s.translate('profile_save_changes'),
                                style: const TextStyle(
                                  fontFamily: 'NRT',
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
          fontFamily: 'NRT',
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(
            color: Color(0xFF829AB1),
            fontFamily: 'NRT',
          ),
          prefixIcon: Icon(icon, color: _kDoctorProfileGold),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}
