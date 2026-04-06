import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/doctor_localized_content.dart';
import '../schedule/schedule_management_screen.dart';
import '../theme/staff_premium_theme.dart';

/// Secretary: pick an approved doctor, then manage their available-day schedule.
class SecretaryScheduleScreen extends StatefulWidget {
  const SecretaryScheduleScreen({super.key});

  @override
  State<SecretaryScheduleScreen> createState() => _SecretaryScheduleScreenState();
}

class _SecretaryScheduleScreenState extends State<SecretaryScheduleScreen> {
  String? _pickedDoctorId;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: ColoredBox(
        color: Colors.transparent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('users')
                    .where('role', isEqualTo: 'Doctor')
                    .where('isApproved', isEqualTo: true)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const LinearProgressIndicator(minHeight: 2);
                  }
                  final docs = snap.data!.docs;
                  if (docs.isEmpty) {
                    return Text(
                      s.translate('master_calendar_no_doctors'),
                      style: staffLabelTextStyle(),
                    );
                  }
                  return DropdownButtonFormField<String>(
                    // ignore: deprecated_member_use
                    value: _pickedDoctorId != null &&
                            docs.any((d) => d.id == _pickedDoctorId)
                        ? _pickedDoctorId
                        : null,
                    dropdownColor: kStaffCardSurface,
                    decoration: InputDecoration(
                      labelText: s.translate('master_calendar_pick_doctor'),
                      labelStyle: staffLabelTextStyle(),
                      filled: true,
                      fillColor: kStaffCardSurface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: kStaffSilverBorder,
                          width: kStaffCardOutlineWidth,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: kStaffSilverBorder,
                          width: kStaffCardOutlineWidth,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: kStaffPrimaryNavy,
                          width: 1.2,
                        ),
                      ),
                    ),
                    items: docs
                        .map(
                          (d) => DropdownMenuItem(
                            value: d.id,
                            child: Text(
                              localizedDoctorFullName(
                                d.data(),
                                AppLocaleScope.of(context).effectiveLanguage,
                              ),
                              style: staffHeaderTextStyle(
                                fontSize: 15,
                                color: kStaffBodyText,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) => setState(() => _pickedDoctorId = v),
                  );
                },
              ),
            ),
            Expanded(
              child: _pickedDoctorId == null
                  ? Center(
                      child: Text(
                        s.translate('master_calendar_pick_doctor'),
                        style: staffLabelTextStyle(),
                      ),
                    )
                  : ScheduleManagementScreen(
                      managedDoctorUserId: _pickedDoctorId!.trim(),
                      embedded: true,
                      embeddedBodyExtendsBehindBottomBar: true,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
