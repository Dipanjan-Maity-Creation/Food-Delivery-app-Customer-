import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
class AddAddressPage extends StatefulWidget {
  const AddAddressPage({super.key});

  @override
  State<AddAddressPage> createState() => _AddAddressPageState();
}

class _AddAddressPageState extends State<AddAddressPage> {
  final _formKey = GlobalKey<FormState>();

  // Controllers (all empty by default)
  final _houseController = TextEditingController();
  final _buildingController = TextEditingController();
  final _streetController = TextEditingController();
  final _landmarkController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _floorController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactNumberController = TextEditingController();

  // Address type
  String _addressType = 'Home'; // Default selection

  @override
  void dispose() {
    _houseController.dispose();
    _buildingController.dispose();
    _streetController.dispose();
    _landmarkController.dispose();
    _pinCodeController.dispose();
    _floorController.dispose();
    _contactPersonController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  void _saveAddress() async {
    if (_formKey.currentState!.validate()) {
      try {
        User? user = FirebaseAuth.instance.currentUser;
        if (user == null) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User not logged in!')),
          );
          return;
        }

        FirebaseFirestore firestore = FirebaseFirestore.instance;
        DocumentReference userRef = firestore.collection('users').doc(user.uid);

        // Create new address entry
        Map<String, dynamic> addressData = {
          'house_flat': _houseController.text.trim(),
          'building_apartment': _buildingController.text.trim(),
          'street': _streetController.text.trim(),
          'landmark': _landmarkController.text.trim(),
          'pin_code': _pinCodeController.text.trim(),
          'floor': _floorController.text.trim(),
          'contact_person': _contactPersonController.text.trim(),
          'contact_number': _contactNumberController.text.trim(),
          'address_type': _addressType, // Timestamp for sorting
        };

        // 🔹 Update Firestore: Push new address to `deliveryAddressDetails` array
        await userRef.set({
          'Delivery Address Details': FieldValue.arrayUnion([addressData]),
        }, SetOptions(merge: true)); // Ensures existing data is not overwritten

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Address Saved Successfully!')),
        );

        Navigator.pop(context);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}')),
        );
      }
    }
  }




  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // AppBar consistent with the Cart Page style
      appBar: AppBar(
        titleSpacing: 0,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black87),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Add Address',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 70),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // House/Flat Number (Required)
                _buildLabel('House/Flat Number*'),
                _buildTextField(
                  controller: _houseController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Building/Apartment Name (Required)
                _buildLabel('Building/Apartment Name*'),
                _buildTextField(
                  controller: _buildingController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Street Name (Required)
                _buildLabel('Street Name*'),
                _buildTextField(
                  controller: _streetController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Landmark (Optional)
                _buildLabel('Landmark (Optional)'),
                _buildTextField(
                  controller: _landmarkController,
                  validator: null,
                ),
                const SizedBox(height: 16),

                // Pin Code (Required, numeric)
                _buildLabel('Pin Code*'),
                _buildTextField(
                  controller: _pinCodeController,
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Pin code is required';
                    }
                    if (value.length < 4) {
                      return 'Invalid pin code';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Floor (Optional)
                _buildLabel('Floor (Optional)'),
                _buildTextField(
                  controller: _floorController,
                  validator: null,
                ),
                const SizedBox(height: 16),

                // Contact Person Name (Required)
                _buildLabel('Contact Person Name*'),
                _buildTextField(
                  controller: _contactPersonController,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'This field is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Contact Number (Required, numeric)
                _buildLabel('Contact Number*'),
                _buildTextField(
                  controller: _contactNumberController,
                  keyboardType: TextInputType.phone,
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Contact number is required';
                    }
                    if (value.length < 6) {
                      return 'Invalid contact number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Address Type
                _buildLabel('Address Type*'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    _buildAddressTypeOption('Home'),
                    const SizedBox(width: 16),
                    _buildAddressTypeOption('Work'),
                    const SizedBox(width: 16),
                    _buildAddressTypeOption('Other'),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
      // Save Address Button pinned at bottom
      bottomNavigationBar: Container(
        height: 60,
        color: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: ElevatedButton(
          onPressed: _saveAddress,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5722), // Deep orange
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Save Address',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  // Label helper (Regular font, not bold)
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.normal, // Regular font
        color: Colors.black87,
      ),
    );
  }

  // TextField helper (No hint text, no border, darker background, custom cursor)
  Widget _buildTextField({
    required TextEditingController controller,
    String? Function(String?)? validator,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      validator: validator,
      keyboardType: keyboardType,
      cursorColor: Colors.grey,
      cursorWidth: 0.6,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        filled: true,
        fillColor:
            Colors.grey.shade200, // Darker background for improved visibility
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: 12, vertical: 10), // Reduced vertical padding
      ),
    );
  }

  /// Builds the address-type “chip” that looks like the screenshot but uses
  /// the deep orange color (0xFFFF5722) for the selected state.
  /// Builds the address-type “chip” with a fixed width, reduced height, and bold text.
  Widget _buildAddressTypeOption(String type) {
    bool isSelected = _addressType == type;

    return InkWell(
      onTap: () {
        setState(() {
          _addressType = type;
        });
      },
      child: Container(
        // Increase the width (adjust as needed)
        width: 100,
        // Shorten the button height by reducing vertical padding
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? Colors.black : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.black, // Black border
          ),
        ),
        child: Center(
          child: Text(
            type,
            style: TextStyle(
              fontWeight: FontWeight.bold, // Bold text
              color: isSelected
                  ? Colors.white
                  : Colors.black, // White if selected, black otherwise
              fontSize: 14,
            ),
          ),
        ),
      ),
    );
  }
}
