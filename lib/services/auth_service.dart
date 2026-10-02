import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:googleapis/drive/v3.dart' as drive;

import '../models/cloud_account.dart';

/// Scopes requested at Google Sign-In time.
/// Drive scopes MUST be requested here — Firebase Auth alone cannot access Drive.
const googleSignInScopes = <String>[
  drive.DriveApi.driveFileScope,
  // Uncomment for full Drive read (needs extra OAuth verification):
  // drive.DriveApi.driveReadonlyScope,
];

/// Handles Firebase Authentication + Google Sign-In.
///
/// Important:
/// - Firebase Auth is used for app user identity (uid, session).
/// - Google Drive API still needs the GoogleSignIn access token / authenticated
///   HTTP client. Firebase ID tokens are NOT valid for Drive.
class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    GoogleSignIn? googleSignIn,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _googleSignIn = googleSignIn ??
            GoogleSignIn(
              scopes: googleSignInScopes,
            );

  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;

  /// Shared instance so [GoogleDriveService] can build an authenticated client.
  GoogleSignIn get googleSignIn => _googleSignIn;

  User? get firebaseUser => _auth.currentUser;
  GoogleSignInAccount? get googleUser => _googleSignIn.currentUser;

  bool get isSignedIn =>
      _auth.currentUser != null || _googleSignIn.currentUser != null;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Interactive Google Sign-In → Firebase credential → Drive-ready session.
  Future<CloudAccount?> signInWithGoogle() async {
    try {
      // 1) Google account picker (requests Drive scopes)
      final GoogleSignInAccount? account = await _googleSignIn.signIn();
      if (account == null) return null; // user cancelled

      // 2) Tokens for Firebase
      final GoogleSignInAuthentication googleAuth = await account.authentication;

      if (googleAuth.idToken == null && googleAuth.accessToken == null) {
        throw AuthException('Google Sign-In returned no tokens');
      }

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 3) Firebase Auth session
      final UserCredential userCredential =
          await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      return CloudAccount(
        id: user?.uid ?? account.id,
        email: user?.email ?? account.email,
        displayName: user?.displayName ?? account.displayName,
        photoUrl: user?.photoURL ?? account.photoUrl,
        provider: 'google',
        connectedAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException(_mapFirebaseError(e));
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Sign-in failed: $e');
    }
  }

  /// Restore previous session without UI (app start).
  Future<CloudAccount?> signInSilently() async {
    try {
      // Prefer existing Firebase session
      final current = _auth.currentUser;
      if (current != null) {
        // Re-attach Google Sign-In so Drive client works
        final googleAccount =
            await _googleSignIn.signInSilently() ?? _googleSignIn.currentUser;
        return CloudAccount(
          id: current.uid,
          email: current.email ?? googleAccount?.email ?? '',
          displayName: current.displayName ?? googleAccount?.displayName,
          photoUrl: current.photoURL ?? googleAccount?.photoUrl,
          provider: 'google',
          connectedAt: DateTime.now(),
        );
      }

      // No Firebase user — try silent Google + then Firebase
      final account = await _googleSignIn.signInSilently();
      if (account == null) return null;

      final googleAuth = await account.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCredential = await _auth.signInWithCredential(credential);
      final user = userCredential.user;

      return CloudAccount(
        id: user?.uid ?? account.id,
        email: user?.email ?? account.email,
        displayName: user?.displayName ?? account.displayName,
        photoUrl: user?.photoURL ?? account.photoUrl,
        provider: 'google',
        connectedAt: DateTime.now(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Sign out of Firebase + Google (keeps app permission grant).
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Revoke Google access + sign out (user must consent again next time).
  Future<void> disconnect() async {
    await _auth.signOut();
    await _googleSignIn.disconnect();
  }

  String _mapFirebaseError(FirebaseAuthException e) {
    switch (e.code) {
      case 'account-exists-with-different-credential':
        return 'An account already exists with a different sign-in method.';
      case 'invalid-credential':
        return 'Invalid Google credential. Try again.';
      case 'operation-not-allowed':
        return 'Google Sign-In is not enabled in Firebase Console.';
      case 'user-disabled':
        return 'This account has been disabled.';
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
