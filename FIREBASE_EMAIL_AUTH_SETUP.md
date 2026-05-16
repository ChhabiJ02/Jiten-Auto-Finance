# Firebase Email Authentication Setup - Documentation

## Overview

This document provides a comprehensive guide to the Firebase email authentication implementation for the JitenAuto app. The system handles user registration, email verification, login, and password management.

---

## Features Implemented

✅ **User Registration** - Email/password registration with validation  
✅ **Email Verification** - Automatic email verification flow  
✅ **Login** - Secure email/password authentication  
✅ **Password Reset** - Self-service password recovery  
✅ **User Roles** - Customer, Staff, Admin role management  
✅ **Error Handling** - User-friendly error messages  
✅ **Data Persistence** - Firestore integration for user data  

---

## Project Structure

```
lib/
├── services/
│   ├── auth_service.dart              # Core authentication service
│   ├── role_service.dart              # Role management
│   └── screens/
│       ├── auth/
│       │   ├── login_screen.dart              # Login UI
│       │   ├── register_screen.dart           # Registration UI
│       │   └── password_reset_screen.dart     # Password reset UI
│       └── shared/
│           └── auth_wrapper.dart             # Auth state management
```

---

## Auth Service API

### AuthService Class

The `AuthService` is a singleton that provides all authentication functionality.

#### Initialization

```dart
final authService = AuthService();
```

### Core Methods

#### 1. **Registration**

```dart
Future<UserCredential> registerWithEmail({
  required String email,
  required String password,
  required String name,
  required String phone,
  String role = 'customer',
})
```

**Parameters:**
- `email` - User's email address
- `password` - User's password (min 6 characters)
- `name` - User's full name
- `phone` - User's phone number (10 digits)
- `role` - User role (default: 'customer')

**Returns:** `UserCredential` on success

**Throws:** `FirebaseAuthException` on failure

**Example:**
```dart
try {
  final credential = await authService.registerWithEmail(
    email: 'user@example.com',
    password: 'password123',
    name: 'John Doe',
    phone: '9876543210',
    role: 'customer',
  );
  print('Registration successful: ${credential.user?.uid}');
} on FirebaseAuthException catch (e) {
  final friendlyMessage = AuthService.getFriendlyAuthErrorMessage(e);
  print('Error: $friendlyMessage');
}
```

#### 2. **Email Verification**

**Send Verification Email:**
```dart
Future<void> sendEmailVerification()
```

**Check if Email is Verified:**
```dart
Future<bool> checkEmailVerified()
```

**Resend Verification Email:**
```dart
Future<void> resendVerificationEmail()
```

**Example:**
```dart
// Send verification email during registration (automatic)
await authService.sendEmailVerification();

// Later, check if user has verified
bool isVerified = await authService.checkEmailVerified();
if (isVerified) {
  print('Email is verified!');
} else {
  print('Email not verified yet');
  // Offer to resend
  await authService.resendVerificationEmail();
}
```

#### 3. **Login**

```dart
Future<UserCredential> signInWithEmail({
  required String email,
  required String password,
})
```

**Example:**
```dart
try {
  final credential = await authService.signInWithEmail(
    email: 'user@example.com',
    password: 'password123',
  );
  print('Login successful: ${credential.user?.email}');
} on FirebaseAuthException catch (e) {
  final friendlyMessage = AuthService.getFriendlyAuthErrorMessage(e);
  print('Login failed: $friendlyMessage');
}
```

#### 4. **Password Reset**

**Send Password Reset Email:**
```dart
Future<void> sendPasswordResetEmail({required String email})
```

**Update Password (for logged-in user):**
```dart
Future<void> updatePassword({required String newPassword})
```

**Example:**
```dart
// Forgot password flow
try {
  await authService.sendPasswordResetEmail(email: 'user@example.com');
  print('Reset email sent');
} on FirebaseAuthException catch (e) {
  print('Error: ${AuthService.getFriendlyAuthErrorMessage(e)}');
}

// Update password (when logged in)
try {
  await authService.updatePassword(newPassword: 'newPassword123');
  print('Password updated successfully');
} on FirebaseAuthException catch (e) {
  print('Error: ${AuthService.getFriendlyAuthErrorMessage(e)}');
}
```

#### 5. **User Data Management**

**Get User Data:**
```dart
Future<Map<String, dynamic>?> getUserData(String uid)
```

**Update User Profile:**
```dart
Future<void> updateUserProfile({
  required String uid,
  String? name,
  String? phone,
  Map<String, dynamic>? additionalData,
})
```

**Get User Role:**
```dart
Future<String> getUserRole(String uid)
```

**Example:**
```dart
// Get user data
final userData = await authService.getUserData(userId);
print('User name: ${userData?['name']}');

// Update profile
await authService.updateUserProfile(
  uid: userId,
  name: 'Jane Doe',
  phone: '9876543210',
  additionalData: {'department': 'Sales'},
);

// Get user role
final role = await authService.getUserRole(userId);
print('User role: $role');
```

#### 6. **Sign Out**

```dart
Future<void> signOut()
```

**Example:**
```dart
await authService.signOut();
print('User signed out');
```

#### 7. **Account Deletion**

```dart
Future<void> deleteAccount()
```

**Example:**
```dart
try {
  await authService.deleteAccount();
  print('Account deleted successfully');
} on FirebaseAuthException catch (e) {
  print('Error: ${AuthService.getFriendlyAuthErrorMessage(e)}');
}
```

### Properties

```dart
// Get authentication state changes stream
Stream<User?> authStateChanges

// Get current authenticated user
User? currentUser

// Check if user is authenticated
bool isAuthenticated
```

### Error Handling

**Convert FirebaseAuthException to user-friendly messages:**
```dart
static String getFriendlyAuthErrorMessage(FirebaseAuthException e)
```

Supported error codes:
- `weak-password` - Password too weak
- `email-already-in-use` - Email already registered
- `invalid-email` - Invalid email format
- `user-not-found` - No account with this email
- `wrong-password` - Incorrect password
- `user-disabled` - Account disabled
- `too-many-requests` - Too many login attempts
- `network-request-failed` - Network error
- `invalid-phone-format` - Invalid phone number

---

## Screens

### 1. Registration Screen

**Location:** `lib/services/screens/auth/register_screen.dart`

**Flow:**
1. User enters name, phone, email, password
2. System creates Firebase Auth account
3. Verification email is sent automatically
4. User clicks "I've Verified My Email" after confirming in inbox
5. System checks verification status and updates Firestore

**Features:**
- Input validation
- Email verification tracking
- Resend verification option
- User-friendly error messages

### 2. Login Screen

**Location:** `lib/services/screens/auth/login_screen.dart`

**Flow:**
1. User enters email and password
2. System authenticates with Firebase
3. For non-admin users: verify email status
4. Route to appropriate dashboard based on role

**Features:**
- Email/password validation
- Password visibility toggle
- "Forgot Password?" link
- "Create Account" link
- Role-based routing
- Beautiful UI with animations

### 3. Password Reset Screen

**Location:** `lib/services/screens/auth/password_reset_screen.dart`

**Flow:**
1. User enters their email
2. System sends password reset link
3. User clicks link in email (handled by Firebase)
4. User creates new password in Firebase console/email flow

**Features:**
- Email input validation
- Success feedback
- Back to login option

### 4. Auth Wrapper

**Location:** `lib/services/screens/shared/auth_wrapper.dart`

**Functionality:**
- Monitors authentication state
- Loads user role from Firestore
- Routes to appropriate dashboard:
  - Admin → Admin Dashboard
  - Staff → Staff Dashboard
  - Customer → Customer Home Screen
  - Not logged in → Login Screen

---

## Firestore Data Structure

### Users Collection

```
users/
├── {uid}/
│   ├── uid: string
│   ├── email: string
│   ├── name: string
│   ├── phone: string
│   ├── role: string (admin|staff|customer)
│   ├── emailVerified: boolean
│   ├── createdAt: timestamp
│   └── updatedAt: timestamp
```

---

## Firebase Console Setup

### 1. Enable Email/Password Authentication

1. Go to Firebase Console → Your Project
2. Navigate to Authentication → Sign-in method
3. Enable "Email/Password"
4. Optional: Enable "Email link (passwordless sign-in)"

### 2. Email Templates

Configure email templates in Firebase Console → Authentication → Templates

#### Verification Email Template
- Subject: "Verify your email address"
- Body: Include the verification link
- Custom domain (optional): Use custom email sender

#### Password Reset Email Template
- Subject: "Reset your password"
- Body: Include the reset link
- Custom domain (optional): Use custom email sender

---

## Integration Guide

### Step 1: Update Your App Entry Point

Ensure Firebase is initialized in `main.dart`:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}
```

### Step 2: Use in Your Screens

Import and use the AuthService:

```dart
import 'package:showroom_app/services/auth_service.dart';

final authService = AuthService();

// Use for registration, login, etc.
```

### Step 3: Monitor Auth State

In your app's main navigation, use AuthWrapper:

```dart
// In main.dart or your router setup
home: const AuthWrapper(), // Routes based on auth state
```

---

## Validation Rules

### Email Validation
- Must be valid email format (regex: `r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'`)

### Password Validation
- Minimum 6 characters required by Firebase
- Recommended: Mix of uppercase, lowercase, numbers, special chars

### Phone Validation
- Must be exactly 10 digits
- Must be numeric only

### Name Validation
- Cannot be empty
- Trimmed of whitespace

---

## Best Practices

### 1. Always Use Try-Catch

```dart
try {
  await authService.registerWithEmail(...);
} on FirebaseAuthException catch (e) {
  final message = AuthService.getFriendlyAuthErrorMessage(e);
  showErrorDialog(message);
} catch (e) {
  showErrorDialog('Unexpected error occurred');
}
```

### 2. Check Email Verification

For non-admin users, always verify email before granting access:

```dart
if (currentUser?.emailVerified == false) {
  await authService.sendEmailVerification();
  // Show message to verify email
}
```

### 3. Use Streams for Auth State

```dart
StreamBuilder<User?>(
  stream: authService.authStateChanges,
  builder: (context, snapshot) {
    if (snapshot.connectionState == ConnectionState.active) {
      final user = snapshot.data;
      return user == null ? LoginScreen() : DashboardScreen();
    }
    return SplashScreen();
  },
)
```

### 4. Handle Network Errors

Always provide user feedback for network issues:

```dart
if (e.code == 'network-request-failed') {
  showMessage('Check your internet connection');
}
```

### 5. Secure Password Reset

- Always use the Firebase-provided reset flow
- Don't implement custom reset links
- Require re-authentication for sensitive operations

---

## Testing

### Test Cases to Verify

1. ✅ Registration with valid data creates user and Firestore record
2. ✅ Verification email is sent automatically
3. ✅ Email verification status is checked correctly
4. ✅ Login with verified email works
5. ✅ Login with unverified email fails
6. ✅ Password reset email is sent
7. ✅ Wrong password shows appropriate error
8. ✅ Duplicate email shows "already in use" error
9. ✅ Weak password shows validation error
10. ✅ Role-based routing works correctly

---

## Troubleshooting

### "Email already in use"
- User already registered with this email
- Solution: Use different email or reset password

### "Invalid email format"
- Email doesn't match validation regex
- Solution: Use standard email format (user@example.com)

### "Weak password"
- Password less than 6 characters
- Solution: Use password with at least 6 characters

### "Email verification not received"
- Check spam folder
- Click "Resend" button in app
- Check Firebase email templates are configured

### "User disabled"
- Account has been disabled in Firebase Console
- Solution: Re-enable in Firebase Authentication

### "Too many requests"
- Too many login attempts
- Solution: Wait a few minutes before trying again

---

## Security Considerations

1. ✅ Passwords are never stored in Firestore
2. ✅ Email verification prevents fake accounts
3. ✅ Phone number validation prevents invalid entries
4. ✅ Firebase security rules should restrict user data access
5. ✅ Use HTTPS for all communications
6. ✅ Implement rate limiting for login attempts
7. ✅ Consider two-factor authentication for admins

---

## Firebase Security Rules

Recommended Firestore security rules:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Users can read their own data
    match /users/{uid} {
      allow read: if request.auth.uid == uid;
      allow update: if request.auth.uid == uid;
      allow create: if request.auth.uid == uid;
    }
    
    // Admins can read all user data
    match /users/{uid} {
      allow read: if isAdmin();
    }
  }
  
  function isAdmin() {
    return get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
  }
}
```

---

## Frequently Asked Questions

**Q: How do I implement two-factor authentication?**
A: Firebase supports phone verification. Check Firebase documentation for implementation.

**Q: Can users update their email?**
A: Yes, use `FirebaseAuth.instance.currentUser?.updateEmail()` with re-authentication.

**Q: How do I implement social login?**
A: Firebase supports Google, Facebook, etc. Check Firebase documentation.

**Q: What's the email verification link expiration time?**
A: Firebase links expire after 24 hours by default (configurable).

**Q: Can I customize the verification email template?**
A: Yes, in Firebase Console → Authentication → Email Templates

---

## Support & Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Firebase Plugin](https://pub.dev/packages/firebase_auth)
- [Firebase Auth Best Practices](https://firebase.google.com/docs/auth/best-practices)

---

**Last Updated:** May 16, 2026  
**Version:** 1.0
