import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_svg/svg.dart';
import 'package:yaammy/screens/offers.dart';
import 'package:yaammy/screens/home.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:yaammy/screens/delivery_tarcking.dart';
import 'package:intl/intl.dart';
import 'package:lottie/lottie.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: const Color(0xFFFFFFFF),
        fontFamily: 'Poppins',
        primaryColor: Colors.deepOrange,
      ),
      home: const OrderTrackingWidget(),
    );
  }
}

class OrderTrackingWidget extends StatefulWidget {
  const OrderTrackingWidget({Key? key}) : super(key: key);

  @override
  State<OrderTrackingWidget> createState() => _OrderTrackingPageState();
}

class _OrderTrackingPageState extends State<OrderTrackingWidget> with SingleTickerProviderStateMixin {
  int _toggleIndex = 0; // 0 = Ongoing, 1 = Completed
  Map<String, bool> _trackingVisibility = {};
  late AnimationController _animationController;
  late Animation<Color?> _colorAnimation;
  int _currentIndex = 1;
  Map<String, double?> _orderRatings = {}; // Store ratings for orders

  final List<String> _steps = [
    'Order Confirmed',
    'Food Preparation',
    'Out for Delivery',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..repeat(reverse: true);

    _colorAnimation = ColorTween(
      begin: Colors.grey,
      end: Colors.green,
    ).animate(_animationController);

    _fetchRatings();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // Fetch existing ratings for orders
  void _fetchRatings() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final ordersSnapshot = await FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .get();

    for (var doc in ordersSnapshot.docs) {
      final ratingSnapshot = await FirebaseFirestore.instance
          .collection('orders')
          .doc(doc.id)
          .collection('ratings')
          .doc(user.uid)
          .get();
      if (ratingSnapshot.exists) {
        setState(() {
          _orderRatings[doc.id] = ratingSnapshot.data()?['rating']?.toDouble();
        });
      }
    }
  }

  Stream<List<Map<String, dynamic>>> _fetchOrders() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    return FirebaseFirestore.instance
        .collection('orders')
        .where('userId', isEqualTo: user.uid)
        .snapshots()
        .map((querySnapshot) => querySnapshot.docs.map((doc) {
      final data = doc.data();
      data['orderId'] = doc.id;
      return data;
    }).toList());
  }

  // Function to submit a rating
  Future<void> _submitRating(String orderId, String restaurantName, double rating) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      // Store rating in orders collection
      await FirebaseFirestore.instance
          .collection('orders')
          .doc(orderId)
          .collection('ratings')
          .doc(user.uid)
          .set({
        'rating': rating,
        'restaurantName': restaurantName,
        'userId': user.uid,
        'timestamp': Timestamp.now(),
      });

      // Assume restaurantId is available in order data; otherwise, query by restaurantName
      final orderDoc = await FirebaseFirestore.instance.collection('orders').doc(orderId).get();
      final restaurantId = orderDoc.data()?['restaurantId'] as String? ?? restaurantName; // Fallback to restaurantName if restaurantId is unavailable

      // Update RestaurantDetails in RestaurantUsers collection
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        // Assume RestaurantUsersid and RestaurantDetailsid are the same as restaurantId for simplicity
        // Adjust this based on your actual Firestore structure
        final restaurantDetailsRef = FirebaseFirestore.instance
            .collection('RestaurantUsers')
            .doc(restaurantId)
            .collection('RestaurantDetails')
            .doc(restaurantId);

        final restaurantDetailsSnapshot = await transaction.get(restaurantDetailsRef);

        double newAverageRating;
        int newRatingCount;

        if (!restaurantDetailsSnapshot.exists) {
          // Initialize if document doesn't exist
          newAverageRating = rating;
          newRatingCount = 1;
          transaction.set(restaurantDetailsRef, {
            'average_rating': newAverageRating,
            'rating_no_count': newRatingCount,
            'restaurantName': restaurantName,
            'last_updated': Timestamp.now(),
          });
        } else {
          // Update existing document
          final currentData = restaurantDetailsSnapshot.data()!;
          final currentAverageRating = (currentData['average_rating'] as num?)?.toDouble() ?? 0.0;
          final currentRatingCount = (currentData['rating_no_count'] as num?)?.toInt() ?? 0;

          // Calculate new average rating
          newRatingCount = currentRatingCount + 1;
          newAverageRating = ((currentAverageRating * currentRatingCount) + rating) / newRatingCount;

          transaction.update(restaurantDetailsRef, {
            'average_rating': newAverageRating,
            'rating_no_count': newRatingCount,
            'last_updated': Timestamp.now(),
          });
        }
      });

      setState(() {
        _orderRatings[orderId] = rating;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.green,
          content: Row(
            children: [
              Icon(Icons.star, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Rating submitted successfully!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.red,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to submit rating: ${e.toString()}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  // Function to cancel an order
  Future<void> _cancelOrder(String orderId) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).update({
        'status': 'cancelled',
        'cancelledTime': Timestamp.now(),
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.deepOrange,
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Order cancelled successfully!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          backgroundColor: Colors.red,
          content: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.white),
              SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Failed to cancel order: ${e.toString()}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          duration: Duration(seconds: 3),
          action: SnackBarAction(
            label: 'DISMISS',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFFFF),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFAF7F7),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0.0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Order Tracking',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildSegmentedToggle(),
          ),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _fetchOrders(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return Center(
                    child: Lottie.asset(
                      'assets/lottie/load animation.json', // Path to your Lottie animation
                      width: 150, // Adjust size as needed
                      height: 150,
                      fit: BoxFit.contain,
                    ),
                  );;
                }

                if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Lottie.asset(
                          'assets/lottie/no orders.json',
                          width: 200,
                          height: 200,
                          fit: BoxFit.contain,
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'No orders found!',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Please log in or place an order to see your tracking.',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: Colors.grey,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                final orders = snapshot.data!;
                final ongoingOrders = orders
                    .where((order) => (order['status'] ?? 'placed').toLowerCase() != 'delivered' && (order['status'] ?? 'placed').toLowerCase() != 'cancelled')
                    .toList();
                final completedOrders = orders
                    .where((order) => (order['status'] ?? 'placed').toLowerCase() == 'delivered' || (order['status'] ?? 'placed').toLowerCase() == 'cancelled')
                    .toList();

                return ListView(
                  children: [
                    if (_toggleIndex == 0) ...[
                      if (ongoingOrders.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildOrderSection('Ongoing Orders', ongoingOrders),
                        )
                      else
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Lottie.asset(
                                'assets/lottie/no orders.json',
                                width: 200,
                                height: 200,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(height: 20),
                              const Text(
                                'No ongoing orders!',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 10),
                              const Text(
                                'Check back later or place a new order.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                    if (_toggleIndex == 1) ...[
                      if (completedOrders.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16.0),
                          child: _buildOrderSection('Completed Orders', completedOrders),
                        )
                      else
                        const Padding(
                          padding: EdgeInsets.all(16.0),
                          child: Text(
                            'No completed orders',
                            style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                          ),
                        ),
                    ],
                  ],
                );
              },
            ),
          ),
        ],
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildSegmentedToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _toggleIndex = 0),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _toggleIndex == 0 ? Colors.white : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(8.0),
                    bottomLeft: Radius.circular(8.0),
                  ),
                  boxShadow: _toggleIndex == 0
                      ? [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                      : [],
                ),
                child: Text(
                  'Ongoing',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: _toggleIndex == 0 ? Colors.deepOrange : Colors.grey[700],
                    fontWeight: _toggleIndex == 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: InkWell(
              onTap: () => setState(() => _toggleIndex = 1),
              child: Container(
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: _toggleIndex == 1 ? Colors.white : Colors.transparent,
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(8.0),
                    bottomRight: Radius.circular(8.0),
                  ),
                  boxShadow: _toggleIndex == 1
                      ? [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ]
                      : [],
                ),
                child: Text(
                  'Completed',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: _toggleIndex == 1 ? Colors.deepOrange : Colors.grey[700],
                    fontWeight: _toggleIndex == 1 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderSection(String title, List<Map<String, dynamic>> orders) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 8),
        ...orders.map((order) => _buildOrderCard(order)).toList(),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order) {
    final String orderId = order['orderId'] ?? 'Unknown';
    final String paymentId = order['paymentId'] ?? 'Unknown';
    final String paymentMethod = order['paymentMethod'] ?? 'Unknown';
    final String restaurantName = order['restaurantName'] ?? 'Unknown';
    final List<dynamic> dishes = order['dishes'] ?? [];
    final double totalBill = order['totalBill']?.toDouble() ?? 0.0;
    final Timestamp? timestamp = order['timestamp'];
    final String orderDateTime = timestamp != null
        ? '${timestamp.toDate().day}/${timestamp.toDate().month}/${timestamp.toDate().year} '
        '${timestamp.toDate().hour > 12 ? timestamp.toDate().hour - 12 : timestamp.toDate().hour == 0 ? 12 : timestamp.toDate().hour}'
        ':${timestamp.toDate().minute.toString().padLeft(2, '0')} '
        '${timestamp.toDate().hour >= 12 ? 'P.M.' : 'A.M.'}'
        : 'Unknown Date';
    final String status = order['status'] ?? 'placed';
    final bool isCompleted = status.toLowerCase() == 'delivered' || status.toLowerCase() == 'cancelled';
    final bool canCancel = status.toLowerCase() != 'picked' && status.toLowerCase() != 'pickup' && status.toLowerCase() != 'delivered' && status.toLowerCase() != 'cancelled';
    final String? travelTimeRaw = order['travelTime'] ?? '30';
    final int? travelTimeMinutes = _parseTravelTime(travelTimeRaw);
    final dynamic pickupTimeRaw = order['pickupTime'];
    final DateTime? pickupTime = pickupTimeRaw is Timestamp
        ? pickupTimeRaw.toDate()
        : (pickupTimeRaw is String ? _parsePickupTime(pickupTimeRaw) : null);
    final Timestamp? acceptedTime = order['acceptedTime'];
    final Timestamp? readyTime = order['readyTime'];
    final Timestamp? deliveredTime = order['delivered'];
    final double? userRating = _orderRatings[orderId];

    final int currentStep;
    switch (status.toLowerCase()) {
      case 'placed':
        currentStep = -1;
        break;
      case 'accepted':
        currentStep = 0;
        break;
      case 'ready':
        currentStep = 1;
        break;
      case 'picked':
      case 'pickup':
        currentStep = 2;
        break;
      case 'delivered':
      case 'cancelled':
        currentStep = 3;
        break;
      default:
        currentStep = -1;
    }

    if (isCompleted) {
      _trackingVisibility.putIfAbsent(orderId, () => false);
    }

    String? estimatedDeliveryTime;
    if (pickupTime != null && currentStep == 2) {
      final estimatedDelivery = pickupTime.add(Duration(minutes: travelTimeMinutes ?? 30));
      final hour = estimatedDelivery.hour > 12 ? estimatedDelivery.hour - 12 : estimatedDelivery.hour == 0 ? 12 : estimatedDelivery.hour;
      final period = estimatedDelivery.hour >= 12 ? 'P.M.' : 'A.M.';
      estimatedDeliveryTime = '$hour:${estimatedDelivery.minute.toString().padLeft(2, '0')} $period (Est.)';
    }

    return GestureDetector(
      onTap: isCompleted
          ? () {
        setState(() {
          _trackingVisibility[orderId] = !_trackingVisibility[orderId]!;
        });
      }
          : null,
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          color: const Color(0xFFF7F7F7),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
          borderRadius: BorderRadius.circular(8.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order ID #$orderId',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontWeight: FontWeight.bold,
                    fontSize: Theme.of(context).textTheme.titleMedium?.fontSize,
                  ),
                ),
                Row(
                  children: [
                    if (isCompleted && status.toLowerCase() == 'delivered')
                      GestureDetector(
                        onTap: () => _showRatingDialog(orderId, restaurantName, userRating),
                        child: Row(
                          children: [
                            Icon(
                              Icons.star,
                              color: userRating != null ? Colors.yellow[700] : Colors.grey,
                              size: 20,
                            ),
                            SizedBox(width: 4),
                            Text(
                              userRating != null ? userRating.toStringAsFixed(1) : 'Rate',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 12,
                                color: userRating != null ? Colors.black87 : Colors.grey,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    SizedBox(width: 8),
                    if (isCompleted)
                      Icon(
                        _trackingVisibility[orderId]! ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                        color: Colors.grey[700],
                      ),
                    if (!isCompleted)
                      GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DeliveryTrackingPage(
                                orderId: orderId,
                                orderData: order,
                              ),
                            ),
                          );
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: Colors.deepOrange),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.directions_bike_outlined, size: 16, color: Colors.deepOrange),
                              const SizedBox(width: 4),
                              const Text(
                                'Track Delivery Partner',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text('$restaurantName • ${dishes.length} item${dishes.length != 1 ? 's' : ''}'),
            const SizedBox(height: 8),
            Text('Payment ID: $paymentId'),
            const SizedBox(height: 8),
            Text('Payment Method: $paymentMethod'),
            const SizedBox(height: 8),
            Text('Order Date: $orderDateTime'),
            const SizedBox(height: 8),
            if (isCompleted && status.toLowerCase() == 'cancelled')
              const Text(
                'Status: Cancelled',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  color: Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
            const SizedBox(height: 8),
            const Text('Dishes:', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            ...dishes.asMap().entries.map((entry) {
              final int index = entry.key + 1;
              final Map<String, dynamic> dish = entry.value;
              final String name = dish['name'] ?? 'Unknown';
              final double price = dish['price']?.toDouble() ?? 0.0;
              final int? quantity = dish['quantity'];
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0),
                child: Text('$index. $name - ₹${price.toStringAsFixed(2)} x ${quantity ?? 0}'),
              );
            }).toList(),
            const SizedBox(height: 8),
            Text(
              'Total Amount: ₹${totalBill.toStringAsFixed(2)}',
              style: const TextStyle(
                color: Colors.deepOrange,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (!isCompleted && canCancel)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => Dialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Cancel Order',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Are you sure you want to cancel this order?',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.grey[700],
                                ),
                                textAlign: TextAlign.center,
                              ),
                              SizedBox(height: 24),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                        side: BorderSide(color: Colors.grey[400]!),
                                      ),
                                    ),
                                    child: Text(
                                      'No',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      _cancelOrder(orderId);
                                      Navigator.pop(context);
                                    },
                                    style: TextButton.styleFrom(
                                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                                      backgroundColor: Colors.red[400],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      'Yes, Cancel',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 14,
                                        color: Colors.white,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.red),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.cancel_outlined, size: 18, color: Colors.red),
                      SizedBox(width: 8),
                      Text(
                        'Cancel Order',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.red,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),
            if (!isCompleted || (isCompleted && _trackingVisibility[orderId]!))
              Column(
                children: [
                  _buildTimelineStep(
                    title: _steps[0],
                    isActive: currentStep >= 0,
                    isLast: false,
                    currentStep: currentStep,
                    stepIndex: 0,
                    timestamp: acceptedTime,
                  ),
                  _buildTimelineStep(
                    title: _steps[1],
                    isActive: currentStep >= 1,
                    isLast: false,
                    currentStep: currentStep,
                    stepIndex: 1,
                    timestamp: readyTime,
                  ),
                  _buildTimelineStep(
                    title: _steps[2],
                    isActive: currentStep >= 2,
                    isLast: false,
                    currentStep: currentStep,
                    stepIndex: 2,
                    timestamp: _convertToTimestamp(pickupTime),
                  ),
                  _buildTimelineStep(
                    title: _steps[3],
                    isActive: currentStep >= 3,
                    isLast: true,
                    currentStep: currentStep,
                    stepIndex: 3,
                    timestamp: deliveredTime,
                    pickupTime: pickupTime,
                    travelTimeMinutes: travelTimeMinutes,
                    estimatedDeliveryTime: estimatedDeliveryTime,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _showRatingDialog(String orderId, String restaurantName, double? currentRating) {
    double selectedRating = currentRating ?? 0.0;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Rate $restaurantName',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 16),
              Text(
                'How would you rate your experience?',
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.grey[700],
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 24),
              StatefulBuilder(
                builder: (context, setState) => Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(5, (index) {
                    final starValue = index + 1;
                    return IconButton(
                      onPressed: () {
                        setState(() {
                          selectedRating = starValue.toDouble();
                        });
                      },
                      icon: Icon(
                        starValue <= selectedRating ? Icons.star : Icons.star_border,
                        color: Colors.yellow[700],
                        size: 30,
                      ),
                    );
                  }),
                ),
              ),
              SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                        side: BorderSide(color: Colors.grey[400]!),
                      ),
                    ),
                    child: Text(
                      'Cancel',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: selectedRating > 0
                        ? () {
                      _submitRating(orderId, restaurantName, selectedRating);
                      Navigator.pop(context);
                    }
                        : null,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      backgroundColor: selectedRating > 0 ? Colors.deepOrange : Colors.grey,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(
                      'Submit',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  int? _parseTravelTime(String? travelTime) {
    if (travelTime == null) return 30;
    final match = RegExp(r'(\d+)-(\d+)').firstMatch(travelTime);
    if (match != null) {
      final min = int.tryParse(match.group(1) ?? '0') ?? 0;
      final max = int.tryParse(match.group(2) ?? '0') ?? 0;
      return (min + max) ~/ 2;
    }
    return 30;
  }

  DateTime? _parsePickupTime(String? pickupTime) {
    if (pickupTime == null) return null;
    try {
      final format = DateFormat("dd MMMM yyyy 'at' HH:mm:ss 'UTC'Z", 'en_US');
      return format.parse(pickupTime, true);
    } catch (e) {
      print('Error parsing pickupTime: $e');
      return null;
    }
  }

  Timestamp? _convertToTimestamp(DateTime? dateTime) {
    return dateTime != null ? Timestamp.fromDate(dateTime) : null;
  }

  Widget _buildTimelineStep({
    required String title,
    required bool isActive,
    required bool isLast,
    required int currentStep,
    required int stepIndex,
    required Timestamp? timestamp,
    DateTime? pickupTime,
    int? travelTimeMinutes,
    String? estimatedDeliveryTime,
  }) {
    Color stepColor = isActive ? Colors.green : Colors.grey;

    String? timeString;
    if (estimatedDeliveryTime != null && stepIndex == 3 && currentStep == 2) {
      timeString = estimatedDeliveryTime;
    } else if (isActive && timestamp != null) {
      final dateTime = timestamp.toDate();
      final hour = dateTime.hour > 12 ? dateTime.hour - 12 : dateTime.hour == 0 ? 12 : dateTime.hour;
      final period = dateTime.hour >= 12 ? 'P.M.' : 'A.M.';
      timeString = '$hour:${dateTime.minute.toString().padLeft(2, '0')} $period';
    } else if (isActive && stepIndex == 3 && pickupTime != null && travelTimeMinutes != null && currentStep == 2) {
      final estimatedDelivery = pickupTime.add(Duration(minutes: travelTimeMinutes));
      final hour = estimatedDelivery.hour > 12 ? estimatedDelivery.hour - 12 : estimatedDelivery.hour == 0 ? 12 : estimatedDelivery.hour;
      final period = estimatedDelivery.hour >= 12 ? 'P.M.' : 'A.M.';
      timeString = '$hour:${estimatedDelivery.minute.toString().padLeft(2, '0')} $period (Est.)';
    } else if (isActive) {
      timeString = 'Pending';
    }

    Color lineColor;
    if (stepIndex < currentStep) {
      lineColor = Colors.green;
    } else if (stepIndex == currentStep && timestamp != null) {
      lineColor = Colors.green;
    } else if (stepIndex == currentStep + 1 && !isLast && currentStep >= -1) {
      return AnimatedBuilder(
        animation: _colorAnimation,
        builder: (context, child) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: stepColor,
                    ),
                    child: const Center(
                      child: Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                  if (!isLast)
                    Container(
                      width: 2,
                      height: 40,
                      color: _colorAnimation.value,
                    ),
                ],
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          color: Colors.black87,
                          fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      if (timeString != null)
                        Text(
                          timeString,
                          style: const TextStyle(
                            fontFamily: 'Poppins',
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      );
    } else {
      lineColor = Colors.grey;
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: stepColor,
              ),
              child: const Center(
                child: Icon(
                  Icons.check,
                  color: Colors.white,
                  size: 16,
                ),
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 40,
                color: lineColor,
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: Colors.black87,
                    fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
                if (timeString != null)
                  Text(
                    timeString,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor: Colors.white,
      selectedItemColor: Colors.deepOrange,
      unselectedItemColor: Colors.grey,
      currentIndex: _currentIndex,
      onTap: (index) async {
        setState(() => _currentIndex = index);
        switch (index) {
          case 0:
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => homepage()),
            );
            break;
          case 1:
            break;
          case 2:
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => OffersWidget()),
            );
            setState(() => _currentIndex = 1);
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