import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yaammy/screens/login.dart';
import 'package:yaammy/screens/home.dart';

class SplashScreenWidget extends StatefulWidget {
  @override
  _SplashScreenWidgetState createState() => _SplashScreenWidgetState();
}

class _SplashScreenWidgetState extends State<SplashScreenWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    );

    _opacityAnimation = Tween<double>(begin: 0, end: 1).animate(_controller);
    _controller.forward();

    _checkUserAuthentication();
  }

  void _checkUserAuthentication() {
    Timer(Duration(seconds: 3), () {
      User? user = FirebaseAuth.instance.currentUser;
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => user != null ? homepage() : LoginPage(),
          ),
        );
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: <Widget>[
          Container(
            width: size.width,
            height: size.height,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topLeft,
                colors: [
                  Color.fromRGBO(244, 81, 30, 1),
                  Color.fromRGBO(248, 124, 71, 1),
                ],
              ),
            ),
          ),
          Center(
            child: FadeTransition(
              opacity: _opacityAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Yaammy',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Poppins',
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'Fast and Fresh Delivery',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontFamily: 'Open Sans',
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
