import 'package:flutter_riverpod/flutter_riverpod.dart';

/// App user model that operates seamlessly in both guest and authenticated modes.
class AppUser {
  final String uid;
  final String? email;
  final String? displayName;
  final String? photoUrl;
  final String? idToken;

  const AppUser({
    required this.uid,
    this.email,
    this.displayName,
    this.photoUrl,
    this.idToken,
  });

  String get token => idToken ?? 'mock_user_$uid';
}

/// Abstract interface for authentication actions.
abstract class AuthRepository {
  Stream<AppUser?> authStateChanges();
  AppUser? get currentUser;
  Future<AppUser?> signInWithGoogle();
  Future<void> signOut();
  Future<String?> getIdToken();
}

/// Guest/Offline implementation that never blocks app startup.
/// Allows full browsing in signed-out guest mode without requiring online Firebase Auth.
class GuestAuthRepository implements AuthRepository {
  AppUser? _currentUser;

  @override
  AppUser? get currentUser => _currentUser;

  @override
  Stream<AppUser?> authStateChanges() => Stream.value(_currentUser);

  @override
  Future<AppUser?> signInWithGoogle() async {
    // Provide authenticated session with mock token for local / offline verification
    _currentUser = const AppUser(
      uid: 'guest_user_1',
      displayName: 'Guest Traveler',
      email: 'traveler@guest.local',
      idToken: 'mock_user_guest_1',
    );
    return _currentUser;
  }

  @override
  Future<void> signOut() async {
    _currentUser = null;
  }

  @override
  Future<String?> getIdToken() async {
    return _currentUser?.token;
  }
}

/// Provider exposing the repository instance.
final authRepositoryProvider = Provider<AuthRepository>((ref) => GuestAuthRepository());

/// Riverpod StreamProvider exposing the current user (or null).
final authStateProvider = StreamProvider<AppUser?>((ref) {
  final repo = ref.watch(authRepositoryProvider);
  return repo.authStateChanges();
});
