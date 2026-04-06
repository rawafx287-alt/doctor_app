import 'dart:math';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../doctor/doctor_premium_shell.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../theme/staff_premium_theme.dart';

/// Admin: upload / delete home promo images ([ads] + Storage `ads/`).
class AdminAdsScreen extends StatefulWidget {
  const AdminAdsScreen({super.key});

  @override
  State<AdminAdsScreen> createState() => _AdminAdsScreenState();
}

class _AdminAdsScreenState extends State<AdminAdsScreen> {
  bool _uploading = false;

  Future<void> _uploadOne(XFile x) async {
    final bytes = await x.readAsBytes();
    final id =
        '${DateTime.now().millisecondsSinceEpoch}_${Random().nextInt(1 << 30)}';
    final ref = FirebaseStorage.instance.ref().child('ads').child('$id.jpg');
    await ref.putData(
      bytes,
      SettableMetadata(contentType: 'image/jpeg'),
    );
    final url = await ref.getDownloadURL();
    await FirebaseFirestore.instance.collection('ads').add({
      'imageUrl': url,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _pickAndUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    final s = S.of(context);
    final picker = ImagePicker();
    var files = await picker.pickMultiImage(imageQuality: 85);
    if (files.isEmpty) {
      final one = await picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (one == null) return;
      files = [one];
    }

    setState(() => _uploading = true);
    var ok = 0;
    Object? lastErr;
    try {
      for (final x in files) {
        try {
          await _uploadOne(x);
          ok++;
        } catch (e) {
          lastErr = e;
        }
      }
      if (!mounted) return;
      if (ok > 0) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              ok == 1
                  ? s.translate('admin_ads_upload_ok')
                  : s.translate(
                      'admin_ads_upload_ok_batch',
                      params: {'count': '$ok'},
                    ),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
      if (ok == 0 && lastErr != null) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              '${s.translate('admin_ads_error')}: $lastErr',
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _uploading = false);
      }
    }
  }

  Future<void> _deleteAd(String docId, String imageUrl) async {
    final s = S.of(context);
    await FirebaseFirestore.instance.collection('ads').doc(docId).delete();
    try {
      final r = FirebaseStorage.instance.refFromURL(imageUrl);
      await r.delete();
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            s.translate('admin_ads_deleted_ok'),
            style: const TextStyle(fontFamily: kPatientPrimaryFont),
          ),
        ),
      );
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    String docId,
    String imageUrl,
  ) async {
    final s = S.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: AppLocaleScope.of(context).textDirection,
        child: AlertDialog(
          backgroundColor: const Color(0xFF1D1E33),
          title: Text(
            s.translate('admin_ads_delete_confirm_title'),
            style: const TextStyle(
              color: Color(0xFFD9E2EC),
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Text(
            s.translate('admin_ads_delete_confirm_body'),
            style: const TextStyle(
              color: Color(0xFF829AB1),
              fontFamily: kPatientPrimaryFont,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(
                s.translate('close'),
                style: const TextStyle(
                  color: Color(0xFF829AB1),
                  fontFamily: kPatientPrimaryFont,
                ),
              ),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(
                s.translate('admin_ads_delete'),
                style: const TextStyle(
                  color: Color(0xFFEF4444),
                  fontFamily: kPatientPrimaryFont,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
    if (ok == true && context.mounted) {
      await _deleteAd(docId, imageUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final dir = AppLocaleScope.of(context).textDirection;

    return Directionality(
      textDirection: dir,
      child: Scaffold(
        backgroundColor: kDoctorPremiumGradientBottom,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          foregroundColor: Colors.white,
          title: Text(
            s.translate('admin_ads_page_title'),
            style: const TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            const DecoratedBox(
              decoration: kDoctorPremiumGradientDecoration,
            ),
            SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: Text(
                      s.translate('admin_ads_intro'),
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontFamily: kPatientPrimaryFont,
                        fontSize: 13.5,
                        height: 1.35,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: FilledButton.icon(
                      onPressed: _uploading ? null : _pickAndUpload,
                      style: FilledButton.styleFrom(
                        backgroundColor: kStaffLuxGold.withValues(alpha: 0.92),
                        foregroundColor: Colors.black87,
                        padding: const EdgeInsets.symmetric(
                          vertical: 14,
                          horizontal: 20,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: _uploading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black54,
                              ),
                            )
                          : const Icon(Icons.add_photo_alternate_rounded),
                      label: Text(
                        _uploading
                            ? s.translate('admin_ads_uploading')
                            : s.translate('admin_ads_upload'),
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: Text(
                        s.translate('admin_ads_active_list_title'),
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.92),
                          fontFamily: kPatientPrimaryFont,
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                  Expanded(
                    child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                      stream: FirebaseFirestore.instance
                          .collection('ads')
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.hasError) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                '${s.translate('admin_ads_error')}: ${snapshot.error}',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Colors.white70,
                                  fontFamily: kPatientPrimaryFont,
                                ),
                              ),
                            ),
                          );
                        }
                        if (!snapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(
                              color: kStaffLuxGold,
                            ),
                          );
                        }
                        final docs = snapshot.data!.docs.toList()
                          ..sort((a, b) {
                            final ta = a.data()['createdAt'];
                            final tb = b.data()['createdAt'];
                            if (ta is Timestamp && tb is Timestamp) {
                              return tb.compareTo(ta);
                            }
                            return b.id.compareTo(a.id);
                          });
                        if (docs.isEmpty) {
                          return Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Text(
                                s.translate('admin_ads_empty'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.75),
                                  fontFamily: kPatientPrimaryFont,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          );
                        }
                        return ListView.separated(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                          itemCount: docs.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final doc = docs[index];
                            final data = doc.data();
                            final url =
                                (data['imageUrl'] ?? '').toString().trim();
                            return DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: kStaffSilverBorder.withValues(
                                    alpha: 0.55,
                                  ),
                                ),
                                color: Colors.black.withValues(alpha: 0.2),
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(15),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: AspectRatio(
                                        aspectRatio: 16 / 9,
                                        child: url.isEmpty
                                            ? const ColoredBox(
                                                color: Color(0xFF2D3748),
                                                child: Center(
                                                  child: Icon(
                                                    Icons.hide_image_rounded,
                                                    color: Colors.white38,
                                                    size: 40,
                                                  ),
                                                ),
                                              )
                                            : CachedNetworkImage(
                                                imageUrl: url,
                                                fit: BoxFit.cover,
                                                memCacheWidth: 480,
                                              ),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 4,
                                        right: 4,
                                      ),
                                      child: TextButton.icon(
                                        onPressed: url.isEmpty
                                            ? null
                                            : () => _confirmDelete(
                                                  context,
                                                  doc.id,
                                                  url,
                                                ),
                                        icon: const Icon(
                                          Icons.delete_outline_rounded,
                                          color: Color(0xFFFF8A80),
                                          size: 22,
                                        ),
                                        label: Text(
                                          s.translate('admin_ads_delete'),
                                          style: const TextStyle(
                                            color: Color(0xFFFFAB91),
                                            fontFamily: kPatientPrimaryFont,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
