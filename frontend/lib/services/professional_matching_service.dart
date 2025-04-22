// lib/services/professional_matching_service.dart

import 'dart:collection';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/blocking_service.dart';

class ProfessionalMatchingService {
  final _db = FirebaseFirestore.instance;
  final _queue = Queue<String>();

  /// Builds a queue of candidate UIDs who:
  /// - are not self
  /// - are not already matched or pending in any category
  Future<void> buildQueue() async {
    final me = FirebaseAuth.instance.currentUser!;
    final blockerSvc = BlockingService();
    final blocked   = await blockerSvc.getBlockedUsers();
    final blockedBy = await blockerSvc.getBlockedByUsers();
    
    final meDoc = await _db.collection('users').doc(me.uid).get();
    final data = meDoc.data()!;
    final myLat = data['location']['lat'] as double;
    final myLng = data['location']['lng'] as double;
    final myBirthday = DateTime.parse(data['birthday'] as String);
    final myAge = DateTime.now().year - myBirthday.year;

    // Exclusion set: self + all previous matches/pending from any category
    final exclude = <String>{ me.uid, ...blocked, ...blockedBy };

    Future<void> _collect(String sub) async {
      final snap = await _db
        .collection('users')
        .doc(me.uid)
        .collection(sub)
        .get();
      exclude.addAll(snap.docs.map((d) => d.id));
    }

    await Future.wait([
      _collect('matches'),
      _collect('professionalMatches'),
      _collect('travelMatches'),
      _collect('datingMatches'),
      _collect('pendingProfessionalRequests'),
    ]);

    // No filters: grab all users, then exclude
    final allUsers = await _db.collection('users').get();
    _queue.clear();
    for (var doc in allUsers.docs) {
      if (!exclude.contains(doc.id)) {
        _queue.add(doc.id);
      }
    }
  }

  /// Next candidate UID, or null if none left
  String? next() => _queue.isEmpty ? null : _queue.first;

  /// Remove candidate from queue
  void reject(String uid) {
    _queue.remove(uid);
  }

  /// Send or confirm a professional request
  Future<void> accept(String otherUid) async {
    final me = FirebaseAuth.instance.currentUser!;
    final pair = [me.uid, otherUid]..sort();
    final docId = pair.join('_');
    final ref = _db.collection('professionalFriendships').doc(docId);
    final doc = await ref.get();

    if (!doc.exists) {
      // first accept → pending
      await ref.set({
        'users': pair,
        'status': 'pending',
        'initiator': me.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else if (doc.data()!['status'] == 'pending'
        && doc.data()!['initiator'] != me.uid) {
      // second accept → matched
      await ref.update({'status': 'matched'});
      final batch = _db.batch();
      batch.set(
        _db.collection('users').doc(me.uid)
          .collection('professionalMatches').doc(otherUid),
        {'since': FieldValue.serverTimestamp()},
      );
      batch.set(
        _db.collection('users').doc(otherUid)
          .collection('professionalMatches').doc(me.uid),
        {'since': FieldValue.serverTimestamp()},
      );
      await batch.commit();
    }

    _queue.remove(otherUid);
  }
}
