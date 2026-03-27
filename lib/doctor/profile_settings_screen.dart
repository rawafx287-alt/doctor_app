import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../app_rtl.dart';
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
  String? _selectedSpecialty;

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

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: kRtlTextDirection,
      child: Scaffold(
        backgroundColor: const Color(0xFF0A0E21),
        appBar: AppBar(
          backgroundColor: const Color(0xFF243B53),
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
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF2CB1BC)))
            : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Form(
                  key: _formKey,
                  child: Column(
                  children: [
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
                        backgroundColor: const Color(0xFF2CB1BC),
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
          prefixIcon: Icon(icon, color: const Color(0xFF2CB1BC)),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        ),
      ),
    );
  }
}
