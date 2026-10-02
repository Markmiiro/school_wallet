// App entry point. Restores any stored session, wraps the app in
// providers for auth and wallet state, applies the design system theme,
// and hands off routing to AppRouter.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'providers/auth_provider.dart';
import 'providers/wallet_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the stored token before the first frame so a returning parent
  // lands on the dashboard instead of being asked to log in again.
  final authProvider = AuthProvider();
  await authProvider.checkExistingSession();

  runApp(SchoolWalletApp(authProvider: authProvider));
}

class SchoolWalletApp extends StatefulWidget {
  final AuthProvider authProvider;

  const SchoolWalletApp({super.key, required this.authProvider});

  @override
  State<SchoolWalletApp> createState() => _SchoolWalletAppState();
}

class _SchoolWalletAppState extends State<SchoolWalletApp> {
  late final GoRouter _router = AppRouter.create(widget.authProvider);

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
      ],
      child: MaterialApp.router(
        title: 'Nuvora',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
      ),
    );
  }
}
