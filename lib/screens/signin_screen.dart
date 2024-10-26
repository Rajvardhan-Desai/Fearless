import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'package:google_fonts/google_fonts.dart';
import 'home_screen.dart';
import 'signup_screen.dart';
import 'package:fearless/Widgets/snack_bar.dart';

class SignInScreen extends StatefulWidget {
  const SignInScreen({super.key});

  @override
  SignInScreenState createState() => SignInScreenState();
}

class SignInScreenState extends State<SignInScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isPasswordVisible = false;
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _signIn() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      try {
        final FirebaseAuth auth = FirebaseAuth.instance;
        await auth.signInWithEmailAndPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );
        _navigateToHome();
      } on FirebaseAuthException catch (e) {
        _showErrorSnackBar(e.code);
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  void _navigateToHome() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (context) => const HomeScreen()),
          (Route<dynamic> route) => false,
    );
  }


  Future<void> _resetPassword() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    if (_emailController.text.isEmpty) {
      showSnackBar(scaffoldMessenger, 'Please enter your email to reset your password.', Colors.red);
      return;
    }

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(
        email: _emailController.text.trim(),
      );
      showSnackBar(scaffoldMessenger, 'Check your email for a password reset link if the account exists.', Colors.green);
    } on FirebaseAuthException catch (e) {
      _showErrorSnackBar(e.code);
    }
  }

  void _showErrorSnackBar(String errorCode) {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    String errorMessage;
    switch (errorCode) {
      case 'user-not-found':
        errorMessage = 'No user found for that email.';
        break;
      case 'wrong-password':
        errorMessage = 'Incorrect password.';
        break;
      case 'invalid-email':
        errorMessage = 'Invalid email address.';
        break;
      case 'user-disabled':
        errorMessage = 'User with this email has been disabled.';
        break;
      case 'operation-not-allowed':
        errorMessage = 'Signing in with Email and Password is not enabled.';
        break;
      case 'network-request-failed':
        errorMessage = 'Network error. Please check your connection.';
        break;
      case 'too-many-requests':
        errorMessage = 'Too many requests. Please try again later.';
        break;
      case 'invalid-credential':
        errorMessage = 'Invalid credentials. Please try again.';
        break;
      default:
        errorMessage = 'An error occurred. Please try again later.';
        break;
    }
    showSnackBar(scaffoldMessenger, errorMessage, Colors.red);
  }


  @override
  Widget build(BuildContext context) {
    const angle = 60; // Gradient angle in degrees
    final double x = cos((angle * pi) / 180.0);
    final double y = sin((angle * pi) / 180.0);

    return Scaffold(
      backgroundColor: Colors.deepPurple[300],
      body: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment(-x, -y),
              end: Alignment(x, y),
              colors: const [
                Color(0xFF4b39ef), // Color 1
                Color(0xFFee8b60), // Color 2
              ],
              stops: const [0.0, 1.0], // Transition points
            ),
          ),
          child: Center(
            child: SingleChildScrollView(
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    _buildHeader(),
                    const SizedBox(height: 30.0),
                    _buildCard(),
                    const SizedBox(height: 20.0),
                    _buildSignUpButton(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Text(
      'Fearless',
      style: GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w600,
        fontSize: 36.0,
        color: Colors.white,
      ),
    );
  }

  Widget _buildCard() {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 20.0),
      elevation: 5.0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: <Widget>[
            Text('Welcome Back',
                style: GoogleFonts.plusJakartaSans(
                  fontWeight: FontWeight.w600,
                  fontSize: 24.0,
                  color: Colors.black,
                )),
            const SizedBox(height: 8.0),
            Text(
                'Fill out the information below in order to access your account.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16.0,
                  color: Colors.black,
                )),
            const SizedBox(height: 20.0),
            _buildEmailField(),
            const SizedBox(height: 20.0),
            _buildPasswordField(),
            const SizedBox(height: 10.0),
            _buildForgotPasswordButton(),
            const SizedBox(height: 20.0),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                minimumSize: const Size(double.infinity, 50),
              ),
              onPressed: _signIn,
              child: const Text(
                'Sign In',
                style: TextStyle(
                  fontSize: 18.0,
                  color: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 20.0),
          ],
        ),
      ),
    );
  }

  Widget _buildForgotPasswordButton() {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _resetPassword,
        child: const Text(
          'Forgot Password?',
          style: TextStyle(color: Colors.deepPurple),
        ),
      ),
    );
  }

  Widget _buildSignUpButton() {
    return TextButton(
      onPressed: () {
        Navigator.push(
          context,
          _createRoute(const SignUpScreen()),
        );
      },
      child: const Text(
        "Don't have an account? Sign Up here",
        style: TextStyle(color: Colors.white),
      ),
    );
  }

  Widget _buildEmailField() {
    return TextFormField(
      controller: _emailController,
      decoration: _inputDecoration(labelText: 'Email'),
      keyboardType: TextInputType.emailAddress,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your email';
        }
        final emailRegex =
        RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$');
        if (!emailRegex.hasMatch(value)) {
          return 'Please enter a valid email';
        }
        return null;
      },
    );
  }

  Widget _buildPasswordField() {
    return TextFormField(
      controller: _passwordController,
      decoration: _inputDecoration(
        labelText: 'Password',
        suffixIcon: IconButton(
          icon: Icon(
            _isPasswordVisible ? Icons.visibility : Icons.visibility_off,
          ),
          onPressed: () {
            setState(() {
              _isPasswordVisible = !_isPasswordVisible;
            });
          },
        ),
      ),
      obscureText: !_isPasswordVisible,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Please enter your password';
        } else if (value.length < 6) {
          return 'Password must be at least 6 characters long';
        }
        return null;
      },
    );
  }

  InputDecoration _inputDecoration({required String labelText, Widget? suffixIcon}) {
    return InputDecoration(
      labelText: labelText,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10.0),
      ),
      contentPadding:
      const EdgeInsets.symmetric(vertical: 10.0, horizontal: 20.0),
      suffixIcon: suffixIcon,
    );
  }

  Route _createRoute(Widget page) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.ease;

        final tween = Tween(begin: begin, end: end);
        final curvedAnimation = CurvedAnimation(
          parent: animation,
          curve: curve,
        );

        return FadeTransition(
          opacity: tween.animate(curvedAnimation),
          child: child,
        );
      },
    );
  }
}
