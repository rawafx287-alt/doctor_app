import 'package:flutter/material.dart';

import '../theme/patient_premium_theme.dart';
import 'favorites_store.dart';
import 'patient_doctor_card.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kPatientSkyTop,
      appBar: AppBar(
        backgroundColor: kPatientSkyTop,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Favorites',
          style: TextStyle(
            fontFamily: kPatientPrimaryFont,
            fontWeight: FontWeight.w800,
            fontSize: 18,
            color: Color(0xFF1A237E),
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: favoritesStore,
        builder: (context, _) {
          final items = favoritesStore.items;
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'Favorites will appear here.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: kPatientPrimaryFont,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: Color(0xFF546E7A),
                  ),
                ),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final d = items[index];
              return Padding(
                padding: EdgeInsets.only(bottom: index == items.length - 1 ? 0 : 10),
                child: PatientDoctorCard(
                  name: d.name,
                  specialty: d.specialty,
                  profileImageUrl: d.profileImageUrl,
                  ratingAverage: d.ratingAverage,
                  ratingCount: d.ratingCount,
                  initiallyFavorite: true,
                  onFavoriteChanged: (fav) {
                    if (!fav) {
                      favoritesStore.setFavorite(d, false);
                    }
                  },
                  onBook: () {},
                  onOpenDetails: () {},
                ),
              );
            },
          );
        },
      ),
    );
  }
}

