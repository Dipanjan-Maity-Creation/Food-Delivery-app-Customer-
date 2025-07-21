import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:intl/intl.dart';

class DeliveryTrackingPage extends StatefulWidget {
  const DeliveryTrackingPage({Key? key, required this.orderId, required this.orderData}) : super(key: key);

  final String orderId;
  final Map<String, dynamic> orderData;

  @override
  _DeliveryTrackingPageState createState() => _DeliveryTrackingPageState();
}

class _DeliveryTrackingPageState extends State<DeliveryTrackingPage> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _bikeAnimation;
  bool _animationCompleted = false;
  Timestamp? _animationStartTime;

  late Future<int> _travelTimeFuture;
  late Future<double> _bikeProgressFuture;

  Map<String, bool> _trackingVisibility = {};
  final List<String> _steps = [
    'Order Confirmed',
    'Food Preparation',
    'Out for Delivery',
    'Delivered',
  ];

  @override
  void initState() {
    super.initState();
    print('initState called with orderId: ${widget.orderId}');
    _travelTimeFuture = _fetchTravelTime();
    _bikeProgressFuture = _fetchBikeProgress();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // Placeholder
    );

    _bikeAnimation = Tween<double>(
      begin: 1.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.linear,
    ));

    _animationController.addListener(() {
      if (_animationController.isAnimating) {
        _saveBikeProgress(_bikeAnimation.value);
        setState(() {}); // Update countdown
      }
    });

    _animationController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _animationController.stop();
        _animationCompleted = true;
        _saveBikeProgress(0.0);
        setState(() {});
        print('Animation completed at ${DateTime.now()}');
      }
    });

    _animationController.stop();
    _animationController.reset();
  }

  Future<int> _fetchTravelTime() async {
    try {
      print('Fetching travelTime for orderId: ${widget.orderId}');
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (!doc.exists) {
        print('Document does not exist for orderId: ${widget.orderId}');
        return 30;
      }

      String? travelTime = doc['travelTime'];
      print('Raw travelTime from Firestore: $travelTime');
      return _parseTravelTime(travelTime);
    } catch (e) {
      print('Error fetching travelTime: $e');
      return 30;
    }
  }

  int _parseTravelTime(String? travelTime) {
    if (travelTime == null) {
      print('travelTime is null, using default: 30 minutes');
      return 30;
    }
    final match = RegExp(r'(\d+)-(\d+)').firstMatch(travelTime);
    if (match != null) {
      final max = int.tryParse(match.group(2) ?? '0') ?? 30;
      print('Parsed travelTime: $travelTime -> Max: $max minutes');
      return max;
    }
    print('Failed to parse travelTime: $travelTime, using default: 30 minutes');
    return 30;
  }

  Future<double> _fetchBikeProgress() async {
    try {
      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('orders')
          .doc(widget.orderId)
          .get();

      if (doc.exists && doc['bikeProgress'] != null) {
        final progress = doc['bikeProgress'] as double;
        _animationStartTime = doc['animationStartTime'] as Timestamp?;
        print('Fetched bikeProgress: $progress, startTime: ${_animationStartTime?.toDate()}');
        return progress;
      }
      print('No bikeProgress found, defaulting to 1.0');
      return 1.0;
    } catch (e) {
      print('Error fetching bikeProgress: $e');
      return 1.0;
    }
  }

  void _saveBikeProgress(double value) async {
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.orderId).update({
        'bikeProgress': value,
        'animationStartTime': _animationStartTime ?? Timestamp.now(),
      });
      print('Saved bikeProgress: $value at ${DateTime.now()}');
    } catch (e) {
      print('Error saving bikeProgress: $e');
    }
  }

  String _getRemainingTime(int travelTimeMinutes) {
    if (_animationCompleted || _animationController.duration == null) {
      return "Delivery in: 0 min 0 sec";
    }

    final totalSeconds = travelTimeMinutes * 60;
    final elapsedSeconds = _animationStartTime != null
        ? DateTime.now().difference(_animationStartTime!.toDate()).inSeconds
        : 0;
    final remainingSeconds = (totalSeconds - elapsedSeconds).clamp(0, totalSeconds);

    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return "Delivery in: $minutes min $seconds sec";
  }

  @override
  void dispose() {
    if (_animationController.isAnimating) {
      _saveBikeProgress(_bikeAnimation.value);
    }
    _animationController.dispose();
    super.dispose();
  }

  DateTime? _parsePickupTime(dynamic pickupTimeRaw) {
    if (pickupTimeRaw == null) return null;
    if (pickupTimeRaw is Timestamp) {
      return pickupTimeRaw.toDate();
    } else if (pickupTimeRaw is String) {
      try {
        final format = DateFormat("dd MMMM yyyy 'at' HH:mm:ss 'UTC'Z", 'en_US');
        return format.parse(pickupTimeRaw, true);
      } catch (e) {
        print('Error parsing pickupTime: $e');
        return null;
      }
    }
    return null;
  }

  Timestamp? _convertToTimestamp(DateTime? dateTime) {
    return dateTime != null ? Timestamp.fromDate(dateTime) : null;
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
    final bool isCompleted = status.toLowerCase() == 'delivered';
    final String? travelTimeRaw = order['travelTime'] ?? '30';
    final int? travelTimeMinutes = _parseTravelTime(travelTimeRaw);
    final dynamic pickupTimeRaw = order['pickupTime'];
    final DateTime? pickupTime = _parsePickupTime(pickupTimeRaw);
    final Timestamp? acceptedTime = order['acceptedTime'];
    final Timestamp? readyTime = order['readyTime'];
    final Timestamp? deliveredTime = order['delivered'];

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
        currentStep = 3;
        break;
      default:
        currentStep = -1;
    }

    if (isCompleted) {
      _trackingVisibility.putIfAbsent(orderId, () => false);
    }

    String? estimatedDeliveryTime;
    if (pickupTime != null && currentStep >= 2) {
      final estimatedDelivery = pickupTime.add(Duration(minutes: travelTimeMinutes ?? 30));
      final hour = estimatedDelivery.hour > 12 ? estimatedDelivery.hour - 12 : estimatedDelivery.hour == 0 ? 12 : estimatedDelivery.hour;
      final period = estimatedDelivery.hour >= 12 ? 'P.M.' : 'A.M.';
      estimatedDeliveryTime = '$hour:${estimatedDelivery.minute.toString().padLeft(2, '0')} $period (Est.)';
    }

    if (currentStep >= 2 && !_animationController.isAnimating && !_animationCompleted) {
      if (_animationStartTime == null) {
        _animationStartTime = Timestamp.now();
      }
      print('Starting/resuming animation, Duration: ${_animationController.duration!.inMinutes} minutes');
      _animationController.forward(from: _bikeAnimation.value);
      print('Animation started - CurrentStep: $currentStep, Start Time: ${_animationStartTime?.toDate()}');
    } else if (currentStep < 2) {
      _animationController.stop();
      _animationController.reset();
      _animationCompleted = false;
      _saveBikeProgress(1.0);
      _animationStartTime = null;
      print('Animation stopped and reset - CurrentStep: $currentStep');
    } else if (currentStep >= 3 && !_animationCompleted) {
      _animationController.value = 0.0;
      _animationCompleted = true;
      _saveBikeProgress(0.0);
      _animationStartTime = null;
      print('Order delivered - Animation set to end at ${DateTime.now()}');
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
                if (isCompleted)
                  Icon(
                    _trackingVisibility[orderId]! ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    color: Colors.grey[700],
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
                    estimatedDeliveryTime: estimatedDeliveryTime,
                  ),
                  _buildTimelineStep(
                    title: _steps[3],
                    isActive: currentStep >= 3,
                    isLast: true,
                    currentStep: currentStep,
                    stepIndex: 3,
                    timestamp: deliveredTime,
                    estimatedDeliveryTime: estimatedDeliveryTime,
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required bool isActive,
    required bool isLast,
    required int currentStep,
    required int stepIndex,
    required Timestamp? timestamp,
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
    } else if (isActive) {
      timeString = 'Pending';
    }

    Color lineColor;
    if (stepIndex < currentStep) {
      lineColor = Colors.green;
    } else if (stepIndex == currentStep && timestamp != null) {
      lineColor = Colors.green;
    } else if (stepIndex == currentStep + 1 && !isLast && currentStep >= -1) {
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
                  color: Colors.grey,
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

  @override
  Widget build(BuildContext context) {
    const double containerWidth = 261.66;
    const double containerHeight = 304;
    const double trackLineWidth = 213.65768432617188;
    const double trackLineHeight = 267.5;
    const double markerSize = 17.65768814086914;
    const double locationSize = 62;

    final spinkit = SpinKitRipple(
      color: Colors.black,
      size: 450,
      controller: _animationController,
    );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFFF5F5F5),
        elevation: 0,
        centerTitle: false,
        titleSpacing: 0.0,
        iconTheme: const IconThemeData(color: Colors.black87),
        title: const Text(
          'Track Delivery Partner',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: Colors.black87,
          ),
        ),
      ),
      body: FutureBuilder<int>(
        future: _travelTimeFuture,
        builder: (context, travelSnapshot) {
          if (travelSnapshot.connectionState == ConnectionState.waiting) {
            print('Waiting for travelTime fetch...');
            return const Center(child: CircularProgressIndicator());
          }

          final int travelTimeMinutes = travelSnapshot.hasError || !travelSnapshot.hasData
              ? 30
              : travelSnapshot.data!;
          if (travelSnapshot.hasError) {
            print('Error in travelTime FutureBuilder: ${travelSnapshot.error}');
          } else {
            print('TravelTime FutureBuilder completed: Duration set to $travelTimeMinutes minutes');
            _animationController.duration = Duration(minutes: travelTimeMinutes);
          }

          return FutureBuilder<double>(
            future: _bikeProgressFuture,
            builder: (context, progressSnapshot) {
              if (progressSnapshot.connectionState == ConnectionState.waiting) {
                print('Waiting for bikeProgress fetch...');
                return const Center(child: CircularProgressIndicator());
              }

              if (progressSnapshot.hasError) {
                print('Error in bikeProgress FutureBuilder: ${progressSnapshot.error}');
                _bikeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
              } else if (progressSnapshot.hasData) {
                double startValue = progressSnapshot.data!;
                if (_animationStartTime != null && startValue > 0.0) {
                  final elapsed = DateTime.now().difference(_animationStartTime!.toDate());
                  final totalDuration = _animationController.duration!.inMilliseconds;
                  final progressMade = elapsed.inMilliseconds / totalDuration;
                  startValue = (1.0 - progressMade).clamp(0.0, 1.0);
                  print('Adjusted startValue based on elapsed time: $startValue');
                }
                _bikeAnimation = Tween<double>(begin: startValue, end: 0.0).animate(_animationController);
                print('BikeProgress FutureBuilder completed: Starting from $startValue');
              } else {
                _bikeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(_animationController);
                print('No bikeProgress data, starting from 1.0');
              }

              final order = {...widget.orderData, 'orderId': widget.orderId};
              final ongoingOrders = [order].where((o) => (o['status'] ?? 'placed').toLowerCase() != 'delivered').toList();

              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const SizedBox(height: 20),
                      Container(
                        width: containerWidth,
                        height: containerHeight,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: <Widget>[
                            Positioned(
                              top: 0,
                              left: 48,
                              child: Container(
                                width: trackLineWidth,
                                height: trackLineHeight,
                                child: Stack(
                                  clipBehavior: Clip.none,
                                  children: <Widget>[
                                    Positioned(
                                      top: 12,
                                      left: 0,
                                      child: CustomPaint(
                                        size: Size(trackLineWidth, trackLineHeight - 12),
                                        painter: TracklinePainter(),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      left: 200,
                                      child: Container(
                                        width: markerSize,
                                        height: markerSize,
                                        decoration: BoxDecoration(
                                          color: Color.fromRGBO(255, 255, 255, 1),
                                          border: Border.all(
                                            color: Color.fromRGBO(255, 184, 0, 1),
                                            width: 4,
                                          ),
                                          borderRadius: BorderRadius.all(Radius.elliptical(17.65768814086914, 17.65768814086914)),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 225,
                                      left: 190,
                                      child: Container(
                                        width: 40,
                                        height: 60,
                                        child: Center(child: spinkit),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            AnimatedBuilder(
                              animation: _bikeAnimation,
                              builder: (context, child) {
                                final path = TracklinePainter().createPath(Size(trackLineWidth, trackLineHeight - 12));
                                final pathMetric = path.computeMetrics().first;
                                final offset = pathMetric.getTangentForOffset(
                                  pathMetric.length * _bikeAnimation.value,
                                )!.position;

                                return Positioned(
                                  left: 48 + offset.dx - locationSize / 2,
                                  top: 12 + offset.dy - locationSize / 2,
                                  child: Container(
                                    width: locationSize,
                                    height: locationSize,
                                    child: const Center(
                                      child: Icon(
                                        Icons.directions_bike_outlined,
                                        color: Colors.deepOrange,
                                        size: 60,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Delivery Partner is on the way',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 16,
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _getRemainingTime(travelTimeMinutes),
                        style: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 20),
                      if (ongoingOrders.isNotEmpty)
                        _buildOrderSection('Order Details', ongoingOrders)
                      else
                        const Text(
                          'No ongoing orders',
                          style: TextStyle(fontFamily: 'Poppins', fontSize: 16),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class TracklinePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..shader = const LinearGradient(
        colors: [Color(0xFFA9CBA4), Color(0xFF2E7D32)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(10, 52, size.width, size.height));

    final path = createPath(size);
    canvas.drawPath(path, paint);
  }

  Path createPath(Size size) {
    final path = Path();
    path.moveTo(size.width / 1, 0.99);

    path.lineTo(size.width * 0.4, size.height * 0.1);
    path.quadraticBezierTo(size.width * 0.3, size.height * 0.2, size.width * 0.5, size.height * 0.3);
    path.quadraticBezierTo(size.width * 0.7, size.height * 0.4, size.width * 0.6, size.height * 0.5);
    path.quadraticBezierTo(size.width * 0.4, size.height * 0.6, size.width * 0.5, size.height * 0.7);
    path.quadraticBezierTo(size.width * 0.6, size.height * 0.8, size.width * 0.4, size.height * 0.9);
    path.lineTo(size.width / 12, size.height);

    return path;
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}