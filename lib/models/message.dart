import 'package:cloud_firestore/cloud_firestore.dart';

enum MessageType {
  text,
  image,
  voice,
}

class Message {
  final String id;
  final String senderId;
  final String content;
  final MessageType type;
  final DateTime timestamp;
  final Map<String, bool> readBy;
  final String? chatId;
  final String? groupId;

  Message({
    required this.id,
    required this.senderId,
    required this.content,
    required this.type,
    required this.timestamp,
    required this.readBy,
    this.chatId,
    this.groupId,
  });

  factory Message.fromFirestore(Map<String, dynamic> data, String id) {
    return Message(
      id: id,
      senderId: data['senderId'] ?? '',
      content: data['content'] ?? '',
      type: MessageType.values.firstWhere(
        (e) => e.toString() == 'MessageType.${data['type']}',
        orElse: () => MessageType.text,
      ),
      timestamp: (data['timestamp'] as Timestamp).toDate(),
      readBy: Map<String, bool>.from(data['readBy'] ?? {}),
      chatId: data['chatId'],
      groupId: data['groupId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'senderId': senderId,
      'content': content,
      'type': type.toString().split('.').last,
      'timestamp': Timestamp.fromDate(timestamp),
      'readBy': readBy,
      'chatId': chatId,
      'groupId': groupId,
    };
  }

  bool isReadBy(String userId) {
    return readBy[userId] ?? false;
  }

  void markAsRead(String userId) {
    readBy[userId] = true;
  }
}
