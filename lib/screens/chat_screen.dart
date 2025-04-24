import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/user.dart' as app;
import '../models/group.dart';
import '../services/message_service.dart';

class ChatScreen extends StatefulWidget {
  final app.User? chatUser;
  final Group? group;

  const ChatScreen({
    super.key,
    this.chatUser,
    this.group,
  }) : assert(chatUser != null || group != null);

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _messageController = TextEditingController();
  final _messageService = MessageService();
  final _imagePicker = ImagePicker();
  final _auth = FirebaseAuth.instance;
  late String _chatId;

  @override
  void initState() {
    super.initState();
    _chatId = widget.chatUser != null
        ? _getChatId(widget.chatUser!.id)
        : widget.group!.id;
  }

  String _getChatId(String otherUserId) {
    final currentUser = _auth.currentUser!;
    return currentUser.uid.hashCode <= otherUserId.hashCode
        ? '${currentUser.uid}_$otherUserId'
        : '${otherUserId}_${currentUser.uid}';
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) return;

    try {
      await _messageService.sendTextMessage(
        content: _messageController.text.trim(),
        chatId: _chatId,
        groupId: widget.group?.id,
      );
      _messageController.clear();
    } catch (e) {
      print('Error sending message: $e');
    }
  }

  Future<void> _sendImage() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      try {
        await _messageService.sendImageMessage(
          imageFile: File(pickedFile.path),
          chatId: _chatId,
          groupId: widget.group?.id,
        );
      } catch (e) {
        print('Error sending image: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            if (widget.chatUser != null) ...[
              CircleAvatar(
                backgroundImage: widget.chatUser!.photoUrl != null
                    ? CachedNetworkImageProvider(widget.chatUser!.photoUrl!)
                    : null,
                child: widget.chatUser!.photoUrl == null
                    ? Text(widget.chatUser!.displayName?[0].toUpperCase() ??
                        widget.chatUser!.email[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.chatUser!.displayName ?? widget.chatUser!.email),
                  Text(
                    widget.chatUser!.lastSeenText,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ] else ...[
              CircleAvatar(
                backgroundImage: widget.group!.photoUrl != null
                    ? CachedNetworkImageProvider(widget.group!.photoUrl!)
                    : null,
                child: widget.group!.photoUrl == null
                    ? Text(widget.group!.name[0].toUpperCase())
                    : null,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.group!.name),
                  Text(
                    '${widget.group!.members.length} members',
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _messageService.getMessages(_chatId,
                  groupId: widget.group?.id),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('No messages yet'));
                }

                return ListView.builder(
                  reverse: true,
                  itemCount: snapshot.data!.docs.length,
                  itemBuilder: (context, index) {
                    final message = snapshot.data!.docs[index];
                    final isMe = message['senderId'] == _auth.currentUser!.uid;

                    return Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: Align(
                        alignment:
                            isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe ? Colors.blue : Colors.grey[300],
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.group != null)
                                Text(
                                  message['senderName'] ?? '',
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                    fontSize: 12,
                                  ),
                                ),
                              const SizedBox(height: 4),
                              if (message['type'] == 'text')
                                Text(
                                  message['content'],
                                  style: TextStyle(
                                    color: isMe ? Colors.white : Colors.black,
                                  ),
                                )
                              else if (message['type'] == 'image')
                                Image.network(
                                  message['content'],
                                  width: 200,
                                  height: 200,
                                  fit: BoxFit.cover,
                                ),
                              const SizedBox(height: 4),
                              Text(
                                message['timestamp'] != null
                                    ? (message['timestamp'] as Timestamp)
                                        .toDate()
                                        .toString()
                                        .substring(11, 16)
                                    : '',
                                style: TextStyle(
                                  color: isMe ? Colors.white70 : Colors.black54,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      hintText: 'Type a message...',
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
