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
import 'package:yaammy/screens/add_more_address_details.dart';

class OrderAddressPage extends StatefulWidget {
  const OrderAddressPage({super.key});

  @override
  _ConfirmLocationPageState createState() => _ConfirmLocationPageState();
}

class _ConfirmLocationPageState extends State<OrderAddressPage> {
  Map<String, dynamic>? _selectedLocation;
  String _locationAddress = "Fetching location...";
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];

  static const String apiKey = "Your Ola Map Api-Key";

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
  }

  Future<void> _requestLocationPermission() async {
    PermissionStatus permissionStatus = await Permission.location.request();
    if (permissionStatus.isGranted) {
      _getCurrentLocation();
    } else {
      print("Location permission denied");
      setState(() {
        _locationAddress = "Location permission denied";
      });
    }
  }

  Future<void> _getCurrentLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      String address =
      await _getAddressFromLatLng(position.latitude, position.longitude);

      setState(() {
        _selectedLocation = {
          "latitude": position.latitude,
          "longitude": position.longitude,
        };
        _locationAddress = address;
      });
    } catch (e) {
      print("Error getting current location: $e");
      setState(() {
        _locationAddress = "Location not available";
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

        setState(() {
          _searchResults = suggestions.map((place) {
            return {
              "name": place["structured_formatting"]["main_text"],
              "address": place["description"],
            };
          }).toList();
        });
      } else {
        print("Error: ${response.statusCode}");
      }
    } catch (e) {
      print("Error fetching places: $e");
    }
  }

  Future<void> _selectPlace(Map<String, dynamic> place) async {
    try {
      // Geocode the selected address to get coordinates
      List<Location> locations = await locationFromAddress(place['address']);
      if (locations.isNotEmpty) {
        final location = locations.first;
        setState(() {
          _locationAddress = place['address'];
          _selectedLocation = {
            "latitude": location.latitude,
            "longitude": location.longitude,
          };
          _searchResults = [];
          _searchController.clear();
        });
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find location coordinates.')),
        );
      }
    } catch (e) {
      print("Error geocoding address: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Error processing address. Try again.')),
      );
    }
  }

  Future<void> _saveLocation() async {
    if (_selectedLocation == null ||
        _selectedLocation!['latitude'] == 0.0 ||
        _selectedLocation!['longitude'] == 0.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a valid location.')),
      );
      return;
    }

    try {
      User? user = FirebaseAuth.instance.currentUser;
      SharedPreferences prefs = await SharedPreferences.getInstance();

      await prefs.setString('address', _locationAddress);
      await prefs.setDouble('latitude', _selectedLocation!['latitude']);
      await prefs.setDouble('longitude', _selectedLocation!['longitude']);

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'delivery_addresses': {
            'address': _locationAddress,
            'latitude': _selectedLocation!['latitude'],
            'longitude': _selectedLocation!['longitude'],
            'timestamp': FieldValue.serverTimestamp(),
          }
        });
        print('Saved delivery_addresses with coordinates: ${_selectedLocation!['latitude']}, ${_selectedLocation!['longitude']}');
      }

      // Navigate to AddAddressPage after saving
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const AddAddressPage()),
      );
    } catch (e) {
      print("⚠️ Error saving location: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save location.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final double searchWidth = MediaQuery.of(context).size.width * 0.98;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        title: const Text('Confirm Location', style: TextStyle(fontSize: 16)),
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
            children: [
              // Search Bar
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black12, blurRadius: 5)
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: const InputDecoration(
                    hintText: "Search for your area...",
                    prefixIcon: Icon(Icons.search, color: Color(0xFFFF5722)),
                    border: InputBorder.none,
                  ),
                  onChanged: (query) {
                    if (query.isEmpty) {
                      setState(() {
                        _searchResults = [];
                      });
                    } else {
                      _searchPlaces(query);
                    }
                  },
                ),
              ),

              const SizedBox(height: 10),

              // Search Results
              if (_searchResults.isNotEmpty)
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) {
                      return ListTile(
                        title: Text(_searchResults[index]['name']),
                        subtitle: Text(_searchResults[index]['address']),
                        onTap: () {
                          FocusScope.of(context).unfocus();
                          _selectPlace(_searchResults[index]);
                        },
                      );
                    },
                  ),
                ),

              const SizedBox(height: 20),

              // Selected Location
              ListTile(
                leading: const Icon(
                    Icons.location_on, color: Color(0xFFFF5722), size: 28),
                title: Text(_locationAddress,
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 40),

              // Use Current Location Button
              ElevatedButton.icon(
                onPressed: _getCurrentLocation,
                icon: const Icon(Icons.my_location, color: Colors.deepOrange),
                label: const Text('Use Current Location',
                    style: TextStyle(fontSize: 14, color: Colors.black)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xBAFEEEEB),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
        ),
      ),

      bottomNavigationBar: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _saveLocation,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFF5722),
                padding: const EdgeInsets.symmetric(horizontal: 120, vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text(
                'Confirm Location',
                style: TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
            const SizedBox(height: 300),
          ],
        ),
      ),
    );
  }
}
