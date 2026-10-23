import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'game_state_persistence_service.dart';

class CloudAuthService extends ChangeNotifier {
  static final CloudAuthService _instance = CloudAuthService._internal();
  factory CloudAuthService() => _instance;
  CloudAuthService._internal();

  bool get _isFirebaseAvailable {
    try {
      return Firebase.apps.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  FirebaseAuth? get _auth {
    if (!_isFirebaseAvailable) return null;
    try {
      return FirebaseAuth.instance;
    } catch (_) {
      return null;
    }
  }

  FirebaseFirestore? get _firestore {
    if (!_isFirebaseAvailable) return null;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  User? get currentUser => _auth?.currentUser;
  bool get isAuthenticated => _auth?.currentUser != null;
  bool get isAnonymous => _auth?.currentUser?.isAnonymous ?? false;
  String get userIdentifier =>
      _auth?.currentUser?.displayName ??
      _auth?.currentUser?.email ??
      (_auth?.currentUser?.isAnonymous == true
          ? 'Guest Alchemist (${_auth!.currentUser!.uid.substring(0, 6)})'
          : (_isFirebaseAvailable ? 'Unknown Alchemist' : 'Offline Alchemist'));

  /// Update the player's custom Citadel Alchemist name
  Future<String?> updateDisplayName(String newName) async {
    final auth = _auth;
    if (auth == null || auth.currentUser == null) return 'Not authenticated';
    try {
      await auth.currentUser!.updateDisplayName(newName);
      final firestore = _firestore;
      if (firestore != null) {
        await firestore.collection('users').doc(auth.currentUser!.uid).set({
          'account': {
            'displayName': newName,
            'lastUpdated': FieldValue.serverTimestamp(),
          }
        }, SetOptions(merge: true));
      }
      notifyListeners();
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  /// Auto-sign-in anonymously on boot so every playtester immediately gets a Firestore UID
  Future<User?> ensureSignedIn() async {
    final auth = _auth;
    if (auth == null) return null;

    try {
      if (auth.currentUser != null) {
        return auth.currentUser;
      }
      final cred = await auth.signInAnonymously();
      notifyListeners();
      return cred.user;
    } catch (e) {
      debugPrint('[CloudAuthService] Anonymous sign-in error: $e');
      return null;
    }
  }

  /// Sign up with email & password or upgrade an anonymous account
  Future<String?> linkOrSignUpWithEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) return 'Firebase not initialized';

    try {
      final user = auth.currentUser;
      if (user != null && user.isAnonymous) {
        final credential = EmailAuthProvider.credential(email: email, password: password);
        await user.linkWithCredential(credential);
      } else {
        await auth.createUserWithEmailAndPassword(email: email, password: password);
      }
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Authentication failed';
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign in with existing email & password
  Future<String?> signInWithEmail(String email, String password) async {
    final auth = _auth;
    if (auth == null) return 'Firebase not initialized';

    try {
      await auth.signInWithEmailAndPassword(email: email, password: password);
      notifyListeners();
      return null; // success
    } on FirebaseAuthException catch (e) {
      return e.message ?? 'Sign-in failed';
    } catch (e) {
      return e.toString();
    }
  }

  /// Sign out and return to a fresh anonymous guest
  Future<void> signOut() async {
    final auth = _auth;
    if (auth == null) return;

    try {
      await auth.signOut();
      await ensureSignedIn();
      notifyListeners();
    } catch (e) {
      debugPrint('[CloudAuthService] Sign-out error: $e');
    }
  }

  /// Push local save data to Cloud Firestore under users/{uid}
  Future<bool> syncSaveToCloud(GameSaveData saveData) async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return false;

    final user = auth.currentUser;
    if (user == null) return false;

    try {
      final docRef = firestore.collection('users').doc(user.uid);
      await docRef.set({
        'account': {
          'uid': user.uid,
          'email': user.email,
          'isAnonymous': user.isAnonymous,
          'lastSynced': FieldValue.serverTimestamp(),
        },
        'saveData': saveData.toJson(),
      }, SetOptions(merge: true));
      return true;
    } catch (e) {
      debugPrint('[CloudAuthService] Firestore sync error: $e');
      return false;
    }
  }

  /// Pull save data from Cloud Firestore
  Future<GameSaveData?> fetchSaveFromCloud() async {
    final auth = _auth;
    final firestore = _firestore;
    if (auth == null || firestore == null) return null;

    final user = auth.currentUser;
    if (user == null) return null;

    try {
      final docSnap = await firestore.collection('users').doc(user.uid).get();
      if (!docSnap.exists || docSnap.data() == null) return null;

      final data = docSnap.data()!;
      final saveJson = data['saveData'] as Map<String, dynamic>?;
      if (saveJson == null) return null;

      return GameSaveData.fromJson(saveJson);
    } catch (e) {
      debugPrint('[CloudAuthService] Firestore fetch error: $e');
      return null;
    }
  }
}
