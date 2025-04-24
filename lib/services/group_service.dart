import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/group.dart';

class GroupService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<Group> createGroup({
    required String name,
    required List<String> members,
    File? imageFile,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    String? photoUrl;
    if (imageFile != null) {
      final ref = _storage
          .ref()
          .child('group_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      photoUrl = await ref.getDownloadURL();
    }

    final group = Group(
      id: '',
      name: name,
      photoUrl: photoUrl,
      members: [...members, userId],
      adminId: userId,
      createdAt: DateTime.now(),
    );

    final docRef =
        await _firestore.collection('groups').add(group.toFirestore());
    return group.copyWith(id: docRef.id);
  }

  Future<void> updateGroup({
    required String groupId,
    String? name,
    File? imageFile,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final group = Group.fromFirestore(groupDoc.data()!, groupId);
    if (group.adminId != userId) return;

    String? photoUrl = group.photoUrl;
    if (imageFile != null) {
      final ref = _storage
          .ref()
          .child('group_images/${DateTime.now().millisecondsSinceEpoch}.jpg');
      await ref.putFile(imageFile);
      photoUrl = await ref.getDownloadURL();
    }

    await _firestore.collection('groups').doc(groupId).update({
      if (name != null) 'name': name,
      if (photoUrl != null) 'photoUrl': photoUrl,
    });
  }

  Future<void> addMember(String groupId, String userId) async {
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) return;

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final group = Group.fromFirestore(groupDoc.data()!, groupId);
    if (group.adminId != adminId) return;

    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayUnion([userId]),
    });
  }

  Future<void> removeMember(String groupId, String userId) async {
    final adminId = _auth.currentUser?.uid;
    if (adminId == null) return;

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final group = Group.fromFirestore(groupDoc.data()!, groupId);
    if (group.adminId != adminId) return;

    await _firestore.collection('groups').doc(groupId).update({
      'members': FieldValue.arrayRemove([userId]),
    });
  }

  Future<void> leaveGroup(String groupId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final groupDoc = await _firestore.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) return;

    final group = Group.fromFirestore(groupDoc.data()!, groupId);
    if (group.adminId == userId) {
      // If admin is leaving, assign new admin or delete group
      if (group.members.length > 1) {
        final newAdmin = group.members.firstWhere((m) => m != userId);
        await _firestore.collection('groups').doc(groupId).update({
          'adminId': newAdmin,
          'members': FieldValue.arrayRemove([userId]),
        });
      } else {
        await _firestore.collection('groups').doc(groupId).delete();
      }
    } else {
      await _firestore.collection('groups').doc(groupId).update({
        'members': FieldValue.arrayRemove([userId]),
      });
    }
  }

  Stream<QuerySnapshot> getUserGroups() {
    final userId = _auth.currentUser?.uid;
    if (userId == null) throw Exception('User not authenticated');

    return _firestore
        .collection('groups')
        .where('members', arrayContains: userId)
        .snapshots();
  }
}
