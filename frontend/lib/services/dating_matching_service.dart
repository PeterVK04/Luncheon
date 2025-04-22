// lib/services/dating_matching_service.dart

import 'dart:collection';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '/services/blocking_service.dart';

class DatingMatchingService {
  final _db = FirebaseFirestore.instance;
  final _queue = Queue<String>();

  double _toRadians(double deg) => deg * pi / 180;

  // Haversine formula to compute miles between two coords
  double _distanceMiles(double lat1, double lng1, double lat2, double lng2) {
    const earthRadiusMiles = 3958.8;
    final dLat = _toRadians(lat2 - lat1);
    final dLng = _toRadians(lng2 - lng1);
    final a = sin(dLat/2)*sin(dLat/2)
            + cos(_toRadians(lat1))
            * cos(_toRadians(lat2))
            * sin(dLng/2)*sin(dLng/2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusMiles * c;
  }

  /// Builds a queue of candidate UIDs who:
  /// - are not self
  /// - are not already matched or pending in *any* category
  /// - are within 30 miles
  /// - are within ±4 years
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
    
    // helper to collect UIDs from a subcollection
    Future<void> _collect(String sub) async {
      final snap = await _db.collection('users')
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
      _collect('pendingDatingRequests'),
    ]);

    // Rough latitude filter (~30 miles ≈ 30/69 degrees)
    final delta = 30.0 / 69.0;
    final minLat = myLat - delta, maxLat = myLat + delta;

    _queue.clear();
    final candidates = await _db
        .collection('users')
        .where('location.lat', isGreaterThan: minLat)
        .where('location.lat', isLessThan: maxLat)
        .get();

    for (var doc in candidates.docs) {
      if (exclude.contains(doc.id)) continue;
      final d = doc.data();
      final lat = d['location']['lat'] as double;
      final lng = d['location']['lng'] as double;
      if (_distanceMiles(myLat, myLng, lat, lng) > 30) continue;

      final otherAge = DateTime.now().year - DateTime.parse(d['birthday'] as String).year;
      if ((otherAge - myAge).abs() > 4) continue;

      _queue.add(doc.id);
    }
  }

  /// Next candidate UID, or null if done
  String? next() => _queue.isEmpty ? null : _queue.first;

  /// Reject and drop from queue
  void reject(String uid) {
    _queue.remove(uid);
  }

  /// Accept: create or update a pending request; if mutual, mark matched
  Future<void> accept(String otherUid) async {
    final me = FirebaseAuth.instance.currentUser!;
    final pairId = [me.uid, otherUid]..sort();
    final docId = pairId.join('_');
    final docRef = _db.collection('datingFriendships').doc(docId);

    final doc = await docRef.get();
    if (!doc.exists) {
      // first accept → pending
      await docRef.set({
        'users': pairId,
        'status': 'pending',
        'initiator': me.uid,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } else if (doc.data()!['status'] == 'pending'
        && doc.data()!['initiator'] != me.uid) {
      // second accept → matched
      await docRef.update({'status': 'matched'});
      // write into each user’s datingMatches subcollection
      final batch = _db.batch();
      batch.set(
        _db.collection('users').doc(me.uid)
            .collection('datingMatches').doc(otherUid),
        {'since': FieldValue.serverTimestamp()},
      );
      batch.set(
        _db.collection('users').doc(otherUid)
            .collection('datingMatches').doc(me.uid),
        {'since': FieldValue.serverTimestamp()},
      );
      await batch.commit();
    }

    _queue.remove(otherUid);
  }
}
