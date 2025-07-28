import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'pages/production_list_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:animate_do/animate_do.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'pages/add_customer_page.dart';
import 'pages/customer_list_page.dart';
import 'pages/add_sales_page.dart';
import 'pages/sales_history_page.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'pages/expenses_page.dart';
import 'pages/expenses_transaction_page.dart';
import 'pages/expenses_transaction_details_page.dart';
import 'pages/settings_page.dart';
import 'pages/milk_production_page.dart'; // Added import for MilkProductionPage
import 'pages/customer_transaction_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({Key? key}) : super(key: key);

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String username = 'User';
  String userType = 'staff';
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        username = prefs.getString('username') ?? 'User';
        userType = prefs.getString('userType') ?? 'staff';
        isLoading = false;
      });
    } catch (e) {
      setState(() {
        isLoading = false;
      });
    }
  }

  void _handleLogout(BuildContext context) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('username');
      await prefs.remove('userType');
      await FirebaseAuth.instance.signOut();
      
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logged out successfully'),
          ),
        );
        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error logging out: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  String get dynamicGreeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }
    final theme = Theme.of(context);
    final accentColor = Colors.teal.shade700;
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: accentColor,
        elevation: 0.5,
        titleSpacing: 0,
        title: Row(
          children: [
            CircleAvatar(
              radius: 22,
              backgroundColor: Colors.white,
              child: Text(
                username.isNotEmpty ? username[0].toUpperCase() : 'U',
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: accentColor,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Dairy Dashboard',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '$dynamicGreeting, $username',
                  style: GoogleFonts.poppins(
                    fontSize: 13,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.logout, color: Colors.white, size: 22),
            tooltip: 'Logout',
            onPressed: () => _handleLogout(context),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1,
          ),
          itemCount: () {
            final actions = [
              _DashboardAction(
                title: 'Add Production',
                subtitle: 'Record new milk production',
                icon: Icons.add_box,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MilkProductionPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Production',
                subtitle: 'Track milk production for each cow',
                icon: Icons.local_drink,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductionListPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Add Sales',
                subtitle: 'Record new sales transactions',
                icon: Icons.add_shopping_cart,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddSalesPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Sales History',
                subtitle: 'View all sales records',
                icon: Icons.history,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SalesHistoryPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Add Customer',
                subtitle: 'Add and manage your customers',
                icon: Icons.person_add,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddCustomerPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Customer List',
                subtitle: 'View and edit all customers',
                icon: Icons.people,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerListPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Customer Transaction',
                subtitle: 'View customer sales and payments',
                icon: Icons.receipt_long,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerTransactionPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Add Expenses',
                subtitle: 'Track expenses and reasons',
                icon: Icons.account_balance_wallet,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpensesPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Expenses History',
                subtitle: 'View all expenses history',
                icon: Icons.receipt_long,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpensesTransactionPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Expenses Transaction',
                subtitle: 'View vendor-wise expenses',
                icon: Icons.account_balance_wallet,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpensesTransactionDetailsPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Inventory',
                subtitle: 'Manage feed and supplies',
                icon: Icons.inventory_2,
                onTap: () {},
              ),
            ];
            if (userType == 'admin') {
              actions.add(_DashboardAction(
                title: 'Settings',
                subtitle: 'Configure app settings',
                icon: Icons.settings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ));
            }
            return actions.length;
          }(),
          itemBuilder: (context, i) {
            final accentColor = Colors.teal.shade700;
            final actions = <_DashboardAction>[
              _DashboardAction(
                title: 'Add Production',
                subtitle: 'Record new milk production',
                icon: Icons.add_box,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const MilkProductionPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Production',
                subtitle: 'Track milk production for each cow',
                icon: Icons.local_drink,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ProductionListPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Add Sales',
                subtitle: 'Record new sales transactions',
                icon: Icons.add_shopping_cart,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddSalesPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Sales History',
                subtitle: 'View all sales records',
                icon: Icons.history,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SalesHistoryPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Add Customer',
                subtitle: 'Add and manage your customers',
                icon: Icons.person_add,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const AddCustomerPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Customer List',
                subtitle: 'View and edit all customers',
                icon: Icons.people,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerListPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Customer Transaction',
                subtitle: 'View customer sales and payments',
                icon: Icons.receipt_long,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerTransactionPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Add Expenses',
                subtitle: 'Track expenses and reasons',
                icon: Icons.account_balance_wallet,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpensesPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Expenses History',
                subtitle: 'View all expenses history',
                icon: Icons.receipt_long,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpensesTransactionPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Expenses Transaction',
                subtitle: 'View vendor-wise expenses',
                icon: Icons.account_balance_wallet,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const ExpensesTransactionDetailsPage(),
                    ),
                  );
                },
              ),
              _DashboardAction(
                title: 'Inventory',
                subtitle: 'Manage feed and supplies',
                icon: Icons.inventory_2,
                onTap: () {},
              ),
            ];
            if (userType == 'admin') {
              actions.add(_DashboardAction(
                title: 'Settings',
                subtitle: 'Configure app settings',
                icon: Icons.settings,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SettingsPage(),
                    ),
                  );
                },
              ));
            }
            if (i < actions.length) {
              return actions[i].build(context, accentColor);
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }
}

// Simple, classy dashboard card
class _DashboardAction {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _DashboardAction({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  Widget build(BuildContext context, Color accentColor) {
    return AnimatedScale(
      scale: 1.0,
      duration: const Duration(milliseconds: 300),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: AspectRatio(
            aspectRatio: 1,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.grey[200]!, width: 1.2),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: accentColor.withOpacity(0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      icon,
                      size: 30,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: accentColor,
                    ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    subtitle,
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 12.5,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
