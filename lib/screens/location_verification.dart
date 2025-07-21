import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:geocoding/geocoding.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'package:yaammy/screens/home.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';

class ConfirmLocationPage extends StatefulWidget {
  const ConfirmLocationPage({super.key});

  @override
  _ConfirmLocationPageState createState() => _ConfirmLocationPageState();
}

class _ConfirmLocationPageState extends State<ConfirmLocationPage> with SingleTickerProviderStateMixin {
  Map<String, dynamic>? _selectedLocation;
  String _locationAddress = "Fetching location...";
  bool _isLoading = true;
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  late AnimationController _animationController;

  static const String apiKey = "rchX4ibNhBMuC0u0CIt4lRRZPv1YXNnXpoqsytwU";

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this, // Now valid with SingleTickerProviderStateMixin
      duration: const Duration(milliseconds: 1200),
    )..repeat(); // Start animation
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    setState(() {
      _isLoading = true; // Start loading
    });
    PermissionStatus permissionStatus = await Permission.location.request();
    if (permissionStatus.isGranted) {
      _getCurrentLocation();
    } else {
      setState(() {
        _locationAddress = "Location permission denied";
        _isLoading = false; // Stop loading
      });
      print("Location permission denied");
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String address = await _getAddressFromLatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = {
          "latitude": position.latitude,
          "longitude": position.longitude,
        };
        _locationAddress = address;
        _isLoading = false; // Stop loading when done
      });
    } catch (e) {
      print("Error getting current location: $e");
      setState(() {
        _locationAddress = "Location not available";
        _isLoading = false; // Stop loading on error
      });
    }
  }

  Future<String> _getAddressFromLatLng(double lat, double lng) async {
    try {
      List<Placemark> placemarks = await placemarkFromCoordinates(lat, lng);
      Placemark place = placemarks.first;
      return "${place.street}, ${place.locality}, ${place.administrativeArea}, ${place.country}";
    } catch (e) {
      print("⚠️ Error getting address: $e");
      return "Unknown Location";
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.isEmpty) return;
    try {
      String url =
          "https://api.olamaps.io/places/v1/autocomplete?input=$query&api_key=$apiKey";
      final response = await http.get(Uri.parse(url), headers: {
        "X-Request-Id": DateTime.now().millisecondsSinceEpoch.toString(),
      });

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        List<dynamic> suggestions = data["predictions"] ?? [];

        List<Map<String, dynamic>> results = [];

        for (var place in suggestions) {
          String placeId = place["place_id"];
          String detailsUrl =
              "https://api.olamaps.io/places/v1/details?place_id=$placeId&api_key=$apiKey";

          final detailsResponse = await http.get(Uri.parse(detailsUrl));

          if (detailsResponse.statusCode == 200) {
            final detailsData = json.decode(detailsResponse.body);
            double latitude = detailsData["result"]["geometry"]["location"]["lat"];
            double longitude = detailsData["result"]["geometry"]["location"]["lng"];

            double? distance;
            if (_selectedLocation != null) {
              distance = Geolocator.distanceBetween(
                _selectedLocation!["latitude"],
                _selectedLocation!["longitude"],
                latitude,
                longitude,
              ) / 1000; // Convert meters to kilometers
            }

            results.add({
              "name": place["structured_formatting"]["main_text"],
              "address": place["description"],
              "latitude": latitude,
              "longitude": longitude,
              "distance": distance?.toStringAsFixed(2),
            });
          }
        }

        setState(() {
          _searchResults = results;
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching places: $e");
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    setState(() {
      _locationAddress = place['address'];
      _selectedLocation = {
        "latitude": place['latitude'],
        "longitude": place['longitude'],
      };
      _searchResults = [];
      _isLoading = false; // Stop loading when manually selected
    });
    _searchController.clear();
  }

  Future<void> _saveLocation() async {
    try {
      User? user = FirebaseAuth.instance.currentUser;
      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString('address', _locationAddress);
      if (_selectedLocation != null) {
        await prefs.setDouble('latitude', _selectedLocation!['latitude']);
        await prefs.setDouble('longitude', _selectedLocation!['longitude']);
      }

      if (user != null && _selectedLocation != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'location': {
            'address': _locationAddress,
            'latitude': _selectedLocation!['latitude'],
            'longitude': _selectedLocation!['longitude'],
            'timestamp': FieldValue.serverTimestamp(),
          }
        });
        print("Location saved to Firestore for user ${user.uid}");
      } else {
        print("Location saved to SharedPreferences for non-logged-in user");
      }

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => homepage()),
      );
    } catch (e) {
      print("⚠️ Error saving location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error saving location')),
      );
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: const Color(0xFFFFFDFD),
      appBar: AppBar(
        title: const Text(
          'Confirm Location',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w600,
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
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 5)],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search for your area...",
                    hintStyle: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                    prefixIcon: Icon(Icons.search, color: Color(0xFFFF5722)),
                    border: InputBorder.none,
                  ),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                  onChanged: _searchPlaces,
                ),
              ),
              const SizedBox(height: 10),
              if (_searchResults.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        leading: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.location_on, color: Colors.redAccent, size: 20),
                            const SizedBox(width: 4),
                            if (_searchResults[index]['distance'] != null)
                              Text(
                                "${_searchResults[index]['distance']} km",
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                        title: Text(
                          _searchResults[index]['name'],
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          _searchResults[index]['address'],
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: Colors.grey,
                          ),
                        ),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _selectPlace(_searchResults[index]);
                        },
                      );
                    },
                  ),
                ),
              const SizedBox(height: 50),
              ListTile(
                leading: const Icon(Icons.house, color: Color(0xFFFF5722), size: 28),
                title: _isLoading
                    ? Row(
                  mainAxisSize: MainAxisSize.min, // Keeps the Row compact
                  children: [
                    const SizedBox(width: 5), // Space between animation and text
                    const Text(
                      'Fetching Location ',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SpinKitThreeInOut(
                      color: const Color(0xFFFF5722),
                      size: 15,
                      controller: _animationController,
                    ),

                  ],
                )
                    : Text(
                  _locationAddress,
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 400),
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location, color: Colors.white),
                label: const Text(
                  'Use Current Location',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.white,
                  ),
                  softWrap: false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF9E80),
                  padding: const EdgeInsets.symmetric(horizontal: 80, vertical: 14),
                  minimumSize: const Size(400, 0),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton(
          onPressed: _selectedLocation != null ? _saveLocation : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFFF5722),
            padding: const EdgeInsets.symmetric(horizontal: 50, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Confirm Location',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 14,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}