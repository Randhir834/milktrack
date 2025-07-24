import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:firebase_auth/firebase_auth.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController typeController = TextEditingController();
  bool isLoading = false;
  bool obscurePassword = true;

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

  Future<void> registerUser() async {
    if (emailController.text.isEmpty || 
        phoneController.text.isEmpty ||
        passwordController.text.isEmpty || 
        typeController.text.isEmpty ||
        usernameController.text.isEmpty) {
      showMessage("All fields are required");
      return;
    }
    // Validate phone number (basic check)
    final phone = phoneController.text.trim();
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      showMessage("Please enter a valid 10-digit phone number");
      return;
    }
    // Check if phone number already exists
    final phoneQuery = await FirebaseFirestore.instance
        .collection('users')
        .where('phone', isEqualTo: phone)
        .get();
    if (phoneQuery.docs.isNotEmpty) {
      showMessage("Phone number already registered. Please use another.");
      return;
    }

    // Validate username (no spaces, special characters, etc.)
    final username = usernameController.text.trim();
    if (username.length < 3) {
      showMessage("Username must be at least 3 characters long");
      return;
    }
    if (!RegExp(r'^[a-zA-Z0-9_]+$').hasMatch(username)) {
      showMessage("Username can only contain letters, numbers, and underscores");
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      // Check if username already exists
      final usernameQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: username)
          .get();

      if (usernameQuery.docs.isNotEmpty) {
        showMessage("Username already taken. Please choose another one.");
        setState(() {
          isLoading = false;
        });
        return;
      }

      // Create user with Firebase Auth
      final UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
              email: emailController.text.trim(),
              password: passwordController.text.trim());

      // Wait for auth state to be ready (important for web)
      User? user;
      await for (final u in FirebaseAuth.instance.authStateChanges()) {
        if (u != null) {
          user = u;
          break;
        }
      }
      print('Current user after authStateChanges: ' + user.toString());
      print('Current user UID: ' + (user?.uid ?? 'null'));
      print('Current user email: ' + (user?.email ?? 'null'));
      if (user != null) {
        try {
          // Test write to a test collection
          await FirebaseFirestore.instance.collection('test').add({'test': 'value', 'uid': user.uid, 'email': user.email});
          print('Test write to test collection succeeded.');
        } catch (testWriteError) {
          print('Test write to test collection failed: ' + testWriteError.toString());
        }
        try {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
            'email': emailController.text.trim(),
            'phone': phoneController.text.trim(),
            'username': username,
            'type': typeController.text.trim().isNotEmpty ? typeController.text.trim() : 'staff',
            'createdAt': FieldValue.serverTimestamp(),
          });
        } catch (firestoreError) {
          print('Firestore write error: ' + firestoreError.toString());
          showMessage('Firestore error: ' + firestoreError.toString());
          setState(() {
            isLoading = false;
          });
          return;
        }

        showMessage("Registration successful! Please login.");
        if (mounted) {
          Navigator.pushReplacementNamed(context, '/');
        }
      }
    } on FirebaseAuthException catch (e) {
      String msg;
      switch (e.code) {
        case 'email-already-in-use':
          msg = 'This email is already registered.';
          break;
        case 'invalid-email':
          msg = 'The email address is invalid.';
          break;
        case 'weak-password':
          msg = 'The password is too weak.';
          break;
        case 'operation-not-allowed':
          msg = 'Email/password accounts are not enabled.';
          break;
        default:
          msg = 'Registration failed: ${e.message ?? e.code}';
      }
      showMessage(msg);
    } catch (e) {
      print('Registration error: $e');
      showMessage('An unexpected error occurred. Please try again. ($e)');
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
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
                const SizedBox(height: 30),
                // Back Button
                FadeInDown(
                  duration: const Duration(milliseconds: 800),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.arrow_back_ios, color: Colors.teal.shade800),
                    ),
                  ),
                ),
                // Cute Cow Image
                FadeInDown(
                  duration: const Duration(milliseconds: 1200),
                  child: Center(
                    child: Container(
                      height: 200,
                      width: 200,
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
                const SizedBox(height: 25),
                // Register Text
                FadeInDown(
                  delay: const Duration(milliseconds: 400),
                  duration: const Duration(milliseconds: 1200),
                  child: Text(
                    'Create Account',
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
                    'Please fill in the details below',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      color: Colors.grey.shade600,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 40),
                // Username Field
                FadeInDown(
                  delay: const Duration(milliseconds: 600),
                  duration: const Duration(milliseconds: 1200),
                  child: TextFormField(
                    controller: usernameController,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Enter your username',
                      prefixIcon: const Icon(Icons.person),
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
                // Email Field
                FadeInDown(
                  delay: const Duration(milliseconds: 800),
                  duration: const Duration(milliseconds: 1200),
                  child: TextFormField(
                    controller: emailController,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'Enter your email',
                      prefixIcon: const Icon(Icons.email),
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
                // Phone Number Field
                FadeInDown(
                  delay: const Duration(milliseconds: 900),
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
                    obscureText: obscurePassword,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText: 'Enter your password',
                      prefixIcon: const Icon(Icons.lock),
                      suffixIcon: IconButton(
                        icon: Icon(
                          obscurePassword ? Icons.visibility : Icons.visibility_off,
                        ),
                        onPressed: () {
                          setState(() {
                            obscurePassword = !obscurePassword;
                          });
                        },
                      ),
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
                // User Type Field
                FadeInDown(
                  delay: const Duration(milliseconds: 1200),
                  duration: const Duration(milliseconds: 1200),
                  child: TextFormField(
                    controller: typeController,
                    decoration: InputDecoration(
                      labelText: 'User Type',
                      hintText: 'Enter user type (admin/staff)',
                      prefixIcon: const Icon(Icons.badge),
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
                // Register Button
                FadeInDown(
                  delay: const Duration(milliseconds: 1400),
                  duration: const Duration(milliseconds: 1200),
                  child: ElevatedButton(
                    onPressed: isLoading ? null : registerUser,
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
                            'Register',
                            style: GoogleFonts.poppins(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 20),
                // Login Link
                FadeInDown(
                  delay: const Duration(milliseconds: 1600),
                  duration: const Duration(milliseconds: 1200),
                  child: TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        text: "Already have an account? ",
                        style: GoogleFonts.poppins(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                        children: [
                          TextSpan(
                            text: 'Login',
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
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
