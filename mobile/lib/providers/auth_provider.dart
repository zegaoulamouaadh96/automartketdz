import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/models.dart';
import '../services/api_service.dart';
import '../services/chat_notification_service.dart';

class AuthProvider with ChangeNotifier {
  AppUser? _user;
  String? _token;
  bool _isLoading = false;

  AppUser? get user => _user;
  String? get token => _token;
  bool get isLoading => _isLoading;
  bool get isLoggedIn => _token != null;

  AuthProvider() {
    _loadFromStorage();
  }

  Future<void> _loadFromStorage() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString('token');
    final userData = prefs.getString('user');
    if (_token != null && userData != null) {
      try {
        final res = await ApiService.getProfile();
        _user = AppUser.fromJson(res['data'] ?? res['user'] ?? res);
        await ChatNotificationService.instance.start();
      } catch (_) {
        _token = null;
        await prefs.remove('token');
        await prefs.remove('user');
        await ChatNotificationService.instance.stop();
      }
    } else {
      await ChatNotificationService.instance.stop();
    }
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (_token == null) {
      return;
    }

    try {
      final res = await ApiService.getProfile();
      _user = AppUser.fromJson(res['data'] ?? res['user'] ?? res);
      notifyListeners();
    } catch (_) {
      // Ignore refresh errors to keep current session state.
    }
  }

  Future<void> login(String email, String password) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.login(email, password);
      final data = res['data'];
      _token =
          (res['token'] ?? (data is Map ? data['token'] : null))?.toString();
      final userJson =
          res['user'] ?? (data is Map ? data['user'] : null) ?? data;
      if (userJson is Map<String, dynamic>) {
        _user = AppUser.fromJson(userJson);
      } else {
        _user = null;
      }

      if (_token == null || _token!.isEmpty) {
        throw Exception('لم يتم استلام رمز الدخول من الخادم');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('user', email);
      await ChatNotificationService.instance.start();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> register(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.register(data);
      final responseData = res['data'];
      _token =
          (res['token'] ?? (responseData is Map ? responseData['token'] : null))
              ?.toString();
      final userJson = res['user'] ??
          (responseData is Map ? responseData['user'] : null) ??
          responseData;
      if (userJson is Map<String, dynamic>) {
        _user = AppUser.fromJson(userJson);
      } else {
        _user = null;
      }

      if (_token == null || _token!.isEmpty) {
        throw Exception('لم يتم استلام رمز الدخول من الخادم');
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('token', _token!);
      await prefs.setString('user', data['email']?.toString() ?? '');
      await ChatNotificationService.instance.start();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> logout() async {
    _user = null;
    _token = null;
    await ChatNotificationService.instance.stop();
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    notifyListeners();
  }

  Future<void> updateProfile(Map<String, dynamic> data) async {
    _isLoading = true;
    notifyListeners();
    try {
      final res = await ApiService.updateProfile(data);
      _user = AppUser.fromJson(res['data'] ?? res['user'] ?? {});
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
