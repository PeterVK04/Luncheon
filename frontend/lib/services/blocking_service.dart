import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BlockingService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _blocks => _db.collection('blocks');

  /// Block [otherUid] by current user
  Future<void> blockUser(String otherUid) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final docId = '${me}_$otherUid';
    await _blocks.doc(docId).set({
      'blocker': me,
      'blocked': otherUid,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  /// Unblock [otherUid] by current user
  Future<void> unblockUser(String otherUid) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final docId = '${me}_$otherUid';
    await _blocks.doc(docId).delete();
  }

  /// UIDs that **I** have blocked
  Future<Set<String>> getBlockedUsers() async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final snap = await _blocks.where('blocker', isEqualTo: me).get();
    return snap.docs.map((d) => d['blocked'] as String).toSet();
  }

  /// UIDs that have blocked **me**
  Future<Set<String>> getBlockedByUsers() async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    final snap = await _blocks.where('blocked', isEqualTo: me).get();
    return snap.docs.map((d) => d['blocker'] as String).toSet();
  }
}

class ReportService {
  final _db = FirebaseFirestore.instance;
  CollectionReference get _reports => _db.collection('reports');

  /// Report [otherUid] for [reason]
  Future<void> reportUser(String otherUid, String reason) async {
    final me = FirebaseAuth.instance.currentUser!.uid;
    await _reports.add({
      'reporter': me,
      'reported': otherUid,
      'reason':   reason,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
