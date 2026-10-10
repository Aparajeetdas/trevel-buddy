import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:google_sign_in/google_sign_in.dart';

/// Abstract interface for authentication actions.
abstract class AuthRepository {
  /// Stream of authentication state changes. Emits a Firebase [User] when signed in,
  /// or `null` when signed out.
  Stream<fb.User?> authStateChanges();

  /// Initiates Google sign‑in flow. Returns the signed‑in [User] or `null`
  /// if the user cancelled or an error occurred.
  Future<fb.User?> signInWithGoogle();

  /// Signs out the current user.
  Future<void> signOut();
}

/// Concrete implementation that uses `firebase_auth` and `google_sign_in`.
class FirebaseAuthRepository implements AuthRepository {
  final fb.FirebaseAuth _auth = fb.FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  @override
  Stream<fb.User?> authStateChanges() => _auth.authStateChanges();

  @override
  Future<fb.User?> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final credential = fb.GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final fb.UserCredential userCredential = await _auth.signInWithCredential(credential);
      return userCredential.user;
    } catch (e) {
      // In a production app you would log this error securely.
      return null;
    }
  }

  @override
  Future<void> signOut() async {
    // Sign out from both Firebase and Google to fully clear the session.
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }
}

/// Provider exposing the repository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) => FirebaseAuthRepository());

/// Riverpod StreamProvider exposing the current user (or `null`).
final authStateProvider = StreamProvider<fb.User?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});
