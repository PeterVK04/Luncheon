// services/friendship_matching_service.dart
import 'dart:collection';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/blocking_service.dart';

class FriendshipMatchingService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;
  final _queue = Queue<String>();

  double _toRadians(double deg) => deg * pi / 180;

  /// Haversine distance in miles
  double _distanceMiles(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMiles = 3958.8;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a =
        sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRadians(lat1)) *
        cos(_toRadians(lat2)) *
        sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  /// Build the queue of candidate UIDs, excluding already matched or pending
  Future<void> buildQueue() async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user');
    final meUid = user.uid;

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
    final exclude = <String>{ meUid, ...blocked, ...blockedBy };

    // Already matched users
    final matchesSnap = await _db
        .collection('users')
        .doc(meUid)
        .collection('matches')
        .get();
    for (var doc in matchesSnap.docs) {
      exclude.add(doc.id);
    }

    // Pending outgoing friend requests
    final pendingSnap = await _db
        .collection('friendships')
        .where('initiator', isEqualTo: meUid)
        .where('status', isEqualTo: 'pending')
        .get();
    for (var doc in pendingSnap.docs) {
      final users = List<String>.from(doc.data()['users'] as List);
      // find the other user's ID
      final other = users.firstWhere((id) => id != meUid);
      exclude.add(other);
    }


    // approximate bounding box for 30 miles in latitude degrees
    final latDelta = 30.0 / 69.0;
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
      final candidateUid = doc.id;
      //print('meUid = $meUid');
      //print('exclude = $exclude');
      //print('Checking doc.id=$meUid → exclude.contains=${exclude.contains(meUid)}');
      if (exclude.contains(candidateUid)) continue;
      final data = doc.data();
      final lat = (data['location'] as Map)['lat'] as double;
      final lng = (data['location'] as Map)['lng'] as double;
      if (_distanceMiles(myLat, myLng, lat, lng) > 30) continue;

      final birth = DateTime.parse(data['birthday'] as String);
      final age = DateTime.now().year - birth.year;
      if ((age - myAge).abs() > 5) continue;

      _queue.add(candidateUid);
      print('Added candidate: $candidateUid, age: $age, location: ($lat, $lng)');
    }
  }

  /// Returns the next candidate UID, or null if none left
  String? next() => _queue.isEmpty ? null : _queue.first;

  /// Accept a candidate: record a friend request or confirm a match
  Future<void> accept(String candidateUid) async {
    final meUid = _auth.currentUser!.uid;
    final users = [meUid, candidateUid]..sort();
    final friendshipId = '${users[0]}_${users[1]}';
    final ref = _db.collection('friendships').doc(friendshipId);
    final doc = await ref.get();

    if (!doc.exists) {
      // First acceptance: create a pending request
      await ref.set({
        'initiator': meUid,
        'status': 'pending',
        'users': users,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      final data = doc.data()!;
      if (data['status'] == 'pending' && data['initiator'] != meUid) {
        // Mutual acceptance: mark matched and add to each user's matches
        final batch = _db.batch();
        batch.update(ref, {
          'status': 'matched',
          'matchedAt': FieldValue.serverTimestamp(),
        });
        // Add to each user's matches subcollection
        final meMatch = _db.collection('users').doc(meUid).collection('matches').doc(candidateUid);
        batch.set(meMatch, {'matchedAt': FieldValue.serverTimestamp()});
        final otherMatch = _db.collection('users').doc(candidateUid).collection('matches').doc(meUid);
        batch.set(otherMatch, {'matchedAt': FieldValue.serverTimestamp()});
        await batch.commit();
      }
    }

    // Remove from queue in all cases
    _queue.remove(candidateUid);
  }

  /// Reject a candidate: simply remove from queue
  void reject(String candidateUid) {
    _queue.remove(candidateUid);
  }
}
