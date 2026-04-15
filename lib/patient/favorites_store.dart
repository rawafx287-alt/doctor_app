import 'package:flutter/foundation.dart';

/// Minimal data needed to render a favorited doctor card consistently.
@immutable
class FavoriteDoctor {
  const FavoriteDoctor({
    required this.doctorId,
    required this.name,
    required this.specialty,
    required this.profileImageUrl,
    required this.ratingAverage,
    required this.ratingCount,
    required this.clinicAddress,
    required this.googleMapsUrl,
  });

  final String doctorId;
  final String name;
  final String specialty;
  final String profileImageUrl;
  final double ratingAverage;
  final int ratingCount;
  final String clinicAddress;
  final String googleMapsUrl;
}

/// Simple global favorites store (UI-only).
class FavoritesStore extends ChangeNotifier {
  final Map<String, FavoriteDoctor> _items = <String, FavoriteDoctor>{};

  List<FavoriteDoctor> get items => _items.values.toList(growable: false);

  bool isFavorite(String doctorId) => _items.containsKey(doctorId);

  void setFavorite(FavoriteDoctor doctor, bool favorite) {
    bool changed = false;
    if (favorite) {
      final had = _items.containsKey(doctor.doctorId);
      _items[doctor.doctorId] = doctor;
      changed = !had;
    } else {
      changed = _items.remove(doctor.doctorId) != null;
    }
    if (changed) notifyListeners();
  }

  void toggle(FavoriteDoctor doctor) {
    setFavorite(doctor, !isFavorite(doctor.doctorId));
  }
}

/// Global singleton (simple, no Provider needed yet).
final FavoritesStore favoritesStore = FavoritesStore();

