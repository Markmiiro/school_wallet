// App entry point. Wraps the app in providers for auth and wallet
// state, applies the design system theme, and hands off routing
// to AppRouter.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/wallet_provider.dart';

void main() {
  runApp(const SchoolWalletApp());
}

class SchoolWalletApp extends StatelessWidget {
  const SchoolWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: MaterialApp.router(
        title: 'School Wallet Uganda',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: AppRouter.router,
      ),
    );
  }
}