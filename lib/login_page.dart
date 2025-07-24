import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({Key? key}) : super(key: key);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool isLoading = false;

  void showMessage(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.teal.shade800,
        ),
      );
    }
  }

  Future<void> loginWithPhoneAndPassword() async {
    final phone = phoneController.text.trim();
    final password = passwordController.text.trim();
    if (phone.isEmpty || !RegExp(r'^\d{10}$').hasMatch(phone)) {
      showMessage("Please enter a valid 10-digit phone number");
      return;
    }
    if (password.isEmpty) {
      showMessage("Please enter your password");
      return;
    }
    setState(() { isLoading = true; });
    try {
      // Find user by phone in Firestore
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('phone', isEqualTo: phone)
          .get();
      if (userQuery.docs.isEmpty) {
        showMessage("No user found for this phone number.");
        setState(() { isLoading = false; });
        return;
      }
      final userData = userQuery.docs.first.data();
      final email = userData['email'] as String?;
      if (email == null || email.isEmpty) {
        showMessage("No email found for this user. Please contact support.");
        setState(() { isLoading = false; });
        return;
      }
      // Sign in with email and password
      final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      if (userCredential.user != null) {
        final userType = userData['type'] as String? ?? 'staff';
        final username = userData['username'] as String? ?? 'User';
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('username', username);
        await prefs.setString('userType', userType);
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/home');
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'user-not-found':
        case 'wrong-password':
          msg = 'Incorrect phone number or password.';
          break;
        default:
          msg = 'Login failed: ${e.message ?? e.code}';
      }
      showMessage(msg);
    } finally {
      if (mounted) setState(() { isLoading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 50),
                // Cute Cow Image
                FadeInDown(
                  duration: const Duration(milliseconds: 1200),
                  child: Center(
                    child: Container(
                      height: 220,
                      width: 220,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.teal.shade100,
                            spreadRadius: 3,
                            blurRadius: 15,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(
                              color: Colors.teal.shade100,
                              width: 3,
                            ),
                          ),
                          child: Image.asset(
                            'assets/images/cowimage.jpg',
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Welcome Text
                FadeInDown(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 1200),
                  child: Text(
                    'Welcome Back!',
                    style: GoogleFonts.poppins(
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      color: Colors.teal.shade800,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 10),
                FadeInDown(
                  delay: const Duration(milliseconds: 600),
                  duration: const Duration(milliseconds: 1200),
                  child: Text(
                    'Login to continue',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                // Phone Number Field
                FadeInDown(
                  delay: const Duration(milliseconds: 800),
                  duration: const Duration(milliseconds: 1200),
                  child: TextFormField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: 'Phone Number',
                      hintText: 'Enter your 10-digit phone number',
                      prefixIcon: const Icon(Icons.phone),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.shade800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Password Field
                FadeInDown(
                  delay: const Duration(milliseconds: 1000),
                  duration: const Duration(milliseconds: 1200),
                  child: TextFormField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade300),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.teal.shade800),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                // Login Button
                FadeInDown(
                  delay: const Duration(milliseconds: 1200),
                  duration: const Duration(milliseconds: 1200),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : loginWithPhoneAndPassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.teal.shade800,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 5,
                    ),
                    child: isLoading
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                            ),
                          )
                        : Text(
                            'Login',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // Forgot Password Link
                FadeInDown(
                  delay: const Duration(milliseconds: 1100),
                  duration: const Duration(milliseconds: 1200),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () async {
                        final email = phoneController.text.trim();
                        if (email.isEmpty) {
                          showMessage('Please enter your phone number to reset password.');
                          return;
                        }
                        setState(() { isLoading = true; });
                        try {
                          await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                          showMessage('Password reset email sent! Check your inbox.');
                        } on FirebaseAuthException catch (e) {
                          String msg;
                          switch (e.code) {
                            case 'user-not-found':
                              msg = 'No user found for that email.';
                              break;
                            case 'invalid-email':
                              msg = 'The email address is invalid.';
                              break;
                            default:
                              msg = 'Failed to send reset email: \\${e.message ?? e.code}';
                          }
                          showMessage(msg);
                        } finally {
                          if (mounted) setState(() { isLoading = false; });
                        }
                      },
                      child: Text(
                        'Forgot Password?',
                        style: GoogleFonts.poppins(
                          color: Colors.teal.shade800,
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ),
                // Register Link
                FadeInDown(
                  delay: const Duration(milliseconds: 1400),
                  duration: const Duration(milliseconds: 1200),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/register');
                    },
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "Don't have an account? ",
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Register',
                            style: GoogleFonts.poppins(
                              color: Colors.teal.shade800,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
