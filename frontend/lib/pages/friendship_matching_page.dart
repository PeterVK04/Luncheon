// pages/friendship_matching_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:frontend/services/friendship_matching_service.dart';

class FriendshipMatchingPage extends StatefulWidget {
  const FriendshipMatchingPage({Key? key}) : super(key: key);
  @override
  State<FriendshipMatchingPage> createState() => _FriendshipPageState();
}

class _FriendshipPageState extends State<FriendshipMatchingPage> {
  final svc = FriendshipMatchingService();
  String? _currentUid;
  Map<String, dynamic>? _currentData;

  @override
  void initState() {
    super.initState();
    _loadQueue();
  }

  Future<void> _loadQueue() async {
    await svc.buildQueue();
    _showNext();
  }

  Future<void> _showNext() async {
    final uid = svc.next();
    if (uid == null) {
      setState(() => _currentData = null);
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _currentUid  = uid;
      _currentData = doc.data();
    });
  }

  void _onAccept() async {
    await svc.accept(_currentUid!);
    _showNext();
  }

  void _onReject() {
    svc.reject(_currentUid!);
    _showNext();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Friendship Matching')),
        body: const Center(child: Text('No more matches.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Friendship Matching')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            // Display candidate’s info
            CircleAvatar(radius: 50),
            const SizedBox(height: 16),
            Text(_currentData!['fullName'], style: const TextStyle(fontSize: 24)),
            Text('${DateTime.parse(_currentData!['birthday']).year}'), // or age
            // …any other details…
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(onPressed: _onReject, child: const Text('Reject')),
                ElevatedButton(onPressed: _onAccept, child: const Text('Accept')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

