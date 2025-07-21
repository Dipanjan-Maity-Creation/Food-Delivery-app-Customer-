import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yaammy/screens/home.dart';
import 'package:yaammy/screens/offers.dart';
import 'dart:async';
import 'package:yaammy/screens/liquor_store.dart';
import 'package:yaammy/screens/myprofile.dart';
import 'package:yaammy/screens/order_tracking.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:yaammy/screens/location_verification.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:geolocator/geolocator.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:shimmer/shimmer.dart';
import 'package:yaammy/screens/voice_animation.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:fuzzy/fuzzy.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:yaammy/screens/restaurantslist.dart';
import 'package:yaammy/screens/restrarants.dart';
import 'package:yaammy/screens/liquor_category.dart';
import 'package:yaammy/screens/grocery.dart';

class LiquorHomePage extends StatefulWidget {
  @override
  _LiquorHomePageState createState() => _LiquorHomePageState();
}

class _LiquorHomePageState extends State<LiquorHomePage> {
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
  bool _isUnder150FilterActive = false; // New state variable
  bool _isUnder5kmFilterActive = false; // New state variable
  Timer? _filterDebounce; // New debounce timer for filter buttons
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
    _currentIndex = 0; // Ensure initialization
    _initializeData();
    _loadSearchData();
    _fetchUserLocation();
  }

  @override
  void dispose() {
    _controller.dispose();
    _debounce?.cancel();
    _animationTimer?.cancel();
    _liquorStoreSubscription?.cancel();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initializeData() async {
    await _fetchUserLocation();
    if (_userLocation != null) {

    }
  }

  Future<void> _fetchUserLocation() async {
    User? user = FirebaseAuth.instance.currentUser;
    print("Fetching user location. User authenticated: ${user != null}");

    if (user != null) {
      try {
        DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists && userDoc['location'] != null) {
          Map<String, dynamic>? locationData = userDoc['location'] as Map<String, dynamic>?;
          if (locationData == null) {
            print("Location data is null in Firestore for user ${user.uid}");
            setState(() => _userLocation = null);
            return;
          }
          double? lat = double.tryParse(locationData['latitude']?.toString() ?? '');
          double? lng = double.tryParse(locationData['longitude']?.toString() ?? '');
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

  Future<void> _updateUserLocation(String newAddress,
      GeoPoint newGeoPoint) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).update(
          {
            'location': {
              'address': newAddress,
              'geopoint': newGeoPoint,
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
  }

  String _truncateText(String text, int maxLength) {
    return text.length > maxLength
        ? "${text.substring(0, maxLength)}..."
        : text;
  }
  @override
  Widget build(BuildContext context) {
    // Get the current theme
    final ThemeData theme = Theme.of(context);
    final bool isDarkMode = theme.brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDarkMode ? Colors.grey[900] : Color.fromRGBO(249, 250, 251, 1),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top Section with Location and Search Bar
            _buildTopSection(isDarkMode),
            SizedBox(height: 10),

            // Category Section (Food, Grocery, Liquor)
            _buildCategorySection(context, isDarkMode),

            SizedBox(height: 10),

            // Offer Banner Section
            _buildOfferBanner(context, isDarkMode),

            SizedBox(height: 10),

            // "What's on your mind to eat?" Section
            _buildWhatsOnYourMindSection(isDarkMode),
            SizedBox(height: 10),

            _buildFilterAndSortSection(isDarkMode),
            SizedBox(height: 10),

            // Popular Stores Section
            _buildPopularStoresSection(context, isDarkMode),
          ],
        ),
      ),

      // Bottom Navigation Bar
      bottomNavigationBar: _buildBottomNavigationBar(context,),
    );
  }

  // Top Section with Location and Search Bar
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



  Widget _buildLocationContainer(BuildContext context, bool isDarkMode, String location) {
    List<String> locationParts = location.split(',');

    // Safely extracting components
    String village = locationParts.isNotEmpty ? locationParts[0].trim() : "";
    String subLocality = locationParts.length > 1 ? locationParts[1].trim() : "";
    String locality = locationParts.length > 2 ? locationParts[2].trim() : "";

    // Include village/small town name in line1
    String line1 = [village, subLocality, locality]
        .where((part) => part.isNotEmpty)
        .join(', ');

    // Line 2: Everything after index 2
    String line2 = locationParts.length > 3
        ? locationParts.sublist(3).join(',').trim()
        : "";

    // Truncate text
    line1 = _truncateText(line1, 25);
    line2 = _truncateText(line2, 25);
    return GestureDetector(
      onTap: () async {
        String? updatedLocation = await Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => ConfirmLocationPage()),
        );
        if (updatedLocation != null) {
          _updateUserLocation(updatedLocation, GeoPoint(22.295, 87.922));
        }
      },
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(15),
              bottomRight: Radius.circular(15)),
          color: isDarkMode ? Colors.grey[850] : Colors.deepPurple[900],
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 4),
                blurRadius: 4)
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          child: Stack(
            children: [
              Positioned(top: 50,
                  left: 0,
                  child: SvgPicture.asset(
                      'assets/images/address_icon.svg', width: 28,
                      height: 30,
                      fit: BoxFit.contain)),
              Positioned(
                top: 50,
                left: 30,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(line1, style: TextStyle(color: Colors.white,
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500),
                            overflow: TextOverflow.ellipsis),
                        const SizedBox(width: 5),
                        Icon(Icons.keyboard_arrow_down, color: Colors.orange,
                            size: 22),
                      ],
                    ),
                    Text(line2, style: TextStyle(color: Colors.white,
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
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(
                          builder: (context) => MyProfileWidget())),
                  child: FutureBuilder<User?>(
                    future: Future.value(FirebaseAuth.instance.currentUser),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting)
                        return const CircularProgressIndicator();
                      User? user = snapshot.data;
                      String? photoUrl = user?.photoURL;
                      return Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(shape: BoxShape.circle,
                            color: Colors.deepOrange),
                        child: ClipOval(
                          child: photoUrl != null
                              ? Image.network(photoUrl, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                                  Icons.person, size: 30, color: Colors.white))
                              : const Icon(
                              Icons.person, size: 30, color: Colors.white),
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
              // Perform search immediately
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
                      onTap: () {
                        if (controller.text.isEmpty && _isSearchDataLoaded) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Start typing or use voice search to find restaurants, food, or liquor.'),
                              backgroundColor: Colors.deepOrange,
                            ),
                          );
                        }
                      },
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

                    final fuzzy = Fuzzy(_searchData.map((e) => e['name'].toLowerCase()).toList(), options: FuzzyOptions(threshold: 0.2)); // Lower threshold for more matches
                    final results = fuzzy.search(pattern.toLowerCase(), 50); // Increased limit

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

                    // Prioritize liquor items
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

  // Category Section (Food, Grocery, Liquor)
  Widget _buildCategorySection(BuildContext context, bool isDarkMode) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildCircularCategory('Food', () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => homepage()),
            );
          }, isDarkMode),
          SizedBox(width: 20),
          _buildCircularCategory('Grocery', () { Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => ComingSoonPage()),
          );}, isDarkMode),
          SizedBox(width: 20),
          _buildCircularCategory('Liquor', () {}, isDarkMode),
        ],
      ),
    );
  }

  // Circular Category Widget
  Widget _buildCircularCategory(String text, VoidCallback onTap, bool isDarkMode) {
    final Map<String, String> categoryImages = {
      'Food': 'assets/images/restraurant logo.svg',
      'Grocery': 'assets/images/grocery.svg',
      'Liquor': 'assets/images/liquor.svg',
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
                    Color.fromRGBO(244, 81, 30, 0.1411764705882353),
                    Color.fromRGBO(244, 81, 30, 0.1450980392156863),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                )
                    : null,
                color: categoryImages.containsKey(text)
                    ? null
                    : isDarkMode ? Colors.grey[700] : Color.fromRGBO(217, 217, 217, 1),
                border: text == 'Liquor'
                    ? Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 2,
                )
                    : null,
              ),
              child: ClipOval(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: categoryImages.containsKey(text)
                      ? SvgPicture.asset(
                    categoryImages[text]!,
                    fit: BoxFit.contain,
                  )
                      : null,
                ),
              ),
            ),
            SizedBox(height: 1),
            Flexible(
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isDarkMode ? Colors.white : Colors.black,
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Offer Banner Section
  Widget _buildOfferBanner(BuildContext context, bool isDarkMode) {
    final List<String> bannerImages = [
      'assets/images/liquorb.png',
      'assets/images/liquorb.png',
      'assets/images/liquorb.png'
    ];

    final PageController pageController = PageController();
    int currentPage = 0;
    Timer? timer;

    void startAutoSlide(StateSetter setState) {
      timer?.cancel(); // Cancel any existing timer
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
          t.cancel(); // Stop timer if controller is no longer valid
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
                      currentPage = index; // Sync with manual swipes
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
                      controller: pageController, // PageController
                      count: bannerImages.length, // Number of pages
                      effect: const WormEffect(
                        dotWidth: 10.0,
                        dotHeight: 10.0,
                        activeDotColor: Colors.deepOrange,
                        dotColor: Colors.grey,
                        spacing: 8.0,
                      ), // Worm effect with customization
                      onDotClicked: (index) {
                        pageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeInOut,
                        );
                        setState(() {
                          currentPage = index; // Update currentPage on click
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

  // "What's on your mind to eat?" Section
  Widget _buildWhatsOnYourMindSection(bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.0),
          child: Text(
            "Food Category", // Fixed typo
            style: TextStyle(
              color: isDarkMode ? Colors.white : Colors.black,
              fontFamily: 'Poppins',
              fontSize: 20,
              fontWeight: FontWeight.w300,
            ),
          ),
        ),
        SizedBox(height: 5),
        SizedBox(
          height: 100,
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _foodCategoryItem('assets/images/wine.png', 'Wine'),
                _foodCategoryItem('assets/images/whiskey.png', 'Whiskey'),
                _foodCategoryItem('assets/images/rum.png', 'Rum'),
                _foodCategoryItem('assets/images/vodka.png', 'Vodka'),
                _foodCategoryItem('assets/images/tiquilia.png', 'Tiquilia'),
                _foodCategoryItem('assets/images/gin.png', 'Gin'),
                _foodCategoryItem('assets/images/brandy.png', 'Brandy'),
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
          if (_userLocation == null) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Location not available. Please set your location.'),
                backgroundColor: Colors.deepOrange,
              ),
            );
            return;
          }
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => LiquorCategoryPage(
                category: label,
                userLocation: _userLocation!,
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
            ),
          ],
        ),
      ),
    );
  }
  Widget _buildFilterAndSortSection(bool isDarkMode) {
    // List of sorting options
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
                    // Add sorting logic here based on the selected option
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
                  // Add filter logic here if needed
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

  // New _buildSortButton widget to handle sorting options
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
        offset: const Offset(0, 35), // Position the dropdown below the button
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
              // Show the selected sort option, replacing "Sort By" after selection
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
                  activeColor: Colors.deepOrange, // Set the selected radio button color to deep orange
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

  // Existing _buildFilterButton remains unchanged
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

  double _calculateDistance(double? lat, double? lng) {
    if (_userLocation == null) {
      print("User location is null. Cannot calculate distance.");
      return -1; // Sentinel value for invalid distance
    }
    if (lat == null || lng == null) {
      print("Invalid store coordinates: lat=$lat, lng=$lng");
      return -1; // Sentinel value for invalid distance
    }

    try {
      double distanceInMeters = Geolocator.distanceBetween(
        _userLocation!.latitude,
        _userLocation!.longitude,
        lat,
        lng,
      );
      double distanceInKm = distanceInMeters / 1000;
      print("Calculated distance: $distanceInKm km from ($_userLocation) to ($lat, $lng)");
      return distanceInKm;
    } catch (e) {
      print("Error calculating distance: $e");
      return -1; // Sentinel value for invalid distance
    }
  }

  String _calculateTravelTime(double distance) {
    if (distance < 0) return 'N/A min'; // Handle invalid distance (including -1)

    const double speedKmh = 10.0;
    double timeHours = distance / speedKmh;
    double timeMinutes = timeHours * 60;

    if (timeMinutes < 1) return '<1 min';
    return '${timeMinutes.round()} min';
  }

  Widget _buildPopularStoresSection(BuildContext context, bool isDarkMode) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Popular Stores',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 19,
              color: isDarkMode ? Colors.white : Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 1),
        StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance.collection('liq_app').snapshots(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return _buildShimmerList(isDarkMode);
            }
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
              return const Center(child: Text('No stores found'));
            }

            final stores = snapshot.data!.docs;
            // Filter stores by distance <= 15 km
            final nearbyStores = stores.where((storeDoc) {
              final data = storeDoc.data() as Map<String, dynamic>;
              final profileData = data['profile'] as Map<String, dynamic>?;
              final double? lat = profileData?['latitude']?.toDouble();
              final double? lng = profileData?['longitude']?.toDouble();
              final double distance = _calculateDistance(lat, lng);
              return distance >= 0 && distance <= 15; // Only include stores within 15 km
            }).toList();

            if (nearbyStores.isEmpty) {
              return const Center(
                child: Text(
                  'No stores found within 15 km',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.grey,
                  ),
                ),
              );
            }

            return Column(
              children: nearbyStores.map((storeDoc) {
                final data = storeDoc.data() as Map<String, dynamic>;
                final profileData = data['profile'] as Map<String, dynamic>?;
                final String name = profileData?['businessName'] ?? 'Unnamed Store';
                final String photoUrl = profileData?['profilePhotoUrl'] ?? '';

                final double? lat = profileData?['latitude']?.toDouble();
                final double? lng = profileData?['longitude']?.toDouble();

                final double distance = _calculateDistance(lat, lng);
                final String travelTime = _calculateTravelTime(distance);
                final String distanceText = distance >= 0 ? '${distance.toStringAsFixed(1)} km' : 'N/A km';

                return _buildStoreCard(
                  context,
                  name,
                  '4.5 (1k)', // Hardcoded rating; fetch from Firestore if available
                  travelTime,
                  distanceText,
                  isDarkMode,
                  photoUrl: photoUrl,
                  liqAppId: storeDoc.id, // Pass the document ID
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }

// Shimmer List for multiple store cards
  Widget _buildShimmerList(bool isDarkMode) {
    return Column(
      children: List.generate(
        3, // Show 3 placeholder cards; adjust as needed
            (_) => _buildShimmerCard(isDarkMode),
      ),
    );
  }

// Shimmer Card mimicking _buildStoreCard
  Widget _buildShimmerCard(bool isDarkMode) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Shimmer.fromColors(
        baseColor: isDarkMode ? Colors.grey[700]! : Colors.grey[300]!,
        highlightColor: isDarkMode ? Colors.grey[600]! : Colors.grey[200]!,
        child: Container(
          width: 370,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.white, // Base color for shimmer
            border: Border.all(
              color: isDarkMode ? Colors.grey[700]! : Colors.black,
              width: 1,
            ),
          ),
          padding: EdgeInsets.all(20),
          child: Row(
            children: [
              // Image placeholder
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.white,
                ),
              ),
              SizedBox(width: 20),
              // Text placeholders
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 150,
                    height: 16,
                    color: Colors.white,
                  ),
                  SizedBox(height: 5),
                  Container(
                    width: 100,
                    height: 15,
                    color: Colors.white,
                  ),
                  SizedBox(height: 5),
                  Container(
                    width: 80,
                    height: 12,
                    color: Colors.white,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Store Card Widget
  Widget _buildStoreCard(
      BuildContext context,
      String name,
      String rating,
      String time,
      String distance,
      bool isDarkMode, {
        String photoUrl = '',
        required String liqAppId, // Add liqAppId as a required parameter
      }) {
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LiquorstoreWidget(
              businessName: name, // Pass store name as businessName
              travelTime: time,   // Pass calculated travel time
              distance: double.parse(distance.split(' ')[0]), // Extract number from "X.X km"
              liqAppId: liqAppId, // Pass Firestore document ID
            ),
          ),
        );
      },
      child: Container(
        width: 370,
        height: 170,
        margin: const EdgeInsets.only(bottom: 20), // Assuming 'bottom' was meant
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Color.fromRGBO(0, 0, 0, 0.25),
              offset: Offset(0, 4),
              blurRadius: 4,
            ),
          ],
          borderRadius: BorderRadius.circular(8),
          color: isDarkMode ? Colors.grey[800] : Colors.white,
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              width: 170,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(6),
                color: isDarkMode ? Colors.grey[700] : const Color.fromRGBO(217, 217, 217, 1),
              ),
              child: photoUrl.isNotEmpty
                  ? ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Icon(
                    Icons.store,
                    color: isDarkMode ? Colors.white : Colors.black,
                    size: 40,
                  ),
                ),
              )
                  : Icon(
                Icons.store,
                color: isDarkMode ? Colors.white : Colors.black,
                size: 40,
              ),
            ),
            const SizedBox(width: 20),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontSize: 16,
                    fontFamily: 'poppins',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  rating,
                  style: TextStyle(
                    fontSize: 15,
                    fontFamily: 'Poppins',
                    color: isDarkMode ? Colors.white : Colors.black,
                  ),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Text(
                      time,
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.5),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      '• $distance',
                      style: TextStyle(
                        fontSize: 12,
                        fontFamily: 'Poppins',
                        color: isDarkMode ? Colors.white.withOpacity(0.7) : Colors.black.withOpacity(0.5),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Category Circle Widget
  Widget _buildCategoryCircle([String? text, bool isDarkMode = false]) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        color: isDarkMode ? Colors.grey[700] : Color.fromRGBO(217, 217, 217, 1),
        shape: BoxShape.rectangle,
      ),
      child: text != null
          ? Center(
        child: Text(
          text,
          style: TextStyle(
            color: isDarkMode ? Colors.white : Colors.black,
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.normal,
          ),
        ),
      )
          : null,
    );
  }

  // Bottom Navigation Bar
  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.deepOrange,
      unselectedItemColor: Colors.grey,
      currentIndex: _currentIndex,
      onTap: (index) async {
        setState(() => _currentIndex = index);
        switch (index) {

          case 1:
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OrderTrackingWidget()),
            );
            setState(() => _currentIndex = 0); // Reset to Home when returning
            break;
          case 2:
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OffersWidget()),
            );
            setState(() => _currentIndex = 0); // Reset to Home when returning
            break;
        }
      },
      items: [
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
      ],
    );
  }
}