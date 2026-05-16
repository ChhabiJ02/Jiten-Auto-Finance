# Firebase Email Authentication - Quick Start Guide

## Installation

All required dependencies are already in `pubspec.yaml`:
- ✅ firebase_core: ^4.6.0
- ✅ firebase_auth: ^6.3.0
- ✅ cloud_firestore: ^6.2.0

Run: `flutter pub get`

---

## Basic Usage Examples

### 1. User Registration

```dart
import 'package:showroom_app/services/auth_service.dart';

final authService = AuthService();

// Simple registration
try {
  await authService.registerWithEmail(
    email: 'user@example.com',
    password: 'SecurePass123',
    name: 'John Doe',
    phone: '9876543210',
  );
  print('User registered! Verification email sent.');
} on FirebaseAuthException catch (e) {
  print(AuthService.getFriendlyAuthErrorMessage(e));
}
```

### 2. User Login

```dart
try {
  final credential = await authService.signInWithEmail(
    email: 'user@example.com',
    password: 'SecurePass123',
  );
  print('Login successful!');
  
  // Check email verification for non-admins
  bool isVerified = await authService.checkEmailVerified();
  print('Email verified: $isVerified');
} on FirebaseAuthException catch (e) {
  print(AuthService.getFriendlyAuthErrorMessage(e));
}
```

### 3. Verify Email

```dart
// Check if current user's email is verified
bool isVerified = await authService.checkEmailVerified();

if (!isVerified) {
  // Resend verification email
  await authService.resendVerificationEmail();
}
```

### 4. Password Reset

```dart
try {
  await authService.sendPasswordResetEmail(
    email: 'user@example.com',
  );
  print('Password reset email sent!');
} on FirebaseAuthException catch (e) {
  print(AuthService.getFriendlyAuthErrorMessage(e));
}
```

### 5. Get Current User

```dart
// Get current logged-in user
final user = authService.currentUser;
print('User email: ${user?.email}');

// Check if user is authenticated
if (authService.isAuthenticated) {
  print('User is logged in');
}

// Get user data from Firestore
final userData = await authService.getUserData(user!.uid);
print('User name: ${userData?['name']}');
```

### 6. Sign Out

```dart
await authService.signOut();
print('User signed out');
```

---

## UI Flow Diagram

```
┌─────────────────┐
│   Launch App    │
└────────┬────────┘
         │
         ▼
┌─────────────────────────────────┐
│  Check Auth State               │
│  (AuthWrapper/StreamBuilder)    │
└────────┬────────────────────────┘
         │
    ┌────┴────┐
    │          │
    ▼          ▼
No User    User Exists
    │          │
    ▼          ▼
┌────────┐  ┌──────────┐
│ Login  │  │  Check   │
│ Screen │  │  Role    │
└────────┘  └──────────┘
    │          │
    ├─────┬────┤
    │     │    │
    ▼     ▼    ▼
  Admin  Staff Customer
  Dashboard Dashboard Dashboard
```

---

## Screen Navigation

### Registration Flow
```
LoginScreen → [Create Account]
           ↓
        RegisterScreen → [Fill Form]
           ↓
        [Send Verification Email]
           ↓
        [User Verifies in Email]
           ↓
        [Click "I've Verified"]
           ↓
        Registration Complete → Back to Login
```

### Login Flow
```
LoginScreen → [Enter Email/Password]
           ↓
        Authenticate with Firebase
           ↓
        Check Email Verification (non-admin)
           ├─ If verified: Route to Dashboard
           ├─ If not: Send Verification → Sign Out
           └─ Show Message
```

### Password Reset Flow
```
LoginScreen → [Forgot Password?]
           ↓
        PasswordResetScreen
           ↓
        [Enter Email]
           ↓
        [Send Reset Email]
           ↓
        [User Clicks Reset Link in Email]
           ↓
        Firebase Password Reset Page
           ↓
        Complete
```

---

## Error Handling Examples

```dart
try {
  await authService.registerWithEmail(...);
} on FirebaseAuthException catch (e) {
  // Use friendly error message
  final message = AuthService.getFriendlyAuthErrorMessage(e);
  
  // Show to user
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message)),
  );
} catch (e) {
  // Unexpected error
  print('Unexpected error: $e');
}
```

---

## Common Scenarios

### Scenario 1: New User Registration
```dart
1. User opens app → Sees LoginScreen
2. Clicks "Create Account" → RegisterScreen
3. Fills in: name, phone, email, password
4. Clicks "Register"
5. Gets: "Verification email sent"
6. Goes to email provider, clicks link
7. Returns to app
8. Clicks "I've Verified My Email"
9. Success! → Back to LoginScreen
10. User logs in with email/password
```

### Scenario 2: Existing User Login
```dart
1. User opens app → Sees LoginScreen
2. Enters email and password
3. Clicks "Login"
4. Firebase verifies credentials
5. System checks email verification
6. Routes to: Admin/Staff/Customer Dashboard
```

### Scenario 3: Forgotten Password
```dart
1. User opens app → Sees LoginScreen
2. Clicks "Forgot Password?"
3. Goes to PasswordResetScreen
4. Enters email
5. Clicks "Send Reset Link"
6. System sends email with reset link
7. User clicks link in email
8. User creates new password (in Firebase email flow)
9. User logs in with new password
```

---

## File Locations

- **Auth Service:** `lib/services/auth_service.dart` (Core logic)
- **Login Screen:** `lib/services/screens/auth/login_screen.dart` (UI for login)
- **Register Screen:** `lib/services/screens/auth/register_screen.dart` (UI for registration)
- **Password Reset:** `lib/services/screens/auth/password_reset_screen.dart` (UI for reset)
- **Auth Wrapper:** `lib/services/screens/shared/auth_wrapper.dart` (Route management)
- **Role Service:** `lib/services/role_service.dart` (Role fetching)

---

## Configuration

No additional configuration needed! Everything is already set up in:
- ✅ `firebase_options.dart` - Firebase project config
- ✅ `pubspec.yaml` - Dependencies
- ✅ `main.dart` - Firebase initialization

---

## Testing in Emulator

1. **Android Emulator:**
   ```bash
   flutter emulators --launch Pixel_4_API_30
   flutter run
   ```

2. **iOS Simulator:**
   ```bash
   open -a Simulator
   flutter run
   ```

3. **Web:**
   ```bash
   flutter run -d chrome
   ```

---

## Debug Tips

### Print Current User Info
```dart
final user = FirebaseAuth.instance.currentUser;
print('UID: ${user?.uid}');
print('Email: ${user?.email}');
print('Email Verified: ${user?.emailVerified}');
```

### Check Firebase Rules
```
Firebase Console → Project Settings → Rules
```

### View Verification Emails
```
Firebase Console → Authentication → Emails
```

### Monitor Firestore Changes
```
Firebase Console → Cloud Firestore → Collections → users
```

---

## Next Steps

1. ✅ Test registration flow
2. ✅ Test email verification
3. ✅ Test login flow
4. ✅ Test password reset
5. ✅ Test role-based routing
6. ✅ Deploy to production
7. ✅ Monitor Firebase logs

---

## Support Commands

```bash
# Check Flutter/Firebase status
flutter doctor

# Get dependencies
flutter pub get

# Build for Android
flutter build apk

# Build for iOS
flutter build ios

# Build for Web
flutter build web
```

---

**Happy coding! 🚀**
