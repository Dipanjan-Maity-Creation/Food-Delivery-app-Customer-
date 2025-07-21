import 'package:flutter/material.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // Entire page background set to white
      appBar: AppBar(
        titleSpacing: 0,
        title: const Text(
          'Contact Us',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Contact details container with darker background
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0), // Updated background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Icon(Icons.phone, color: Colors.deepOrange.shade800),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            '+91 98765 43210',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(Icons.email, color: Colors.deepOrange.shade800),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'contact@businessname.com',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Message form section
              Text(
                'Send us a message',
                style: TextStyle(
                  color: Colors.black87,
                  fontSize: 18,
                  fontFamily: 'Poppins',
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                cursorColor: Colors.deepOrange.shade800,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(8),
                decoration: InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: const TextStyle(fontFamily: 'Poppins'),
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                cursorColor: Colors.deepOrange.shade800,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(8),
                decoration: InputDecoration(
                  labelText: 'Email Address',
                  labelStyle: const TextStyle(fontFamily: 'Poppins'),
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                cursorColor: Colors.deepOrange.shade800,
                cursorWidth: 2,
                cursorRadius: const Radius.circular(8),
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true, // Places the label at the top left
                  labelStyle: const TextStyle(fontFamily: 'Poppins'),
                  filled: true,
                  fillColor: const Color(0xFFF0F0F0),
                  border: OutlineInputBorder(
                    borderSide: BorderSide.none,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () {
                    // TODO: Add send message logic
                  },
                  child: const Text(
                    'Send Message',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.white,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Business hours section with darker background and proper alignment
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0F0F0), // Updated background
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Business Hours',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'Monday - Friday',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '9:00 AM - 6:00 PM',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'Saturday',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            '10:00 AM - 4:00 PM',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: const [
                        Expanded(
                          child: Text(
                            'Sunday',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.black54,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            'Closed',
                            textAlign: TextAlign.end,
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.black54,
                            ),
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
}