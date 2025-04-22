// services/travel_matching_service.dart
import 'dart:collection';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/blocking_service.dart';

/// Service to handle travel-based matching: radius 8 miles, age range ±8 years
class TravelMatchingService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Queue<String> _queue = Queue<String>();

  double _toRadians(double deg) => deg * pi / 180;

  /// Compute Haversine distance in miles between two coords
  double _distanceMiles(double lat1, double lng1, double lat2, double lng2) {
    const earthRadius = 3958.8; // miles
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) * cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadius * c;
  }

  /// Build queue of travel match candidates, excluding self, all existing matches, and pending
  Future<void> buildQueue() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final myUid = user.uid;
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

    // Helper to collect UIDs from a subcollection
    Future<void> _collect(String sub) async {
      final snap = await _db.collection('users').doc(myUid).collection(sub).get();
      for (var d in snap.docs) exclude.add(d.id);
    }

    // Collect matches from all types
    await _collect('matches');
    await _collect('professionalMatches');
    await _collect('travelMatches');
    await _collect('datingMatches');

    // Pending travel requests
    final pending = await _db
        .collection('travelFriendships')
        .where('initiator', isEqualTo: myUid)
        .where('status', isEqualTo: 'pending')
        .get();
    for (var d in pending.docs) {
      final users = List<String>.from(d.data()['users'] as List);
      final other = users.firstWhere((id) => id != myUid);
      exclude.add(other);
    }


    // Latitude band for ~8 miles
    final latDelta = 8.0 / 69.0;
    final minLat = myLat - latDelta;
    final maxLat = myLat + latDelta;

    _queue.clear();

    // Query by latitude band
    final snap = await _db
        .collection('users')
        .where('location.lat', isGreaterThan: minLat)
        .where('location.lat', isLessThan: maxLat)
        .get();

    for (var doc in snap.docs) {
      final candUid = doc.id;
      if (exclude.contains(candUid)) continue;
      final data = doc.data();
      final lat = (data['location'] as Map)['lat'] as double;
      final lng = (data['location'] as Map)['lng'] as double;
      final dist = _distanceMiles(myLat, myLng, lat, lng);
      if (dist > 8) continue;

      final birth = DateTime.parse(data['birthday'] as String);
      final age = DateTime.now().year - birth.year;
      if ((age - myAge).abs() > 8) continue;

      _queue.add(candUid);
    }
  }

  /// Peek next travel candidate
  String? next() => _queue.isEmpty ? null : _queue.first;

  /// Accept a travel candidate: create or confirm travel friendship
  Future<void> accept(String candidateUid) async {
    final myUid = _auth.currentUser!.uid;
    final users = [myUid, candidateUid]..sort();
    final id = '${users[0]}_${users[1]}';
    final ref = _db.collection('travelFriendships').doc(id);
    final doc = await ref.get();

    if (!doc.exists) {
      // First accept -> pending
      await ref.set({
        'initiator': myUid,
        'users': users,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else if (doc.data()!['status'] == 'pending' && doc.data()!['initiator'] != myUid) {
      // Mutual accept -> matched
      final batch = _db.batch();
      batch.update(ref, {'status': 'matched', 'matchedAt': FieldValue.serverTimestamp()});
      // Add to travelMatches subcollections
      batch.set(
        _db.collection('users').doc(myUid).collection('travelMatches').doc(candidateUid),
        {'matchedAt': FieldValue.serverTimestamp()},
      );
      batch.set(
        _db.collection('users').doc(candidateUid).collection('travelMatches').doc(myUid),
        {'matchedAt': FieldValue.serverTimestamp()},
      );
      await batch.commit();
    }

    _queue.remove(candidateUid);
  }

  /// Reject a candidate
  void reject(String candidateUid) {
    _queue.remove(candidateUid);
  }
}
