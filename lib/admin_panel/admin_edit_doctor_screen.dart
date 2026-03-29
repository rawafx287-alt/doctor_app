import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../specialty_categories.dart';
import 'widgets/admin_hospital_dropdown.dart';

/// Admin: edit an existing doctor (including [hospitalId]).
class AdminEditDoctorScreen extends StatefulWidget {
  const AdminEditDoctorScreen({super.key, required this.doctorId});

  final String doctorId;

  @override
  State<AdminEditDoctorScreen> createState() => _AdminEditDoctorScreenState();
}

class _AdminEditDoctorScreenState extends State<AdminEditDoctorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _clinicLocation = TextEditingController();
  final _phone = TextEditingController();
  final _hours = TextEditingController();

  String? _selectedSpecialty;
  String? _selectedHospitalId;

  bool _loading = true;
  bool _isSaving = false;
  String? _loadError;

  @override
  void dispose() {
    _name.dispose();
    _clinicLocation.dispose();
    _phone.dispose();
    _hours.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.doctorId)
          .get();
      if (!doc.exists) {
        if (mounted) {
          setState(() {
            _loading = false;
            _loadError = 'پزیشک نەدۆزرایەوە';
          });
        }
        return;
      }
      final data = doc.data() ?? {};
      _name.text = (data['fullName'] ?? data['fullName_ku'] ?? '').toString();
      final spec = (data['specialty'] ?? '').toString().trim();
      _selectedSpecialty = kDoctorSpecialtyOptions.contains(spec) ? spec : null;
      _clinicLocation.text =
          (data['clinicLocation'] ?? data['clinicAddress'] ?? data['address_ku'] ?? '')
              .toString();
      _phone.text = (data['phone'] ?? '').toString();
      _hours.text = (data['workingHours'] ?? '').toString();
      final hid = (data['hospitalId'] ?? '').toString().trim();
      _selectedHospitalId = hid.isEmpty ? null : hid;
      if (mounted) setState(() => _loading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = '$e';
        });
      }
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final name = _name.text.trim();
      final payload = <String, dynamic>{
        'fullName': name,
        'fullName_ku': name,
        'specialty': (_selectedSpecialty ?? '').trim(),
        'clinicLocation': _clinicLocation.text.trim(),
        'phone': _phone.text.trim(),
        'workingHours': _hours.text.trim(),
      };
      final hid = (_selectedHospitalId ?? '').trim();
      if (hid.isEmpty) {
        payload['hospitalId'] = FieldValue.delete();
      } else {
        payload['hospitalId'] = hid;
      }
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.doctorId)
          .set(payload, SetOptions(merge: true));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'پاشەکەوت کرا بە سەرکەوتوویی',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'هەڵە: $e',
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
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
          'دەستکاری پزیشک',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'KurdishFont',
          ),
        ),
      ),
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF42A5F5)))
            : _loadError != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _loadError!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontFamily: 'KurdishFont',
                        ),
                      ),
                    ),
                  )
                : SingleChildScrollView(
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
                          KurdishDoctorSpecialtyDropdown(
                            value: _selectedSpecialty,
                            accentColor: Colors.blueAccent,
                            onChanged: (v) => setState(() => _selectedSpecialty = v),
                            validator: (v) =>
                                v == null || v.isEmpty ? 'پسپۆڕی هەڵبژێرە لە لیستەکە' : null,
                          ),
                          const SizedBox(height: 12),
                          AdminHospitalDropdown(
                            value: _selectedHospitalId,
                            onChanged: (v) => setState(() => _selectedHospitalId = v),
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
                            child: _isSaving
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'پاشەکەوتکردن',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      fontFamily: 'KurdishFont',
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
