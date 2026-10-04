import 'dart:convert';
import 'dart:io';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class ApiClient {
  final String baseUrl;
  final FlutterSecureStorage? secureStorage;
  final Map<String, String> _inMemoryStorage = {};

  String? _accessToken;
  String? _refreshToken;

  ApiClient({
    this.baseUrl = 'http://localhost:8000/api/v1',
    this.secureStorage,
  });

  static const String _keyAccessToken = 'bucket_access_token';
  static const String _keyRefreshToken = 'bucket_refresh_token';

  Future<void> initTokens() async {
    if (secureStorage != null) {
      try {
        _accessToken = await secureStorage!.read(key: _keyAccessToken);
        _refreshToken = await secureStorage!.read(key: _keyRefreshToken);
      } catch (_) {
        _accessToken = _inMemoryStorage[_keyAccessToken];
        _refreshToken = _inMemoryStorage[_keyRefreshToken];
      }
    } else {
      _accessToken = _inMemoryStorage[_keyAccessToken];
      _refreshToken = _inMemoryStorage[_keyRefreshToken];
    }
  }

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    _accessToken = accessToken;
    _refreshToken = refreshToken;

    if (secureStorage != null) {
      try {
        await secureStorage!.write(key: _keyAccessToken, value: accessToken);
        await secureStorage!.write(key: _keyRefreshToken, value: refreshToken);
      } catch (_) {
        _inMemoryStorage[_keyAccessToken] = accessToken;
        _inMemoryStorage[_keyRefreshToken] = refreshToken;
      }
    } else {
      _inMemoryStorage[_keyAccessToken] = accessToken;
      _inMemoryStorage[_keyRefreshToken] = refreshToken;
    }
  }

  Future<void> clearTokens() async {
    _accessToken = null;
    _refreshToken = null;

    if (secureStorage != null) {
      try {
        await secureStorage!.delete(key: _keyAccessToken);
        await secureStorage!.delete(key: _keyRefreshToken);
      } catch (_) {}
    }
    _inMemoryStorage.clear();
  }

  bool get isAuthenticated => _accessToken != null && _accessToken!.isNotEmpty;

  Map<String, String> _buildHeaders({bool includeAuth = true}) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (includeAuth && _accessToken != null) {
      headers['Authorization'] = 'Bearer $_accessToken';
    }
    return headers;
  }

  // --- Auth Endpoints ---

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _buildHeaders(includeAuth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 201) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return data;
    } else {
      final error = _parseError(response);
      throw HttpException(error);
    }
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _buildHeaders(includeAuth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      await saveTokens(
        accessToken: data['access_token'] as String,
        refreshToken: data['refresh_token'] as String,
      );
      return data;
    } else {
      final error = _parseError(response);
      throw HttpException(error);
    }
  }

  Future<bool> refreshToken() async {
    if (_refreshToken == null) return false;

    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/refresh'),
        headers: _buildHeaders(includeAuth: false),
        body: jsonEncode({'refresh_token': _refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        await saveTokens(
          accessToken: data['access_token'] as String,
          refreshToken: data['refresh_token'] as String,
        );
        return true;
      } else {
        await clearTokens();
        return false;
      }
    } catch (_) {
      return false;
    }
  }

  Future<void> registerDevice({
    required String deviceToken,
    String platform = 'android',
  }) async {
    if (!isAuthenticated) return;
    await http.post(
      Uri.parse('$baseUrl/auth/device'),
      headers: _buildHeaders(),
      body: jsonEncode({'device_token': deviceToken, 'platform': platform}),
    );
  }

  // --- Users Endpoints ---

  Future<Map<String, dynamic>> getProfile() async {
    final response = await _authenticatedGet('$baseUrl/users/me');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw HttpException(_parseError(response));
    }
  }

  // --- Sync Session Metadata ---

  Future<Map<String, dynamic>> recordSyncSession({
    required String sessionHash,
    String? deviceId,
  }) async {
    final response = await _authenticatedPost(
      '$baseUrl/sync/session',
      body: {'session_hash': sessionHash, 'device_id': deviceId},
    );
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw HttpException(_parseError(response));
    }
  }

  // --- Payments Endpoints ---

  Future<Map<String, dynamic>> initiatePayment({
    required String payeeVpa,
    required String payeeName,
    required int amountPaise,
    String? note,
  }) async {
    final response = await _authenticatedPost(
      '$baseUrl/payments/initiate',
      body: {
        'payee_vpa': payeeVpa,
        'payee_name': payeeName,
        'amount_paise': amountPaise,
        'note': note ?? 'Bucket UPI Payment',
      },
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw HttpException(_parseError(response));
    }
  }

  Future<Map<String, dynamic>> getPaymentStatus(String providerRef) async {
    final response = await _authenticatedGet('$baseUrl/payments/$providerRef/status');
    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw HttpException(_parseError(response));
    }
  }

  // --- Encrypted Backup Endpoints ---

  Future<Map<String, dynamic>> storeBackup({
    required String ciphertext,
    required String iv,
    int keyVersion = 1,
  }) async {
    final response = await _authenticatedPost(
      '$baseUrl/backup/',
      body: {
        'ciphertext': ciphertext,
        'iv': iv,
        'key_version': keyVersion,
      },
    );
    if (response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw HttpException(_parseError(response));
    }
  }

  Future<Map<String, dynamic>?> getLatestBackup() async {
    try {
      final response = await _authenticatedGet('$baseUrl/backup/latest');
      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  // --- Authenticated HTTP Helpers with 401 Auto-Refresh ---

  Future<http.Response> _authenticatedGet(String url) async {
    var response = await http.get(Uri.parse(url), headers: _buildHeaders());
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await http.get(Uri.parse(url), headers: _buildHeaders());
      }
    }
    return response;
  }

  Future<http.Response> _authenticatedPost(
    String url, {
    required Map<String, dynamic> body,
  }) async {
    var response = await http.post(
      Uri.parse(url),
      headers: _buildHeaders(),
      body: jsonEncode(body),
    );
    if (response.statusCode == 401) {
      final refreshed = await refreshToken();
      if (refreshed) {
        response = await http.post(
          Uri.parse(url),
          headers: _buildHeaders(),
          body: jsonEncode(body),
        );
      }
    }
    return response;
  }

  String _parseError(http.Response response) {
    try {
      final json = jsonDecode(response.body);
      if (json is Map && json.containsKey('detail')) {
        return json['detail'].toString();
      }
    } catch (_) {}
    return 'Server error (${response.statusCode})';
  }
}
