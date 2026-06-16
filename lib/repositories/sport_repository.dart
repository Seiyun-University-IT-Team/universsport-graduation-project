import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/sport_model.dart';
import '../core/demo_config.dart';

class SportRepository {
  FirebaseFirestore get _firestore => FirebaseFirestore.instance;
  final String _collection = 'sports';

  Future<void> addSport(SportModel sport) async {
    if (AppDemoConfig.useMockData) return;
    await _firestore.collection(_collection).doc(sport.id).set(sport.toMap());
  }

  Future<void> updateSport(SportModel sport) async {
    if (AppDemoConfig.useMockData) return;
    await _firestore.collection(_collection).doc(sport.id).update(sport.toMap());
  }

  Future<void> deleteSport(String id) async {
    if (AppDemoConfig.useMockData) return;
    await _firestore.collection(_collection).doc(id).delete();
  }

  Stream<List<SportModel>> getSports() {
    if (AppDemoConfig.useMockData) {
      return Stream.value(AppDemoConfig.mockSports);
    }
    return _firestore.collection(_collection).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => SportModel.fromFirestore(doc)).toList();
    });
  }

  Future<SportModel?> getSportById(String id) async {
    if (AppDemoConfig.useMockData) {
      try {
        return AppDemoConfig.mockSports.firstWhere((sport) => sport.id == id);
      } catch (_) {
        return null;
      }
    }
    final doc = await _firestore.collection(_collection).doc(id).get();
    if (doc.exists) {
      return SportModel.fromFirestore(doc);
    }
    return null;
  }
}

