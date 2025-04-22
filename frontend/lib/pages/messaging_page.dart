// lib/pages/messaging_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/blocking_service.dart';  // ← import your BlockingService
import '/pages/suggest_lunch.dart';  // <-- make sure this path matches your file

class MessagingPage extends StatefulWidget {
  final String otherUid;
  const MessagingPage({Key? key, required this.otherUid}) : super(key: key);

  @override
  State<MessagingPage> createState() => _MessagingPageState();
}

class _MessagingPageState extends State<MessagingPage> {
  final _textCtrl = TextEditingController();
  late final String _meUid;
  late final String _chatId;
  late final Stream<QuerySnapshot> _msgsStream;

  @override
  void initState() {
    super.initState();
    _meUid = FirebaseAuth.instance.currentUser!.uid;
    // deterministic chat ID:
    final ids = <String>[_meUid, widget.otherUid]..sort();
    _chatId = ids.join('_');

    _msgsStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();
  }

  Future<void> _send() async {
    final text = _textCtrl.text.trim();
    if (text.isEmpty) return;
    _textCtrl.clear();
    await FirebaseFirestore.instance
        .collection('chats')
        .doc(_chatId)
        .collection('messages')
        .add({
      'sender': _meUid,
      'text': text,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _blockUser() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Block this user?'),
        content: const Text(
          'They will no longer be able to message or match with you.'
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Block'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await BlockingService().blockUser(widget.otherUid);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('User blocked.')),
      );
      Navigator.pop(context); // leave the chat screen
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          // 1) Lunch suggestion button
          IconButton(
            icon: const Icon(Icons.lunch_dining),
            tooltip: 'Suggest Lunch',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => LunchSuggestion(),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.block),
            tooltip: 'Block User',
            onPressed: _blockUser,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _msgsStream,
              builder: (ctx, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snap.data!.docs;
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (ctx, i) {
                    final msg = docs[i];
                    final isMe = msg['sender'] == _meUid;
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            vertical: 4, horizontal: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? Colors.blue[200] : Colors.grey[300],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(msg['text']),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textCtrl,
                    decoration:
                        const InputDecoration(hintText: 'Type a message'),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _send,
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}
