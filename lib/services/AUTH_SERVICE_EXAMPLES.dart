// Firebase Email Authentication - Usage Examples
// This file demonstrates common use cases for the AuthService

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:showroom_app/services/auth_service.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Example 1: Simple Registration
// ─────────────────────────────────────────────────────────────────────────────

class RegistrationExample {
  final AuthService authService = AuthService();

  Future<void> registerNewUser(
    String email,
    String password,
    String name,
    String phone,
  ) async {
    try {
      final userCredential = await authService.registerWithEmail(
        email: email,
        password: password,
        name: name,
        phone: phone,
        role: 'customer',
      );

      print('✅ Registration successful!');
      print('User UID: ${userCredential.user?.uid}');
      print('Email: ${userCredential.user?.email}');

      // Next: User should verify email
    } on FirebaseAuthException catch (e) {
      final errorMessage = AuthService.getFriendlyAuthErrorMessage(e);
      print('❌ Registration failed: $errorMessage');
      // Show error to user
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 2: Email Verification Flow
// ─────────────────────────────────────────────────────────────────────────────

class EmailVerificationExample {
  final AuthService authService = AuthService();

  Future<void> waitForEmailVerification() async {
    // Step 1: Verification email was already sent during registration
    print('📧 Verification email sent. Waiting for user to verify...');

    // Step 2: When user comes back and clicks "I've Verified"
    bool isVerified = await authService.checkEmailVerified();

    if (isVerified) {
      print('✅ Email is verified!');
      // User can now log in
    } else {
      print('⏳ Email not verified yet');

      // Offer to resend
      print('Resending verification email...');
      await authService.resendVerificationEmail();
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 3: Login with Role-Based Routing
// ─────────────────────────────────────────────────────────────────────────────

class LoginExample {
  final AuthService authService = AuthService();

  Future<void> loginAndRoute(
    String email,
    String password,
    BuildContext context,
  ) async {
    try {
      // Step 1: Authenticate
      final credential = await authService.signInWithEmail(
        email: email,
        password: password,
      );

      print('✅ Login successful: ${credential.user?.email}');

      // Step 2: Check email verification (for non-admin users)
      final user = credential.user;
      if (user != null && !user.emailVerified) {
        print('⚠️ Email not verified. Sending verification...');
        await user.sendEmailVerification();
        print('📧 Verification email sent');
        await authService.signOut();
        // Show message to verify email
        return;
      }

      // Step 3: Get user role
      final role = await authService.getUserRole(user!.uid);
      print('👤 User role: $role');

      // Step 4: Route to appropriate dashboard
      switch (role) {
        case 'admin':
          Navigator.pushReplacementNamed(context, '/adminDashboard');
          break;
        case 'staff':
          Navigator.pushReplacementNamed(context, '/staffDashboard');
          break;
        default:
          Navigator.pushReplacementNamed(context, '/customerDashboard');
      }
    } on FirebaseAuthException catch (e) {
      final errorMessage = AuthService.getFriendlyAuthErrorMessage(e);
      print('❌ Login failed: $errorMessage');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage)),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 4: Password Reset Flow
// ─────────────────────────────────────────────────────────────────────────────

class PasswordResetExample {
  final AuthService authService = AuthService();

  Future<void> resetPassword(String email) async {
    try {
      await authService.sendPasswordResetEmail(email: email);
      print('✅ Password reset email sent to: $email');
      print('📧 User should check their inbox and spam folder');
    } on FirebaseAuthException catch (e) {
      final errorMessage = AuthService.getFriendlyAuthErrorMessage(e);
      print('❌ Failed to send reset email: $errorMessage');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 5: Monitor Authentication State
// ─────────────────────────────────────────────────────────────────────────────

class AuthStateMonitorExample extends StatelessWidget {
  final AuthService authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // User is not authenticated
        if (!snapshot.hasData || snapshot.data == null) {
          print('👤 No user authenticated');
          return const LoginScreen();
        }

        // User is authenticated
        final user = snapshot.data!;
        print('✅ User authenticated: ${user.email}');
        print('📧 Email verified: ${user.emailVerified}');

        return const DashboardScreen();
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 6: Get and Update User Profile
// ─────────────────────────────────────────────────────────────────────────────

class UserProfileExample {
  final AuthService authService = AuthService();

  Future<void> getUserInfo(String uid) async {
    try {
      // Get user data
      final userData = await authService.getUserData(uid);

      print('👤 User Information:');
      print('Name: ${userData?['name']}');
      print('Email: ${userData?['email']}');
      print('Phone: ${userData?['phone']}');
      print('Role: ${userData?['role']}');
      print('Created: ${userData?['createdAt']}');
    } catch (e) {
      print('❌ Failed to fetch user data: $e');
    }
  }

  Future<void> updateUserProfile(String uid, String name, String phone) async {
    try {
      await authService.updateUserProfile(
        uid: uid,
        name: name,
        phone: phone,
      );

      print('✅ Profile updated successfully!');
      print('New name: $name');
      print('New phone: $phone');
    } catch (e) {
      print('❌ Failed to update profile: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 7: Change Password (for logged-in user)
// ─────────────────────────────────────────────────────────────────────────────

class ChangePasswordExample {
  final AuthService authService = AuthService();

  Future<void> changePassword(String newPassword) async {
    try {
      // Validate new password
      if (newPassword.length < 6) {
        print('❌ Password must be at least 6 characters');
        return;
      }

      // Update password
      await authService.updatePassword(newPassword: newPassword);

      print('✅ Password changed successfully!');
      print('⚠️ You will be signed out. Please log in again.');

      // Optionally sign out
      await authService.signOut();
    } on FirebaseAuthException catch (e) {
      final errorMessage = AuthService.getFriendlyAuthErrorMessage(e);
      print('❌ Failed to change password: $errorMessage');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 8: Sign Out
// ─────────────────────────────────────────────────────────────────────────────

class SignOutExample {
  final AuthService authService = AuthService();

  Future<void> signOutUser(BuildContext context) async {
    try {
      await authService.signOut();

      print('✅ User signed out successfully');

      // Navigate to login
      Navigator.pushReplacementNamed(context, '/login');
    } catch (e) {
      print('❌ Failed to sign out: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 9: Delete Account
// ─────────────────────────────────────────────────────────────────────────────

class DeleteAccountExample {
  final AuthService authService = AuthService();

  Future<void> deleteUserAccount(BuildContext context) async {
    // Show confirmation dialog first
    bool confirmed = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!confirmed) return;

    try {
      await authService.deleteAccount();

      print('✅ Account deleted successfully');
      print('⚠️ All user data has been removed');

      // Navigate to login
      Navigator.pushReplacementNamed(context, '/login');
    } on FirebaseAuthException catch (e) {
      final errorMessage = AuthService.getFriendlyAuthErrorMessage(e);
      print('❌ Failed to delete account: $errorMessage');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $errorMessage')),
      );
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Example 10: Error Handling Pattern
// ─────────────────────────────────────────────────────────────────────────────

class ErrorHandlingExample {
  final AuthService authService = AuthService();

  Future<void> demonstrateErrorHandling() async {
    try {
      // Try to register with invalid email
      await authService.registerWithEmail(
        email: 'invalid-email', // Missing @
        password: 'pass123',
        name: 'John',
        phone: '1234567890',
      );
    } on FirebaseAuthException catch (e) {
      // Get user-friendly error message
      final friendlyMessage = AuthService.getFriendlyAuthErrorMessage(e);
      print('❌ Error: $friendlyMessage');

      // Handle specific errors
      switch (e.code) {
        case 'invalid-email-format':
          print('💡 Please enter a valid email address');
          break;
        case 'weak-password':
          print('💡 Password must be at least 6 characters');
          break;
        case 'invalid-phone-format':
          print('💡 Phone must be exactly 10 digits');
          break;
        default:
          print('💡 An error occurred. Please try again.');
      }
    } catch (e) {
      // Handle unexpected errors
      print('❌ Unexpected error: $e');
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Placeholder Classes (used in examples)
// ─────────────────────────────────────────────────────────────────────────────

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Login Screen')));
  }
}

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Dashboard')));
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Complete Example: Typical App Flow
// ─────────────────────────────────────────────────────────────────────────────

void completeAppFlowExample() {
  print('''
  ╔═══════════════════════════════════════════════════════════════╗
  ║         Firebase Email Authentication - Complete Flow         ║
  ╚═══════════════════════════════════════════════════════════════╝

  1️⃣  APP LAUNCH
      ↓
      Check if user is authenticated (AuthWrapper)
      
  2️⃣  NOT AUTHENTICATED
      ↓
      Show LoginScreen
      
  3️⃣  NEW USER
      ↓
      Click "Create Account"
      ↓
      RegisterScreen
      ↓
      Fill: name, phone, email, password
      ↓
      RegisterButton.onPressed()
      ↓
      authService.registerWithEmail()
      ↓
      ✅ Firebase account created
      ✅ Verification email sent
      ✅ User data saved to Firestore
      
  4️⃣  VERIFY EMAIL
      ↓
      User checks inbox/spam
      ↓
      Clicks verification link
      ↓
      Returns to app
      ↓
      Clicks "I've Verified My Email"
      ↓
      authService.checkEmailVerified()
      ↓
      ✅ Firestore updated
      ↓
      Back to LoginScreen
      
  5️⃣  LOGIN
      ↓
      Enter email & password
      ↓
      LoginButton.onPressed()
      ↓
      authService.signInWithEmail()
      ↓
      ✅ Authenticated
      ✅ Check email verification
      ✅ Get user role
      ↓
      Route to dashboard (Admin/Staff/Customer)
      
  6️⃣  FORGOT PASSWORD
      ↓
      LoginScreen: Click "Forgot Password?"
      ↓
      PasswordResetScreen
      ↓
      Enter email
      ↓
      authService.sendPasswordResetEmail()
      ↓
      ✅ Reset email sent
      ↓
      User clicks link in email
      ↓
      Sets new password (in Firebase flow)
      ↓
      Returns to app, logs in with new password
      
  7️⃣  SIGNED IN
      ↓
      Dashboard / User Actions
      
  8️⃣  SIGN OUT
      ↓
      authService.signOut()
      ↓
      ✅ Logged out
      ↓
      Back to LoginScreen
  ''');
}
