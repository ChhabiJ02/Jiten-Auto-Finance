import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Firebase Email Authentication Service
/// Handles user registration, login, email verification, and password management
class AuthService {
  static final AuthService _instance = AuthService._internal();

  final FirebaseAuth _firebaseAuth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  factory AuthService() {
    return _instance;
  }

  AuthService._internal();

  // ─── Stream Listeners ───────────────────────────────────────────────────────

  /// Stream of authentication state changes
  Stream<User?> get authStateChanges => _firebaseAuth.authStateChanges();

  /// Get current authenticated user
  User? get currentUser => _firebaseAuth.currentUser;

  /// Check if user is currently authenticated
  bool get isAuthenticated => currentUser != null;

  // ─── Registration ──────────────────────────────────────────────────────────

  /// Register a new user with email and password
  /// Returns user credential if successful
  /// Throws FirebaseAuthException on failure
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
    required String name,
    required String phone,
    String role = 'customer',
  }) async {
    try {
      // Validate input
      _validateRegistrationInput(email, password, name, phone);

      // Create Firebase Auth account
      UserCredential userCredential =
          await _firebaseAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      // Update user profile
      await userCredential.user?.updateDisplayName(name);

      // Save user data to Firestore
      await _saveUserToFirestore(
        uid: userCredential.user!.uid,
        email: email.trim(),
        name: name,
        phone: phone,
        role: role,
      );

      // Send email verification
      await sendEmailVerification();

      return userCredential;
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'registration-failed',
        message: 'Registration failed: ${e.toString()}',
      );
    }
  }

  // ─── Email Verification ────────────────────────────────────────────────────

  /// Send email verification link to current user
  Future<void> sendEmailVerification() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      }
    } catch (e) {
      throw FirebaseAuthException(
        code: 'verification-email-failed',
        message: 'Failed to send verification email: ${e.toString()}',
      );
    }
  }

  /// Check if current user's email is verified
  /// Also updates Firestore record if verified
  Future<bool> checkEmailVerified() async {
    try {
      final user = currentUser;
      if (user == null) {
        return false;
      }

      // Reload user to get latest verification status
      await user.reload();
      final refreshedUser = _firebaseAuth.currentUser;

      if (refreshedUser != null && refreshedUser.emailVerified) {
        // Update Firestore
        await _firestore
            .collection('users')
            .doc(refreshedUser.uid)
            .update({'emailVerified': true});

        return true;
      }

      return false;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'verification-check-failed',
        message: 'Failed to check email verification: ${e.toString()}',
      );
    }
  }

  /// Resend email verification link
  Future<void> resendVerificationEmail() async {
    try {
      final user = currentUser;
      if (user != null && !user.emailVerified) {
        await user.sendEmailVerification();
      } else if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user is currently authenticated',
        );
      }
    } catch (e) {
      throw FirebaseAuthException(
        code: 'resend-verification-failed',
        message: 'Failed to resend verification email: ${e.toString()}',
      );
    }
  }

  // ─── Login ─────────────────────────────────────────────────────────────────

  /// Sign in with email and password
  /// Returns user credential if successful
  /// Throws FirebaseAuthException on failure
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      if (email.trim().isEmpty || password.isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-input',
          message: 'Email and password cannot be empty',
        );
      }

      return await _firebaseAuth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'login-failed',
        message: 'Login failed: ${e.toString()}',
      );
    }
  }

  // ─── Password Management ───────────────────────────────────────────────────

  /// Send password reset email
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      if (email.trim().isEmpty) {
        throw FirebaseAuthException(
          code: 'invalid-email',
          message: 'Email cannot be empty',
        );
      }

      await _firebaseAuth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw FirebaseAuthException(
        code: 'password-reset-failed',
        message: 'Failed to send password reset email: ${e.toString()}',
      );
    }
  }

  /// Update password for current user
  Future<void> updatePassword({required String newPassword}) async {
    try {
      final user = currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user is currently authenticated',
        );
      }

      if (newPassword.length < 6) {
        throw FirebaseAuthException(
          code: 'weak-password',
          message: 'Password must be at least 6 characters long',
        );
      }

      await user.updatePassword(newPassword);
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'password-update-failed',
        message: 'Failed to update password: ${e.toString()}',
      );
    }
  }

  // ─── User Data Management ──────────────────────────────────────────────────

  /// Get user data from Firestore
  Future<Map<String, dynamic>?> getUserData(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return doc.data();
    } catch (e) {
      throw FirebaseAuthException(
        code: 'user-data-failed',
        message: 'Failed to fetch user data: ${e.toString()}',
      );
    }
  }

  /// Update user profile in Firestore
  Future<void> updateUserProfile({
    required String uid,
    String? name,
    String? phone,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      Map<String, dynamic> updateData = {
        'updatedAt': Timestamp.now(),
      };

      if (name != null) {
        updateData['name'] = name;
        await currentUser?.updateDisplayName(name);
      }

      if (phone != null) {
        updateData['phone'] = phone;
      }

      if (additionalData != null) {
        updateData.addAll(additionalData);
      }

      await _firestore.collection('users').doc(uid).update(updateData);
    } catch (e) {
      throw FirebaseAuthException(
        code: 'profile-update-failed',
        message: 'Failed to update user profile: ${e.toString()}',
      );
    }
  }

  /// Get user role from Firestore
  Future<String> getUserRole(String uid) async {
    try {
      final doc = await _firestore.collection('users').doc(uid).get();
      return (doc.data()?['role'] ?? 'customer').toString().toLowerCase();
    } catch (e) {
      return 'customer'; // Default role
    }
  }

  // ─── Sign Out ──────────────────────────────────────────────────────────────

  /// Sign out current user
  Future<void> signOut() async {
    try {
      await _firebaseAuth.signOut();
    } catch (e) {
      throw FirebaseAuthException(
        code: 'signout-failed',
        message: 'Failed to sign out: ${e.toString()}',
      );
    }
  }

  // ─── Account Deletion ──────────────────────────────────────────────────────

  /// Delete current user account and their data
  Future<void> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        throw FirebaseAuthException(
          code: 'no-user',
          message: 'No user is currently authenticated',
        );
      }

      // Delete user data from Firestore
      await _firestore.collection('users').doc(user.uid).delete();

      // Delete user account from Firebase Auth
      await user.delete();
    } on FirebaseAuthException {
      rethrow;
    } catch (e) {
      throw FirebaseAuthException(
        code: 'delete-account-failed',
        message: 'Failed to delete account: ${e.toString()}',
      );
    }
  }

  // ─── Private Helper Methods ────────────────────────────────────────────────

  /// Save user data to Firestore
  Future<void> _saveUserToFirestore({
    required String uid,
    required String email,
    required String name,
    required String phone,
    required String role,
  }) async {
    await _firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'name': name,
      'phone': phone,
      'role': role,
      'emailVerified': false,
      'createdAt': Timestamp.now(),
      'updatedAt': Timestamp.now(),
    });
  }

  /// Validate registration input
  void _validateRegistrationInput(
    String email,
    String password,
    String name,
    String phone,
  ) {
    if (email.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-email',
        message: 'Email cannot be empty',
      );
    }

    if (!_isValidEmail(email)) {
      throw FirebaseAuthException(
        code: 'invalid-email-format',
        message: 'Please enter a valid email address',
      );
    }

    if (password.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-password',
        message: 'Password cannot be empty',
      );
    }

    if (password.length < 6) {
      throw FirebaseAuthException(
        code: 'weak-password',
        message: 'Password must be at least 6 characters long',
      );
    }

    if (name.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-name',
        message: 'Name cannot be empty',
      );
    }

    if (phone.trim().isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-phone',
        message: 'Phone number cannot be empty',
      );
    }

    if (phone.length != 10 || !_isNumeric(phone)) {
      throw FirebaseAuthException(
        code: 'invalid-phone-format',
        message: 'Please enter a valid 10-digit phone number',
      );
    }
  }

  /// Validate email format
  bool _isValidEmail(String email) {
    final RegExp emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );
    return emailRegex.hasMatch(email.trim());
  }

  /// Check if string is numeric
  bool _isNumeric(String str) {
    return int.tryParse(str) != null;
  }

  /// Convert FirebaseAuthException to user-friendly message
  static String getFriendlyAuthErrorMessage(FirebaseAuthException e) {
    switch (e.code) {
      case 'weak-password':
        return 'Password is too weak. Use at least 6 characters.';
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'user-not-found':
        return 'No account found with this email.';
      case 'wrong-password':
        return 'Incorrect password. Please try again.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email.';
      case 'invalid-phone-format':
        return 'Please enter a valid 10-digit phone number.';
      case 'invalid-input':
        return 'Please fill all required fields.';
      default:
        return e.message ?? 'An error occurred. Please try again.';
    }
  }
}
