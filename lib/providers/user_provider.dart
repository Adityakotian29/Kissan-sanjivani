import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final userProvider = StateNotifierProvider<UserNotifier, Map<String, dynamic>>((ref) {
  return UserNotifier();
});

class UserNotifier extends StateNotifier<Map<String, dynamic>> {
  UserNotifier() : super({}) {
    // Listen to auth state changes
    FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        loadUserData();
      } else {
        state = {};
      }
    });
  }

  Future<void> loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      
      if (userData.exists) {
        state = userData.data() ?? {};
      } else {
        // Initialize with default data if document doesn't exist
        state = {
          'name': user.displayName ?? 'User',
          'phone': user.phoneNumber ?? '',
        };
        // Create the document in Firestore
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(state);
      }
    }
  }

  Future<void> updateUserData(Map<String, dynamic> data) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update(data);
      
      state = {...state, ...data};
    }
  }
}