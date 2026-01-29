import 'package:flutter/material.dart';
import 'finance_screen.dart';
import 'orders_screen.dart';
import 'shipping_companies_screen.dart'; // ✅ 1. استدعاء صفحة الشركات

class HomeLayout extends StatefulWidget {
  const HomeLayout({super.key});

  @override
  State<HomeLayout> createState() => _HomeLayoutState();
}

class _HomeLayoutState extends State<HomeLayout> {
  int _currentIndex = 0;

  // ✅ 2. إضافة الصفحة للقائمة
  final List<Widget> _screens = [
    const FinanceScreen(),
    const OrdersScreen(),
    const ShippingCompaniesScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        backgroundColor: Colors.white,
        elevation: 5,
        indicatorColor: const Color(0xFF1A237E).withOpacity(0.1),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.attach_money),
            selectedIcon: Icon(Icons.attach_money, color: Color(0xFF1A237E)),
            label: "الخزنة",
          ),
          NavigationDestination(
            icon: Icon(Icons.local_shipping_outlined),
            selectedIcon: Icon(Icons.local_shipping, color: Color(0xFF1A237E)),
            label: "الشحنات",
          ),
          // ✅ 3. إضافة زرار الشركات في الشريط السفلي
          NavigationDestination(
            icon: Icon(Icons.business_outlined),
            selectedIcon: Icon(Icons.business, color: Color(0xFF1A237E)),
            label: "الشركات",
          ),
        ],
      ),
    );
  }
}