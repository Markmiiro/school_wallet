// Bottom-navigation shell wrapping the three main tabs:
// Home (dashboard), Transactions, and Profile.

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../profile/screens/profile_screen.dart';
import 'dashboard_screen.dart';
import '../../wallet/screens/transactions_screen.dart';

class MainShell extends StatefulWidget {
  const MainShell({super.key});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  int _index = 0;

  static const int _homeTab = 0;
  static const int _transactionsTab = 1;

  late final List<Widget> _tabs = [
    DashboardScreen(
      onOpenTransactions: () => setState(() => _index = _transactionsTab),
    ),
    TransactionsScreen(onOpenHome: () => setState(() => _index = _homeTab)),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBarTheme(
        data: NavigationBarThemeData(
          backgroundColor: AppColors.navBar,
          surfaceTintColor: Colors.transparent,
          indicatorColor: AppColors.navBarIndicator,
          iconTheme: WidgetStateProperty.resolveWith(
            (states) => IconThemeData(
              // The selected icon sits on the blue pill: navy on blue.
              color: states.contains(WidgetState.selected)
                  ? AppColors.navBarActiveIcon
                  : AppColors.navBarInactive,
            ),
          ),
          labelTextStyle: WidgetStateProperty.resolveWith(
            (states) => AppTheme.bodySm.copyWith(
              // The label is below the pill, on the navy bar.
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.navBarActiveLabel
                  : AppColors.navBarInactive,
            ),
          ),
        ),
        child: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home_rounded),
              label: 'Home',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Transactions',
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline_rounded),
              selectedIcon: Icon(Icons.person_rounded),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
