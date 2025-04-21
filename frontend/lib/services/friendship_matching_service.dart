// services/friendship_matching_service.dart
import 'dart:collection';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FriendshipMatchingService {
  final _db = FirebaseFirestore.instance;
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

  /// Build the queue of candidate UIDs
  Future<void> buildQueue() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      throw Exception('No authenticated user');
    }

    final meDoc = await _db.collection('users').doc(user.uid).get();
    if (!meDoc.exists) {
      throw Exception('Current user profile not found');
    }
    final me = meDoc.data()!;
    final myLat = (me['location'] as Map)['lat'] as double;
    final myLng = (me['location'] as Map)['lng'] as double;
    final myBirthday = DateTime.parse(me['birthday'] as String);
    final myAge = DateTime.now().year - myBirthday.year;

    // Approximate bounding box for 30 miles in latitude
    final latDelta = 30.0 / 69.0;
    final minLat = myLat - latDelta;
    final maxLat = myLat + latDelta;

    // Clear previous queue
    _queue.clear();

    // Query candidates by latitude band
    final snap = await _db
        .collection('users')
        .where('location.lat', isGreaterThan: minLat)
        .where('location.lat', isLessThan: maxLat)
        .get();

    for (var doc in snap.docs) {
      if (doc.id == user.uid) continue;
      final data = doc.data();
      final lat = (data['location'] as Map)['lat'] as double;
      final lng = (data['location'] as Map)['lng'] as double;
      final distance = _distanceMiles(myLat, myLng, lat, lng);
      if (distance > 30) continue;

      final birth = DateTime.parse(data['birthday'] as String);
      final age = DateTime.now().year - birth.year;
      if ((age - myAge).abs() > 5) continue;

      _queue.add(doc.id);
    }
  }

  /// Returns the next candidate UID, or null if none left
  String? next() => _queue.isEmpty ? null : _queue.first;

  /// Accept a candidate: remove and record acceptance
  Future<void> accept(String candidateUid) async {
    _queue.remove(candidateUid);
    // TODO: Write acceptance record, e.g. in Firestore
  }

  /// Reject a candidate: simply remove
  void reject(String candidateUid) {
    _queue.remove(candidateUid);
  }
}
