// lib/data/datasources/local/auth_local_ds.dart

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/constants/db_constants.dart';
import '../../../core/errors/exceptions.dart';
import '../../models/user_model.dart';
import '../../models/company_model.dart';

abstract class AuthLocalDataSource {
  /// Save user data to local storage
  Future<void> saveUser(UserModel user);

  /// Get saved user data
  Future<UserModel?> getSavedUser();

  /// Clear user data (logout)
  Future<void> clearUser();

  /// Save auth token
  Future<void> saveToken(String token);

  /// Get saved token
  Future<String?> getToken();

  /// Clear token
  Future<void> clearToken();

  /// Save refresh token
  Future<void> saveRefreshToken(String refreshToken);

  /// Get refresh token
  Future<String?> getRefreshToken();

  /// Check if user is logged in
  Future<bool> isLoggedIn();

  /// Save company data
  Future<void> saveCompany(CompanyModel company);

  /// Get saved company data
  Future<CompanyModel?> getSavedCompany();

  /// Clear company data
  Future<void> clearCompany();

  /// Save login credentials for remember me
  Future<void> saveCredentials({
    required String phone,
    required String password,
    required bool rememberMe,
  });

  /// Get saved credentials
  Future<Map<String, dynamic>?> getSavedCredentials();

  /// Clear saved credentials
  Future<void> clearCredentials();

  /// Save last sync time
  Future<void> saveLastSyncTime(DateTime dateTime);

  /// Get last sync time
  Future<DateTime?> getLastSyncTime();

  /// Save user preferences
  Future<void> savePreference(String key, dynamic value);

  /// Get user preference
  Future<dynamic> getPreference(String key);

  /// Clear all preferences
  Future<void> clearAllPreferences();

  /// Save FCM token
  Future<void> saveFcmToken(String token);

  /// Get FCM token
  Future<String?> getFcmToken();

  /// Clear all local data (complete reset)
  Future<void> clearAllData();
}

class AuthLocalDataSourceImpl implements AuthLocalDataSource {
  final SharedPreferences sharedPreferences;

  // Keys
  static const String _keyUser = 'user_data';
  static const String _keyToken = 'auth_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyCompany = 'company_data';
  static const String _keyCredentialsPhone = 'saved_phone';
  static const String _keyCredentialsPassword = 'saved_password';
  static const String _keyRememberMe = 'remember_me';
  static const String _keyLastSync = 'last_sync_time';
  static const String _keyFcmToken = 'fcm_token';
  static const String _keyIsLoggedIn = 'is_logged_in';
  static const String _prefPrefix = 'pref_';

  AuthLocalDataSourceImpl({required this.sharedPreferences});

  @override
  Future<void> saveUser(UserModel user) async {
    try {
      final userJson = json.encode(user.toJson());
      await sharedPreferences.setString(_keyUser, userJson);
      await sharedPreferences.setBool(_keyIsLoggedIn, true);
    } catch (e) {
      throw CacheException(message: 'Failed to save user: ${e.toString()}');
    }
  }

  @override
  Future<UserModel?> getSavedUser() async {
    try {
      final userJson = sharedPreferences.getString(_keyUser);
      if (userJson != null) {
        final Map<String, dynamic> userMap = json.decode(userJson);
        return UserModel.fromJson(userMap);
      }
      return null;
    } catch (e) {
      throw CacheException(message: 'Failed to get saved user: ${e.toString()}');
    }
  }

  @override
  Future<void> clearUser() async {
    try {
      await sharedPreferences.remove(_keyUser);
      await sharedPreferences.setBool(_keyIsLoggedIn, false);
    } catch (e) {
      throw CacheException(message: 'Failed to clear user: ${e.toString()}');
    }
  }

  @override
  Future<void> saveToken(String token) async {
    try {
      await sharedPreferences.setString(_keyToken, token);
    } catch (e) {
      throw CacheException(message: 'Failed to save token: ${e.toString()}');
    }
  }

  @override
  Future<String?> getToken() async {
    try {
      return sharedPreferences.getString(_keyToken);
    } catch (e) {
      throw CacheException(message: 'Failed to get token: ${e.toString()}');
    }
  }

  @override
  Future<void> clearToken() async {
    try {
      await sharedPreferences.remove(_keyToken);
    } catch (e) {
      throw CacheException(message: 'Failed to clear token: ${e.toString()}');
    }
  }

  @override
  Future<void> saveRefreshToken(String refreshToken) async {
    try {
      await sharedPreferences.setString(_keyRefreshToken, refreshToken);
    } catch (e) {
      throw CacheException(message: 'Failed to save refresh token: ${e.toString()}');
    }
  }

  @override
  Future<String?> getRefreshToken() async {
    try {
      return sharedPreferences.getString(_keyRefreshToken);
    } catch (e) {
      throw CacheException(message: 'Failed to get refresh token: ${e.toString()}');
    }
  }

  @override
  Future<bool> isLoggedIn() async {
    try {
      final hasToken = sharedPreferences.getString(_keyToken) != null;
      final hasUser = sharedPreferences.getString(_keyUser) != null;
      final isLoggedIn = sharedPreferences.getBool(_keyIsLoggedIn) ?? false;
      return hasToken && hasUser && isLoggedIn;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> saveCompany(CompanyModel company) async {
    try {
      final companyJson = json.encode(company.toJson());
      await sharedPreferences.setString(_keyCompany, companyJson);
    } catch (e) {
      throw CacheException(message: 'Failed to save company: ${e.toString()}');
    }
  }

  @override
  Future<CompanyModel?> getSavedCompany() async {
    try {
      final companyJson = sharedPreferences.getString(_keyCompany);
      if (companyJson != null) {
        final Map<String, dynamic> companyMap = json.decode(companyJson);
        return CompanyModel.fromJson(companyMap);
      }
      return null;
    } catch (e) {
      throw CacheException(message: 'Failed to get saved company: ${e.toString()}');
    }
  }

  @override
  Future<void> clearCompany() async {
    try {
      await sharedPreferences.remove(_keyCompany);
    } catch (e) {
      throw CacheException(message: 'Failed to clear company: ${e.toString()}');
    }
  }

  @override
  Future<void> saveCredentials({
    required String phone,
    required String password,
    required bool rememberMe,
  }) async {
    try {
      if (rememberMe) {
        // Encode password with base64 (basic encoding - consider using flutter_secure_storage for production)
        final encodedPassword = base64.encode(utf8.encode(password));
        await sharedPreferences.setString(_keyCredentialsPhone, phone);
        await sharedPreferences.setString(_keyCredentialsPassword, encodedPassword);
        await sharedPreferences.setBool(_keyRememberMe, true);
      } else {
        await clearCredentials();
      }
    } catch (e) {
      throw CacheException(message: 'Failed to save credentials: ${e.toString()}');
    }
  }

  @override
  Future<Map<String, dynamic>?> getSavedCredentials() async {
    try {
      final rememberMe = sharedPreferences.getBool(_keyRememberMe) ?? false;
      if (!rememberMe) return null;

      final phone = sharedPreferences.getString(_keyCredentialsPhone);
      final encodedPassword = sharedPreferences.getString(_keyCredentialsPassword);

      if (phone != null && encodedPassword != null) {
        final password = utf8.decode(base64.decode(encodedPassword));
        return {
          'phone': phone,
          'password': password,
          'rememberMe': true,
        };
      }
      return null;
    } catch (e) {
      throw CacheException(message: 'Failed to get saved credentials: ${e.toString()}');
    }
  }

  @override
  Future<void> clearCredentials() async {
    try {
      await sharedPreferences.remove(_keyCredentialsPhone);
      await sharedPreferences.remove(_keyCredentialsPassword);
      await sharedPreferences.setBool(_keyRememberMe, false);
    } catch (e) {
      throw CacheException(message: 'Failed to clear credentials: ${e.toString()}');
    }
  }

  @override
  Future<void> saveLastSyncTime(DateTime dateTime) async {
    try {
      await sharedPreferences.setString(_keyLastSync, dateTime.toIso8601String());
    } catch (e) {
      throw CacheException(message: 'Failed to save last sync time: ${e.toString()}');
    }
  }

  @override
  Future<DateTime?> getLastSyncTime() async {
    try {
      final syncTimeStr = sharedPreferences.getString(_keyLastSync);
      if (syncTimeStr != null) {
        return DateTime.parse(syncTimeStr);
      }
      return null;
    } catch (e) {
      throw CacheException(message: 'Failed to get last sync time: ${e.toString()}');
    }
  }

  @override
  Future<void> savePreference(String key, dynamic value) async {
    try {
      final prefKey = '$_prefPrefix$key';
      if (value is String) {
        await sharedPreferences.setString(prefKey, value);
      } else if (value is int) {
        await sharedPreferences.setInt(prefKey, value);
      } else if (value is double) {
        await sharedPreferences.setDouble(prefKey, value);
      } else if (value is bool) {
        await sharedPreferences.setBool(prefKey, value);
      } else if (value is List<String>) {
        await sharedPreferences.setStringList(prefKey, value);
      } else {
        // Convert to JSON string for complex types
        await sharedPreferences.setString(prefKey, json.encode(value));
      }
    } catch (e) {
      throw CacheException(message: 'Failed to save preference: ${e.toString()}');
    }
  }

  @override
  Future<dynamic> getPreference(String key) async {
    try {
      final prefKey = '$_prefPrefix$key';
      return sharedPreferences.get(prefKey);
    } catch (e) {
      throw CacheException(message: 'Failed to get preference: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAllPreferences() async {
    try {
      final keys = sharedPreferences.getKeys();
      for (final key in keys) {
        if (key.startsWith(_prefPrefix)) {
          await sharedPreferences.remove(key);
        }
      }
    } catch (e) {
      throw CacheException(message: 'Failed to clear preferences: ${e.toString()}');
    }
  }

  @override
  Future<void> saveFcmToken(String token) async {
    try {
      await sharedPreferences.setString(_keyFcmToken, token);
    } catch (e) {
      throw CacheException(message: 'Failed to save FCM token: ${e.toString()}');
    }
  }

  @override
  Future<String?> getFcmToken() async {
    try {
      return sharedPreferences.getString(_keyFcmToken);
    } catch (e) {
      throw CacheException(message: 'Failed to get FCM token: ${e.toString()}');
    }
  }

  @override
  Future<void> clearAllData() async {
    try {
      await sharedPreferences.clear();
    } catch (e) {
      throw CacheException(message: 'Failed to clear all data: ${e.toString()}');
    }
  }
}