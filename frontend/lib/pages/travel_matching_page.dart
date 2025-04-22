// pages/trav_matching_page.dart
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:frontend/services/travel_matching_service.dart';

class TravelMatchingPage extends StatefulWidget {
  const TravelMatchingPage({Key? key}) : super(key: key);

  @override
  _TravelMatchingPageState createState() => _TravelMatchingPageState();
}

class _TravelMatchingPageState extends State<TravelMatchingPage> {
  final _svc = TravelMatchingService();
  String? _currentUid;
  Map<String, dynamic>? _currentData;

  @override
  void initState() {
    super.initState();
    _initQueue();
  }

  Future<void> _initQueue() async {
    await _svc.buildQueue();
    _showNext();
  }

  Future<void> _showNext() async {
    final uid = _svc.next();
    if (uid == null) {
      setState(() => _currentData = null);
      return;
    }
    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    setState(() {
      _currentUid = uid;
      _currentData = doc.data();
    });
  }

  Future<void> _onAccept() async {
    if (_currentUid == null) return;
    await _svc.accept(_currentUid!);
    _showNext();
  }

  void _onReject() {
    if (_currentUid == null) return;
    _svc.reject(_currentUid!);
    _showNext();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Travel Matching')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: _currentData == null
            ? const Center(child: Text('No more travel matches.'))
            : Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundImage: _currentData!['photoUrls'] is List && (_currentData!['photoUrls'] as List).isNotEmpty
                        ? NetworkImage((_currentData!['photoUrls'] as List).first) as ImageProvider
                        : null,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _currentData!['fullName'] ?? '',
                    style: const TextStyle(fontSize: 24),
                  ),
                  const SizedBox(height: 8),
                  // Calculate age separately to avoid too many positional arguments
                  Builder(
                    builder: (ctx) {
                      final birthdayStr = _currentData!['birthday'] as String;
                      final birth = DateTime.parse(birthdayStr);
                      final age = DateTime.now().year - birth.year;
                      return Text(
                        'Age: \$age',
                        style: const TextStyle(fontSize: 18),
                      );
                    },
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
