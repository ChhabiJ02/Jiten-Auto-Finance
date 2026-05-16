import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() =>
      _LoginScreenState();
}

class _LoginScreenState
    extends State<LoginScreen>
    with SingleTickerProviderStateMixin {

  final _emailCtrl =
      TextEditingController();

  final _passwordCtrl =
      TextEditingController();

  bool _loading = false;

  bool _obscurePassword = true;

  late AnimationController _slideCtrl;

  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();

    _slideCtrl = AnimationController(
      vsync: this,
      duration:
          const Duration(milliseconds: 420),
    );

    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.12),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _slideCtrl,
        curve: Curves.easeOut,
      ),
    );

    _slideCtrl.forward();
  }

  @override
  void dispose() {

    _emailCtrl.dispose();

    _passwordCtrl.dispose();

    _slideCtrl.dispose();

    super.dispose();
  }

  void _setLoading(bool value) {

    if (mounted) {

      setState(() {
        _loading = value;
      });
    }
  }

  void _msg(
    String text, {
    bool error = true,
  }) {

    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(
      SnackBar(
        content: Text(text),

        backgroundColor:
            error
                ? const Color(0xFF7B1F3F)
                : Colors.green,

        behavior:
            SnackBarBehavior.floating,
      ),
    );
  }

  Future<void> _onLoginPressed() async {

    final email =
        _emailCtrl.text.trim();

    final password =
        _passwordCtrl.text.trim();

    if (email.isEmpty &&
        password.isEmpty) {

      _msg(
        "Please enter your email and password.",
      );

      return;
    }

    if (email.isEmpty) {

      _msg(
        "Please enter your email address.",
      );

      return;
    }

    if (password.isEmpty) {

      _msg(
        "Please enter your password.",
      );

      return;
    }

    _setLoading(true);

    try {

      final credential =
          await FirebaseAuth.instance
              .signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid =
          credential.user!.uid;

      Map<String, dynamic>? data;

      final doc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(uid)
              .get();

      if (doc.exists) {

        data = doc.data();

      } else {

        final snap =
            await FirebaseFirestore.instance
                .collection('users')
                .where(
                  'email',
                  isEqualTo: email,
                )
                .limit(1)
                .get();

        if (snap.docs.isNotEmpty) {

          data =
              snap.docs.first.data();
        }
      }

      final role =
          (data?['role'] ?? '')
              .toString()
              .toLowerCase();

      // ADMIN
      if (role == 'admin') {

        Navigator.pushReplacementNamed(
          context,
          '/adminDashboard',
        );

      } else {

        await credential.user!.reload();

        final updatedUser =
            FirebaseAuth
                .instance
                .currentUser;

        if (updatedUser != null &&
            updatedUser.emailVerified) {

          // STAFF
          if (role == 'staff' ||
              role == 'workshop') {

            Navigator.pushReplacementNamed(
              context,
              '/staffDashboard',
            );

          }
          // CUSTOMER
          else if (role ==
              'customer') {

            Navigator.pushReplacementNamed(
              context,
              '/customerDashboard',
            );

          }
          // UNKNOWN ROLE
          else {

            _msg(
              "Invalid role found.",
            );

            await FirebaseAuth.instance
                .signOut();
          }

        } else {

          await updatedUser
              ?.sendEmailVerification();

          _msg(
            "Please verify your email first. Verification link sent.",
          );

          await FirebaseAuth.instance
              .signOut();
        }
      }

    } on FirebaseAuthException catch (e) {

      _msg(
        _friendlyAuthError(e.code),
      );

    } catch (e) {

      debugPrint(
        "LOGIN ERROR: $e",
      );

      _msg(
        "Something went wrong.",
      );

    } finally {

      _setLoading(false);
    }
  }

  String _friendlyAuthError(
    String code,
  ) {

    switch (code) {

      case 'user-not-found':
        return "No account found with this email.";

      case 'wrong-password':
        return "Incorrect password.";

      case 'invalid-email':
        return "Please enter valid email.";

      case 'user-disabled':
        return "This account is disabled.";

      case 'too-many-requests':
        return "Too many attempts. Try later.";

      case 'network-request-failed':
        return "Network error.";

      default:
        return "Login failed.";
    }
  }

  @override
  Widget build(BuildContext context) {

    final theme =
        Theme.of(context);

    return Scaffold(

      body: Container(

        decoration:
            const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Color(0xFF7B1F3F),
              Color(0xFFF4DBE1),
            ],
          ),
        ),

        child: Center(

          child:
              SingleChildScrollView(

            padding:
                const EdgeInsets.symmetric(
              horizontal: 20,
              vertical: 40,
            ),

            child: ConstrainedBox(

              constraints:
                  const BoxConstraints(
                maxWidth: 500,
              ),

              child: SlideTransition(

                position: _slideAnim,

                child: FadeTransition(

                  opacity: _slideCtrl,

                  child: Card(

                    elevation: 16,

                    shape:
                        RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(
                        28,
                      ),
                    ),

                    child: Padding(

                      padding:
                          const EdgeInsets.all(
                        28,
                      ),

                      child: Column(

                        mainAxisSize:
                            MainAxisSize.min,

                        children: [

                          Image.asset(
                            'assets/appLogo/applogo.png',
                            height: 90,
                          ),

                          const SizedBox(
                            height: 18,
                          ),

                          Text(
                            "JitenAuto",

                            style: theme
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                              fontWeight:
                                  FontWeight.bold,
                            ),
                          ),

                          const SizedBox(
                            height: 6,
                          ),

                          Text(
                            "Drive leads faster with JitenAuto.",

                            textAlign:
                                TextAlign.center,

                            style: theme
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                              color:
                                  Colors.black54,
                            ),
                          ),

                          const SizedBox(
                            height: 28,
                          ),

                          TextField(

                            controller:
                                _emailCtrl,

                            keyboardType:
                                TextInputType
                                    .emailAddress,

                            decoration:
                                InputDecoration(
                              labelText:
                                  "Email",

                              prefixIcon:
                                  const Icon(
                                Icons
                                    .email_outlined,
                              ),

                              filled: true,

                              fillColor:
                                  Colors.grey
                                      .shade100,

                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  16,
                                ),

                                borderSide:
                                    BorderSide.none,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          TextField(

                            controller:
                                _passwordCtrl,

                            obscureText:
                                _obscurePassword,

                            decoration:
                                InputDecoration(
                              labelText:
                                  "Password",

                              prefixIcon:
                                  const Icon(
                                Icons
                                    .lock_outline,
                              ),

                              suffixIcon:
                                  IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons
                                          .visibility_outlined
                                      : Icons
                                          .visibility_off_outlined,
                                ),

                                onPressed: () {

                                  setState(() {

                                    _obscurePassword =
                                        !_obscurePassword;
                                  });
                                },
                              ),

                              filled: true,

                              fillColor:
                                  Colors.grey
                                      .shade100,

                              border:
                                  OutlineInputBorder(
                                borderRadius:
                                    BorderRadius.circular(
                                  16,
                                ),

                                borderSide:
                                    BorderSide.none,
                              ),
                            ),
                          ),

                          const SizedBox(
                            height: 28,
                          ),

                          SizedBox(

                            width:
                                double.infinity,

                            child:
                                ElevatedButton(

                              onPressed:
                                  _loading
                                      ? null
                                      : _onLoginPressed,

                              style:
                                  ElevatedButton.styleFrom(
                                padding:
                                    const EdgeInsets.symmetric(
                                  vertical: 16,
                                ),

                                shape:
                                    RoundedRectangleBorder(
                                  borderRadius:
                                      BorderRadius.circular(
                                    16,
                                  ),
                                ),
                              ),

                              child:
                                  _loading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,

                                          child:
                                              CircularProgressIndicator(
                                            color:
                                                Colors.white,

                                            strokeWidth:
                                                2,
                                          ),
                                        )
                                      : const Text(
                                          "Login",
                                        ),
                            ),
                          ),

                          const SizedBox(
                            height: 16,
                          ),

                          Wrap(

                            alignment:
                                WrapAlignment
                                    .center,

                            children: [

                              const Text(
                                "Don't have an account?",
                              ),

                              TextButton(

                                onPressed: () {

                                  Navigator.push(
                                    context,

                                    MaterialPageRoute(
                                      builder:
                                          (_) =>
                                              RegisterScreen(),
                                    ),
                                  );
                                },

                                child:
                                    const Text(
                                  "Create Account",
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}