// App entry point. Restores any stored session, wraps the app in
// providers for auth, wallet, balance privacy and the app lock, applies
// the design system theme, and hands off routing to AppRouter. LockGate
// sits over the router so a lock keeps the parent's place.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'core/device_prefs.dart';
import 'core/theme/app_theme.dart';
import 'core/routing/app_router.dart';
import 'data/services/auth_service.dart';
import 'features/lock/lock_gate.dart';
import 'providers/app_lock.dart';
import 'providers/auth_provider.dart';
import 'providers/balance_privacy.dart';
import 'providers/wallet_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Read the stored token before the first frame so a returning parent
  // lands on the dashboard instead of being asked to log in again.
  final authProvider = AuthProvider();
  await authProvider.checkExistingSession();

  final prefs = SecureDevicePrefs();
  final privacy = BalancePrivacy(prefs);
  await privacy.load();

  // A restored session opens locked if the app was away more than
  // 5 minutes, so the balance is never on screen before the PIN.
  final lock = AppLock(prefs, verifyPin: AuthService().unlock);
  await lock.start(loggedIn: authProvider.isLoggedIn);
  lock.startHeartbeat();

  runApp(SchoolWalletApp(
    authProvider: authProvider,
    privacy: privacy,
    lock: lock,
  ));
}

class SchoolWalletApp extends StatefulWidget {
  final AuthProvider authProvider;
  final BalancePrivacy privacy;
  final AppLock lock;

  const SchoolWalletApp({
    super.key,
    required this.authProvider,
    required this.privacy,
    required this.lock,
  });

  @override
  State<SchoolWalletApp> createState() => _SchoolWalletAppState();
}

class _SchoolWalletAppState extends State<SchoolWalletApp> {
  late final GoRouter _router = AppRouter.create(widget.authProvider);
  late bool _wasLoggedIn = widget.authProvider.isLoggedIn;

  @override
  void initState() {
    super.initState();
    widget.authProvider.addListener(_authChanged);
  }

  // A full sign-in needs no further unlock; signing out (or a session
  // ending) clears the lock so the login screen is not hidden behind it.
  void _authChanged() {
    final now = widget.authProvider.isLoggedIn;
    if (now && !_wasLoggedIn) widget.lock.unlockedBySignIn();
    if (!now && _wasLoggedIn) widget.lock.signedOut();
    _wasLoggedIn = now;
  }

  @override
  void dispose() {
    widget.authProvider.removeListener(_authChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.authProvider),
        ChangeNotifierProvider(create: (_) => WalletProvider()),
        ChangeNotifierProvider.value(value: widget.privacy),
        ChangeNotifierProvider.value(value: widget.lock),
      ],
      child: MaterialApp.router(
        title: 'Nuvora',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
        routerConfig: _router,
        builder: (context, child) => LockGate(child: child!),
      ),
    );
  }
}
