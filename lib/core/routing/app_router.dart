// go_router configuration — all app routes in one place.
//
// The router listens to AuthProvider. Every route except /login and
// /register needs a logged-in user; logging out, or a session expiring
// mid-use, sends the app back to /login on its own.

import 'package:go_router/go_router.dart';
import '../../features/auth/screens/login_screen.dart';
import '../../features/auth/screens/register_screen.dart';
import '../../features/profile/screens/profile_screen.dart';
import '../../features/profile/screens/change_pin_screen.dart';
import '../../features/profile/screens/delete_account_screen.dart';
import '../../features/dashboard/screens/main_shell.dart';
import '../../features/wallet/screens/buy_card_screen.dart';
import '../../providers/auth_provider.dart';

class AppRouter {
  AppRouter._();

  static const _publicRoutes = {'/login', '/register'};

  static GoRouter create(AuthProvider auth) {
    return GoRouter(
      initialLocation: auth.isLoggedIn ? '/dashboard' : '/login',
      refreshListenable: auth,
      redirect: (context, state) {
        final isPublic = _publicRoutes.contains(state.matchedLocation);
        if (!auth.isLoggedIn) return isPublic ? null : '/login';
        if (isPublic) return '/dashboard';
        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/register',
          builder: (context, state) => const RegisterScreen(),
        ),
        GoRoute(
          path: '/dashboard',
          builder: (context, state) => const MainShell(),
        ),
        GoRoute(
          path: '/profile',
          builder: (context, state) => const ProfileScreen(),
        ),
        GoRoute(
          path: '/buy-card',
          builder: (context, state) => const BuyCardScreen(),
        ),
        GoRoute(
          path: '/change-pin',
          builder: (context, state) => const ChangePinScreen(),
        ),
        GoRoute(
          path: '/delete-account',
          builder: (context, state) => const DeleteAccountScreen(),
        ),
      ],
    );
  }
}
