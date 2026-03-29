import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../firestore/hospital_queries.dart';

/// Dropdown of [HospitalFields.collection] for admin add/edit doctor flows.
class AdminHospitalDropdown extends StatelessWidget {
  const AdminHospitalDropdown({
    super.key,
    required this.value,
    required this.onChanged,
    this.label = 'نەخۆشخانە',
  });

  final String? value;
  final ValueChanged<String?> onChanged;
  final String label;

  static String displayName(Map<String, dynamic> data) {
    final n = (data['name'] ?? data['name_ku'] ?? '').toString().trim();
    if (n.isNotEmpty) return n;
    return (data['name_en'] ?? '—').toString();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: hospitalsSnapshotStream(),
      builder: (context, snap) {
        if (snap.hasError) {
          return Text(
            'هەڵە لە هێنانی نەخۆشخانەکان: ${snap.error}',
            style: const TextStyle(color: Color(0xFFEF4444), fontSize: 12),
          );
        }
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Color(0xFF42A5F5),
                ),
              ),
            ),
          );
        }
        final sorted = sortHospitalDocuments(snap.data?.docs ?? const []);
        String? effective = value;
        if (effective != null &&
            effective.isNotEmpty &&
            !sorted.any((d) => d.id == effective)) {
          effective = null;
        }
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsetsDirectional.only(start: 4, end: 12),
          child: DropdownButtonFormField<String?>(
            // ignore: deprecated_member_use
            value: effective,
            isExpanded: true,
            iconEnabledColor: Colors.blueAccent,
            dropdownColor: const Color(0xFF1D1E33),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
            decoration: InputDecoration(
              labelText: label,
              labelStyle: const TextStyle(color: Colors.grey),
              prefixIcon: const Icon(Icons.local_hospital_rounded, color: Colors.blueAccent),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('دیارینەکراو'),
              ),
              ...sorted.map(
                (d) => DropdownMenuItem<String?>(
                  value: d.id,
                  child: Text(
                    displayName(d.data()),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
            onChanged: onChanged,
          ),
        );
      },
    );
  }
}
