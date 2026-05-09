import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class CustomerProfileScreen extends StatefulWidget {
  const CustomerProfileScreen({super.key});

  @override
  State<CustomerProfileScreen> createState() =>
      _CustomerProfileScreenState();
}

class _CustomerProfileScreenState
    extends State<CustomerProfileScreen> {

  final displayNameController =
      TextEditingController();

  final emailController =
      TextEditingController();

  final phoneController =
      TextEditingController();

  bool loading = false;

  @override
  void dispose() {
    displayNameController.dispose();
    emailController.dispose();
    phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {

    final user =
        FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final newName =
        displayNameController.text.trim();

    final newEmail =
        emailController.text.trim();

    final newPhone =
        phoneController.text.trim();

    // NAME VALIDATION
    if (newName.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter your name.',
          ),
        ),
      );

      return;
    }

    // EMAIL VALIDATION
    if (newEmail.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter email.',
          ),
        ),
      );

      return;
    }

    // PHONE VALIDATION
    if (newPhone.isEmpty) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Please enter phone number.',
          ),
        ),
      );

      return;
    }

    if (!RegExp(r'^[0-9]{10}$')
        .hasMatch(newPhone)) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        const SnackBar(
          content: Text(
            'Enter valid 10-digit phone number.',
          ),
        ),
      );

      return;
    }

    setState(() => loading = true);

    try {

      // UPDATE AUTH EMAIL
      if (newEmail != user.email) {

        await user.verifyBeforeUpdateEmail(
          newEmail,
        );
      }

      // UPDATE DISPLAY NAME
      await user.updateDisplayName(
        newName,
      );

      // UPDATE FIRESTORE
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .set(
        {
          'name': newName,
          'email': newEmail,
          'phone': newPhone,
        },
        SetOptions(merge: true),
      );

      await user.reload();

      if (mounted) {

        ScaffoldMessenger.of(context)
            .showSnackBar(
          const SnackBar(
            content: Text(
              'Customer profile updated successfully.',
            ),
          ),
        );

        setState(() {});
      }

    } catch (e) {

      ScaffoldMessenger.of(context)
          .showSnackBar(
        SnackBar(
          content: Text(
            'Error: ${e.toString()}',
          ),
        ),
      );

    } finally {

      if (mounted) {
        setState(() => loading = false);
      }
    }
  }

  Future<void> _confirmLogout() async {

    final shouldLogout =
        await showDialog<bool>(
      context: context,
      builder: (context) {

        return AlertDialog(
          title: const Text(
            'Confirm Logout',
          ),

          content: const Text(
            'Are you sure you want to logout?',
          ),

          actions: [

            TextButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  false,
                );
              },
              child: const Text('Cancel'),
            ),

            ElevatedButton(
              onPressed: () {
                Navigator.pop(
                  context,
                  true,
                );
              },
              child: const Text('Logout'),
            ),
          ],
        );
      },
    );

    if (shouldLogout == true) {

      await FirebaseAuth.instance
          .signOut();

      if (mounted) {

        Navigator.popUntil(
          context,
          (route) => route.isFirst,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    final theme = Theme.of(context);

    return Scaffold(

      resizeToAvoidBottomInset: true,

      appBar: AppBar(
        title: const Text('Customer Profile'),
        backgroundColor:
            theme.colorScheme.primary,
      ),

      body: StreamBuilder<DocumentSnapshot>(

        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(
              FirebaseAuth
                  .instance
                  .currentUser!
                  .uid,
            )
            .snapshots(),

        builder: (context, snapshot) {

          if (!snapshot.hasData) {

            return const Center(
              child:
                  CircularProgressIndicator(),
            );
          }

          final data =
              snapshot.data!.data()
                  as Map<String, dynamic>?;

          final firestoreName =
              data?['name'] ?? '';

          final firestoreEmail =
              data?['email'] ?? '';

          final firestorePhone =
              data?['phone'] ?? '';

          // LIVE UPDATE CONTROLLERS
          displayNameController.text =
              firestoreName;

          emailController.text =
              firestoreEmail;

          phoneController.text =
              firestorePhone.toString();

          return SingleChildScrollView(

            padding:
                const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment:
                  CrossAxisAlignment
                      .stretch,

              children: [

                Card(

                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                  ),

                  elevation: 4,

                  child: Padding(

                    padding:
                        const EdgeInsets.all(
                      20,
                    ),

                    child: Column(

                      crossAxisAlignment:
                          CrossAxisAlignment
                              .start,

                      children: [

                        Text(
                          'Customer Profile',

                          style: theme
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                            fontWeight:
                                FontWeight.bold,
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        TextField(

                          controller:
                              displayNameController,

                          decoration:
                              const InputDecoration(
                            labelText:
                                'Customer Name',
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        TextField(

                          controller:
                              emailController,

                          keyboardType:
                              TextInputType
                                  .emailAddress,

                          decoration:
                              const InputDecoration(
                            labelText:
                                'Customer Email',
                          ),
                        ),

                        const SizedBox(
                          height: 16,
                        ),

                        TextField(

                          controller:
                              phoneController,

                          keyboardType:
                              TextInputType.phone,

                          decoration:
                              const InputDecoration(
                            labelText:
                                'Customer Phone',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(
                  height: 24,
                ),

                ElevatedButton(

                  onPressed:
                      loading
                          ? null
                          : _saveProfile,

                  style:
                      ElevatedButton.styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 16,
                    ),
                  ),

                  child:
                      loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child:
                                  CircularProgressIndicator(
                                color:
                                    Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Text(
                              'Save Profile',
                            ),
                ),

                const SizedBox(
                  height: 12,
                ),

                OutlinedButton(

                  onPressed:
                      _confirmLogout,

                  style:
                      OutlinedButton.styleFrom(
                    padding:
                        const EdgeInsets
                            .symmetric(
                      vertical: 16,
                    ),
                  ),

                  child:
                      const Text('Logout'),
                ),

                const SizedBox(
                  height: 20,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}