import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../locale/app_locale.dart';
import '../specialty_categories.dart';

class ProfileSettingsScreen extends StatefulWidget {
  const ProfileSettingsScreen({super.key});

  @override
  State<ProfileSettingsScreen> createState() => _ProfileSettingsScreenState();
}

class _ProfileSettingsScreenState extends State<ProfileSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _clinicAddressController = TextEditingController();
  final TextEditingController _consultationFeeController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _biographyController = TextEditingController();

  bool _isLoading = true;
  bool _isSaving = false;
  bool _isUploadingImage = false;
  String? _selectedSpecialty;
  String _profileImageUrl = '';
  static const String _placeholderImageUrl =
      'https://images.unsplash.com/photo-1612349317150-e413f6a5b16d?auto=format&fit=crop&w=300&q=80';

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _clinicAddressController.dispose();
    _consultationFeeController.dispose();
    _phoneController.dispose();
    _biographyController.dispose();
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

      _fullNameController.text = (data['fullName'] ?? '').toString();
      final spec = (data['specialty'] ?? '').toString().trim();
      _selectedSpecialty = kDoctorSpecialtyOptions.contains(spec) ? spec : null;
      _profileImageUrl = (data['profileImageUrl'] ?? '').toString().trim();
      _clinicAddressController.text = (data['clinicAddress'] ?? '').toString();
      _consultationFeeController.text = (data['consultationFee'] ?? '').toString();
      _phoneController.text = (data['phone'] ?? '').toString();
      _biographyController.text =
          (data['biography'] ?? data['about'] ?? '').toString();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هەڵە لە هێنانی زانیارییەکان')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _saveChanges() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بەکارهێنەر نەدۆزرایەوە')),
      );
      return;
    }

    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'fullName': _fullNameController.text.trim(),
        'specialty': (_selectedSpecialty ?? '').trim(),
        'clinicAddress': _clinicAddressController.text.trim(),
        'consultationFee': _consultationFeeController.text.trim(),
        'phone': _phoneController.text.trim(),
        'biography': _biographyController.text.trim(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('گۆڕانکارییەکان بە سەرکەوتوویی پاشەکەوتکران')),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('هەڵە ڕوویدا (${e.code})')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Uploads to [profile_pictures/${uid}.jpg] and writes [profileImageUrl] in Firestore.
  Future<void> _uploadProfileImageToFirebase(XFile file) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('بەکارهێنەر نەدۆزرایەوە')),
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
        const SnackBar(
          content: Text(
            'وێنەی پڕۆفایل بە سەرکەوتوویی بارکرا',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } on FirebaseException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هەڵە لە بارکردنی وێنە (${e.code})',
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هەڵە لە بارکردنی وێنە: $e',
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
                title: const Text(
                  'گەلەری',
                  style: TextStyle(
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
                title: const Text(
                  'کامێرا',
                  style: TextStyle(
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

  @override
  Widget build(BuildContext context) {
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
            tooltip: 'گەڕانەوە',
          ),
          title: const Text(
            'ڕێکخستنەکانی پڕۆفایل',
            style: TextStyle(
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
                    _field(
                      controller: _fullNameController,
                      label: 'ناو',
                      icon: Icons.person_rounded,
                    ),
                    const SizedBox(height: 12),
                    KurdishDoctorSpecialtyDropdown(
                      dense: true,
                      value: _selectedSpecialty,
                      onChanged: (v) => setState(() => _selectedSpecialty = v),
                      validator: (v) =>
                          v == null || v.isEmpty ? 'پسپۆڕی هەڵبژێرە لە لیستەکە' : null,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _clinicAddressController,
                      label: 'ناونیشانی نۆرینگە',
                      icon: Icons.location_on_rounded,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _consultationFeeController,
                      label: 'نرخی بینین',
                      icon: Icons.payments_rounded,
                      keyboardType: TextInputType.number,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _phoneController,
                      label: 'ژمارەی مۆبایل',
                      icon: Icons.phone_rounded,
                      keyboardType: TextInputType.phone,
                    ),
                    const SizedBox(height: 12),
                    _field(
                      controller: _biographyController,
                      label: 'دەربارەی پزیشک',
                      icon: Icons.info_outline_rounded,
                      maxLines: 5,
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
                          : const Text(
                              'پاشکەوتکردنی گۆڕانکارییەکان',
                              style: TextStyle(
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
