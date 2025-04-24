import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../models/group.dart';
import '../services/group_service.dart';
import 'chat_screen.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({super.key});

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _groupService = GroupService();
  final _imagePicker = ImagePicker();
  File? _imageFile;

  Future<void> _createGroup() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => const CreateGroupDialog(),
    );

    if (result != null) {
      try {
        await _groupService.createGroup(
          name: result['name'],
          members: result['members'],
          imageFile: _imageFile,
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Group created successfully')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error creating group: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Groups'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _createGroup,
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _groupService.getUserGroups(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No groups yet'));
          }

          final groups = snapshot.data!.docs
              .map((doc) => Group.fromFirestore(
                  doc.data() as Map<String, dynamic>, doc.id))
              .toList();

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: group.photoUrl != null
                      ? NetworkImage(group.photoUrl!)
                      : null,
                  child: group.photoUrl == null
                      ? Text(group.name[0].toUpperCase())
                      : null,
                ),
                title: Text(group.name),
                subtitle: Text('${group.members.length} members'),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => ChatScreen(
                        chatUser: null,
                        group: group,
                      ),
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

class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});

  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _imagePicker = ImagePicker();
  File? _imageFile;
  List<String> _selectedMembers = [];

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final pickedFile =
        await _imagePicker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Create Group'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              GestureDetector(
                onTap: _pickImage,
                child: CircleAvatar(
                  radius: 40,
                  backgroundImage:
                      _imageFile != null ? FileImage(_imageFile!) : null,
                  child:
                      _imageFile == null ? const Icon(Icons.camera_alt) : null,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Group Name',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a group name';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text('Select Members'),
              StreamBuilder<QuerySnapshot>(
                stream:
                    FirebaseFirestore.instance.collection('users').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const CircularProgressIndicator();
                  }

                  final currentUser = FirebaseAuth.instance.currentUser;
                  final users = snapshot.data!.docs
                      .map((doc) => doc.data() as Map<String, dynamic>)
                      .where((user) => user['id'] != currentUser!.uid)
                      .toList();

                  return Column(
                    children: users.map((user) {
                      final isSelected = _selectedMembers.contains(user['id']);
                      return CheckboxListTile(
                        title: Text(user['displayName'] ?? user['email']),
                        value: isSelected,
                        onChanged: (value) {
                          setState(() {
                            if (value!) {
                              _selectedMembers.add(user['id']);
                            } else {
                              _selectedMembers.remove(user['id']);
                            }
                          });
                        },
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            if (_formKey.currentState!.validate() &&
                _selectedMembers.isNotEmpty) {
              Navigator.pop(context, {
                'name': _nameController.text.trim(),
                'members': _selectedMembers,
              });
            }
          },
          child: const Text('Create'),
        ),
      ],
    );
  }
}
