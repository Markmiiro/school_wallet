// ChangeNotifier holding authentication state for the whole app.
// Screens listen to this via Provider/context.watch instead of
// calling AuthService directly.

import 'package:flutter/material.dart';
import '../data/services/auth_service.dart';
import '../data/models/auth_user.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  bool isLoading = false;
  bool isInitialized = false;
  String? errorMessage;

  bool isLoggedIn = false;
  AuthUser? currentUser;

  /// Called once at app startup to check for an existing session
  /// (e.g. from secure storage) before showing Login or Home.
  Future<void> checkExistingSession() async {
    isLoading = true;
    notifyListeners();

    final user = await _authService.checkExistingSession();

    if (user != null) {
      currentUser = user;
      isLoggedIn = true;
    } else {
      isLoggedIn = false;
      currentUser = null;
    }

    isLoading = false;
    isInitialized = true;
    notifyListeners();
  }

  Future<bool> login(String phone, String pin) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _authService.login(phone, pin);

    if (result.success) {
      currentUser = result.user;
      isLoggedIn = true;
      isLoading = false;
      notifyListeners();
      return true;
    } else {
      errorMessage = result.errorMessage;
      isLoggedIn = false;
      isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Registers a new parent account, then ensures they end up logged in.
  /// If /auth/register returns a token/user directly, we use it. If not,
  /// we log in immediately with the same credentials so the user still
  /// lands on the dashboard.
  Future<bool> register({
    required String name,
    required String phone,
    required String pin,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _authService.register(
      name: name,
      phone: phone,
      pin: pin,
    );

    // If registration returned a session directly, we're done.
    if (result.success && result.user != null) {
      currentUser = result.user;
      isLoggedIn = true;
      isLoading = false;
      notifyListeners();
      return true;
    }

    // Registration succeeded but no token/user was returned — log in
    // immediately with the same credentials.
    if (result.success) {
      final loginResult = await _authService.login(phone, pin);
      isLoading = false;
      if (loginResult.success) {
        currentUser = loginResult.user;
        isLoggedIn = true;
        notifyListeners();
        return true;
      } else {
        errorMessage =
            'Account created. Please log in with your new details.';
        notifyListeners();
        return false;
      }
    }

    // Registration itself failed.
    errorMessage = result.errorMessage;
    isLoading = false;
    notifyListeners();
    return false;
  }

  /// Changes the PIN, then logs the user out (the backend invalidates
  /// the session on success and requires re-login with the new PIN).
  /// Returns true on success.
  Future<bool> changePin({
    required String currentPin,
    required String newPin,
  }) async {
    isLoading = true;
    errorMessage = null;
    notifyListeners();

    final result = await _authService.changePin(
      currentPin: currentPin,
      newPin: newPin,
    );

    isLoading = false;

    if (result.success) {
      // Backend invalidates the old session; clear it locally too.
      await _authService.logout();
      isLoggedIn = false;
      currentUser = null;
      notifyListeners();
      return true;
    } else {
      errorMessage = result.errorMessage;
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authService.logout();
    isLoggedIn = false;
    currentUser = null;
    notifyListeners();
  }
}