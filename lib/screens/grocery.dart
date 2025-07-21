import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:yaammy/screens/liiquor_home.dart';
class ComingSoonPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFFFAF7F7),
      appBar: AppBar(
        backgroundColor: Color(0xFFFFFFFF),
        title: Text(
          'Grocery',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w200,
            color: Colors.black,
          ),
        ),
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.of(context).pop(),
        ),
        automaticallyImplyLeading: false, // Prevents default back arrow
      ),
      body: Stack(
        children: [
          Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: 20),
                Text(
                  'We are Coming Soon,\n Stay Connect With Yaammy',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 20,
                    fontWeight: FontWeight.normal,
                    color: Colors.black,
                  ),
                ),
                SizedBox(height: 40),
              ],
            ),
          ),
          Positioned(
            top: 30, // Places animation above center
            left: 0,
            right: 0,
            child: Center(
              child: Lottie.asset(
                'assets/lottie/order animation.json', // Ensure this file exists in assets folder
                width: 370,
                height: 280,
              ),
            ),
          ),
          Positioned(
            bottom: 70, // Adjust this value to position the text vertically
            left: 0,
            right: 200,
            child: Center(
              child: Text(
                '@Yaammy',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color:  Colors.grey[200],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}