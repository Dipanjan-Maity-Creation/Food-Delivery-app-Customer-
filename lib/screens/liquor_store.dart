import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_typeahead/flutter_typeahead.dart';
import 'package:fuzzy/fuzzy.dart';
import 'package:yaammy/screens/model/dish.dart';
import 'package:yaammy/screens/order_items.dart';
import 'dart:async';
import 'package:lottie/lottie.dart';

class LiquorstoreWidget extends StatefulWidget {
  final String businessName;
  final String travelTime;
  final double distance;
  final String liqAppId;

  const LiquorstoreWidget({
    super.key,
    required this.businessName,
    required this.travelTime,
    required this.distance,
    required this.liqAppId,
  });

  @override
  State<LiquorstoreWidget> createState() => _LiquorstoreWidgetState();
}

class _LiquorstoreWidgetState extends State<LiquorstoreWidget> {
  List<Dish> _dishes = [];
  GeoPoint? _userLocation;
  String _searchQuery = '';
  String? _selectedCategory; // Track selected category
  bool _showTitle = false;
  final double _titleScrollThreshold = 50.0;
  List<Map<String, dynamic>> _searchData = [];
  bool _isSearchDataLoaded = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchUserLocation();
    _fetchProducts();
    _loadSearchData();

    Future.delayed(const Duration(milliseconds: 1300), () {
      if (mounted) {
        setState(() {
          _isLoading = false;
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
            .get();
        if (userDoc.exists && userDoc['location'] != null) {
          Map<String, dynamic> locationData = userDoc['location'] as Map<String, dynamic>;
          double? lat = double.tryParse(locationData['latitude']?.toString() ?? '');
          double? lng = double.tryParse(locationData['longitude']?.toString() ?? '');
          if (lat != null && lng != null) {
            setState(() {
              _userLocation = GeoPoint(lat, lng);
              print("User location set from Firestore: lat=$lat, lng=$lng");
            });
            return;
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

  Future<void> _fetchProducts() async {
    try {
      QuerySnapshot productSnapshot = await FirebaseFirestore.instance
          .collection('liq_app')
          .doc(widget.liqAppId)
          .collection('products')
          .get();

      List<Dish> fetchedDishes = productSnapshot.docs.map((doc) {
        var data = doc.data() as Map<String, dynamic>;
        return Dish(
          name: data['name'] ?? 'Unknown Product',
          description: data['description'] ?? 'No description available',
          price: double.tryParse(data['price']?.toString() ?? '0') ?? 0.0,
          rating: double.tryParse(data['rating']?.toString() ?? '0') ?? 0.0,
          imageUrl: data['image'],
          category: data['category']?.toString() ?? 'Unknown',
        );
      }).toList();

      setState(() {
        _dishes = fetchedDishes;
        _loadSearchData();
      });
    } catch (e) {
      print("Error fetching products from Firestore: $e");
      setState(() {
        _dishes = [];
        _isSearchDataLoaded = true;
      });
    }
  }

  Future<void> _loadSearchData() async {
    try {
      List<Map<String, dynamic>> searchData = [];

      searchData.add({
        'type': 'store',
        'name': widget.businessName,
        'storeId': widget.liqAppId,
      });

      for (var dish in _dishes) {
        searchData.add({
          'type': 'liquor',
          'name': dish.name,
          'storeId': widget.liqAppId,
          'storeName': widget.businessName,
        });
      }

      setState(() {
        _searchData = searchData;
        _isSearchDataLoaded = true;
      });
      print("Loaded ${_searchData.length} search items");
    } catch (e) {
      print("Error loading search data: $e");
      setState(() {
        _isSearchDataLoaded = true;
      });
    }
  }

  int get totalItems => _dishes.fold(0, (sum, dish) => sum + dish.quantity);

  double get totalPrice => _dishes.fold(0.0, (sum, dish) => sum + dish.quantity * dish.price);

  List<Dish> get _filteredDishes => _dishes.where((dish) {
    final nameLower = dish.name.toLowerCase();
    final descriptionLower = dish.description.toLowerCase();
    final matchesSearch = _searchQuery.isEmpty ||
        nameLower.contains(_searchQuery) ||
        descriptionLower.contains(_searchQuery);
    final matchesCategory = _selectedCategory == null ||
        dish.category.toLowerCase() == _selectedCategory!.toLowerCase() ||
        (_selectedCategory!.isNotEmpty &&
            nameLower.contains(_selectedCategory!.toLowerCase()));
    return matchesSearch && matchesCategory;
  }).toList();

  void _updateSelectedCategory(String? category) {
    setState(() {
      _selectedCategory = category;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _buildAppBar(),
      body: Stack(
        children: [
          NotificationListener<ScrollNotification>(
            onNotification: (scrollNotification) {
              final pixels = scrollNotification.metrics.pixels;
              if (pixels > _titleScrollThreshold && !_showTitle) {
                setState(() => _showTitle = true);
              } else if (pixels <= _titleScrollThreshold && _showTitle) {
                setState(() => _showTitle = false);
              }
              return false;
            },
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            widget.businessName,
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFF5722),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.star, color: Colors.white, size: 14),
                              const SizedBox(width: 4),
                              Text(
                                '4.8',
                                style: GoogleFonts.poppins(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
                    child: Row(
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.access_time, size: 14, color: Color(0xFFFF5722)),
                            const SizedBox(width: 4),
                            Text(
                              widget.travelTime,
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Colors.black54,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '${widget.distance.toStringAsFixed(1)} km',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '•',
                          style: GoogleFonts.poppins(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tamluk locality',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.black54,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: SearchBar(
                      dishes: _dishes,
                      storeName: widget.businessName,
                      searchData: _searchData,
                      isSearchDataLoaded: _isSearchDataLoaded,
                      onSearch: (query) => setState(() => _searchQuery = query),
                      onCategorySelected: _updateSelectedCategory,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: _isLoading || _dishes.isEmpty
                        ? Center(
                      child: Lottie.asset(
                        'assets/lottie/Celebration.json',
                        width: 200,
                        height: 200,
                        fit: BoxFit.contain,
                        repeat: true,
                      ),
                    )
                        : _filteredDishes.isEmpty
                        ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Lottie.asset(
                            'assets/lottie/no orders.json',
                            width: 150,
                            height: 150,
                            fit: BoxFit.contain,
                          ),
                          Text(
                            _selectedCategory == null
                                ? 'No products match your search'
                                : 'No products found for $_selectedCategory',
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    )
                        : Column(
                      children: List.generate(_filteredDishes.length, (index) {
                        final dish = _filteredDishes[index];
                        final originalIndex = _dishes.indexOf(dish);
                        return Column(
                          children: [
                            _buildMenuItem(dish, originalIndex),
                            if (index < _filteredDishes.length - 1)
                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16),
                                child: DottedLine(),
                              ),
                          ],
                        );
                      }),
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
          if (totalItems > 0)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                color: const Color(0xFFF5F5F5),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '$totalItems items selected',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                          Text(
                            'Total: ₹${totalPrice.toStringAsFixed(2)}',
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF5722),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: () {
                        if (_userLocation != null) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => CartPage(
                                dishes: _dishes,
                                liqstoreId: widget.liqAppId,
                                storeName: widget.businessName,
                                userLat: _userLocation!.latitude,
                                userLng: _userLocation!.longitude,
                                travelTime: widget.travelTime,
                                restaurantName: widget.businessName,
                                isFromLiquorStore: true,
                              ),
                            ),
                          );
                        } else {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Location not available. Please wait or set your location.'),
                            ),
                          );
                        }
                      },
                      child: Text(
                        'View Cart',
                        style: GoogleFonts.poppins(),
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

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      titleSpacing: 0,
      title: _showTitle
          ? Text(
        widget.businessName,
        style: GoogleFonts.poppins(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: Colors.black87,
        ),
      )
          : null,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back, color: Colors.black87),
        onPressed: () => Navigator.pop(context),
      ),
    );
  }

  Widget _buildMenuItem(Dish dish, int index) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 120,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: dish.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
              )
                  : const Icon(Icons.image, color: Colors.grey, size: 48),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dish.name,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.normal,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    dish.description,
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        '₹${dish.price.toStringAsFixed(0)}',
                        style: GoogleFonts.poppins(
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF5722).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Color(0xFFFF5722)),
                            const SizedBox(width: 2),
                            Text(
                              dish.rating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: const Color(0xFFFF5722),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(right: 12, top: 12),
            child: dish.quantity == 0 ? _buildAddButton(index) : _buildQuantitySelector(dish, index),
          ),
        ],
      ),
    );
  }

  Widget _buildAddButton(int index) {
    return SizedBox(
      width: 80,
      height: 36,
      child: OutlinedButton(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: const BorderSide(color: Color(0xFFFF5722), width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
        onPressed: () => setState(() => _dishes[index].quantity = 1),
        child: Text(
          'Add',
          style: GoogleFonts.poppins(
            color: const Color(0xFFFF5722),
          ),
        ),
      ),
    );
  }

  Widget _buildQuantitySelector(Dish dish, int index) {
    return SizedBox(
      width: 80,
      height: 36,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: const Color(0xFFFFF3E0),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFFFF5722), width: 1.0),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            GestureDetector(
              onTap: () => setState(() {
                dish.quantity--;
                if (dish.quantity < 0) dish.quantity = 0;
              }),
              child: Text(
                '   -   ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFFFF5722),
                ),
              ),
            ),
            Text(
              '${dish.quantity}',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            GestureDetector(
              onTap: () => setState(() => dish.quantity++),
              child: Text(
                '   +   ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFFFF5722),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class SearchBar extends StatefulWidget {
  final List<Dish> dishes;
  final String storeName;
  final List<Map<String, dynamic>> searchData;
  final bool isSearchDataLoaded;
  final Function(String) onSearch;
  final Function(String?) onCategorySelected;

  const SearchBar({
    Key? key,
    required this.dishes,
    required this.storeName,
    required this.searchData,
    required this.isSearchDataLoaded,
    required this.onSearch,
    required this.onCategorySelected,
  }) : super(key: key);

  @override
  _SearchBarState createState() => _SearchBarState();
}

class _SearchBarState extends State<SearchBar> {
  final TextEditingController _controller = TextEditingController();
  Timer? _animationTimer;
  Timer? _debounce;
  int _currentIndex = 0;
  String? _selectedCategory;

  final List<Map<String, String>> _categories = [
    {'name': 'Wine', 'image': 'assets/images/wine.png'},
    {'name': 'Whiskey', 'image': 'assets/images/whiskey.png'},
    {'name': 'Rum', 'image': 'assets/images/rum.png'},
    {'name': 'Vodka', 'image': 'assets/images/vodka.png'},
    {'name': 'tequila', 'image': 'assets/images/tiquilia.png'},
    {'name': 'Gin', 'image': 'assets/images/gin.png'},
    {'name': 'Brandy', 'image': 'assets/images/brandy.png'},
  ];

  @override
  void initState() {
    super.initState();
    _startTimer();
    _controller.addListener(() {
      widget.onSearch(_controller.text.toLowerCase());
    });
  }

  void _startTimer() {
    _animationTimer?.cancel();
    _animationTimer = Timer.periodic(const Duration(seconds: 2), (Timer t) {
      if (mounted && _controller.text.isEmpty) {
        setState(() {
          _currentIndex = (_currentIndex + 1) % _searchSuggestions.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _animationTimer?.cancel();
    _debounce?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _handleSuggestionTap(Map<String, dynamic> suggestion) {
    _controller.text = suggestion['name'];
    widget.onSearch(suggestion['name'].toLowerCase());
    _animationTimer?.cancel();
    final index = widget.dishes.indexWhere((dish) => dish.name == suggestion['name']);
    if (index != -1) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Selected: ${suggestion['name']}')),
      );
    }
  }

  Widget _foodCategoryItem(String imagePath, String label, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: GestureDetector(
        onTap: () {
          setState(() {
            _selectedCategory = isSelected ? null : label;
            widget.onCategorySelected(_selectedCategory);
          });
        },
        child: Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? const Color(0xFFFF5722) : Colors.grey,
              width: isSelected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(8),
            color: isSelected ? const Color(0xFFFFF3E0) : Colors.transparent,
          ),
          padding: const EdgeInsets.all(8),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: const BoxDecoration(shape: BoxShape.circle),
                child: ClipOval(child: Image.asset(imagePath, fit: BoxFit.cover)),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.poppins(
                  fontSize: 10,
                  color: isSelected ? const Color(0xFFFF5722) : Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          height: 45,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: const Color(0xFFF5F5F5),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              const Icon(Icons.search, color: Color(0xFFFF5722), size: 26),
              const SizedBox(width: 8),
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
                        hintText: widget.isSearchDataLoaded
                            ? _searchSuggestions[_currentIndex]
                            : 'Loading...',
                        hintStyle: GoogleFonts.poppins(
                          fontSize: 12,
                          color: Colors.black38,
                        ),
                      ),
                      style: GoogleFonts.poppins(
                        fontSize: 12,
                        color: Colors.black87,
                      ),
                      onTap: () {
                        if (controller.text.isEmpty && widget.isSearchDataLoaded) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Start typing to search for products.')),
                          );
                        }
                      },
                      onChanged: (value) {
                        if (value.isNotEmpty) {
                          _animationTimer?.cancel();
                        } else if (widget.isSearchDataLoaded) {
                          _startTimer();
                        }
                      },
                      onSubmitted: (value) {
                        if (value.isNotEmpty && widget.searchData.isNotEmpty) {
                          if (_debounce?.isActive ?? false) _debounce!.cancel();
                          _debounce = Timer(const Duration(milliseconds: 300), () {
                            final fuzzy = Fuzzy(widget.searchData.map((e) => e['name']).toList());
                            final results = fuzzy.search(value, 1);
                            if (results.isNotEmpty) {
                              final index = widget.searchData.indexWhere((e) => e['name'] == results[0].item);
                              if (index != -1) {
                                _handleSuggestionTap(widget.searchData[index]);
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('No matching products found.')),
                              );
                            }
                          });
                        }
                      },
                    );
                  },
                  suggestionsCallback: (pattern) async {
                    if (pattern.isEmpty || !widget.isSearchDataLoaded) return [];

                    if (_debounce?.isActive ?? false) _debounce!.cancel();
                    await Future.delayed(const Duration(milliseconds: 300));

                    final fuzzy = Fuzzy(widget.searchData.map((e) => e['name']).toList());
                    final results = fuzzy.search(pattern, 5);

                    return results.map((result) {
                      return widget.searchData.firstWhere((e) => e['name'] == result.item);
                    }).toList();
                  },
                  itemBuilder: (context, Map<String, dynamic> suggestion) {
                    return Material(
                      elevation: 4,
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
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
                            suggestion['type'] == 'store' ? Icons.store : Icons.liquor,
                            color: Colors.black,
                            size: 20,
                          ),
                          title: Text(
                            suggestion['name'],
                            style: GoogleFonts.poppins(
                              fontSize: 14,
                              color: Colors.black,
                            ),
                          ),
                          subtitle: suggestion['type'] == 'liquor'
                              ? Text(
                            'From ${suggestion['storeName']}',
                            style: GoogleFonts.poppins(
                              fontSize: 12,
                              color: Colors.grey[600],
                            ),
                          )
                              : null,
                        ),
                      ),
                    );
                  },
                  emptyBuilder: (context) => Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      'No matching products found.',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: Colors.grey[600],
                      ),
                    ),
                  ),
                  onSelected: _handleSuggestionTap,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Voice search not implemented yet')),
                    );
                  },
                  child: const Icon(Icons.mic, color: Color(0xFFFF5722), size: 20),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(

          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _categories.map((category) {
                final isSelected = _selectedCategory == category['name'];
                return _foodCategoryItem(
                  category['image']!,
                  category['name']!,
                  isSelected,
                );
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  List<String> get _searchSuggestions {
    final productSuggestions = widget.dishes
        .take(3)
        .map((dish) => 'Search for "${dish.name}"')
        .toList();
    return [
      'Search in "${widget.storeName}"',
      ...productSuggestions,
    ];
  }
}

class DottedLine extends StatelessWidget {
  final Color color;
  final double height;
  final double dotWidth;
  final double spacing;
  const DottedLine({
    super.key,
    this.color = Colors.grey,
    this.height = 1.0,
    this.dotWidth = 4.0,
    this.spacing = 4.0,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size(double.infinity, height),
      painter: _DottedLinePainter(color: color, dotWidth: dotWidth, spacing: spacing),
    );
  }
}

class _DottedLinePainter extends CustomPainter {
  final Color color;
  final double dotWidth;
  final double spacing;
  _DottedLinePainter({required this.color, required this.dotWidth, required this.spacing});

  @override
  void paint(Canvas canvas, Size size) {
    Paint paint = Paint()..color = color..strokeWidth = size.height;
    double startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dotWidth, 0), paint);
      startX += dotWidth + spacing;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}