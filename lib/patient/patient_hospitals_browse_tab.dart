import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../firestore/hospital_queries.dart';
import '../locale/app_locale.dart';
import '../locale/app_localizations.dart';
import '../models/hospital_localized_content.dart';
import 'hospital_doctors_screen.dart';
import 'hospital_mock_data.dart';

const double _kHospitalsSearchHeaderExtent = 56;

List<({String id, Map<String, dynamic> data})> _resolveHospitalRowsForTab(
  QuerySnapshot<Map<String, dynamic>>? snap,
) {
  if (snap == null) return <({String id, Map<String, dynamic> data})>[];
  final sorted = sortHospitalDocuments(snap.docs);
  if (sorted.isNotEmpty) {
    return [for (final d in sorted) (id: d.id, data: d.data())];
  }
  if (kShowMockHospitalsWhenEmpty) return kMockHospitalRows;
  return <({String id, Map<String, dynamic> data})>[];
}

String _hospitalSearchBlob(Map<String, dynamic> data, HrNoraLanguage lang) {
  return [
    localizedHospitalName(data, lang),
    (data['location'] ?? '').toString(),
    (data['name'] ?? '').toString(),
    (data['name_ar'] ?? '').toString(),
    (data['name_en'] ?? '').toString(),
  ].join(' ');
}

List<({String id, Map<String, dynamic> data})> _filterHospitalRowsForTab(
  List<({String id, Map<String, dynamic> data})> rows,
  String query,
  HrNoraLanguage lang,
) {
  final q = query.trim().toLowerCase();
  if (q.isEmpty) return rows;
  return rows
      .where((r) => _hospitalSearchBlob(r.data, lang).toLowerCase().contains(q))
      .toList();
}

/// Dedicated hospitals grid (bottom-nav tab). Sticky search; list scrolls.
class PatientHospitalsBrowseTab extends StatefulWidget {
  const PatientHospitalsBrowseTab({super.key});

  @override
  State<PatientHospitalsBrowseTab> createState() =>
      _PatientHospitalsBrowseTabState();
}

class _PatientHospitalsBrowseTabState extends State<PatientHospitalsBrowseTab> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Widget _buildThinSearchBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF15182C),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (_) => setState(() {}),
          textAlign: TextAlign.start,
          style: const TextStyle(
            color: Color(0xFFD9E2EC),
            fontFamily: 'KurdishFont',
            fontSize: 14,
            height: 1.2,
          ),
          cursorColor: const Color(0xFF42A5F5),
          decoration: InputDecoration(
            isDense: true,
            hintText: S.of(context).translate('search_hospitals_hint'),
            hintStyle: TextStyle(
              color: const Color(0xFF829AB1).withValues(alpha: 0.9),
              fontFamily: 'KurdishFont',
              fontSize: 13,
            ),
            prefixIcon: const Icon(
              Icons.search_rounded,
              color: Color(0xFF42A5F5),
              size: 20,
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 40,
              minHeight: 36,
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 8,
              vertical: 10,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: AppLocaleScope.of(context).textDirection,
      child: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverPersistentHeader(
              pinned: true,
              delegate: _HospitalsStickyHeaderDelegate(
                extent: _kHospitalsSearchHeaderExtent,
                builder: (context, shrinkOffset, overlapsContent) {
                  return Material(
                    color: const Color(0xFF0A0E21),
                    surfaceTintColor: Colors.transparent,
                    elevation: overlapsContent ? 3 : 0,
                    shadowColor: Colors.black54,
                    child: _buildThinSearchBar(context),
                  );
                },
              ),
            ),
          ];
        },
        body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: hospitalsSnapshotStream(),
          builder: (context, hospSnap) {
            final lang = AppLocaleScope.of(context).effectiveLanguage;
            final dir = AppLocaleScope.of(context).textDirection;
            if (hospSnap.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    S
                        .of(context)
                        .translate(
                          'hospitals_load_error',
                          params: {'error': '${hospSnap.error}'},
                        ),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontFamily: 'KurdishFont',
                      fontSize: 13,
                    ),
                  ),
                ),
              );
            }
            if (hospSnap.connectionState == ConnectionState.waiting &&
                !hospSnap.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: Color(0xFF42A5F5)),
              );
            }
            final rows = _resolveHospitalRowsForTab(hospSnap.data);
            final filtered = _filterHospitalRowsForTab(
              rows,
              _searchController.text,
              lang,
            );
            if (filtered.isEmpty) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    S.of(context).translate('hospitals_browse_empty'),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Color(0xFF829AB1),
                      fontFamily: 'KurdishFont',
                      fontSize: 16,
                    ),
                  ),
                ),
              );
            }
            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 0.78,
              ),
              itemCount: filtered.length,
              itemBuilder: (context, index) {
                return _HospitalGridCard(
                  row: filtered[index],
                  lang: lang,
                  dir: dir,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _HospitalGridCard extends StatelessWidget {
  const _HospitalGridCard({
    required this.row,
    required this.lang,
    required this.dir,
  });

  final ({String id, Map<String, dynamic> data}) row;
  final HrNoraLanguage lang;
  final TextDirection dir;

  @override
  Widget build(BuildContext context) {
    final data = row.data;
    final name = localizedHospitalName(data, lang);
    final logoUrl = (data['logoUrl'] ?? '').toString().trim();
    final loc = (data['location'] ?? '').toString().trim();
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Navigator.push<void>(
            context,
            MaterialPageRoute<void>(
              builder: (context) => HospitalDoctorsScreen(
                hospitalId: row.id,
                initialHospitalData: Map<String, dynamic>.from(data),
              ),
            ),
          );
        },
        borderRadius: BorderRadius.circular(18),
        child: Ink(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFF1D1E33),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            textDirection: dir,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF12152A),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: const Color(0xFF42A5F5).withValues(alpha: 0.35),
                    ),
                  ),
                  clipBehavior: Clip.antiAlias,
                  alignment: Alignment.center,
                  child: logoUrl.isEmpty
                      ? const Icon(
                          Icons.local_hospital_rounded,
                          color: Color(0xFF42A5F5),
                          size: 40,
                        )
                      : CachedNetworkImage(
                          imageUrl: logoUrl,
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                          memCacheWidth: 200,
                          memCacheHeight: 200,
                          fadeInDuration: Duration.zero,
                          errorWidget: (context, url, error) => const Icon(
                            Icons.local_hospital_rounded,
                            color: Color(0xFF42A5F5),
                            size: 40,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                name.isEmpty ? '—' : name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Color(0xFFD9E2EC),
                  fontFamily: 'KurdishFont',
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  height: 1.2,
                ),
              ),
              if (loc.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  loc,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFF829AB1),
                    fontFamily: 'KurdishFont',
                    fontSize: 11,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _HospitalsStickyHeaderDelegate extends SliverPersistentHeaderDelegate {
  _HospitalsStickyHeaderDelegate({required this.extent, required this.builder});

  final double extent;
  final Widget Function(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  )
  builder;

  @override
  double get minExtent => extent;

  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return SizedBox(
      height: extent,
      child: builder(context, shrinkOffset, overlapsContent),
    );
  }

  @override
  bool shouldRebuild(covariant _HospitalsStickyHeaderDelegate oldDelegate) =>
      true;
}
