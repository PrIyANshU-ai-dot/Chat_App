import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user.dart' as app;

class Group {
  final String id;
  final String name;
  final String? photoUrl;
  final List<String> members;
  final String adminId;
  final DateTime createdAt;

  Group({
    required this.id,
    required this.name,
    required this.members,
    required this.adminId,
    required this.createdAt,
    this.photoUrl,
  });

  factory Group.fromFirestore(Map<String, dynamic> data, String id) {
    return Group(
      id: id,
      name: data['name'] ?? '',
      photoUrl: data['photoUrl'],
      members: List<String>.from(data['members'] ?? []),
      adminId: data['adminId'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'photoUrl': photoUrl,
      'members': members,
      'adminId': adminId,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  Group copyWith({
    String? id,
    String? name,
    String? photoUrl,
    List<String>? members,
    String? adminId,
    DateTime? createdAt,
  }) {
    return Group(
      id: id ?? this.id,
      name: name ?? this.name,
      photoUrl: photoUrl ?? this.photoUrl,
      members: members ?? this.members,
      adminId: adminId ?? this.adminId,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
