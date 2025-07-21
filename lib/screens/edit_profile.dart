import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

class EditProfileWidget extends StatefulWidget {
  @override
  _EditProfileWidgetState createState() => _EditProfileWidgetState();
}

class _EditProfileWidgetState extends State<EditProfileWidget> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  File? _imageFile;
  String? _photoUrl;
  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    User? user = _auth.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await _firestore.collection('users').doc(user.uid).get();
      print('Firestore data after login: ${userDoc.data()}'); // Log full document
      setState(() {
        _nameController.text = user.displayName ?? userDoc.get('name') ?? '';
        _emailController.text = user.email ?? userDoc.get('email') ?? '';
        _phoneController.text = userDoc.get('contact')?.replaceFirst('+91', '') ??
            user.phoneNumber?.replaceFirst('+91', '') ?? '';
        _photoUrl = user.photoURL ?? userDoc.get('photoURL');
      });
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() {
        _imageFile = File(pickedFile.path);
        print('Image picked: ${pickedFile.path}');
      });
    } else {
      print('No image picked');
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) {
      print('No image file to upload');
      return null;
    }
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        print('No user signed in');
        return null;
      }
      print('User authenticated: ${user.uid}');
      String? token = await user.getIdToken();
      print('Auth token: ${token?.substring(0, 20)}...');
      final ref = _storage
          .ref()
          .child('users/${user.uid}/profile_${DateTime.now().millisecondsSinceEpoch}.jpg');
      print('Uploading image to: ${ref.fullPath}');
      await ref.putFile(_imageFile!);
      String url = await ref.getDownloadURL();
      print('Image uploaded successfully: $url');
      setState(() {
        _photoUrl = url;
      });
      return url;
    } catch (e) {
      print('Image upload failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to upload image: $e')),
      );
      return null;
    }
  }

  Future<void> _saveChanges() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      User? user = _auth.currentUser;
      if (user == null) {
        throw Exception('No user signed in. Please log in again.');
      }
      print('User signed in: ${user.uid}');
      print('Current email verified: ${user.emailVerified}');

      if (!user.emailVerified) {
        await user.sendEmailVerification();
        throw Exception('Your current email (${user.email}) is not verified. A verification email has been sent.');
      }

      String? newPhotoUrl = await _uploadImage() ?? _photoUrl;
      setState(() {
        _photoUrl = newPhotoUrl;
      });

      await user.updateProfile(displayName: _nameController.text.trim(), photoURL: newPhotoUrl);

      String newEmail = _emailController.text.trim();
      if (newEmail != user.email) {
        await user.updateEmail(newEmail);
        await user.sendEmailVerification();
        print('Email updated to $newEmail. Verification email sent.');
      }

      await user.reload();
      user = _auth.currentUser;

      String newContact = '+91${_phoneController.text.trim()}';
      print('Saving to Firestore: contact=$newContact');
      await _firestore.collection('users').doc(user!.uid).set({
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'contact': newContact,
        'photoURL': newPhotoUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print('Firestore update complete');

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Profile updated successfully${newEmail != user!.email ? '. Please verify your new email.' : ''}')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Save changes failed: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: SvgPicture.asset('assets/images/line4.svg', semanticsLabel: 'Back'),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Edit Profile',
          style: TextStyle(
            color: Color.fromRGBO(0, 0, 0, 1),
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.normal,
          ),
        ),
        backgroundColor: Color.fromRGBO(255, 255, 255, 1),
        elevation: 4,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(28),
            topRight: Radius.circular(28),
          ),
        ),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          color: Color.fromRGBO(249, 250, 251, 1),
        ),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                SizedBox(height: 40),
                Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      width: 98,
                      height: 98,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Color.fromRGBO(217, 217, 217, 1),
                        border: Border.all(
                          color: Color.fromRGBO(244, 81, 30, 1),
                          width: 1,
                        ),
                        image: _imageFile != null
                            ? DecorationImage(
                          image: FileImage(_imageFile!),
                          fit: BoxFit.cover,
                        )
                            : _photoUrl != null
                            ? DecorationImage(
                          image: NetworkImage(_photoUrl!),
                          fit: BoxFit.cover,
                        )
                            : null,
                      ),
                    ),
                    GestureDetector(
                      onTap: _pickImage,
                      child: Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color.fromRGBO(244, 81, 30, 1),
                        ),
                        child: Center(
                          child: SvgPicture.asset(
                            'assets/images/camera1.svg',
                            semanticsLabel: 'Camera',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                GestureDetector(
                  onTap: _pickImage,
                  child: Text(
                    'Change Photo',
                    style: TextStyle(
                      color: Color.fromRGBO(244, 81, 30, 1),
                      fontFamily: 'Poppins',
                      fontSize: 17,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 38, vertical: 20),
                  child: Column(
                    children: [
                      _buildInputField(
                        'Full Name',
                        _nameController,
                        validator: (value) =>
                        value == null || value.trim().isEmpty ? 'Please enter your name' : null,
                      ),
                      SizedBox(height: 20),
                      _buildInputField(
                        'Phone Number',
                        _phoneController,
                        keyboardType: TextInputType.phone,
                        validator: (value) =>
                        value == null || value.trim().length != 10
                            ? 'Please enter a valid 10-digit phone number'
                            : null,
                      ),
                      SizedBox(height: 20),
                      _buildInputField(
                        'Email Address',
                        _emailController,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) =>
                        value == null || !RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)
                            ? 'Please enter a valid email'
                            : null,
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: GestureDetector(
                    onTap: _isLoading ? null : _saveChanges,
                    child: Container(
                      width: double.infinity,
                      height: 47,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        gradient: LinearGradient(
                          begin: Alignment(1, 0),
                          end: Alignment(0, 1),
                          colors: [
                            Color.fromRGBO(244, 81, 30, 1),
                            Color.fromRGBO(248, 124, 71, 1),
                          ],
                        ),
                      ),
                      child: Center(
                        child: _isLoading
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text(
                          'Save Changes',
                          style: TextStyle(
                            color: Color.fromRGBO(255, 255, 255, 1),
                            fontFamily: 'Poppins',
                            fontSize: 18,
                          ),
                        ),
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

  Widget _buildInputField(
      String label,
      TextEditingController controller, {
        TextInputType? keyboardType,
        String? Function(String?)? validator,
      }) {
    return Container(
      width: double.infinity,
      height: 87,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Color.fromRGBO(0, 0, 0, 0.25),
            offset: Offset(0, 1),
            blurRadius: 2,
          ),
        ],
        color: Color.fromRGBO(255, 255, 255, 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: Color.fromRGBO(0, 0, 0, 0.6),
                fontFamily: 'Poppins',
                fontSize: 14,
              ),
            ),
            SizedBox(height: 5),
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: keyboardType,
                style: TextStyle(
                  color: Color.fromRGBO(0, 0, 0, 1),
                  fontFamily: 'Poppins',
                  fontSize: 17,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
                validator: validator,
              ),
            ),
          ],
        ),
      ),
    );
  }
}