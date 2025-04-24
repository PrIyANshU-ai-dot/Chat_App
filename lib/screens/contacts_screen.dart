import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../models/user.dart' as app;
import 'chat_screen.dart';

class ContactsScreen extends StatelessWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Contacts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance.collection('users').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            print('Error loading contacts: ${snapshot.error}');
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text('Error loading contacts'),
                  Text(snapshot.error.toString()),
                  ElevatedButton(
                    onPressed: () {
                      // Retry loading
                      (context as Element).markNeedsBuild();
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No contacts found'));
          }

          final currentUser = FirebaseAuth.instance.currentUser;
          if (currentUser == null) {
            return const Center(child: Text('Not authenticated'));
          }

          final users = snapshot.data!.docs
              .map((doc) {
                try {
                  return app.User.fromFirestore(
                      doc.data() as Map<String, dynamic>, doc.id);
                } catch (e) {
                  print('Error parsing user data: $e');
                  return null;
                }
              })
              .where((user) => user != null && user.id != currentUser.uid)
              .cast<app.User>()
              .toList();

          if (users.isEmpty) {
            return const Center(child: Text('No contacts found'));
          }

          return ListView.builder(
            itemCount: users.length,
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: user.photoUrl != null
                      ? CachedNetworkImageProvider(user.photoUrl!)
                      : null,
                  child: user.photoUrl == null
                      ? Text(user.displayName?[0].toUpperCase() ??
                          user.email[0].toUpperCase())
                      : null,
                ),
                title: Text(user.displayName ?? user.email),
                subtitle: Text(user.status ?? ''),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(chatUser: user),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
