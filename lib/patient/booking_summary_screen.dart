import 'dart:ui' show ImageFilter;
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show HapticFeedback;
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../firestore/appointment_queries.dart';
import '../firestore/available_days_queries.dart';
import '../auth/patient_session_cache.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import 'my_appointments_screen.dart';
import '../theme/hr_nora_colors.dart';
import '../theme/patient_premium_theme.dart';
import 'booking_details_page.dart';
import 'patient_booking_form_result.dart';

const Color _kNavy = Color(0xFF0D2137);
const Color _kBodyMuted = Color(0xFF455A64);
const Color _kGoldDark = Color(0xFF8B6914);
const Color _kGoldMid = Color(0xFFD4AF37);
const Color _kGoldShine = Color(0xFFFFE082);
const Color _kEmeraldAvailable = HrNoraColors.openDayFill;
const Color _kSlotBorderBlue = Color(0xFF1565C0);
const Color _kBookedRed = HrNoraColors.closedDayFill;

/// «دووپاتکردنەوەی نۆرە» — bright gold → dark goldenrod (matches home CTA spec).
const Color _kConfirmGoldBright = Color(0xFFE6B800);
const Color _kConfirmGoldDarkRod = Color(0xFFB8860B);
const Color _kConfirmButtonSilverBorder = Color(0xFFD1D1D1);

const LinearGradient _kConfirmBookingGoldGradient = LinearGradient(
  begin: Alignment.topCenter,
  end: Alignment.bottomCenter,
  colors: [_kConfirmGoldBright, _kConfirmGoldDarkRod],
);

/// Final step before committing an [available_days] booking (patient).
/// Shows only **available vs booked** per slot (no other patients' names).
class BookingSummaryScreen extends StatefulWidget {
  const BookingSummaryScreen({
    super.key,
    required this.availableDayDocId,
    required this.doctorId,
    required this.patientName,
    required this.doctorDisplayName,
    required this.mergedDoctorData,
    required this.dateLocal,
  });

  final String availableDayDocId;
  final String doctorId;
  final String patientName;
  final String doctorDisplayName;
  final Map<String, dynamic> mergedDoctorData;
  final DateTime dateLocal;

  @override
  State<BookingSummaryScreen> createState() => _BookingSummaryScreenState();
}

class _BookingSummaryScreenState extends State<BookingSummaryScreen> {
  bool _submitting = false;
  final GlobalKey _selectedSlotKey = GlobalKey();
  bool _didEnsureSelectedVisible = false;
  bool _scrollToSlotScheduled = false;

  String get _doctorUid => widget.doctorId.trim();

  @override
  void didUpdateWidget(covariant BookingSummaryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.availableDayDocId != widget.availableDayDocId ||
        oldWidget.dateLocal != widget.dateLocal) {
      _didEnsureSelectedVisible = false;
      _scrollToSlotScheduled = false;
    }
  }

  String get _resolvedDoctorUid {
    final direct = widget.doctorId.trim();
    if (direct.isNotEmpty) return direct;
    final fromMap = (widget.mergedDoctorData['uid'] ??
            widget.mergedDoctorData['doctorId'] ??
            widget.mergedDoctorData['id'] ??
            '')
        .toString()
        .trim();
    return fromMap;
  }

  void _scheduleScrollToAssignedSlot(
    DateTime? firstFree,
    List<DateTime> slots,
  ) {
    if (_scrollToSlotScheduled ||
        _didEnsureSelectedVisible ||
        firstFree == null ||
        slots.isEmpty) {
      return;
    }
    final target = formatTimeHhMm(firstFree);
    if (!slots.any((s) => formatTimeHhMm(s) == target)) return;

    _scrollToSlotScheduled = true;

    void tryVisible({bool allowRetry = true}) {
      if (!mounted || _didEnsureSelectedVisible) return;
      final ctx = _selectedSlotKey.currentContext;
      if (ctx != null) {
        _didEnsureSelectedVisible = true;
        Scrollable.ensureVisible(
          ctx,
          alignment: 0.22,
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutCubic,
        );
      } else if (allowRetry) {
        WidgetsBinding.instance.addPostFrameCallback(
          (_) => tryVisible(allowRetry: false),
        );
      }
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => tryVisible());
    });
  }

  Future<bool> _hasActiveAppointmentForPatient(String patientUid) async {
    final uid = patientUid.trim();
    if (uid.isEmpty) return false;
    const activeStatuses = {'pending', 'confirmed', 'arrived'};

    final col = FirebaseFirestore.instance.collection(AppointmentFields.collection);

    final byUserId =
        await col.where(AppointmentFields.userId, isEqualTo: uid).limit(60).get();
    for (final d in byUserId.docs) {
      final st = (d.data()[AppointmentFields.status] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      if (activeStatuses.contains(st)) return true;
    }

    final byPatientId =
        await col.where(AppointmentFields.patientId, isEqualTo: uid).limit(60).get();
    for (final d in byPatientId.docs) {
      final st = (d.data()[AppointmentFields.status] ?? 'pending')
          .toString()
          .trim()
          .toLowerCase();
      if (activeStatuses.contains(st)) return true;
    }
    return false;
  }

  Future<void> _showActiveBookingWarningDialog(BuildContext context) async {
    final s = S.of(context);
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.16),
      builder: (ctx) {
        final dir = AppLocaleScope.of(ctx).textDirection;
        return Directionality(
          textDirection: dir,
          child: Stack(
            children: [
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
                  child: const SizedBox.expand(),
                ),
              ),
              Center(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 26),
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(alpha: 0.98),
                        const Color(0xFFE3F2FD).withValues(alpha: 0.92),
                      ],
                    ),
                    border: Border.all(
                      color: _kGoldMid.withValues(alpha: 0.42),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 66,
                        height: 66,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFFFFF3E0),
                          boxShadow: [
                            BoxShadow(
                              color: _kGoldMid.withValues(alpha: 0.22),
                              blurRadius: 16,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.warning_amber_rounded,
                          size: 42,
                          color: _kGoldDark.withValues(alpha: 0.95),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        s.translate('booking_active_warning_title'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          color: _kNavy,
                          fontWeight: FontWeight.w800,
                          fontSize: 20,
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        s.translate('booking_active_warning_body'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontFamily: kPatientPrimaryFont,
                          color: _kBodyMuted,
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                          height: 1.45,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: kPatientDeepBlue,
                            borderRadius: BorderRadius.circular(14),
                            boxShadow: [
                              BoxShadow(
                                color: kPatientDeepBlue.withValues(alpha: 0.34),
                                blurRadius: 14,
                                offset: const Offset(0, 5),
                              ),
                            ],
                          ),
                          child: TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            child: Text(
                              s.translate('booking_active_warning_ok'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontFamily: kPatientPrimaryFont,
                                fontWeight: FontWeight.w800,
                                fontSize: 15,
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
        );
      },
    );
  }

  Future<bool> _showLegalWarningDialog(BuildContext context) async {
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.18),
      builder: (ctx) {
        final dir = AppLocaleScope.of(ctx).textDirection;
        return Directionality(
          textDirection: dir,
          child: Dialog(
            backgroundColor: Colors.transparent,
            elevation: 0,
            insetPadding: const EdgeInsets.symmetric(horizontal: 24),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(25),
                border: Border.all(
                  color: _kGoldMid.withValues(alpha: 0.42),
                  width: 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFFFFEBEE),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFD32F2F).withValues(alpha: 0.2),
                          blurRadius: 14,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.gavel_rounded,
                      size: 36,
                      color: Color(0xFFC62828),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'ئاگاداری',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      color: _kNavy,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تێبینی: تۆمارکردنی نۆرەی وەهمی و بێمانا بە سیستمەکە، دەبێتە هۆی بلۆککردنی هەمیشەیی ژمارەکەت و ڕووبەڕووی لێپرسینەوەی یاسایی دەبیتەوە.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      color: Color(0xFFB71C1C),
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFFB71C1C),
                            foregroundColor: Colors.white,
                            elevation: 2,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'دووپاتکردنەوە',
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 14.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _kNavy,
                            side: BorderSide(
                              color: _kGoldMid.withValues(alpha: 0.65),
                              width: 1,
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text(
                            'پاشگەزبوونەوە',
                            style: TextStyle(
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    return approved ?? false;
  }

  Future<_PaymentSelectionResult?> _showPaymentSelectionSheet(
    BuildContext context,
  ) async {
    final s = S.of(context);
    final picker = ImagePicker();
    final docId = _resolvedDoctorUid;
    String fibNumber = '';
    String fastPayNumber = '';
    if (docId.isNotEmpty) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(docId).get();
      final data = doc.data() ?? const <String, dynamic>{};
      fibNumber = (data['payment_fib_number'] ?? '').toString().trim();
      fastPayNumber = (data['payment_fastpay_number'] ?? '').toString().trim();
    }
    if (!context.mounted) return null;
    final hasDigital = fibNumber.isNotEmpty || fastPayNumber.isNotEmpty;
    _PaymentMethod method = _PaymentMethod.cash;
    XFile? receipt;

    Future<void> pickReceipt(ImageSource src, StateSetter setModalState) async {
      final file = await picker.pickImage(
        source: src,
        imageQuality: 85,
        maxWidth: 1800,
      );
      if (file == null) return;
      setModalState(() => receipt = file);
    }

    return showModalBottomSheet<_PaymentSelectionResult>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final dir = AppLocaleScope.of(ctx).textDirection;
        return Directionality(
          textDirection: dir,
          child: StatefulBuilder(
            builder: (context, setModalState) {
              final isCash = method == _PaymentMethod.cash || !hasDigital;
              final digitalValid = receipt != null;
              final canConfirm = isCash || (hasDigital && digitalValid);
              return SafeArea(
                top: false,
                child: Padding(
                  padding: EdgeInsets.only(
                    left: 14,
                    right: 14,
                    top: 12,
                    bottom: 14 + MediaQuery.of(ctx).viewInsets.bottom,
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                      child: Container(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Colors.white.withValues(alpha: 0.98),
                              const Color(0xFFE3F2FD).withValues(alpha: 0.84),
                            ],
                          ),
                          border: Border.all(
                            color: _kGoldMid.withValues(alpha: 0.5),
                            width: 0.9,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 18,
                              offset: const Offset(0, 7),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text(
                              'شێوازی پارەدان هەڵبژێرە',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: kPatientPrimaryFont,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                                color: _kNavy,
                              ),
                            ),
                            const SizedBox(height: 14),
                            _paymentOptionTile(
                              selected: isCash,
                              title: 'کاش (Cash)',
                              subtitle: 'تکایە لە کاتی سەردانیکردن پارەکە بدە',
                              icon: Icons.payments_rounded,
                              onTap: () => setModalState(() {
                                method = _PaymentMethod.cash;
                              }),
                            ),
                            const SizedBox(height: 10),
                            _paymentOptionTile(
                              selected: !isCash,
                              title: 'فاستپەی / FIB',
                              subtitle: hasDigital
                                  ? 'پارەدان بە ڕێگای وەرگرتنی ژمارەی ئەکاونت'
                                  : 'Not Available',
                              icon: Icons.account_balance_wallet_rounded,
                              onTap: hasDigital
                                  ? () => setModalState(() {
                                      method = _PaymentMethod.digital;
                                    })
                                  : () {},
                            ),
                            if (!isCash && hasDigital) ...[
                              const SizedBox(height: 12),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(14),
                                  color: Colors.white.withValues(alpha: 0.9),
                                  border: Border.all(
                                    color: _kSlotBorderBlue.withValues(alpha: 0.3),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    if (fibNumber.isNotEmpty)
                                      Text(
                                        'FIB: $fibNumber',
                                        style: const TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: _kNavy,
                                        ),
                                      ),
                                    if (fibNumber.isNotEmpty &&
                                        fastPayNumber.isNotEmpty)
                                      const SizedBox(height: 4),
                                    if (fastPayNumber.isNotEmpty)
                                      Text(
                                        'FastPay: $fastPayNumber',
                                        style: const TextStyle(
                                          fontFamily: kPatientPrimaryFont,
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w800,
                                          color: _kNavy,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 10),
                              Row(
                                children: [
                                  Expanded(
                                    child: OutlinedButton.icon(
                                      onPressed: () => pickReceipt(
                                        ImageSource.gallery,
                                        setModalState,
                                      ),
                                      icon: const Icon(Icons.image_rounded, size: 18),
                                      label: const Text('بارکردنی وێنەی پسوڵە'),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: _kNavy,
                                        side: BorderSide(
                                          color: _kGoldMid.withValues(alpha: 0.72),
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  IconButton.filledTonal(
                                    onPressed: () => pickReceipt(
                                      ImageSource.camera,
                                      setModalState,
                                    ),
                                    icon: const Icon(Icons.photo_camera_rounded),
                                  ),
                                ],
                              ),
                              if (receipt != null) ...[
                                const SizedBox(height: 10),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.file(
                                    File(receipt!.path),
                                    height: 110,
                                    width: double.infinity,
                                    fit: BoxFit.cover,
                                  ),
                                ),
                              ],
                            ],
                            const SizedBox(height: 14),
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: canConfirm
                                    ? kPatientDeepBlue
                                    : const Color(0xFF9E9E9E),
                                borderRadius: BorderRadius.circular(14),
                                boxShadow: canConfirm
                                    ? [
                                        BoxShadow(
                                          color: kPatientDeepBlue.withValues(alpha: 0.32),
                                          blurRadius: 12,
                                          offset: const Offset(0, 5),
                                        ),
                                      ]
                                    : null,
                              ),
                              child: TextButton(
                                onPressed: canConfirm
                                    ? () => Navigator.pop(
                                          ctx,
                                          _PaymentSelectionResult(
                                            method: hasDigital
                                                ? method
                                                : _PaymentMethod.cash,
                                            receipt: receipt,
                                          ),
                                        )
                                    : null,
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                                child: Text(
                                  s.translate('confirm_booking'),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontFamily: kPatientPrimaryFont,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
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
            },
          ),
        );
      },
    );
  }

  Widget _paymentOptionTile({
    required bool selected,
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected
              ? const Color(0xFF0D47A1).withValues(alpha: 0.08)
              : Colors.white.withValues(alpha: 0.82),
          border: Border.all(
            color: selected
                ? _kGoldMid.withValues(alpha: 0.9)
                : const Color(0xFF90CAF9).withValues(alpha: 0.35),
            width: selected ? 1.15 : 0.85,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _kGoldMid.withValues(alpha: 0.15),
              ),
              child: Icon(icon, color: _kGoldDark, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5,
                      color: _kNavy,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontFamily: kPatientPrimaryFont,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                      color: _kBodyMuted.withValues(alpha: 0.92),
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              const Icon(
                Icons.check_circle_rounded,
                color: HrNoraColors.openDayFill,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmWithPreview(
    BuildContext context, {
    required String slotTimeLabelEn,
  }) async {
    final form = await Navigator.of(context).push<PatientBookingFormResult>(
      MaterialPageRoute<PatientBookingFormResult>(
        builder: (_) => BookingDetailsPage(
          initialFullName: widget.patientName,
          doctorDisplayName: widget.doctorDisplayName,
          dateLocal: widget.dateLocal,
          slotTimeLabelEn: slotTimeLabelEn,
        ),
      ),
    );
    if (form == null || !context.mounted) return;

    final uid = (FirebaseAuth.instance.currentUser?.uid ??
            await PatientSessionCache.readPatientRefId())
        ?.trim();
    if (uid == null || uid.isEmpty) return;
    final hasActive = await _hasActiveAppointmentForPatient(uid);
    if (!context.mounted) return;
    if (hasActive) {
      await _showActiveBookingWarningDialog(context);
      return;
    }
    final legalApproved = await _showLegalWarningDialog(context);
    if (!context.mounted || !legalApproved) return;
    final payment = await _showPaymentSelectionSheet(context);
    if (payment == null || !context.mounted) return;
    await _commitBooking(context, payment, form);
  }

  Future<void> _commitBooking(
    BuildContext context,
    _PaymentSelectionResult payment,
    PatientBookingFormResult form,
  ) async {
    final s = S.of(context);
    final uid = (FirebaseAuth.instance.currentUser?.uid ??
            await PatientSessionCache.readPatientRefId())
        ?.trim();
    if (uid == null || uid.isEmpty) return;

    setState(() => _submitting = true);
    try {
      var doctorName = widget.doctorDisplayName.trim();
      if (doctorName.isEmpty) {
        try {
          doctorName = canonicalDoctorNameForStorage(widget.mergedDoctorData);
        } catch (_) {}
      }
      if (doctorName.isEmpty) doctorName = s.translate('doctor_default');

      String? receiptUrl;
      if (payment.method == _PaymentMethod.digital && payment.receipt != null) {
        try {
          final ref = FirebaseStorage.instance
              .ref()
              .child('appointment_receipts')
              .child(uid)
              .child('${DateTime.now().millisecondsSinceEpoch}.jpg');
          await ref.putFile(File(payment.receipt!.path));
          receiptUrl = await ref.getDownloadURL();
        } catch (e) {
          if (!mounted || !context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                s.translate('error_with_details', params: {'detail': '$e'}),
                style: const TextStyle(fontFamily: kPatientPrimaryFont),
              ),
            ),
          );
          return;
        }
      }

      final pm = payment.method == _PaymentMethod.cash ? 'cash' : 'digital';

      final displayName = form.fullName.trim().isEmpty
          ? widget.patientName.trim()
          : form.fullName.trim();

      final err = await bookAvailableDayTransaction(
        availableDayDocId: widget.availableDayDocId,
        patientId: uid,
        patientName: displayName.isEmpty ? widget.patientName : displayName,
        doctorId: _resolvedDoctorUid,
        doctorDisplayName: doctorName,
        paymentMethod: pm,
        receiptUrl: receiptUrl,
        extraAppointmentData: form.toAppointmentExtras(),
      );

      if (!mounted || !context.mounted) return;

      if (err != null) {
        final key = switch (err) {
          'available_day_full' => 'available_day_full',
          'available_day_missing' => 'available_day_missing',
          'available_day_doctor_mismatch' => 'available_day_mismatch',
          'available_day_closed' => 'available_day_closed',
          'login_required' => 'login_required',
          _ => 'available_day_tx_failed',
        };
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.translate(key),
              style: const TextStyle(fontFamily: kPatientPrimaryFont),
            ),
          ),
        );
        return;
      }

      if (!mounted || !context.mounted) return;

      final goToMyBookings = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        barrierColor: Colors.black.withValues(alpha: 0.16),
        builder: (ctx) {
          final dir = AppLocaleScope.of(ctx).textDirection;
          final loc = S.of(ctx);
          return Directionality(
            textDirection: dir,
            child: Stack(
              children: [
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 5.5, sigmaY: 5.5),
                    child: const SizedBox.expand(),
                  ),
                ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 26),
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.98),
                          const Color(0xFFE3F2FD).withValues(alpha: 0.92),
                        ],
                      ),
                      border: Border.all(
                        color: _kGoldMid.withValues(alpha: 0.42),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                        BoxShadow(
                          color: _kGoldMid.withValues(alpha: 0.14),
                          blurRadius: 20,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const _BookingSuccessCheckAnimation(),
                        const SizedBox(height: 14),
                        Text(
                          loc.translate('booking_success_title'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            color: _kNavy,
                            fontWeight: FontWeight.w800,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          loc.translate('booking_success_body'),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            color: _kBodyMuted,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${loc.translate('booking_summary_doctor')}: $doctorName',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            color: _kBodyMuted.withValues(alpha: 0.86),
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: FilledButton.styleFrom(
                            backgroundColor: kPatientDeepBlue,
                            foregroundColor: Colors.white,
                            elevation: 2,
                            shadowColor: kPatientDeepBlue.withValues(alpha: 0.34),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: Text(
                            loc.translate('ok'),
                            style: const TextStyle(
                              color: Colors.white,
                              fontFamily: kPatientPrimaryFont,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
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
          );
        },
      );

      if (!mounted || !context.mounted) return;
      if (goToMyBookings == true) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => MyAppointmentsScreen(
              highlightAvailableDayDocId: widget.availableDayDocId,
            ),
          ),
        );
        return;
      }
      Navigator.of(context).popUntil((route) => route.isFirst);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final localeTag = Localizations.localeOf(context).toLanguageTag();
    final dayOnly = DateTime(
      widget.dateLocal.year,
      widget.dateLocal.month,
      widget.dateLocal.day,
    );

    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        extendBodyBehindAppBar: false,
        appBar: AppBar(
          backgroundColor: Colors.white,
          foregroundColor: _kNavy,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          shadowColor: Colors.black.withValues(alpha: 0.06),
          leading: IconButton(
            icon: const Icon(Icons.arrow_forward_ios_rounded, color: _kNavy),
            onPressed: () => Navigator.pop(context),
            tooltip: s.translate('tooltip_back'),
          ),
          title: Text(
            s.translate('booking_summary_title'),
            style: const TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontWeight: FontWeight.w800,
              fontSize: 18,
              color: _kNavy,
              letterSpacing: 0.2,
            ),
          ),
        ),
        body: DecoratedBox(
          decoration: patientSkyGradientDecoration(),
          child: CustomPaint(
            painter: PatientSubtleGeometricPatternPainter(),
            child: SafeArea(
              top: false,
              child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection(AvailableDayFields.collection)
                .doc(widget.availableDayDocId)
                .snapshots(),
            builder: (context, daySnap) {
              if (daySnap.connectionState == ConnectionState.waiting &&
                  !daySnap.hasData) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(40),
                    child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
                  ),
                );
              }
              final dayData = daySnap.data?.data();
              final open = availableDayIsOpen(dayData);
              if (dayData == null) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.translate('available_day_missing'),
                      style: const TextStyle(
                        color: _kBodyMuted,
                        fontFamily: kPatientPrimaryFont,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }

              final startHhMm = normalizeAvailableDayStartTimeHhMm(
                dayData[AvailableDayFields.startTime],
              );
              final closingHhMm = normalizeAvailableDayClosingTimeHhMm(
                dayData[AvailableDayFields.closingTime],
              );
              final durMin = normalizeAppointmentDurationMinutes(
                dayData[AvailableDayFields.appointmentDuration],
              );

              final slots = generatedSlotStartsForDay(
                dateOnly: dayOnly,
                startTimeHhMm: startHhMm,
                closingTimeHhMm: closingHhMm,
                durationMinutes: durMin,
              );

              return StreamBuilder<List<QueryDocumentSnapshot<Map<String, dynamic>>>>(
                stream: watchDoctorAppointmentsForLocalDay(
                  doctorUserId: _doctorUid,
                  dayLocal: dayOnly,
                ),
                builder: (context, apptSnap) {
                  if (apptSnap.hasError) {
                    return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text(
                          s.translate(
                            'doctors_load_error_detail',
                            params: {'error': '${apptSnap.error}'},
                          ),
                          style: const TextStyle(
                            color: Colors.redAccent,
                            fontFamily: kPatientPrimaryFont,
                            fontWeight: FontWeight.w600,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }

                  final docs = apptSnap.data ??
                      const <QueryDocumentSnapshot<Map<String, dynamic>>>[];
                  final bookedKeys = bookedTimeKeysHhMmForAvailableDay(
                    sameDayDocs: docs,
                    availableDayDocId: widget.availableDayDocId,
                  );
                  final firstFree = firstAvailableSlotStart(
                    slots: slots,
                    bookedKeys: bookedKeys,
                  );
                  final assignedTimeDisplay = firstFree != null
                      ? DateFormat.jm(localeTag).format(firstFree)
                      : '—';

                  final doctorName = widget.doctorDisplayName.trim().isEmpty
                      ? s.translate('doctor_default')
                      : widget.doctorDisplayName;
                  final dateLabelValue =
                      DateFormat.yMMMEd(localeTag).format(widget.dateLocal);

                  final bookedCount = bookedKeys.length;
                  final totalCapacity = slots.length;
                  final spotsLeft =
                      (totalCapacity - bookedCount).clamp(0, totalCapacity);

                  _scheduleScrollToAssignedSlot(firstFree, slots);

                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(22),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(22),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Colors.white.withValues(alpha: 0.93),
                                    Colors.white.withValues(alpha: 0.78),
                                  ],
                                ),
                                border: Border.all(
                                  color: _kGoldMid.withValues(alpha: 0.78),
                                  width: 1.15,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.06),
                                    blurRadius: 26,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color: _kGoldMid.withValues(alpha: 0.16),
                                    blurRadius: 22,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  18,
                                  20,
                                  18,
                                  20,
                                ),
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    Text(
                                      s.translate(
                                        'booking_summary_assigned_time',
                                      ),
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: _kBodyMuted.withValues(
                                          alpha: 0.92,
                                        ),
                                        height: 1.25,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      assignedTimeDisplay,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontSize: 34,
                                        fontWeight: FontWeight.w800,
                                        color: _kNavy,
                                        height: 1.1,
                                        letterSpacing: 0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 20),
                                    _BookingSummaryInfoRow(
                                      icon: Icons.person_rounded,
                                      label: s.translate(
                                        'booking_summary_doctor',
                                      ),
                                      value: doctorName,
                                    ),
                                    const SizedBox(height: 14),
                                    _BookingSummaryInfoRow(
                                      icon: Icons.calendar_today_rounded,
                                      label: s.translate(
                                        'booking_summary_date_label',
                                      ),
                                      value: dateLabelValue,
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: 18,
                                        bottom: 6,
                                      ),
                                      child: _BookingCapacityStats(
                                        bookedText: _localizedDigitString(
                                          context,
                                          bookedCount,
                                        ),
                                        totalText: _localizedDigitString(
                                          context,
                                          totalCapacity,
                                        ),
                                        sublabel: s.translate(
                                          'booking_summary_only_spots_left',
                                          params: {
                                            'x': _localizedDigitString(
                                              context,
                                              spotsLeft,
                                            ),
                                          },
                                        ),
                                      ),
                                    ),
                                    if (!open)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 8),
                                        child: Text(
                                          s.translate(
                                            'available_day_closed_banner',
                                          ),
                                          style: const TextStyle(
                                            fontFamily: kPatientPrimaryFont,
                                            color: HrNoraColors.closedDayFill,
                                            fontWeight: FontWeight.w700,
                                            fontSize: 13,
                                          ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          s.translate('patient_booking_slots_privacy_title'),
                          style: TextStyle(
                            fontFamily: kPatientPrimaryFont,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: _kBodyMuted.withValues(alpha: 0.85),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (firstFree != null && slots.isNotEmpty) ...[
                          DecoratedBox(
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.72),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _kGoldMid.withValues(alpha: 0.35),
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline_rounded,
                                    size: 18,
                                    color: _kGoldDark.withValues(alpha: 0.9),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      s.translate(
                                        'booking_summary_selected_slot_hint',
                                      ),
                                      style: TextStyle(
                                        fontFamily: kPatientPrimaryFont,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                        height: 1.35,
                                        color: _kNavy.withValues(alpha: 0.88),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 10),
                        ],
                        Expanded(
                          child: slots.isEmpty
                              ? Center(
                                  child: Text(
                                    s.translate('day_mgmt_no_slots'),
                                    style: TextStyle(
                                      color: _kBodyMuted.withValues(alpha: 0.9),
                                      fontFamily: kPatientPrimaryFont,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                )
                              : ListView.builder(
                                  padding: const EdgeInsets.only(bottom: 16),
                                  itemCount: slots.length,
                                  itemBuilder: (context, i) {
                                    final slot = slots[i];
                                    final key = formatTimeHhMm(slot);
                                    final isBooked = bookedKeys.contains(key);
                                    final assigned = firstFree;
                                    final isYourSlot = assigned != null &&
                                        !isBooked &&
                                        key == formatTimeHhMm(assigned);
                                    final dimOthers = firstFree != null &&
                                        slots.isNotEmpty &&
                                        !isYourSlot;
                                    final timePretty =
                                        DateFormat.jm(localeTag).format(slot);

                                    final statusText = isBooked
                                        ? s.translate(
                                            'patient_slot_label_booked',
                                          )
                                        : (isYourSlot
                                              ? s.translate(
                                                  'patient_slot_label_yours',
                                                )
                                              : s.translate(
                                                  'patient_slot_label_available',
                                                ));

                                    final statusStyle = TextStyle(
                                      fontFamily: kPatientPrimaryFont,
                                      fontSize: isYourSlot ? 15 : 14,
                                      fontWeight: isYourSlot
                                          ? FontWeight.w900
                                          : FontWeight.w800,
                                      color: isBooked
                                          ? _kBookedRed
                                          : (isYourSlot
                                                ? _kNavy
                                                : _kEmeraldAvailable),
                                    );

                                    Widget card = DecoratedBox(
                                      decoration: BoxDecoration(
                                        gradient: isYourSlot
                                            ? LinearGradient(
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                                colors: [
                                                  const Color(0xFFFFF8E1)
                                                      .withValues(alpha: 0.98),
                                                  const Color(0xFFFFECB3)
                                                      .withValues(alpha: 0.92),
                                                  Color(0xFFE8EAF6)
                                                      .withValues(alpha: 0.55),
                                                ],
                                              )
                                            : null,
                                        color: isYourSlot
                                            ? null
                                            : Colors.white.withValues(
                                                alpha: 0.94,
                                              ),
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: isYourSlot
                                              ? _kGoldMid.withValues(
                                                  alpha: 0.98,
                                                )
                                              : _kSlotBorderBlue.withValues(
                                                  alpha: 0.28,
                                                ),
                                          width: isYourSlot ? 2.85 : 0.75,
                                        ),
                                        boxShadow: isYourSlot
                                            ? [
                                                BoxShadow(
                                                  color: _kGoldMid.withValues(
                                                    alpha: 0.38,
                                                  ),
                                                  blurRadius: 20,
                                                  offset: const Offset(0, 5),
                                                  spreadRadius: 0.5,
                                                ),
                                                BoxShadow(
                                                  color: _kGoldShine
                                                      .withValues(alpha: 0.35),
                                                  blurRadius: 16,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ]
                                            : [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.04),
                                                  blurRadius: 10,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 14,
                                          vertical: 12,
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.schedule_rounded,
                                              color: isYourSlot
                                                  ? _kGoldDark.withValues(
                                                      alpha: 0.95,
                                                    )
                                                  : _kGoldMid.withValues(
                                                      alpha: 0.95,
                                                    ),
                                              size: 20,
                                            ),
                                            const SizedBox(width: 10),
                                            SizedBox(
                                              width: 86,
                                              child: Text(
                                                timePretty,
                                                style: const TextStyle(
                                                  fontFamily:
                                                      kPatientPrimaryFont,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 13,
                                                  color: _kNavy,
                                                ),
                                              ),
                                            ),
                                            Expanded(
                                              child: Text(
                                                statusText,
                                                textAlign: TextAlign.end,
                                                style: statusStyle,
                                              ),
                                            ),
                                            if (isYourSlot) ...[
                                              const SizedBox(width: 6),
                                              Icon(
                                                Icons.check_circle_rounded,
                                                color: _kEmeraldAvailable,
                                                size: 22,
                                              ),
                                              const SizedBox(width: 4),
                                              Icon(
                                                Icons.star_rounded,
                                                color: _kGoldMid,
                                                size: 26,
                                                shadows: [
                                                  Shadow(
                                                    color: _kGoldDark
                                                        .withValues(alpha: 0.35),
                                                    blurRadius: 6,
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    );

                                    if (dimOthers) {
                                      card = Opacity(opacity: 0.5, child: card);
                                    }

                                    return Padding(
                                      key: isYourSlot
                                          ? _selectedSlotKey
                                          : ValueKey<String>('slot_$key'),
                                      padding: const EdgeInsets.only(bottom: 8),
                                      child: card,
                                    );
                                  },
                                ),
                        ),
                        const SizedBox(height: 12),
                        _PremiumGoldBookingButton(
                          enabled: !_submitting &&
                              open &&
                              firstFree != null &&
                              slots.isNotEmpty,
                          submitting: _submitting,
                          label: s.translate('confirm_booking'),
                          onPressed: () {
                            final slotEn = firstFree != null
                                ? DateFormat.jm('en_US').format(firstFree)
                                : '—';
                            _confirmWithPreview(
                              context,
                              slotTimeLabelEn: slotEn,
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              );
            },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _BookingSuccessCheckAnimation extends StatefulWidget {
  const _BookingSuccessCheckAnimation();

  @override
  State<_BookingSuccessCheckAnimation> createState() =>
      _BookingSuccessCheckAnimationState();
}

class _BookingSuccessCheckAnimationState extends State<_BookingSuccessCheckAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 680),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: CurvedAnimation(
        parent: _controller,
        curve: Curves.elasticOut,
      ),
      child: FadeTransition(
        opacity: CurvedAnimation(
          parent: _controller,
          curve: const Interval(0, 0.5, curve: Curves.easeOut),
        ),
        child: Container(
          width: 72,
          height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                HrNoraColors.openDayGradientLight.withValues(alpha: 0.32),
                HrNoraColors.openDayFill.withValues(alpha: 0.18),
              ],
            ),
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 46,
            color: HrNoraColors.openDayFill,
          ),
        ),
      ),
    );
  }
}

enum _PaymentMethod { cash, digital }

class _PaymentSelectionResult {
  const _PaymentSelectionResult({
    required this.method,
    this.receipt,
  });

  final _PaymentMethod method;
  final XFile? receipt;
}

String _localizedDigitString(BuildContext context, int n) {
  final code = Localizations.localeOf(context).languageCode;
  if (code == 'ar' || code == 'ckb') {
    try {
      return NumberFormat('#', 'ar').format(n);
    } catch (_) {
      return '$n';
    }
  }
  return '$n';
}

/// Doctor + date row with gold icon on soft emerald circle (summary card).
class _BookingSummaryInfoRow extends StatelessWidget {
  const _BookingSummaryInfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  static const Color _iconCircleGreen = HrNoraColors.openDayFill;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _iconCircleGreen.withValues(alpha: 0.12),
            border: Border.all(
              color: _kGoldMid.withValues(alpha: 0.48),
              width: 0.75,
            ),
          ),
          child: Icon(icon, color: _kGoldMid, size: 22),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _kBodyMuted.withValues(alpha: 0.88),
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _kNavy,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Booked (red) + `/` total capacity (green), with remaining-spots sentence below.
class _BookingCapacityStats extends StatelessWidget {
  const _BookingCapacityStats({
    required this.bookedText,
    required this.totalText,
    required this.sublabel,
  });

  final String bookedText;
  final String totalText;
  final String sublabel;

  static const Color _bookedRed = Color(0xFFB91C1C);
  static const Color _capGreen = Color(0xFF22C55E);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                bookedText,
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: _bookedRed,
                  height: 1,
                ),
              ),
              Text(
                ' / ',
                style: TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _kBodyMuted.withValues(alpha: 0.75),
                  height: 1,
                ),
              ),
              Text(
                totalText,
                style: const TextStyle(
                  fontFamily: kPatientPrimaryFont,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: _capGreen,
                  height: 1,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(
            sublabel,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: kPatientPrimaryFont,
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: _kBodyMuted.withValues(alpha: 0.82),
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _PremiumGoldBookingButton extends StatefulWidget {
  const _PremiumGoldBookingButton({
    required this.enabled,
    required this.submitting,
    required this.label,
    required this.onPressed,
  });

  final bool enabled;
  final bool submitting;
  final String label;
  final VoidCallback onPressed;

  @override
  State<_PremiumGoldBookingButton> createState() =>
      _PremiumGoldBookingButtonState();
}

class _PremiumGoldBookingButtonState extends State<_PremiumGoldBookingButton>
    with SingleTickerProviderStateMixin {
  static const double _kPressedScale = 0.96;

  late final AnimationController _scaleController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 115),
    reverseDuration: const Duration(milliseconds: 135),
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: _kPressedScale,
  ).animate(
    CurvedAnimation(
      parent: _scaleController,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeOutBack,
    ),
  );

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _pressDown() {
    if (!widget.enabled || widget.submitting) return;
    HapticFeedback.lightImpact();
    _scaleController.forward();
  }

  void _pressEnd() {
    _scaleController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.enabled && !widget.submitting;
    final shell = Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: active
            ? _kConfirmBookingGoldGradient
            : const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF9CA3AF), Color(0xFF6B7280)],
              ),
        border: Border.all(
          color: active
              ? _kConfirmButtonSilverBorder
              : const Color(0xFFB0BEC5),
          width: 0.8,
        ),
        boxShadow: active
            ? [
                BoxShadow(
                  color: _kConfirmGoldDarkRod.withValues(alpha: 0.40),
                  blurRadius: 14,
                  offset: const Offset(0, 5),
                  spreadRadius: 0,
                ),
                BoxShadow(
                  color: const Color(0xFF8B6914).withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 9),
                  spreadRadius: -3,
                ),
              ]
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: widget.submitting
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: Color(0xFF1A120E),
                  ),
                )
              : Text(
                  widget.label,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: active ? Colors.black : const Color(0xFFE5E7EB),
                  ),
                ),
        ),
      ),
    );

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _pressDown(),
      onTapUp: (_) => _pressEnd(),
      onTapCancel: _pressEnd,
      onTap: active ? widget.onPressed : null,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(
            scale: active ? _scale.value : 1.0,
            alignment: Alignment.center,
            child: child,
          );
        },
        child: shell,
      ),
    );
  }
}
