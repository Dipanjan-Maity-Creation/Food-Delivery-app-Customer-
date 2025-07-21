import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shimmer/shimmer.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:theme_provider/theme_provider.dart';
import 'package:yaammy/screens/grocery.dart';
import 'package:yaammy/screens/liiquor_home.dart';
import 'package:yaammy/screens/liquor_store.dart';
import 'package:yaammy/screens/location_verification.dart';
import 'package:yaammy/screens/myprofile.dart';
import 'package:yaammy/screens/offers.dart';
import 'package:yaammy/screens/order_tracking.dart';
import 'package:yaammy/screens/restrarants.dart';
import 'package:yaammy/screens/voice_animation.dart';
import 'package:yaammy/screens/restaurantslist.dart';
import 'package:lottie/lottie.dart';
import 'package:yaammy/screens/restrarants.dart'; // Import RestaurantDetailsPage

class homepage extends StatefulWidget {
  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<homepage> {
  int _currentIndex = 0;
  GeoPoint? _userLocation;
  List<Map<String, dynamic>> _searchData = [];
  bool _isSearchDataLoaded = false;
  StreamSubscription<QuerySnapshot>? _liquorStoreSubscription;
  final stt.SpeechToText _speech = stt.SpeechToText();
  bool _isListening = false;
  bool _speechInitialized = false;
  Timer? _debounce;
  Timer? _animationTimer;
  bool _isUnder150FilterActive = false;
  bool _isUnder5kmFilterActive = false;
  Timer? _filterDebounce;
  String _currentSortOption = 'Relevance (Default)';

  final TextEditingController _controller = TextEditingController();

  List<String> _searchSuggestions = [
    'Search for "Pizza" 🍕',
    'Find your favorite "Burger" 🍔',
    'Get fresh "Groceries" 🛒',
    'Order some "Sushi" 🍣',
    'Buy "Liquor" & "Drinks" 🍷',
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = 0;
    _initializeData();
    _loadSearchData();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _animationTimer?.cancel();
    _liquorStoreSubscription?.cancel();
    _filterDebounce?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchUserLocation();
    if (_userLocation != null) {
      _recalculateRestaurantCount(_userLocation!);
    }
  }

  Future<void> _loadSearchData() async {
    try {
      List<Map<String, dynamic>> searchData = [];

      QuerySnapshot restaurantSnapshot =
      await FirebaseFirestore.instance.collection('RestaurantUsers').get();

      for (var restaurantDoc in restaurantSnapshot.docs) {
        String restaurantId = restaurantDoc.id;
        QuerySnapshot detailsSnapshot = await FirebaseFirestore.instance
            .collection('RestaurantUsers')
            .doc(restaurantId)
            .collection('RestaurantDetails')
            .get();

        for (var doc in detailsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          String restaurantName = data['restaurantName'] ?? 'Unknown Restaurant';
          double? lat = double.tryParse(data['latitude']?.toString() ?? '');
          double? lng = double.tryParse(data['longitude']?.toString() ?? '');

          searchData.add({
            'type': 'restaurant',
            'name': restaurantName,
            'restaurantId': restaurantId,
            'lat': lat ?? 22.295,
            'lng': lng ?? 87.922,
          });

          QuerySnapshot menuSnapshot = await FirebaseFirestore.instance
              .collection('RestaurantUsers')
              .doc(restaurantId)
              .collection('RestaurantDetails')
              .doc(doc.id)
              .collection('MenuItems')
              .get();

          for (var menuDoc in menuSnapshot.docs) {
            final menuData = menuDoc.data() as Map<String, dynamic>;
            String itemName = menuData['name'] ?? 'Unknown Item';
            searchData.add({
              'type': 'food',
              'name': itemName,
              'restaurantId': restaurantId,
              'restaurantName': restaurantName,
              'lat': lat ?? 22.295,
              'lng': lng ?? 87.922,
            });
          }
        }
      }

      QuerySnapshot liquorSnapshot =
      await FirebaseFirestore.instance.collection('liq_app').get();

      if (liquorSnapshot.docs.isEmpty) {
        print("No liquor stores found in liq_app collection");
      } else {
        print("Found ${liquorSnapshot.docs.length} liquor stores");
      }

      for (var liquorDoc in liquorSnapshot.docs) {
        String storeId = liquorDoc.id;
        final data = liquorDoc.data() as Map<String, dynamic>;
        final profileData = data['profile'] as Map<String, dynamic>?;

        if (profileData == null) {
          print("No profile data for store $storeId");
          continue;
        }

        String storeName = profileData['businessName'] ?? 'Unnamed Store';
        double? lat = double.tryParse(profileData['latitude']?.toString() ?? '');
        double? lng = double.tryParse(profileData['longitude']?.toString() ?? '');

        if (storeName.isNotEmpty) {
          searchData.add({
            'type': 'store',
            'name': storeName,
            'storeId': storeId,
            'lat': lat ?? 22.295,
            'lng': lng ?? 87.922,
          });
        }

        QuerySnapshot productSnapshot = await FirebaseFirestore.instance
            .collection('liq_app')
            .doc(storeId)
            .collection('products')
            .get();

        if (productSnapshot.docs.isEmpty) {
          print("No products found for store $storeId");
        } else {
          print("Found ${productSnapshot.docs.length} products for store $storeId");
        }

        for (var productDoc in productSnapshot.docs) {
          final productData = productDoc.data() as Map<String, dynamic>;
          String itemName = productData['name'] ?? 'Unknown Product';
          if (itemName.isNotEmpty) {
            searchData.add({
              'type': 'liquor',
              'name': itemName,
              'storeId': storeId,
              'storeName': storeName,
              'lat': lat ?? 22.295,
              'lng': lng ?? 87.922,
            });
          }
        }
      }

      if (mounted) {
        setState(() {
          _searchData = searchData;
          _isSearchDataLoaded = true;
        });
        print("Loaded ${_searchData.length} total items");
        final liquorItems = _searchData
            .where((item) => item['type'] == 'store' || item['type'] == 'liquor')
            .toList();
        print("Liquor store items: ${liquorItems.length}");
        for (var item in liquorItems) {
          print(
              " - ${item['type']}: ${item['name']}, storeId: ${item['storeId']}, lat: ${item['lat']}, lng: ${item['lng']}");
        }
      }
    } catch (e) {
      print("Error loading search data: $e");
      if (mounted) {
        setState(() {
          _isSearchDataLoaded = true;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load search data: $e')),
        );
      }
    }
  }

  Future<void> _updateUserLocation(String newAddress, GeoPoint newGeoPoint) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'location': {
          'address': newAddress,
          'latitude': newGeoPoint.latitude,
          'longitude': newGeoPoint.longitude,
        },
      });
      print("Updated Firestore location: $newAddress, $newGeoPoint");
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      await prefs.setString('address', newAddress);
      await prefs.setDouble('latitude', newGeoPoint.latitude);
      await prefs.setDouble('longitude', newGeoPoint.longitude);
      print("Updated SharedPrefs location: $newAddress, $newGeoPoint");
    }

    setState(() {
      _userLocation = newGeoPoint;
    });

    _recalculateRestaurantCount(newGeoPoint);
  }

  Future<void> _recalculateRestaurantCount(GeoPoint geoPoint) async {
    int newCount = await _calculateRestaurantCount(geoPoint);
    await _updateRestaurantCount(newCount);
    print("Background recalculation complete: count=$newCount");
    if (mounted) {
      setState(() {});
    }
  }

  Future<int> _calculateRestaurantCount(GeoPoint userLocation) async {
    int count = 0;
    try {
      QuerySnapshot restaurantSnapshot = await FirebaseFirestore.instance
          .collection('RestaurantUsers')
          .get(const GetOptions(source: Source.cache));
      print("Found ${restaurantSnapshot.docs.length} restaurant users");

      for (var restaurantDoc in restaurantSnapshot.docs) {
        String restaurantId = restaurantDoc.id;
        QuerySnapshot detailsSnapshot = await FirebaseFirestore.instance
            .collection('RestaurantUsers')
            .doc(restaurantId)
            .collection('RestaurantDetails')
            .get(const GetOptions(source: Source.cache));

        print(
            "Found ${detailsSnapshot.docs.length} restaurant details for $restaurantId");

        for (var doc in detailsSnapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          double? restaurantLat =
          double.tryParse(data['latitude']?.toString() ?? '');
          double? restaurantLng =
          double.tryParse(data['longitude']?.toString() ?? '');

          print(
              "Restaurant: ${data['restaurantName']}, lat=$restaurantLat, lng=$restaurantLng");

          if (restaurantLat != null && restaurantLng != null) {
            double distanceInMeters = Geolocator.distanceBetween(
              userLocation.latitude,
              userLocation.longitude,
              restaurantLat,
              restaurantLng,
            );
            double distanceInKm = distanceInMeters / 1000;

            if (distanceInKm <= 15) {
              count++;
              print(
                  "Restaurant ${data['restaurantName']} included: distance=$distanceInKm km");
            } else {
              print(
                  "Restaurant ${data['restaurantName']} excluded: distance=$distanceInKm km");
            }
          }
        }
      }

      if (count == 0 && restaurantSnapshot.docs.isEmpty) {
        print("Cache empty, fetching from server");
        restaurantSnapshot =
        await FirebaseFirestore.instance.collection('RestaurantUsers').get();
        for (var restaurantDoc in restaurantSnapshot.docs) {
          String restaurantId = restaurantDoc.id;
          QuerySnapshot detailsSnapshot = await FirebaseFirestore.instance
              .collection('RestaurantUsers')
              .doc(restaurantId)
              .collection('RestaurantDetails')
              .get();

          for (var doc in detailsSnapshot.docs) {
            final data = doc.data() as Map<String, dynamic>;
            double? restaurantLat =
            double.tryParse(data['latitude']?.toString() ?? '');
            double? restaurantLng =
            double.tryParse(data['longitude']?.toString() ?? '');

            if (restaurantLat != null && restaurantLng != null) {
              double distanceInMeters = Geolocator.distanceBetween(
                userLocation.latitude,
                userLocation.longitude,
                restaurantLat,
                restaurantLng,
              );
              double distanceInKm = distanceInMeters / 1000;

              if (distanceInKm <= 15) {
                count++;
              }
            }
          }
        }
      }
    } catch (e) {
      print("Error calculating restaurant count: $e");
    }
    print("Calculated restaurant count: $count");
    return count;
  }

  Future<void> _updateRestaurantCount(int count) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set(
          {'restaurants counts': count},
          SetOptions(merge: true),
        );
        print("Updated restaurant count to $count for user ${user.uid} in Firestore");
      } catch (e) {
        print("Error updating restaurant count in Firestore: $e");
      }
    } else {
      try {
        SharedPreferences prefs = await SharedPreferences.getInstance();
        await prefs.setInt('restaurants_count', count);
        print("Stored restaurant count $count in SharedPreferences");
      } catch (e) {
        print("Error storing restaurant count in SharedPreferences: $e");
      }
    }
  }

  String _truncateText(String text, int maxLength) {
    return text.length > maxLength
        ? "${text.substring(0, maxLength)}..."
        : text;
  }

  double _calculateDistance(double? lat, double? lng) {
    if (_userLocation == null) {
      print("User location is null. Cannot calculate distance.");
      return double.infinity;
    }
    if (lat == null || lng == null) {
      print("Invalid restaurant coordinates: lat=$lat, lng=$lng");
      return double.infinity;
    }

    try {
      double distanceInMeters = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        lat,
        lng,
      );
      double distanceInKm = distanceInMeters / 1000;
      print(
          "Calculated distance: $distanceInKm km from ($_userLocation) to ($lat, $lng)");
      return distanceInKm;
    } catch (e) {
      print("Error calculating distance: $e");
      return double.infinity;
    }
  }

  String _calculateTravelTime(double distance) {
    if (distance <= 0) return 'N/A min';

    const double speedKmh = 10.0;
    double timeHours = distance / speedKmh;
    double timeMinutes = timeHours * 60;

    if (timeMinutes < 1) return '<1 min';
    return '${timeMinutes.round()} min';
  }

  Future<void> _initializeSpeech(StateSetter setState) async {
    if (!_speechInitialized) {
      _speechInitialized = await _speech.initialize(
        onStatus: (status) {
          print("Speech status: $status");
          if (status == 'done' || status == 'notListening') {
            setState(() {
              _isListening = false;
              if (_controller.text.isEmpty && _isSearchDataLoaded) {
                _startTimer(setState);
              }
            });
          }
        },
        onError: (error) {
          print("Speech error: ${error.errorMsg}");
          setState(() {
            _isListening = false;
            if (_controller.text.isEmpty && _isSearchDataLoaded) {
              _startTimer(setState);
            }
          });
          String errorMessage = error.errorMsg == 'error_speech_timeout'
              ? 'No speech detected. Please speak clearly and try again.'
              : 'No speech detected. Please speak clearly and try again: ${error.errorMsg}';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(errorMessage, style: const TextStyle(fontFamily: 'Poppins')),
              backgroundColor: Colors.deepOrange,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _startVoiceSearch(setState),
              ),
            ),
          );
        },
      );
    }
  }

  Future<void> _startVoiceSearch(StateSetter setState) async {
    PermissionStatus status = await Permission.microphone.status;
    print("Microphone permission status: $status");

    if (status.isPermanentlyDenied) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Microphone permission is permanently denied. Please enable it in settings.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.deepOrange,
          action: SnackBarAction(
            label: 'Settings',
            onPressed: () async => await openAppSettings(),
          ),
        ),
      );
      return;
    }

    if (status.isDenied) {
      status = await Permission.microphone.request();
      print("After request, status: $status");
      if (status != PermissionStatus.granted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text(
              'Microphone permission is required for voice search.',
              style: TextStyle(fontFamily: 'Poppins'),
            ),
            backgroundColor: Colors.deepOrange,
            action: SnackBarAction(
              label: 'Retry',
              onPressed: () => _startVoiceSearch(setState),
            ),
          ),
        );
        return;
      }
    }

    await _initializeSpeech(setState);

    if (_speechInitialized) {
      setState(() {
        _isListening = true;
        _controller.clear();
        _animationTimer?.cancel();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Listening...',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.grey[600],
                  ),
                ),
                const SizedBox(height: 8), // Spacing between text and animation
                SpinKitWaveAnimation(
                  height: 70.0,
                  width: 50.0,
                  color: Colors.deepOrange, // Match the UI's orange theme if possible
                ),
              ],
            ),
          ),
          backgroundColor: Colors.white,
          duration: const Duration(seconds: 3),
        ),
      );
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _controller.text = result.recognizedWords;
            if (result.finalResult && _controller.text.isNotEmpty) {
              _isListening = false;
              final fuzzy = Fuzzy(_searchData.map((e) => e['name'].toLowerCase()).toList());
              final results = fuzzy.search(result.recognizedWords.toLowerCase(), 1);
              if (results.isNotEmpty) {
                final index = _searchData.indexWhere((e) => e['name'].toLowerCase() == results[0].item);
                if (index != -1) {
                  final suggestion = _searchData[index];
                  double distance = _calculateDistance(suggestion['lat'], suggestion['lng']);
                  if (distance <= 15 || distance == double.infinity) {
                    _controller.clear();
                    _handleSuggestionTap(context, suggestion);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Item is too far (>15 km).'),
                        backgroundColor: Colors.deepOrange,
                      ),
                    );
                  }
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('No matching restaurants or liquor stores found for "${result.recognizedWords}".'),
                    backgroundColor: Colors.deepOrange,
                  ),
                );
              }
            }
          });
        },
        listenFor: const Duration(seconds: 10),
        pauseFor: const Duration(seconds: 3),
        localeId: 'en_US',
      );
    } else {
      setState(() {
        _isListening = false;
        if (_controller.text.isEmpty && _isSearchDataLoaded) {
          _startTimer(setState);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Speech recognition not available. Please check your device settings.',
            style: TextStyle(fontFamily: 'Poppins'),
          ),
          backgroundColor: Colors.deepOrange,
          action: SnackBarAction(
            label: 'Retry',
            onPressed: () => _startVoiceSearch(setState),
          ),
        ),
      );
    }
  }

  Future<void> _stopVoiceSearch(StateSetter setState) async {
    if (_isListening) {
      await _speech.stop();
      setState(() {
        _isListening = false;
        if (_controller.text.isEmpty && _isSearchDataLoaded) {
          _startTimer(setState);
        }
      });
    }
  }

  void _handleSuggestionTap(BuildContext context, Map<String, dynamic> suggestion) {
    if (_userLocation == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location not available. Please set your location.')),
      );
      return;
    }

    double distance = _calculateDistance(suggestion['lat'], suggestion['lng']);
    if (distance > 15 && distance != double.infinity) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selected item is too far (>15 km).')),
      );
      return;
    }

    _controller.clear();
    if (suggestion['type'] == 'restaurant' || suggestion['type'] == 'food') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RestaurantDetailsPage(
            restaurantId: suggestion['restaurantId'],
            userLat: _userLocation!.latitude,
            userLng: _userLocation!.longitude,
          ),
        ),
      );
    } else if (suggestion['type'] == 'store' || suggestion['type'] == 'liquor') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => LiquorstoreWidget(
            businessName: suggestion['type'] == 'store' ? suggestion['name'] : suggestion['storeName'],
            travelTime: _calculateTravelTime(distance),
            distance: distance,
            liqAppId: suggestion['storeId'],
          ),
        ),
      );
    }
  }

  void _startTimer(StateSetter setState) {
    _animationTimer?.cancel();
    if (_searchSuggestions.isEmpty) return;
    _animationTimer = Timer.periodic(const Duration(seconds: 2), (Timer t) {
      if (_controller.text.isEmpty && _isSearchDataLoaded && !_isListening) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _searchSuggestions.length;
        });
      }
    });
  }

  Future<void> _fetchUserLocation() async {
    User? user = FirebaseAuth.instance.currentUser;
    print("Fetching user location. User authenticated: ${user != null}");

    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get(const GetOptions(source: Source.cache));
        if (!userDoc.exists || userDoc['location'] == null) {
          userDoc = await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get();
        }
        if (userDoc.exists && userDoc['location'] != null) {
          Map<String, dynamic>? locationData =
          userDoc['location'] as Map<String, dynamic>?;
          if (locationData == null) {
            print("Location data is null in Firestore for user ${user.uid}");
            setState(() => _userLocation = null);
            return;
          }
          double? lat =
          double.tryParse(locationData['latitude']?.toString() ?? '');
          double? lng =
          double.tryParse(locationData['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            setState(() {
              _userLocation = GeoPoint(lat, lng);
              print("User location set from Firestore: lat=$lat, lng=$lng");
            });
          } else {
            print("Invalid lat/lng in Firestore: lat=$lat, lng=$lng");
            setState(() => _userLocation = null);
          }
        } else {
          print("No location data in Firestore for user ${user.uid}");
          setState(() => _userLocation = null);
        }
      } catch (e) {
        print("Error fetching location from Firestore: $e");
        setState(() => _userLocation = null);
      }
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      double? lat = prefs.getDouble('latitude');
      double? lng = prefs.getDouble('longitude');
      if (lat != null && lng != null) {
        setState(() {
          _userLocation = GeoPoint(lat, lng);
          print("User location set from SharedPrefs: lat=$lat, lng=$lng");
        });
      } else {
        setState(() {
          _userLocation = GeoPoint(22.295, 87.922);
          print("Default location set: lat=22.295, lng=87.922");
        });
      }
    }
  }

  Future<String> _fetchUserLocationString() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get(const GetOptions(source: Source.cache));
      if (!userDoc.exists) {
        userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
      }
      return userDoc.exists
          ? (userDoc['location']?['address'] ?? "Unknown Location")
          : "No location found";
    } else {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      return prefs.getString('address') ?? "No location found";
    }
  }

  Widget _buildSearchBar(bool isDarkMode) {
    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_controller.text.isEmpty && _isSearchDataLoaded && !_isListening) {
            _startTimer(setState);
          }
        });

        return Container(
          width: 350,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.white,
          ),
          child: Row(
            children: [
              const SizedBox(width: 20),
              Icon(Icons.search, color: Colors.black, size: 26, semanticLabel: 'Search'),
              const SizedBox(width: 10),
              Expanded(
                child: TypeAheadField<Map<String, dynamic>>(
                  controller: _controller,
                  hideOnEmpty: true,
                  builder: (context, controller, focusNode) {
                    return TextField(
                      controller: controller,
                      focusNode: focusNode,
                      decoration: InputDecoration(
                        border: InputBorder.none,
                        hintText: _isSearchDataLoaded
                            ? _searchSuggestions[_currentIndex % _searchSuggestions.length]
                            : ' Search',
                        hintStyle: TextStyle(
                          color: Colors.black.withOpacity(0.6),
                          fontFamily: 'Radio Canada',
                          fontSize: 16,
                        ),
                      ),
                      style: const TextStyle(
                        color: Colors.black,
                        fontSize: 16,
                      ),


                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          _animationTimer?.cancel();
                        } else if (_isSearchDataLoaded && !_isListening) {
                          _startTimer(setState);
                        }
                      },
                      onSubmitted: (value) async {
                        if (value.isEmpty || _searchData.isEmpty) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please enter a search query.'),
                              backgroundColor: Colors.deepOrange,
                            ),
                          );
                          return;
                        }
                        final fuzzy = Fuzzy(_searchData.map((e) => e['name'].toLowerCase()).toList());
                        final results = fuzzy.search(value.toLowerCase(), 1);
                        if (results.isNotEmpty) {
                          final index = _searchData.indexWhere((e) => e['name'].toLowerCase() == results[0].item);
                          if (index != -1) {
                            final suggestion = _searchData[index];
                            _controller.clear();
                            _handleSuggestionTap(context, suggestion);
                          } else {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('No matching restaurants or liquor stores found for "$value".'),
                                backgroundColor: Colors.deepOrange,
                              ),
                            );
                          }
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('No matching restaurants or liquor stores found for "$value".'),
                              backgroundColor: Colors.deepOrange,
                            ),
                          );
                        }
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty || !_isSearchDataLoaded) return [];

                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    await Future.delayed(const Duration(milliseconds: 300));

                    final fuzzy = Fuzzy(_searchData.map((e) => e['name'].toLowerCase()).toList(), options: FuzzyOptions(threshold: 0.2));
                    final results = fuzzy.search(pattern.toLowerCase(), 50);

                    List<Map<String, dynamic>> suggestions = [];
                    for (var result in results) {
                      final item = _searchData.firstWhere(
                            (e) => e['name'].toLowerCase() == result.item,
                        orElse: () => {'name': result.item, 'type': 'unknown', 'lat': 22.295, 'lng': 87.922},
                      );
                      if (item.isNotEmpty) {
                        suggestions.add(item);
                        print("Matched suggestion: ${item['name']}, type: ${item['type']}, score: ${result.score}");
                      }
                    }

                    suggestions.sort((a, b) {
                      bool aIsLiquor = a['type'] == 'store' || a['type'] == 'liquor';
                      bool bIsLiquor = b['type'] == 'store' || b['type'] == 'liquor';
                      if (aIsLiquor && !bIsLiquor) return -1;
                      if (!aIsLiquor && bIsLiquor) return 1;
                      return 0;
                    });

                    print("Suggestions for '$pattern': ${suggestions.length}");
                    for (var suggestion in suggestions) {
                      print(" - ${suggestion['type']}: ${suggestion['name']}");
                    }

                    return suggestions.take(10).toList();
                  },
                  itemBuilder: (context, Map<String, dynamic> suggestion) {
                    return Material(
                      elevation: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: isDarkMode ? Colors.grey[800] : Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.1),
                              spreadRadius: 1,
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        child: ListTile(
                          leading: Icon(
                            suggestion['type'] == 'restaurant'
                                ? Icons.restaurant
                                : suggestion['type'] == 'food'
                                ? Icons.fastfood
                                : suggestion['type'] == 'store'
                                ? Icons.store
                                : Icons.liquor,
                            color: Colors.black,
                            size: 20,
                            semanticLabel: suggestion['type'],
                          ),
                          title: Text(
                            suggestion['name'],
                            style: const TextStyle(
                              color: Colors.black,
                              fontFamily: 'Poppins',
                              fontSize: 14,
                            ),
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (suggestion['type'] == 'food')
                                Text(
                                  'From ${suggestion['restaurantName']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                  ),
                                ),
                              if (suggestion['type'] == 'liquor')
                                Text(
                                  'From ${suggestion['storeName']}',
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  emptyBuilder: (context) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'No matching restaurants, food, or liquor found.',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontFamily: 'Poppins',
                        fontSize: 14,
                      ),
                    ),
                  ),
                  onSelected: (suggestion) {
                    _controller.text = suggestion['name'];
                    _animationTimer?.cancel();
                    _handleSuggestionTap(context, suggestion);
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 15),
                child: GestureDetector(
                  onTap: () {
                    if (_isListening) {
                      _stopVoiceSearch(setState);
                    } else {
                      _startVoiceSearch(setState);
                    }
                  },
                  child: Icon(
                    Icons.mic,
                    color: _isListening ? Colors.deepOrange : Colors.black,
                    size: 26,
                    semanticLabel: _isListening ? 'Stop voice search' : 'Voice search',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeController = ThemeProvider.controllerOf(context);
    final isDarkMode = themeController.theme.id == 'dark';

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : const Color(0xFFFFFDFD),
      body: FutureBuilder<dynamic>(
        future: FirebaseAuth.instance.currentUser != null
            ? FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get(const GetOptions(source: Source.cache))
            : SharedPreferences.getInstance().then((prefs) => prefs.getInt('restaurants_count')),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return SingleChildScrollView(
              child: Column(
                children: [
                  _buildTopSection(isDarkMode),
                  SizedBox(height: 20),
                  _buildCategorySection(context, isDarkMode),
                  _buildShimmerList(isDarkMode),
                ],
              ),
            );
          }

          int restaurantCount = 0;
          if (snapshot.hasData) {
            if (FirebaseAuth.instance.currentUser != null && snapshot.data is DocumentSnapshot) {
              final data = (snapshot.data as DocumentSnapshot).data() as Map<String, dynamic>?;
              restaurantCount = data?['restaurants counts'] as int? ?? 0;
              print("Firestore data: $data");
              print("Restaurant count from Firestore: $restaurantCount");
            } else if (FirebaseAuth.instance.currentUser == null && snapshot.data is int?) {
              restaurantCount = snapshot.data as int? ?? 0;
              print("Restaurant count from SharedPreferences: $restaurantCount");
            } else {
              print("Unexpected snapshot data: ${snapshot.data}");
            }
          } else {
            print("No user data or document exists");
          }

          return Stack(
            children: [
              SingleChildScrollView(
                child: Column(
                  children: [
                    _buildTopSection(isDarkMode),
                    SizedBox(height: 10),
                    _buildCategorySection(context, isDarkMode),
                    IgnorePointer(
                      ignoring: restaurantCount <= 0,
                      child: Opacity(
                        opacity: restaurantCount <= 0 ? 0.5 : 1.0,
                        child: Column(
                          children: [
                            SizedBox(height: 10),
                            _buildOfferBanner(context, isDarkMode),
                            SizedBox(height: 10),
                            _buildWhatsOnYourMindSection(isDarkMode),
                            SizedBox(height: 5),
                            _buildFilterAndSortSection(isDarkMode),
                            SizedBox(height: 10),
                            _buildRestaurantsNearbySection(context, isDarkMode),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (restaurantCount <= 0)
                Positioned(
                  top: 267,
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: Container(
                    color: isDarkMode ? Colors.grey[900] : const Color(0xFFFFFDFD),
                    child: _buildNoRestaurantsWidget(isDarkMode),
                  ),
                ),
            ],
          );
        },
      ),
      bottomNavigationBar: FutureBuilder<dynamic>(
        future: FirebaseAuth.instance.currentUser != null
            ? FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .get(const GetOptions(source: Source.cache))
            : SharedPreferences.getInstance().then((prefs) => prefs.getInt('restaurants_count')),
        builder: (context, snapshot) {
          int restaurantCount = 0;
          if (snapshot.hasData) {
            if (FirebaseAuth.instance.currentUser != null && snapshot.data is DocumentSnapshot) {
              final data = (snapshot.data as DocumentSnapshot).data() as Map<String, dynamic>?;
              restaurantCount = data?['restaurants counts'] as int? ?? 0;
            } else if (FirebaseAuth.instance.currentUser == null && snapshot.data is int?) {
              restaurantCount = snapshot.data as int? ?? 0;
            }
          }
          return IgnorePointer(
            ignoring: restaurantCount <= 0,
            child: Opacity(
              opacity: restaurantCount <= 0 ? 0.5 : 1.0,
              child: _buildBottomNavigationBar(context, isDarkMode),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopSection(bool isDarkMode) {
    return FutureBuilder<String>(
      future: _fetchUserLocationString(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return _buildLocationContainer(
              context, isDarkMode, "Fetching location...");
        } else if (snapshot.hasError) {
          return _buildLocationContainer(
              context, isDarkMode, "Error fetching location");
        } else {
          String locationAddress = snapshot.data ?? "No location found";
          return _buildLocationContainer(context, isDarkMode, locationAddress);
        }
      },
    );
  }

  Widget _buildLocationContainer(
      BuildContext context, bool isDarkMode, String location) {
    List<String> locationParts = location.split(',');

    String village = locationParts.isNotEmpty ? locationParts[0].trim() : "";
    String subLocality =
    locationParts.length > 1 ? locationParts[1].trim() : "";
    String locality = locationParts.length > 2 ? locationParts[2].trim() : "";

    String line1 =
    [village, subLocality, locality].where((part) => part.isNotEmpty).join(', ');
    String line2 =
    locationParts.length > 3 ? locationParts.sublist(3).join(',').trim() : "";

    line1 = _truncateText(line1, 25);
    line2 = _truncateText(line2, 25);

    return GestureDetector(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ConfirmLocationPage()),
        );
        if (result != null && result is Map<String, dynamic>) {
          String updatedLocation = result['address'];
          GeoPoint newGeoPoint = result['geoPoint'];
          _updateUserLocation(updatedLocation, newGeoPoint);
        }
      },
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(15), bottomRight: Radius.circular(15)),
          color: isDarkMode ? Colors.grey[850] : Colors.deepPurple[900],
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 4),
                blurRadius: 4)
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Stack(
            children: [
              Positioned(
                  top: 50,
                  left: 0,
                  child: SvgPicture.asset('assets/images/address_icon.svg',
                      width: 28, height: 30, fit: BoxFit.contain)),
              Positioned(
                top: 50,
                left: 30,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(line1,
                            style: TextStyle(
                                color: Colors.white,
                                fontFamily: 'Poppins',
                                fontSize: 16,
                                fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(width: 5),
                        Icon(Icons.keyboard_arrow_down,
                            color: Colors.orange, size: 22),
                      ],
                    ),
                    Text(line2,
                        style: TextStyle(
                            color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w400),
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              Positioned(top: 105, left: 7, child: _buildSearchBar(isDarkMode)),
              Positioned(
                top: 50,
                right: 10,
                child: GestureDetector(
                  onTap: () => Navigator.push(context,
                      MaterialPageRoute(builder: (context) => MyProfileWidget())),
                  child: FutureBuilder<User?>(
                    future: Future.value(FirebaseAuth.instance.currentUser),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }
                      User? user = snapshot.data;
                      String? photoUrl = user?.photoURL;
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle, color: Colors.deepOrange),
                        child: ClipOval(
                          child: photoUrl != null
                              ? Image.network(
                            photoUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.person,
                                size: 30, color: Colors.white),
                          )
                              : const Icon(Icons.person,
                              size: 30, color: Colors.white),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategorySection(BuildContext context, bool isDarkMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCircularCategory('Food', () {}, isDarkMode),
          SizedBox(width: 20),
          _buildCircularCategory(
              'Grocery',
                  () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => ComingSoonPage())),
              isDarkMode),
          SizedBox(width: 20),
          _buildCircularCategory(
              'Liquor',
                  () => Navigator.push(context,
                  MaterialPageRoute(builder: (context) => LiquorHomePage())),
              isDarkMode),
        ],
      ),
    );
  }

  Widget _buildCircularCategory(String text, VoidCallback onTap, bool isDarkMode) {
    final Map<String, String> categoryImages = {
      'Food': 'assets/images/restraurant logo.svg',
      'Grocery': 'assets/images/grocery.svg',
      'Liquor': 'assets/images/liquor.svg'
    };
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 90,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: categoryImages.containsKey(text)
                    ? LinearGradient(
                    colors: [
                      Color.fromRGBO(244, 81, 30, 0.14),
                      Color.fromRGBO(244, 81, 30, 0.15)
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter)
                    : null,
                color: categoryImages.containsKey(text)
                    ? null
                    : Color.fromRGBO(217, 217, 217, 0.92),
                border: text == 'Food'
                    ? Border.all(color: Colors.orange.withOpacity(0.3), width: 2)
                    : null,
              ),
              child: ClipOval(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: categoryImages.containsKey(text)
                      ? SvgPicture.asset(categoryImages[text]!,
                      fit: BoxFit.contain)
                      : null,
                ),
              ),
            ),
            SizedBox(height: 1),
            Flexible(
              child: Text(text,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                      color: isDarkMode ? Colors.white : Colors.black,
                      fontFamily: 'Poppins',
                      fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWhatsOnYourMindSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Food Category",
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        const SizedBox(height: 5),
        SizedBox(
          height: 100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _foodCategoryItem('assets/images/Biriyani.png', 'Biriyani'),
                _foodCategoryItem('assets/images/Chicken.png', 'Chicken'),
                _foodCategoryItem('assets/images/Burger.png', 'Burger'),
                _foodCategoryItem('assets/images/Roll.png', 'Roll'),
                _foodCategoryItem('assets/images/Pizza.png', 'Pizza'),
                _foodCategoryItem('assets/images/Paneer.png', 'Paneer'),
                _foodCategoryItem('assets/images/Noodles.png', 'Noodles'),
                _foodCategoryItem('assets/images/Momo.png', 'Momo'),
                _foodCategoryItem('assets/images/Fries.png', 'Fries'),
                _foodCategoryItem('assets/images/Fried Rice.png', 'Fried Rice'),
                _foodCategoryItem('assets/images/Desserts.png', 'Desserts'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _foodCategoryItem(String imagePath, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => RestaurantListPage(
                category: label,
                userLocation: _userLocation,
                calculateDistance: _calculateDistance,
                calculateTravelTime: _calculateTravelTime,
              ),
            ),
          );
        },
        child: Column(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(shape: BoxShape.circle),
              child: ClipOval(child: Image.asset(imagePath, fit: BoxFit.cover)),
            ),
            const SizedBox(height: 5),
            Text(
              label,
              style: const TextStyle(fontFamily: 'Poppins', fontSize: 12),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOfferBanner(BuildContext context, bool isDarkMode) {
    final List<String> bannerImages = [
      'assets/images/foodd.jpg',
      'assets/images/Groups.png',
      'assets/images/image 9.png'
    ];

    final PageController pageController = PageController();
    int currentPage = 0;
    Timer? timer;

    void startAutoSlide(StateSetter setState) {
      timer?.cancel();
      timer = Timer.periodic(const Duration(seconds: 3), (Timer t) {
        if (pageController.hasClients) {
          setState(() {
            if (currentPage < bannerImages.length - 1) {
              currentPage++;
            } else {
              currentPage = 0;
            }
            pageController.animateToPage(
              currentPage,
              duration: const Duration(milliseconds: 500),
              curve: Curves.easeInOut,
            );
          });
        } else {
          t.cancel();
        }
      });
    }

    return StatefulBuilder(
      builder: (BuildContext context, StateSetter setState) {
        if (timer == null || !timer!.isActive) {
          startAutoSlide(setState);
        }

        return GestureDetector(
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => OffersWidget()),
          ),
          child: Container(
            width: 360,
            height: 125,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: Stack(
              children: [
                PageView.builder(
                  controller: pageController,
                  itemCount: bannerImages.length,
                  onPageChanged: (index) {
                    setState(() {
                      currentPage = index;
                    });
                  },
                  itemBuilder: (context, index) => ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.asset(
                      bannerImages[index],
                      fit: BoxFit.cover,
                      width: double.infinity,
                      height: double.infinity,
                    ),
                  ),
                ),
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: SmoothPageIndicator(
                      controller: pageController,
                      count: bannerImages.length,
                      effect: const WormEffect(
                        dotWidth: 10.0,
                        dotHeight: 10.0,
                        activeDotColor: Colors.deepOrange,
                        dotColor: Colors.grey,
                        spacing: 8.0,
                      ),
                      onDotClicked: (index) {
                        pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                        setState(() {
                          currentPage = index;
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildFilterAndSortSection(bool isDarkMode) {
    final List<String> sortOptions = [
      'Relevance (Default)',
      'Delivery Time',
      'Rating',
      'Cost: Low to High',
      'Cost: High to Low',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 1),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildSortButton(
                'Sort By',
                'assets/images/sort.svg',
                isDarkMode,
                currentSortOption: _currentSortOption,
                onSelected: (String value) {
                  setState(() {
                    _currentSortOption = value;
                    print('Selected sort option: $value');
                  });
                },
                sortOptions: sortOptions,
              ),
              const SizedBox(width: 16),
              _buildFilterButton(
                'Filter',
                'assets/images/filter.svg',
                isDarkMode,
                onTap: () {
                  print('Filter tapped');
                },
              ),
              const SizedBox(width: 16),
              _buildFilterButton(
                'Under 150',
                'assets/images/rupee.svg',
                isDarkMode,
                onTap: () {
                  if (_filterDebounce?.isActive ?? false) return;
                  _filterDebounce = Timer(const Duration(milliseconds: 500), () {
                    setState(() {
                      _isUnder150FilterActive = !_isUnder150FilterActive;
                      print('Under 150 filter toggled: $_isUnder150FilterActive, currentIndex: $_currentIndex');
                    });
                  });
                },
                isActive: _isUnder150FilterActive,
              ),
              const SizedBox(width: 16),
              _buildFilterButton(
                'Under 5km',
                'assets/images/distance.svg',
                isDarkMode,
                onTap: () {
                  if (_filterDebounce?.isActive ?? false) return;
                  _filterDebounce = Timer(const Duration(milliseconds: 500), () {
                    setState(() {
                      _isUnder5kmFilterActive = !_isUnder5kmFilterActive;
                      print('Under 5km filter toggled: $_isUnder5kmFilterActive, currentIndex: $_currentIndex');
                    });
                  });
                },
                isActive: _isUnder5kmFilterActive,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSortButton(
      String text,
      String iconPath,
      bool isDarkMode, {
        required String currentSortOption,
        required List<String> sortOptions,
        required ValueChanged<String> onSelected,
        bool isActive = false,
      }) {
    return SizedBox(
      height: 35,
      child: PopupMenuButton<String>(
        offset: const Offset(0, 35),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          constraints: const BoxConstraints(minWidth: 90),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? Colors.deepOrange
                  : isDarkMode
                  ? Colors.white
                  : Colors.black,
              width: isActive ? 2.0 : 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(
                  isActive
                      ? Colors.deepOrange
                      : isDarkMode
                      ? Colors.white
                      : Colors.black,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                currentSortOption == 'Relevance (Default)' ? text : currentSortOption.split(': ').length > 1 ? currentSortOption.split(': ')[1] : currentSortOption,
                style: TextStyle(
                  color: isActive
                      ? Colors.deepOrange
                      : isDarkMode
                      ? Colors.white
                      : Colors.black,
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        itemBuilder: (BuildContext context) => sortOptions.map((String option) {
          return PopupMenuItem<String>(
            value: option,
            child: Row(
              children: [
                Radio<String>(
                  value: option,
                  groupValue: currentSortOption,
                  activeColor: Colors.deepOrange,
                  onChanged: (String? value) {
                    if (value != null) {
                      onSelected(value);
                      Navigator.pop(context);
                    }
                  },
                ),
                Text(option, style: TextStyle(fontFamily: 'Poppins')),
              ],
            ),
          );
        }).toList(),
        onSelected: onSelected,
      ),
    );
  }

  Widget _buildFilterButton(
      String text,
      String iconPath,
      bool isDarkMode, {
        VoidCallback? onTap,
        bool isActive = false,
      }) {
    return SizedBox(
      height: 35,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          constraints: const BoxConstraints(minWidth: 90),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isActive
                  ? Colors.deepOrange
                  : isDarkMode
                  ? Colors.white
                  : Colors.black,
              width: isActive ? 2.0 : 1.2,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                iconPath,
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(
                  isActive
                      ? Colors.deepOrange
                      : isDarkMode
                      ? Colors.white
                      : Colors.black,
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                text,
                style: TextStyle(
                  color: isActive
                      ? Colors.deepOrange
                      : isDarkMode
                      ? Colors.white
                      : Colors.black,
                  fontFamily: 'Poppins',
                  fontSize: 16,
                  fontWeight: FontWeight.w300,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRestaurantsNearbySection(BuildContext context, bool isDarkMode) {
    print('Building RestaurantsNearbySection: Under150=$_isUnder150FilterActive, Under5km=$_isUnder5kmFilterActive, currentIndex=$_currentIndex');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 20),
          child: Text(
            'Restaurants nearby',
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        const SizedBox(height: 10),
        FutureBuilder<dynamic>(
          future: FirebaseAuth.instance.currentUser != null
              ? FirebaseFirestore.instance
              .collection('users')
              .doc(FirebaseAuth.instance.currentUser!.uid)
              .get(const GetOptions(source: Source.cache))
              : SharedPreferences.getInstance().then((prefs) => prefs.getInt('restaurants_count')),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList(isDarkMode);
            }
            if (snapshot.hasError) {
              print("Error fetching user data: ${snapshot.error}");
              return FutureBuilder<dynamic>(
                future: FirebaseAuth.instance.currentUser != null
                    ? FirebaseFirestore.instance
                    .collection('users')
                    .doc(FirebaseAuth.instance.currentUser!.uid)
                    .get()
                    : SharedPreferences.getInstance().then((prefs) => prefs.getInt('restaurants_count')),
                builder: (context, serverSnapshot) {
                  if (serverSnapshot.connectionState == ConnectionState.waiting) {
                    return _buildShimmerList(isDarkMode);
                  }
                  return _buildRestaurantList(
                    context,
                    serverSnapshot,
                    isDarkMode,
                    _isUnder150FilterActive,
                    _isUnder5kmFilterActive,
                  );
                },
              );
            }
            return _buildRestaurantList(
              context,
              snapshot,
              isDarkMode,
              _isUnder150FilterActive,
              _isUnder5kmFilterActive,
            );
          },
        ),
      ],
    );
  }

  Widget _buildRestaurantList(
      BuildContext context,
      AsyncSnapshot<dynamic> snapshot,
      bool isDarkMode,
      bool isUnder150FilterActive,
      bool isUnder5kmFilterActive) {
    int restaurantCount = 0;
    if (snapshot.hasData) {
      if (FirebaseAuth.instance.currentUser != null && snapshot.data is DocumentSnapshot) {
        final data = (snapshot.data as DocumentSnapshot).data() as Map<String, dynamic>?;
        restaurantCount = data?['restaurants counts'] as int? ?? 0;
        print("Firestore data: $data");
        print("Restaurant count from Firestore: $restaurantCount");
      } else if (FirebaseAuth.instance.currentUser == null && snapshot.data is int?) {
        restaurantCount = snapshot.data as int? ?? 0;
        print("Restaurant count from SharedPreferences: $restaurantCount");
      } else {
        print("Unexpected snapshot data: ${snapshot.data}");
      }
    } else {
      print("No user data or document exists");
    }

    if (restaurantCount <= 0) {
      print("Showing no restaurants widget due to count: $restaurantCount");
      return const SizedBox.shrink();
    }

    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _fetchRestaurantData(
        isUnder150FilterActive,
        isUnder5kmFilterActive,
      ),
      builder: (context, dataSnapshot) {
        if (dataSnapshot.connectionState == ConnectionState.waiting) {
          return _buildShimmerList(isDarkMode);
        }
        if (dataSnapshot.hasError) {
          print("Error fetching restaurant data: ${dataSnapshot.error}");
          return Center(
            child: Text('Error: ${dataSnapshot.error}',
                style: const TextStyle(fontFamily: 'Poppins')),
          );
        }
        if (!dataSnapshot.hasData || dataSnapshot.data!.isEmpty) {
          print("No restaurant data found");
          _updateRestaurantCount(0);
          return const SizedBox.shrink();
        }

        List<Map<String, dynamic>> restaurantData = dataSnapshot.data!;
        int filteredRestaurantCount = restaurantData.length;

        // Sort based on minPrice if "Cost: Low to High" is selected
        if (_currentSortOption == 'Cost: Low to High') {
          restaurantData.sort((a, b) => (a['minPrice'] as double).compareTo(b['minPrice'] as double));
        }
        // Sort based on averageRating if "Rating" is selected
        else if (_currentSortOption == 'Rating') {
          restaurantData.sort((a, b) => (b['averageRating'] as double).compareTo(a['averageRating'] as double));
        }

        List<Widget> restaurantWidgets = restaurantData.map((data) {
          return GestureDetector(
            onTap: () {
              if (_userLocation != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RestaurantDetailsPage(
                      restaurantId: data['restaurantId'],
                      userLat: _userLocation!.latitude,
                      userLng: _userLocation!.longitude,
                    ),
                  ),
                );
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Location not available. Please set your location.'),
                  ),
                );
              }
            },
            child: _buildRestaurantCard(
              context,
              imageUrl: data['imageUrl'],
              name: data['restaurantName'],
              itemName: data['itemName'],
              itemPrice: data['itemPrice'],
              prepTime: data['prepTime'],
              distance: data['distance'],
              averageRating: data['averageRating'],
              ratingCount: data['ratingCount'],
              isDarkMode: isDarkMode,
            ),
          );
        }).toList();

        WidgetsBinding.instance.addPostFrameCallback((_) async {
          if (filteredRestaurantCount != restaurantCount) {
            await Future.delayed(const Duration(milliseconds: 500));
            _updateRestaurantCount(filteredRestaurantCount);
          }
        });

        return Column(children: restaurantWidgets);
      },
    );
  }

  Future<List<Map<String, dynamic>>> _fetchRestaurantData(
      bool isUnder150FilterActive,
      bool isUnder5kmFilterActive) async {
    List<Map<String, dynamic>> restaurantData = [];
    QuerySnapshot restaurantSnapshot =
    await FirebaseFirestore.instance.collection('RestaurantUsers').get();

    for (var restaurantDoc in restaurantSnapshot.docs) {
      String restaurantId = restaurantDoc.id;
      QuerySnapshot detailsSnapshot = await FirebaseFirestore.instance
          .collection('RestaurantUsers')
          .doc(restaurantId)
          .collection('RestaurantDetails')
          .get();

      for (var doc in detailsSnapshot.docs) {
        final data = doc.data() as Map<String, dynamic>;

        double? restaurantLat = double.tryParse(data['latitude']?.toString() ?? '');
        double? restaurantLng = double.tryParse(data['longitude']?.toString() ?? '');

        double distance = _calculateDistance(restaurantLat, restaurantLng);

        // Apply distance filter
        if (isUnder5kmFilterActive && distance > 5) {
          print("Restaurant ${data['restaurantName']} filtered out: distance=$distance km exceeds 5 km");
          continue;
        }
        if (!isUnder5kmFilterActive && distance > 15) {
          print("Restaurant ${data['restaurantName']} filtered out: distance=$distance km exceeds 15 km");
          continue;
        }

        String restaurantName = data['restaurantName'] ?? 'Unknown Restaurant';
        List<dynamic>? images = data['images'];
        String imageUrl = (images != null && images.isNotEmpty)
            ? images[0] as String
            : 'https://picsum.photos/150';

        // Fetch rating data
        double averageRating = (data['average_rating'] as num?)?.toDouble() ?? 0.0;
        int ratingCount = (data['rating_no_count'] as num?)?.toInt() ?? 0;

        QuerySnapshot menuSnapshot = await FirebaseFirestore.instance
            .collection('RestaurantUsers')
            .doc(restaurantId)
            .collection('RestaurantDetails')
            .doc(doc.id)
            .collection('MenuItems')
            .get();

        if (menuSnapshot.docs.isEmpty) {
          print("No menu items found for restaurant ${doc.id}");
          restaurantData.add({
            'restaurantId': restaurantId,
            'imageUrl': imageUrl,
            'restaurantName': restaurantName,
            'itemName': 'No items available',
            'itemPrice': 'N/A',
            'prepTime': _calculateTravelTime(distance),
            'distance': distance.toStringAsFixed(1) + ' km',
            'minPrice': double.infinity,
            'averageRating': averageRating,
            'ratingCount': ratingCount,
          });
          continue;
        }

        // Apply price filter
        if (isUnder150FilterActive) {
          bool hasItemUnder150 = false;
          for (var item in menuSnapshot.docs) {
            double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
            if (price <= 150 && price > 0) {
              hasItemUnder150 = true;
              break;
            }
          }
          if (!hasItemUnder150) {
            print("Restaurant $restaurantName filtered out: no items under ₹150");
            continue;
          }
        }

        // Select the lowest-priced item
        QueryDocumentSnapshot? minPriceItem;
        double minPrice = double.infinity;
        for (var item in menuSnapshot.docs) {
          double price = double.tryParse(item['price']?.toString() ?? '0') ?? 0;
          if (price < minPrice) {
            minPrice = price;
            minPriceItem = item;
          }
        }

        String itemName = minPriceItem?['name'] ?? 'Unknown Item';
        String itemPrice = minPriceItem == null
            ? 'N/A'
            : 'Price ₹${minPriceItem['price']?.toString() ?? 'N/A'}';

        restaurantData.add({
          'restaurantId': restaurantId,
          'imageUrl': imageUrl,
          'restaurantName': restaurantName,
          'itemName': itemName,
          'itemPrice': itemPrice,
          'prepTime': _calculateTravelTime(distance),
          'distance': distance.toStringAsFixed(1) + ' km',
          'minPrice': minPrice,
          'averageRating': averageRating,
          'ratingCount': ratingCount,
        });
      }
    }

    print("Fetched ${restaurantData.length} restaurant entries");
    return restaurantData;
  }

  Widget _buildNoRestaurantsWidget(bool isDarkMode) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Get screen dimensions
        final screenWidth = constraints.maxWidth;
        final screenHeight = constraints.maxHeight;

        return SingleChildScrollView(
          child: SizedBox(
            height: screenHeight, // Match screen height
            child: Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                // Full-screen background animation (speed line.json)
                Positioned(
                  bottom: 100,
                  child: Lottie.asset(
                    'assets/lottie/speed line.json',
                    width: screenWidth,
                    height: screenHeight,
                    fit: BoxFit.cover, // Cover the screen
                    repeat: true,
                  ),
                ),
                // Foreground animation (delivery animation.json) - Smaller size
                Positioned(
                  bottom: screenHeight * 0.3, // Position above text/button
                  child: Lottie.asset(
                    'assets/lottie/delivery animation.json',
                    width: 200,
                    height: 200,
                    fit: BoxFit.contain,
                    repeat: true,
                  ),
                ),
                // Text and Button - Positioned higher
                Positioned(
                  top: 250, // Near the top
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No restaurants available,\nYaammy Coming Soon this location',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.w400,
                          color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                          backgroundColor: isDarkMode
                              ? Colors.black.withOpacity(0.5)
                              : Colors.white.withOpacity(0.5),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: () async {
                          final result = await Navigator.push(
                            context,
                            MaterialPageRoute(builder: (context) => ConfirmLocationPage()),
                          );
                          if (result != null && result is Map<String, dynamic>) {
                            String updatedLocation = result['address'];
                            GeoPoint newGeoPoint = result['geoPoint'];
                            await _updateUserLocation(updatedLocation, newGeoPoint);
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.deepOrange,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: const Text(
                          'change location',
                          style: TextStyle(fontFamily: 'Poppins', color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 50),
                      Padding(
                        padding: const EdgeInsets.only(right: 200), // Adjust the value to move left
                        child: Text(
                          '@Yaammy',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: isDarkMode ? Colors.grey[200] : Colors.grey[200],
                            backgroundColor: isDarkMode
                                ? Colors.black.withOpacity(0.5)
                                : Colors.white.withOpacity(0.5),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRestaurantCard(
      BuildContext context, {
        required String imageUrl,
        required String name,
        required String itemName,
        required String itemPrice,
        required String prepTime,
        required String distance,
        required double averageRating,
        required int ratingCount,
        bool isDarkMode = false,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Card(
        color: isDarkMode ? Colors.grey[850] : const Color(0xFFF5F5F5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                height: 160,
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(
                      color: Color.fromRGBO(0, 0, 0, 0.25),
                      offset: Offset(0, 4),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  width: double.infinity,
                  height: 160,
                  fit: BoxFit.cover,
                  placeholder: (context, url) => Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.grey.shade300,
                    child: Center(
                      child: CircularProgressIndicator(color: Colors.deepOrange),
                    ),
                  ),
                  errorWidget: (context, url, error) => Container(
                    width: double.infinity,
                    height: 160,
                    color: Colors.grey.shade300,
                    child: Center(
                      child: Text(
                        'Image not available',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Row for restaurant name and rating
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w900,
                            fontSize: 16,
                            color: isDarkMode ? Colors.white : Colors.black,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Row(
                        children: [
                          Icon(Icons.star, size: 16, color: Color(0xFFFF5722)),
                          const SizedBox(width: 4),
                          Text(
                            averageRating > 0
                                ? '${averageRating.toStringAsFixed(1)}${ratingCount > 0 ? ' ($ratingCount)' : ''}'
                                : 'N/A',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontWeight: FontWeight.w400,
                              fontSize: 14,
                              color: isDarkMode ? Colors.grey[400] : Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          itemName,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontWeight: FontWeight.w400,
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                      Text(
                        itemPrice,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined,
                          size: 16, color: Color(0xFFFF5722)),
                      const SizedBox(width: 4),
                      Text(
                        prepTime,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '•',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        distance,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w400,
                          fontSize: 14,
                          color: isDarkMode ? Colors.white : Colors.black,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShimmerList(bool isDarkMode) {
    return Column(
      children: List.generate(3, (_) => _buildShimmerCard(isDarkMode)),
    );
  }

  Widget _buildShimmerCard(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      child: Shimmer.fromColors(
        baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[200]!,
        child: Card(
          color: isDarkMode ? Colors.grey[850] : const Color(0xFFF5F5F5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 10,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 120,
                width: 200,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 120,
                      height: 16,
                      color: Colors.white,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Container(
                            height: 14,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 40,
                          height: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Container(
                          width: 60,
                          height: 14,
                          color: Colors.white,
                        ),
                        const SizedBox(width: 16),
                        Container(
                          width: 60,
                          height: 14,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context, bool isDarkMode) {
    final items = <BottomNavigationBarItem>[
      BottomNavigationBarItem(
        icon: SvgPicture.asset(
          'assets/images/home.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            _currentIndex == 0 ? Colors.deepOrange : Colors.grey,
            BlendMode.srcIn,
          ),
        ),
        label: 'Home',
      ),
      BottomNavigationBarItem(
        icon: SvgPicture.asset(
          'assets/images/cart.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            _currentIndex == 1 ? Colors.deepOrange : Colors.grey,
            BlendMode.srcIn,
          ),
        ),
        label: 'Orders',
      ),
      BottomNavigationBarItem(
        icon: SvgPicture.asset(
          'assets/images/offer.svg',
          width: 24,
          height: 24,
          colorFilter: ColorFilter.mode(
            _currentIndex == 2 ? Colors.deepOrange : Colors.grey,
            BlendMode.srcIn,
          ),
        ),
        label: 'Offers',
      ),
    ];

    // Clamp _currentIndex to valid range [0, 2]
    int safeIndex = _currentIndex.clamp(0, items.length - 1);
    if (_currentIndex != safeIndex) {
      print('Adjusted _currentIndex from $_currentIndex to $safeIndex (items length: ${items.length})');
      _currentIndex = safeIndex; // Update without setState to avoid loop
    }

    print('Building BottomNavigationBar: currentIndex=$safeIndex, items length=${items.length}');

    return BottomNavigationBar(
      backgroundColor: isDarkMode ? Colors.grey[900] : Colors.white,
      selectedItemColor: Colors.deepOrange,
      unselectedItemColor: Colors.grey,
      currentIndex: safeIndex,
      onTap: (index) async {
        print('BottomNavigationBar tapped: newIndex=$index, previous=$_currentIndex');
        int previousIndex = _currentIndex;
        setState(() => _currentIndex = index.clamp(0, items.length - 1));
        switch (index) {
          case 1:
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OrderTrackingWidget()),
            );
            // Only reset to Home if coming back from Orders
            if (mounted) {
              setState(() => _currentIndex = previousIndex == 1 ? 0 : previousIndex);
            }
            break;
          case 2:
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OffersWidget()),
            );
            // Only reset to Home if coming back from Offers
            if (mounted) {
              setState(() => _currentIndex = previousIndex == 2 ? 0 : previousIndex);
            }
            break;
        }
      },
      items: items,
    );
  }
}