// lib/pages/conversations_list_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/blocking_service.dart';  // ← import it

class ConversationsListPage extends StatefulWidget {
  const ConversationsListPage({Key? key}) : super(key: key);

  @override
  State<ConversationsListPage> createState() => _ConversationsListPageState();
}

class _ConversationsListPageState extends State<ConversationsListPage> {
  late Future<List<Map<String, String>>> _matchesFuture;
  final _meUid = FirebaseAuth.instance.currentUser!.uid;

  @override
  void initState() {
    super.initState();
    _matchesFuture = _loadMatches();
  }

  Future<List<Map<String, String>>> _loadMatches() async {
    // 1) Pull all your match‐UIDs
    const subs = [
      'matches',
      'professionalMatches',
      'travelMatches',
      'datingMatches',
    ];
    final uids = <String>{};
    final userDoc = FirebaseFirestore.instance.collection('users').doc(_meUid);

    for (var sub in subs) {
      final snap = await userDoc.collection(sub).get();
      for (var d in snap.docs) {
        uids.add(d.id);
      }
    }

    // 2) Remove any blocked people
    final blockSvc = BlockingService();
    final blocked   = await blockSvc.getBlockedUsers();
    final blockedBy = await blockSvc.getBlockedByUsers();
    uids.removeAll(blocked);
    uids.removeAll(blockedBy);

    // 3) Fetch profile info for the remaining UIDs
    final results = <Map<String, String>>[];
    for (var uid in uids) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data()!;
      results.add({
        'uid':      uid,
        'fullName': data['fullName'] as String,
        'photoUrl': (data['photoUrls'] as List).first as String,
      });
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Messages')),
      body: FutureBuilder<List<Map<String, String>>>(
        future: _matchesFuture,
        builder: (ctx, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final list = snap.data!;
          if (list.isEmpty) {
            return const Center(child: Text('No conversations yet.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (ctx, i) {
              final item = list[i];
              return ListTile(
                leading: CircleAvatar(
                  backgroundImage: NetworkImage(item['photoUrl']!),
                ),
                title: Text(item['fullName']!),
                onTap: () => Navigator.pushNamed(
                  context,
                  '/chat',
                  arguments: item['uid'],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
