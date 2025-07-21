import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:yaammy/screens/home.dart';
import 'package:yaammy/screens/order_tracking.dart';
class OffersWidget extends StatefulWidget {

  @override
  _OffersWidgetState createState() => _OffersWidgetState();
}

class _OffersWidgetState extends State<OffersWidget> {
  int _currentIndex = 2;
  @override
  Widget build(BuildContext context) {
    final Size screenSize = MediaQuery.of(context).size;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 4,
        title: Text(
          'Special Offers',
          style: TextStyle(
            color: Colors.black,
            fontFamily: 'Poppins',
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: screenSize.width,
              height: screenSize.height * 0.22,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: Colors.grey[300],
              ),
              child: Center(
                child: ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.deepOrange,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    child: Text(
                      'Order Now',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Featured Deals',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 10),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                children: [
                  _buildDealCard(title: 'Healthy Meals\n30% off'),
                  _buildDealCard(title: 'Sweet Treats\nBuy 2 Get 1'),
                  _buildDealCard(title: 'Indian Cuisine\n20% off'),
                  _buildDealCard(title: 'Breakfast Deals\nFrom ₹79'),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildBottomNavigationBar(context),
    );
  }

  Widget _buildDealCard({required String title}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            offset: Offset(0, 4),
            blurRadius: 4,
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomNavigationBar(BuildContext context) {
    return BottomNavigationBar(
      backgroundColor:  Colors.white,
      selectedItemColor: Colors.deepOrange,
      unselectedItemColor: Colors.grey,
      currentIndex: _currentIndex,
      onTap: (index) async {
        setState(() => _currentIndex = index);
        switch (index) {
          case 0:
          // Navigate to Home (assuming HomeWidget exists)
            await Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) =>  homepage()), // Replace with your Home page
            );
            break;
          case 2:
          // Already on OrderTrackingWidget, no action needed
            break;
          case 1:
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) =>  OrderTrackingWidget()), // Replace with your Offers page
            );
            setState(() => _currentIndex = 1); // Reset to Orders when returning
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
