import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yaammy/screens/model/dish.dart'; // Adjust path
import 'package:yaammy/screens/order_items.dart'; // Adjust path
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lottie/lottie.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class RestaurantDetailsPage extends StatefulWidget {
  final String restaurantId;
  final double userLat;
  final double userLng;
  final Function(Dish, String, String, String)? addToCartCallback;

  const RestaurantDetailsPage({
    super.key,
    required this.restaurantId,
    required this.userLat,
    required this.userLng,
    this.addToCartCallback,
  });

  @override
  State<RestaurantDetailsPage> createState() => _RestaurantDetailsPageState();
}

class _RestaurantDetailsPageState extends State<RestaurantDetailsPage> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All';
  String restaurantName = 'Loading...';
  List<Dish> _dishes = [];
  bool _isLoading = true;
  double? restaurantLat;
  double? restaurantLng;
  double distance = 0.0;
  String travelTime = 'N/A min';
  String cityName = 'Unknown';
  String cancellationPolicy = 'No policy available';
  String fssaiLicenseNumber = 'Not provided';
  double _averageRating = 0.0; // New state variable for average rating
  int _ratingCount = 0; // New state variable for rating count

  bool _showTitle = false;
  final double _titleScrollThreshold = 50.0;

  @override
  void initState() {
    super.initState();
    _fetchRestaurantData();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  Future<void> _fetchRestaurantData() async {
    try {
      QuerySnapshot detailsSnapshot = await FirebaseFirestore.instance
          .collection('RestaurantUsers')
          .doc(widget.restaurantId)
          .collection('RestaurantDetails')
          .get();

      if (detailsSnapshot.docs.isNotEmpty) {
        var detailsDoc = detailsSnapshot.docs.first.data() as Map<String, dynamic>;
        setState(() {
          restaurantName = detailsDoc['restaurantName'] ?? 'Unknown Restaurant';
          restaurantLat = double.tryParse(detailsDoc['latitude']?.toString() ?? '');
          restaurantLng = double.tryParse(detailsDoc['longitude']?.toString() ?? '');
          cityName = detailsDoc['city'] ?? detailsDoc['locality'] ?? 'Unknown';
          cancellationPolicy = detailsDoc['cancellationPolicy'] ?? 'No policy available';
          fssaiLicenseNumber = detailsDoc['fssaiLicenseNumber'] ?? 'Not provided';
          _averageRating = (detailsDoc['average_rating'] as num?)?.toDouble() ?? 0.0;
          _ratingCount = (detailsDoc['rating_no_count'] as num?)?.toInt() ?? 0;
        });

        QuerySnapshot menuSnapshot = await FirebaseFirestore.instance
            .collection('RestaurantUsers')
            .doc(widget.restaurantId)
            .collection('RestaurantDetails')
            .doc(detailsSnapshot.docs.first.id)
            .collection('MenuItems')
            .get();

        List<Dish> fetchedDishes = menuSnapshot.docs.map((doc) {
          var data = doc.data() as Map<String, dynamic>;
          print('Dish: ${data['name']}, Category: ${data['category']}');
          return Dish(
            name: data['name'] ?? 'Unknown Dish',
            description: data['description'] ?? 'No description available',
            price: double.tryParse(data['price']?.toString() ?? '0') ?? 0.0,
            rating: double.tryParse(data['rating']?.toString() ?? '0') ?? 0.0,
            imageUrl: data['imageUrl'],
            category: data['category'] ?? 'Veg',
            quantity: 0,
          );
        }).toList();

        await _loadCartFromSharedPreferences(fetchedDishes);

        setState(() {
          _dishes = fetchedDishes;
          _isLoading = false;
          print('All fetched dishes: ${_dishes.map((d) => '${d.name}: ${d.category}').toList()}');
        });

        _updateDistanceAndTime();
      } else {
        setState(() {
          restaurantName = 'Restaurant Not Found';
          _averageRating = 0.0;
          _ratingCount = 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error fetching restaurant data: $e');
      setState(() {
        restaurantName = 'Error Loading Restaurant';
        _averageRating = 0.0;
        _ratingCount = 0;
        _isLoading = false;
      });
    }
  }

  Future<void> _loadCartFromSharedPreferences(List<Dish> dishes) async {
    final prefs = await SharedPreferences.getInstance();
    final cartKey = 'cart_${widget.restaurantId}';
    final cartData = prefs.getString(cartKey);
    if (cartData != null) {
      try {
        final List<Map<String, dynamic>> savedCart = (jsonDecode(cartData) as List<dynamic>).cast<Map<String, dynamic>>();
        for (var item in savedCart) {
          final dishName = item['name'] as String;
          final quantity = item['quantity'] as int;
          final dishIndex = dishes.indexWhere((d) => d.name == dishName);
          if (dishIndex != -1) {
            dishes[dishIndex].quantity = quantity;
          }
        }
      } catch (e) {
        print('Error loading cart from SharedPreferences: $e');
      }
    }
  }

  Future<void> _saveCartToSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final cartKey = 'cart_${widget.restaurantId}';
    final cartItems = _dishes
        .where((dish) => dish.quantity > 0)
        .map((dish) => {
      'name': dish.name,
      'price': dish.price,
      'quantity': dish.quantity,
      'category': dish.category,
      'description': dish.description,
      'rating': dish.rating,
      'imageUrl': dish.imageUrl,
    })
        .toList();
    await prefs.setString(cartKey, jsonEncode(cartItems));
    print('Saved cart to SharedPreferences: $cartItems');
  }

  Future<void> _clearCartInSharedPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    final cartKey = 'cart_${widget.restaurantId}';
    await prefs.remove(cartKey);
    print('Cleared cart in SharedPreferences for restaurant ${widget.restaurantId}');
  }

  void _updateDistanceAndTime() {
    if (restaurantLat != null && restaurantLng != null) {
      setState(() {
        distance = _calculateDistance(widget.userLat, widget.userLng, restaurantLat, restaurantLng);
        travelTime = _calculateTravelTime(distance);
      });
    }
  }

  double _calculateDistance(double userLat, double userLng, double? restaurantLat, double? restaurantLng) {
    if (restaurantLat == null || restaurantLng == null) return 0.0;
    return Geolocator.distanceBetween(userLat, userLng, restaurantLat, restaurantLng) / 1000;
  }

  String _calculateTravelTime(double distance) {
    if (distance <= 0) return 'N/A min';
    const double speedKmh = 10.0;
    double timeMinutes = (distance / speedKmh) * 60;
    if (timeMinutes < 1) return '<1 min';
    int roundedTime = timeMinutes.round();
    return '$roundedTime-${(roundedTime + 10).round()} min';
  }

  int get totalItems => _dishes.fold(0, (sum, dish) => sum + dish.quantity);

  double get totalPrice => _dishes.fold(0.0, (sum, dish) => sum + dish.quantity * dish.price);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFDFD),
      appBar: _buildAppBar(),
      body: _buildScrollableContent(),
      bottomNavigationBar: totalItems > 0 && !_isLoading ? _buildCartBottomBar() : null,
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: const Color(0xFFFFFDFD),
      elevation: 0,
      titleSpacing: 0,
      title: _showTitle
          ? Text(
        restaurantName,
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

  Widget _buildScrollableContent() {
    if (_isLoading) {
      return Center(
        child: Lottie.asset(
          'assets/lottie/load animation.json',
          width: 200,
          height: 200,
        ),
      );
    }
    return NotificationListener<ScrollNotification>(
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
            _buildRestaurantHeader(),
            _buildDeliveryDetailsRow(),
            const SizedBox(height: 8),
            _buildSearchBar(),
            _buildFilterRow(),
            _buildMenuItemsSection(),
            const SizedBox(height: 200),
            _buildRestaurantPolicies(),
          ],
        ),
      ),
    );
  }

  Widget _buildRestaurantHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              restaurantName,
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
                  _averageRating > 0 ? _averageRating.toStringAsFixed(1) : 'N/A',
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.white,
                  ),
                ),
                if (_ratingCount > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '($_ratingCount)',
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: Colors.white,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRestaurantPolicies() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(thickness: 1),
          const SizedBox(height: 8),
          Text(
            "Cancellation Policy: $cancellationPolicy",
            style: GoogleFonts.poppins(
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Image.asset('assets/images/fssai_logo.jpg', width: 24, height: 24),
              const SizedBox(width: 8),
              Text(
                "Lic No: $fssaiLicenseNumber",
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeliveryDetailsRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.access_time, size: 14, color: Color(0xFFFF5722)),
                const SizedBox(width: 4),
                Text(
                  travelTime,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    color: Colors.black54,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
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
          Flexible(
            child: Text(
              '${distance.toStringAsFixed(1)} km',
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
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
              cityName,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: Colors.black54,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'Search menu items...',
          hintStyle: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.black38,
          ),
          prefixIcon: const Icon(Icons.search, color: Color(0xFFFF5722)),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear, color: Color(0xFFFF5722)),
            onPressed: () {
              setState(() {
                _searchController.clear();
                _searchQuery = '';
              });
            },
          )
              : null,
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          filled: true,
          fillColor: const Color(0xFFF5F5F5),
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          _buildFilterButton('Veg', 'assets/images/veg.svg'),
          const SizedBox(width: 16),
          _buildFilterButton('Non-Veg', 'assets/images/nonveg.svg'),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String filter, String svgPath) {
    bool isSelected = _selectedFilter == filter;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedFilter = isSelected ? 'All' : filter;
          print('Selected filter: $_selectedFilter');
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFF5722).withOpacity(0.1) : Colors.white,
          border: Border.all(color: isSelected ? const Color(0xFFFF5722) : Colors.grey, width: 1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            SvgPicture.asset(svgPath, width: 20, height: 20),
            const SizedBox(width: 8),
            Text(
              filter,
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: isSelected ? const Color(0xFFFF5722) : Colors.black87,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItemsSection() {
    List<Dish> filteredDishes = _searchQuery.isEmpty
        ? _dishes
        : _dishes.where((dish) {
      final nameLower = dish.name.toLowerCase();
      final descriptionLower = dish.description.toLowerCase();
      return nameLower.contains(_searchQuery) || descriptionLower.contains(_searchQuery);
    }).toList();
    print('After search filter: ${filteredDishes.map((d) => '${d.name}: ${d.category}').toList()}');

    if (_selectedFilter != 'All') {
      filteredDishes = filteredDishes.where((dish) {
        String normalizedCategory = dish.category?.toLowerCase() ?? '';
        bool matches;
        if (_selectedFilter == 'Veg') {
          matches = normalizedCategory.contains('veg') && !normalizedCategory.contains('non-veg');
        } else if (_selectedFilter == 'Non-Veg') {
          matches = normalizedCategory.contains('non-veg');
        } else {
          matches = true;
        }
        print('Dish: ${dish.name}, Category: ${dish.category}, Normalized: $normalizedCategory, Matches: $matches');
        return matches;
      }).toList();
    }
    print('After category filter: ${filteredDishes.map((d) => '${d.name}: ${d.category}').toList()}');

    if (filteredDishes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          _searchQuery.isEmpty && _selectedFilter == 'All'
              ? 'No menu items available'
              : 'No items match your filter or search',
          style: GoogleFonts.poppins(
            color: Colors.grey,
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: List.generate(filteredDishes.length, (index) {
          final dish = filteredDishes[index];
          final originalIndex = _dishes.indexOf(dish);
          return Column(
            children: [
              _buildMenuItem(dish, originalIndex),
              if (index < filteredDishes.length - 1) const Padding(padding: EdgeInsets.symmetric(vertical: 16), child: DottedLine()),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildMenuItem(Dish dish, int index) {
    String truncatedDescription = dish.description.length > 150 ? '${dish.description.substring(0, 150)}...' : dish.description;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 120,
            margin: const EdgeInsets.all(12),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: dish.imageUrl != null && dish.imageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                imageUrl: dish.imageUrl!,
                fit: BoxFit.cover,
                placeholder: (context, url) => Center(
                  child: LoadingAnimationWidget.dotsTriangle(
                    color: const Color(0xFF1A1A3F),
                    size: 50,
                  ),
                ),
                errorWidget: (context, url, error) => const Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
              )
                  : const Icon(Icons.image_not_supported, color: Colors.grey, size: 48),
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
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    truncatedDescription,
                    style: GoogleFonts.poppins(
                      fontSize: 10,
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
                      const SizedBox(width: 5),
                      SvgPicture.asset(
                        (dish.category?.toLowerCase().contains('non-veg') ?? false) ? 'assets/images/nonveg.svg' : 'assets/images/veg.svg',
                        width: 16,
                        height: 16,
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: const Color(0xFFFF5722).withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                        child: Row(
                          children: [
                            const Icon(Icons.star, size: 14, color: Color(0xFFFF5722)),
                            const SizedBox(width: 2),
                            Text(
                              dish.rating.toStringAsFixed(1),
                              style: GoogleFonts.poppins(
                                fontSize: 12,
                                color: Color(0xFFFF5722),
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
        onPressed: () {
          setState(() {
            _dishes[index].quantity = 1;
          });
          _saveCartToSharedPreferences();
        },
        child: Text(
          'Add',
          style: GoogleFonts.poppins(color: Color(0xFFFF5722)),
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
              onTap: () => setState(() => dish.quantity = (dish.quantity - 1).clamp(0, double.infinity).toInt()),
              child: Text(
                '   -   ',
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: Color(0xFFFF5722),
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
                  color: Color(0xFFFF5722),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCartBottomBar() {
    return BottomNavigationBar(
      backgroundColor: const Color(0xFFF5F5F5),
      items: [
        BottomNavigationBarItem(
          icon: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '     $totalItems items selected',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  ),
                  Text(
                    '     Total: ₹${totalPrice.toStringAsFixed(2)}',
                    style: GoogleFonts.poppins(fontSize: 14, color: Colors.black87),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF5722), size: 24),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: Text('Clear Cart', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
                      content: Text('Are you sure you want to remove all items from the cart?', style: GoogleFonts.poppins()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text('Cancel', style: GoogleFonts.poppins()),
                        ),
                        TextButton(
                          onPressed: () async {
                            setState(() => _dishes.forEach((dish) => dish.quantity = 0));
                            await _clearCartInSharedPreferences();
                            if (widget.addToCartCallback != null) {
                              widget.addToCartCallback!(
                                Dish(name: '', price: 0, quantity: 0, description: '', rating: 0,category: ""),
                                widget.restaurantId,
                                restaurantName,
                                travelTime,
                              );
                            }
                            Navigator.pop(context);
                          },
                          child: Text('Clear', style: GoogleFonts.poppins(color: Colors.red)),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
          label: '',
        ),
        BottomNavigationBarItem(
          icon: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF5722),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () async {
              await _saveCartToSharedPreferences();
              if (widget.addToCartCallback != null) {
                for (var dish in _dishes.where((d) => d.quantity > 0)) {
                  widget.addToCartCallback!(
                    Dish(
                      name: dish.name,
                      price: dish.price,
                      quantity: dish.quantity,
                      description: dish.description,
                      rating: dish.rating,
                      imageUrl: dish.imageUrl,
                      category: dish.category,
                    ),
                    widget.restaurantId,
                    restaurantName,
                    travelTime,
                  );
                }
              }
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => CartPage(
                    dishes: _dishes.where((d) => d.quantity > 0).toList(),
                    restaurantId: widget.restaurantId,
                    userLat: widget.userLat,
                    userLng: widget.userLng,
                    travelTime: travelTime,
                    restaurantName: restaurantName,
                  ),
                ),
              );
            },
            child: Text('View Cart', style: GoogleFonts.poppins()),
          ),
          label: '',
        ),
      ],
      showSelectedLabels: false,
      showUnselectedLabels: false,
    );
  }
}

class DottedLine extends StatelessWidget {
  final Color color;
  final double height;
  final double dotWidth;
  final double spacing;

  const DottedLine({super.key, this.color = Colors.grey, this.height = 1.0, this.dotWidth = 4.0, this.spacing = 4.0});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(double.infinity, height), painter: _DottedLinePainter(color: color, dotWidth: dotWidth, spacing: spacing));
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