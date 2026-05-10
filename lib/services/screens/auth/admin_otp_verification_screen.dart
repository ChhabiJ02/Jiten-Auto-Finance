import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class AdminOtpVerificationScreen extends StatefulWidget {
  final String adminPhoneNumber;

const AdminOtpVerificationScreen({
  super.key,
  required this.adminPhoneNumber,
});

  @override
  State<AdminOtpVerificationScreen> createState() =>
      _AdminOtpVerificationScreenState();
}

class _AdminOtpVerificationScreenState
    extends State<AdminOtpVerificationScreen> {

  final TextEditingController otpController = TextEditingController();

  bool loading = false;

  String verificationId = '';

  // ADMIN PHONE NUMBER
  // Replace with your real admin number
//   final String adminPhoneNumber = '+91XXXXXXXXXX';

  @override
  void initState() {
    super.initState();
    sendOtp();
  }

  Future<void> sendOtp() async {

    setState(() {
      loading = true;
    });

    await FirebaseAuth.instance.verifyPhoneNumber(

     phoneNumber: widget.adminPhoneNumber,
      verificationCompleted: (PhoneAuthCredential credential) async {

        await FirebaseAuth.instance
            .signInWithCredential(credential);

        goToDashboard();
      },

      verificationFailed: (FirebaseAuthException e) {

        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.message ?? 'OTP verification failed',
            ),
          ),
        );
      },

      codeSent: (String verId, int? resendToken) {

        verificationId = verId;

        setState(() {
          loading = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('OTP sent successfully'),
          ),
        );
      },

      codeAutoRetrievalTimeout: (String verId) {
        verificationId = verId;
      },
    );
  }

  Future<void> verifyOtp() async {

    final otp = otpController.text.trim();

    if (otp.isEmpty || otp.length < 6) {

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Enter valid OTP'),
        ),
      );

      return;
    }

    try {

      setState(() {
        loading = true;
      });

      PhoneAuthCredential credential =
          PhoneAuthProvider.credential(
        verificationId: verificationId,
        smsCode: otp,
      );

      await FirebaseAuth.instance
          .signInWithCredential(credential);

      goToDashboard();

    } on FirebaseAuthException catch (e) {

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            e.message ?? 'Invalid OTP',
          ),
        ),
      );

    } finally {

      setState(() {
        loading = false;
      });
    }
  }

  void goToDashboard() {

    Navigator.pushReplacementNamed(
      context,
      '/adminDashboard',
    );
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(

      appBar: AppBar(
        title: const Text('Admin OTP Verification'),
      ),

      body: Padding(
        padding: const EdgeInsets.all(20),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [

            const Icon(
              Icons.security,
              size: 90,
              color: Colors.blue,
            ),

            const SizedBox(height: 20),

            const Text(
              'OTP Verification',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'OTP sent to ${widget.adminPhoneNumber}',
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 30),

            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,

              decoration: const InputDecoration(
                labelText: 'Enter OTP',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,

              height: 55,

              child: ElevatedButton(

                onPressed: loading
                    ? null
                    : verifyOtp,

                child: loading
                    ? const CircularProgressIndicator(
                        color: Colors.white,
                      )
                    : const Text(
                        'Verify OTP',
                        style: TextStyle(
                          fontSize: 18,
                        ),
                      ),
              ),
            ),

            const SizedBox(height: 20),

            TextButton(

              onPressed: loading
                  ? null
                  : sendOtp,

              child: const Text(
                'Resend OTP',
              ),
            ),
          ],
        ),
      ),
    );
  }
}