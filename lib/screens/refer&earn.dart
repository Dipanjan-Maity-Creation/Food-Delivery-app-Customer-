import 'package:flutter/material.dart';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class ReferEarnWidget extends StatelessWidget {
  const ReferEarnWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const orangeColor = Color(0xFFFF7A00);
    const lightGrey = Color(0xFFF8F8F8);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0.0, // Moves the title closer to the back button
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Refer & Earn',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Earnings & Successful Referrals
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildInfoCard(
                    title: 'Total Earnings',
                    value: '₹2,450',
                    valueColor: orangeColor,
                  ),
                  _buildInfoCard(
                    title: 'Successful Referrals',
                    value: '48', // Not a currency, so no ₹
                    valueColor: orangeColor,
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Referral description
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: lightGrey,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Earn ₹50 for each friend who joins and completes '
                      'their first transaction',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16.0,
                  ),
                ),
              ),
              const SizedBox(height: 32),

              // "Invite Friends" card-like container
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16.0),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invite Friends',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // First row: WhatsApp & Facebook
                    Row(
                      children: [
                        Expanded(
                          child: _buildInviteOption(
                            label: 'WhatsApp',
                            backgroundColor: Colors.green.shade50,
                            svgPath: 'assets/images/chat-whatsapp.svg',
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInviteOption(
                            label: 'Facebook',
                            backgroundColor: Colors.blue.shade50,
                            svgPath: 'assets/images/social-facebook.svg',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Second row: SMS & Instagram
                    Row(
                      children: [
                        Expanded(
                          child: _buildInviteOption(
                            label: 'SMS',
                            backgroundColor: Colors.grey.shade200,
                            iconData: Icons.sms,
                            iconColor: Colors.grey,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildInviteOption(
                            label: 'Instagram',
                            backgroundColor: Colors.pink.shade50,
                            svgPath: 'assets/images/camera-instagram.svg',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Builds the info cards (e.g. "Total Earnings", "Successful Referrals")
  Widget _buildInfoCard({
    required String title,
    required String value,
    required Color valueColor,
  }) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: valueColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  // Builds a single invite option (either with an SVG or a fallback icon)
  Widget _buildInviteOption({
    required String label,
    required Color backgroundColor,
    String? svgPath,       // pass an SVG path if you want to render an SVG
    IconData? iconData,    // pass an IconData if you want a Material icon fallback
    Color? iconColor,
  }) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (svgPath != null)
            SvgPicture.asset(
              svgPath,
              width: 28,
              height: 28,
              fit: BoxFit.contain,
            )
          else if (iconData != null)
            Icon(
              iconData,
              color: iconColor ?? Colors.black54,
              size: 28,
            ),
          const SizedBox(height: 8),
          Text(
            label,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}