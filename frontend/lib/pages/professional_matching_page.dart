// lib/pages/professional_matching_page.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../services/professional_matching_service.dart';

class ProfessionalMatchingPage extends StatefulWidget {
  const ProfessionalMatchingPage({Key? key}) : super(key: key);

  @override
  State<ProfessionalMatchingPage> createState() => _ProfessionalPageState();
}

class _ProfessionalPageState extends State<ProfessionalMatchingPage> {
  final _svc = ProfessionalMatchingService();
  String? _currentUid;
  Map<String, dynamic>? _currentData;

  @override
  void initState() {
    super.initState();
    _initQueue();
  }

  Future<void> _initQueue() async {
    await _svc.buildQueue();
    _loadNext();
  }

  Future<void> _loadNext() async {
    final uid = _svc.next();
    if (uid == null) {
      setState(() => _currentData = null);
      return;
    }
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();
    setState(() {
      _currentUid = uid;
      _currentData = doc.data();
    });
  }

  void _onReject() {
    _svc.reject(_currentUid!);
    _loadNext();
  }

  Future<void> _onAccept() async {
    await _svc.accept(_currentUid!);
    _loadNext();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Professional Matching')),
        body: const Center(child: Text('No more matches.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Professional Matching')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(
                (_currentData!['photoUrls'] as List).first,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _currentData!['fullName'] as String,
              style: const TextStyle(fontSize: 24),
            ),
            const SizedBox(height: 8),
            Text(
              _currentData!['profession'] as String,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _onReject,
                  child: const Text('Reject'),
                ),
                ElevatedButton(
                  onPressed: _onAccept,
                  child: const Text('Accept'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
