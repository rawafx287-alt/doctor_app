import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../app_rtl.dart';

class AddDoctorScreen extends StatefulWidget {
  const AddDoctorScreen({super.key});

  @override
  State<AddDoctorScreen> createState() => _AddDoctorScreenState();
}

class _AddDoctorScreenState extends State<AddDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _specialty = TextEditingController();
  final _clinicLocation = TextEditingController();
  final _phone = TextEditingController();
  final _hours = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _clinicLocation.dispose();
    _phone.dispose();
    _hours.dispose();
    super.dispose();
  }

  bool _isSaving = false;

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      await FirebaseFirestore.instance.collection('users').add({
        'fullName': _name.text.trim(),
        'specialty': _specialty.text.trim(),
        'clinicLocation': _clinicLocation.text.trim(),
        'phone': _phone.text.trim(),
        'workingHours': _hours.text.trim(),
        'role': 'Doctor',
        'isApproved': true,
        'createdAt': FieldValue.serverTimestamp(),
        'createdByAdmin': true,
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('پاشەکەوت کرا بە سەرکەوتوویی')),
      );
      _formKey.currentState?.reset();
      _name.clear();
      _specialty.clear();
      _clinicLocation.clear();
      _phone.clear();
      _hours.clear();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هەڵەیەک ڕوویدا، دووبارە هەوڵ بدەرەوە')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0A0E21),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'زیادکردنی پزیشک',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
      ),
      body: Directionality(
        textDirection: kRtlTextDirection,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(18),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                _field(
                  controller: _name,
                  label: 'ناوی پزیشک',
                  icon: Icons.person_outline_rounded,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _specialty,
                  label: 'پسپۆڕی (وەک: دڵ، منداڵان)',
                  icon: Icons.local_hospital_outlined,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _clinicLocation,
                  label: 'ناونیشانی نۆرینگە',
                  icon: Icons.location_on_outlined,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _phone,
                  label: 'ژمارەی مۆبایل',
                  icon: Icons.phone_android_rounded,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                _field(
                  controller: _hours,
                  label: 'کاتەکانی دەوام',
                  icon: Icons.schedule_rounded,
                ),
                const SizedBox(height: 18),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    minimumSize: const Size(double.infinity, 56),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: _isSaving ? null : _save,
                  child: const Text(
                    'پاشەکەوتکردن',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
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
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1D1E33),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white10),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: Colors.white),
        validator: (value) {
          if (value == null || value.trim().isEmpty) {
            return 'تکایە ئەم خانە پڕ بکەرەوە';
          }
          return null;
        },
        decoration: InputDecoration(
          hintText: label,
          hintStyle: const TextStyle(color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18),
          prefixIcon: Icon(icon, color: Colors.blueAccent),
        ),
      ),
    );
  }
}

