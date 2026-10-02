import 'package:firebase_auth/firebase_auth.dart';

import '../models/cloud_account.dart';

/// Firebase Authentication with **Email / Password** only.
/// Google Sign-In provider removed from Firebase Auth.
class AuthService {
  AuthService({FirebaseAuth? firebaseAuth})
      : _auth = firebaseAuth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  User? get firebaseUser => _auth.currentUser;
  bool get isSignedIn => _auth.currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  CloudAccount _toAccount(User user) {
    return CloudAccount(
      id: user.uid,
      email: user.email ?? '',
      displayName: user.displayName ?? user.email?.split('@').first,
      photoUrl: user.photoURL,
      provider: 'password',
      connectedAt: DateTime.now(),
    );
  }

  Future<CloudAccount> signUpWithEmail({
    required String email,
    required String password,
    String? displayName,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw AuthException('Sign-up failed: no user returned');
      }
      if (displayName != null && displayName.trim().isNotEmpty) {
        await user.updateDisplayName(displayName.trim());
        await user.reload();
      }
      return _toAccount(_auth.currentUser ?? user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<CloudAccount> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      final user = cred.user;
      if (user == null) {
        throw AuthException('Sign-in failed: no user returned');
      }
      return _toAccount(user);
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<CloudAccount?> restoreSession() async {
    final user = _auth.currentUser;
    if (user == null) return null;
    return _toAccount(user);
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapError(e));
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> disconnect() => signOut();

  String _mapError(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'That email address looks invalid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'user-not-found':
        return 'No account found for that email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-credential':
        return 'Incorrect email or password.';
      case 'email-already-in-use':
        return 'An account already exists with that email.';
      case 'weak-password':
        return 'Password is too weak (use at least 6 characters).';
      case 'operation-not-allowed':
        return 'Email/password is not enabled in Firebase Console.\n'
            'Authentication → Sign-in method → Email/Password → Enable';
      case 'too-many-requests':
        return 'Too many attempts. Try again later.';
      case 'network-request-failed':
        return 'Network error. Check your connection.';
      default:
        return e.message ?? 'Authentication error (${e.code})';
    }
  }
}

class AuthException implements Exception {
  AuthException(this.message);
  final String message;

  @override
  String toString() => message;
}
