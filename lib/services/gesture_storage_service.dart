import 'package:shared_preferences/shared_preferences.dart';

import '../models/gesture_models.dart';

class GestureStorageService {
  static const String _repositoryKey = 'gesture_repository_v1';

  Future<GestureRepositorySnapshot> loadRepository() async {
    final prefs = await SharedPreferences.getInstance();
    final encoded = prefs.getString(_repositoryKey);
    if (encoded == null || encoded.isEmpty) {
      return const GestureRepositorySnapshot(
        samples: [],
        gestures: [],
        model: null,
      );
    }

    return GestureRepositorySnapshot.fromEncodedJson(encoded);
  }

  Future<void> saveRepository(GestureRepositorySnapshot repository) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_repositoryKey, repository.toEncodedJson());
  }
}
