import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firestore/hospital_queries.dart';
import '../locale/app_locale.dart';
import 'widgets/admin_hospital_dropdown.dart';

/// Admin: add hospitals to Firestore and delete existing ones.
/// Patient home uses [hospitalsSnapshotStream] — new rows appear immediately.
class AdminHospitalManagementScreen extends StatefulWidget {
  const AdminHospitalManagementScreen({super.key});

  @override
  State<AdminHospitalManagementScreen> createState() =>
      _AdminHospitalManagementScreenState();
}

class _AdminHospitalManagementScreenState
    extends State<AdminHospitalManagementScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _location = TextEditingController();
  final _imageUrl = TextEditingController();

  bool _isSaving = false;

  @override
  void dispose() {
    _name.dispose();
    _location.dispose();
    _imageUrl.dispose();
    super.dispose();
  }

  Future<void> _addHospital() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _isSaving = true);
    try {
      final name = _name.text.trim();
      final location = _location.text.trim();
      final logoUrl = _imageUrl.text.trim();
      await FirebaseFirestore.instance.collection(HospitalFields.collection).add({
        'name': name,
        'name_ku': name,
        'location': location,
        'logoUrl': logoUrl,
        'sortOrder': DateTime.now().millisecondsSinceEpoch,
        'createdAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'نەخۆشخانەکە پاشەکەوت کرا',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
      _name.clear();
      _location.clear();
      _imageUrl.clear();
      _formKey.currentState?.reset();
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

  Future<void> _confirmAndDelete(
    BuildContext context,
    String docId,
    String displayName,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: const Text(
            'سڕینەوەی نەخۆشخانە',
            style: TextStyle(
              color: Color(0xFFD9E2EC),
              fontFamily: 'KurdishFont',
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            'دڵنیایت لە سڕینەوەی "$displayName"؟',
            style: const TextStyle(
              color: Color(0xFF829AB1),
              fontFamily: 'KurdishFont',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text(
                'پاشگەزبوونەوە',
                style: TextStyle(color: Color(0xFF829AB1), fontFamily: 'KurdishFont'),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text(
                'سڕینەوە',
                style: TextStyle(
                  color: Color(0xFFEF4444),
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await FirebaseFirestore.instance
          .collection(HospitalFields.collection)
          .doc(docId)
          .delete();
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'سڕایەوە: $displayName',
            style: const TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'هەڵەیەک ڕوویدا لە سڕینەوە',
            style: TextStyle(fontFamily: 'KurdishFont'),
          ),
        ),
      );
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
          'بەڕێوەبردنی نەخۆشخانەکان',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontFamily: 'KurdishFont',
          ),
        ),
      ),
      body: Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: hospitalsSnapshotStream(),
          builder: (context, listSnap) {
            final sorted = listSnap.hasData
                ? sortHospitalDocuments(listSnap.data!.docs)
                : <QueryDocumentSnapshot<Map<String, dynamic>>>[];

            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'زیادکردنی نەخۆشخانە',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            fontFamily: 'KurdishFont',
                          ),
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          controller: _name,
                          label: 'ناوی نەخۆشخانە',
                          icon: Icons.local_hospital_rounded,
                          isRequired: true,
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          controller: _location,
                          label: 'شوێن / ناونیشان',
                          icon: Icons.place_outlined,
                          isRequired: true,
                        ),
                        const SizedBox(height: 12),
                        _formField(
                          controller: _imageUrl,
                          label: 'بەستەری وێنە (URL)',
                          icon: Icons.image_outlined,
                          isRequired: false,
                          keyboardType: TextInputType.url,
                        ),
                        const SizedBox(height: 18),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.blueAccent,
                            minimumSize: const Size(double.infinity, 52),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isSaving ? null : _addHospital,
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
                                    fontSize: 17,
                                    fontWeight: FontWeight.bold,
                                    fontFamily: 'KurdishFont',
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),
                  const Text(
                    'نەخۆشخانەکانی ئێستا',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      fontFamily: 'KurdishFont',
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (listSnap.hasError)
                    Text(
                      'هەڵە: ${listSnap.error}',
                      style: const TextStyle(color: Color(0xFFEF4444)),
                    )
                  else if (listSnap.connectionState == ConnectionState.waiting &&
                      !listSnap.hasData)
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                      ),
                    )
                  else if (sorted.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Text(
                        'هیچ نەخۆشخانەیەک تۆمار نەکراوە',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Color(0xFF829AB1),
                          fontFamily: 'KurdishFont',
                        ),
                      ),
                    )
                  else
                    ...sorted.map((doc) {
                      final data = doc.data();
                      final title = AdminHospitalDropdown.displayName(data);
                      final loc = (data['location'] ?? '').toString().trim();
                      final url = (data['logoUrl'] ?? '').toString().trim();
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1D1E33),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              _ListThumb(url: url),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      title,
                                      style: const TextStyle(
                                        color: Color(0xFFD9E2EC),
                                        fontWeight: FontWeight.w700,
                                        fontFamily: 'KurdishFont',
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (loc.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        loc,
                                        style: const TextStyle(
                                          color: Color(0xFF829AB1),
                                          fontSize: 12,
                                          fontFamily: 'KurdishFont',
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              IconButton(
                                tooltip: 'سڕینەوە',
                                icon: const Icon(
                                  Icons.delete_outline_rounded,
                                  color: Color(0xFFEF4444),
                                ),
                                onPressed: () =>
                                    _confirmAndDelete(context, doc.id, title),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _formField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isRequired = true,
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
        validator: isRequired
            ? (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'تکایە ئەم خانە پڕ بکەرەوە';
                }
                return null;
              }
            : null,
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

class _ListThumb extends StatelessWidget {
  const _ListThumb({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    const size = 48.0;
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFF12152A),
        child: url.isEmpty
            ? const Icon(Icons.local_hospital_rounded, color: Colors.blueAccent)
            : Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => const Icon(
                  Icons.local_hospital_rounded,
                  color: Colors.blueAccent,
                ),
              ),
      ),
    );
  }
}
