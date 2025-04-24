import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class StatusService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  void updateOnlineStatus(bool isOnline) {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    _firestore.collection('users').doc(userId).update({
      'isOnline': isOnline,
      'lastSeen': FieldValue.serverTimestamp(),
    });
  }

  void startListening() {
    _auth.authStateChanges().listen((user) {
      if (user != null) {
        updateOnlineStatus(true);
      }
    });
  }

  void stopListening() {
    updateOnlineStatus(false);
  }
}
