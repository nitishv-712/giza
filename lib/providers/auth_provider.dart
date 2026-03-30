import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService.instance;
  
  User? _user;
  bool _isLoading = false;
  String? _errorMessage;

  User? get user => _user;
  bool get isLoading => _isLoading;
  bool get isAuthenticated => _user != null;
  String? get errorMessage => _errorMessage;

  AuthProvider() {
    _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<bool> signInWithGoogle() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithGoogle();
      _isLoading = false;
      notifyListeners();
      return result != null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> signInWithFacebook() async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await _authService.signInWithFacebook();
      _isLoading = false;
      notifyListeners();
      return result != null;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> signOut() async {
    _isLoading = true;
    notifyListeners();

    try {
      await _authService.signOut();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
