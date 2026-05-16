
import 'package:firebase_database/firebase_database.dart';

class ElderDatabaseService {
  // 1. Pointing to your Realtime Database
  final FirebaseDatabase _db = FirebaseDatabase.instance;

  // 2. The function that saves the User Profile
  Future<void> createUserProfile({
    required String uid,
    required String fullName,
    required String role,
    required int age,
    required String phone,
  }) async {
    await _db.ref('users/$uid').set({
      'full_name': fullName,
      'role': role,
      'age': age,
      'phone': phone,
    });
  }

  // 3. The function that adds medical conditions dynamically
  Future<void> addHealthCondition({
    required String elderlyUid,
    required String conditionName,
    required String severity,
    required String diagnosedDate,
  }) async {
    // .push() creates a new unique ID every time so you can have infinite conditions
    await _db.ref('users/$elderlyUid/health_profile/conditions').push().set({
      'name': conditionName,
      'severity': severity,
      'diagnosed_date': diagnosedDate,
    });
  }
}