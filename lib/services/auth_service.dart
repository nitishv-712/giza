import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';

class AuthService {
  static final AuthService instance = AuthService._();
  AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  // ── Google Sign In ─────────────────────────────────────────────────────────
  Future<UserCredential?> signInWithGoogle() async {
    final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
    if (googleUser == null) return null;

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await _auth.signInWithCredential(credential);
  }

  // ── Facebook Sign In ───────────────────────────────────────────────────────
  Future<UserCredential?> signInWithFacebook() async {
    final LoginResult result = await FacebookAuth.instance.login();
    
    if (result.status != LoginStatus.success) return null;

    final OAuthCredential credential = 
        FacebookAuthProvider.credential(result.accessToken!.tokenString);

    return await _auth.signInWithCredential(credential);
  }

  // ── Sign Out ───────────────────────────────────────────────────────────────
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
      FacebookAuth.instance.logOut(),
    ]);
  }
}
