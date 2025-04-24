import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'dart:io';
import '../models/message.dart';

class MessageService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  Future<void> sendTextMessage({
    required String content,
    required String chatId,
    String? groupId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final message = Message(
      id: '',
      senderId: userId,
      content: content,
      type: MessageType.text,
      timestamp: DateTime.now(),
      readBy: {userId: true},
      chatId: chatId,
      groupId: groupId,
    );

    await _firestore.collection('messages').add(message.toFirestore());
  }

  Future<void> sendImageMessage({
    required File imageFile,
    required String chatId,
    String? groupId,
  }) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    try {
      final ref = _storage.ref().child(
          'chat_images/${DateTime.now().millisecondsSinceEpoch}_${userId}.jpg');
      await ref.putFile(imageFile);
      final imageUrl = await ref.getDownloadURL();

      final message = Message(
        id: '',
        senderId: userId,
        content: imageUrl,
        type: MessageType.image,
        timestamp: DateTime.now(),
        readBy: {userId: true},
        chatId: chatId,
        groupId: groupId,
      );

      await _firestore.collection('messages').add(message.toFirestore());
    } catch (e) {
      print('Error sending image message: $e');
    }
  }

  Future<void> markMessageAsRead(String messageId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    await _firestore.collection('messages').doc(messageId).update({
      'readBy.$userId': true,
    });
  }

  Stream<QuerySnapshot> getMessages(String chatId, {String? groupId}) {
    return _firestore
        .collection('messages')
        .where('chatId', isEqualTo: chatId)
        .where('groupId', isEqualTo: groupId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  Future<void> deleteMessage(String messageId) async {
    final userId = _auth.currentUser?.uid;
    if (userId == null) return;

    final messageDoc =
        await _firestore.collection('messages').doc(messageId).get();
    if (messageDoc.exists) {
      final message = Message.fromFirestore(messageDoc.data()!, messageId);
      if (message.senderId == userId) {
        await _firestore.collection('messages').doc(messageId).delete();
      }
    }
  }
}
