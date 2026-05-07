import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AccountAccessState {
  const AccountAccessState({
    required this.accountType,
    required this.isBlocked,
  });

  final String accountType;
  final bool isBlocked;
}

class AccountAccessService {
  AccountAccessService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  static const String blockedActionMessage =
      'Your account is restricted. You cannot perform this action.';

  Future<AccountAccessState> loadAccessState({required String uid}) async {
    final trimmedUid = uid.trim();
    final userDoc = await _firestore.collection('users').doc(trimmedUid).get();
    final userData = userDoc.data() ?? <String, dynamic>{};

    return AccountAccessState(
      accountType: (userData['accountType'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      isBlocked: userData['isBlocked'] == true,
    );
  }

  Stream<bool> watchBlockedState({required String uid}) {
    final trimmedUid = uid.trim();
    if (trimmedUid.isEmpty) {
      return Stream<bool>.value(false);
    }

    return _firestore.collection('users').doc(trimmedUid).snapshots().map((
      snapshot,
    ) {
      final userData = snapshot.data() ?? <String, dynamic>{};
      return userData['isBlocked'] == true;
    });
  }

  Future<bool> isCurrentUserBlocked() async {
    final uid = (_auth.currentUser?.uid ?? '').trim();
    if (uid.isEmpty) return false;

    final accessState = await loadAccessState(uid: uid);
    return accessState.isBlocked;
  }

  Future<void> ensureCurrentUserNotBlocked() async {
    if (await isCurrentUserBlocked()) {
      throw const BlockedUserActionException();
    }
  }
}

class BlockedUserActionException implements Exception {
  const BlockedUserActionException([
    this.message = AccountAccessService.blockedActionMessage,
  ]);

  final String message;

  @override
  String toString() => message;
}
