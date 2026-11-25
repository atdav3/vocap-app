import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'api_config.dart';

class ApiResponse<T> {
  final bool success;
  final T? data;
  final String? message;
  final int statusCode;

  ApiResponse({
    required this.success,
    this.data,
    this.message,
    this.statusCode = 200,
  });
}

class ApiClient {
  ApiClient({http.Client? client, ApiConfig? config})
      : _client = client ?? http.Client(),
        _config = config ?? ApiConfig();

  final http.Client _client;
  final ApiConfig _config;
  String? _authToken;

  void setAuthToken(String? token) {
    _authToken = token;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (_authToken != null) 'Authorization': 'Bearer $_authToken',
      };

  /// Cloud Login
  Future<ApiResponse<Map<String, dynamic>>> login({
    required String usernameOrEmail,
    required String password,
  }) async {
    final endpoint = Uri.parse('${_config.apiUrl}/auth/login');
    try {
      final response = await _client
          .post(
            endpoint,
            headers: _headers,
            body: jsonEncode({
              'username_or_email': usernameOrEmail,
              'password': password,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(success: true, data: body);
      } else {
        return ApiResponse(
          success: false,
          statusCode: response.statusCode,
          message: 'Lỗi đăng nhập: ${response.statusCode}',
        );
      }
    } catch (e) {
      debugPrint('[ApiClient] Remote API unreachable ($e), using local/cloud bridge mode');
      return ApiResponse(
        success: false,
        message: 'Không thể kết nối máy chủ đám mây: $e',
        statusCode: 503,
      );
    }
  }

  /// Cloud Register
  Future<ApiResponse<Map<String, dynamic>>> register({
    required String username,
    required String email,
    required String password,
    required String fullName,
  }) async {
    final endpoint = Uri.parse('${_config.apiUrl}/auth/register');
    try {
      final response = await _client
          .post(
            endpoint,
            headers: _headers,
            body: jsonEncode({
              'username': username,
              'email': email,
              'password': password,
              'full_name': fullName,
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        return ApiResponse(success: true, data: body);
      }
      return ApiResponse(
        success: false,
        statusCode: response.statusCode,
        message: 'Lỗi đăng ký tài khoản từ Cloud',
      );
    } catch (e) {
      return ApiResponse(
        success: false,
        message: 'Không thể kết nối API máy chủ: $e',
        statusCode: 503,
      );
    }
  }

  /// Fetch remote lessons/categories from Cloud
  Future<ApiResponse<List<Map<String, dynamic>>>> fetchCategories() async {
    final endpoint = Uri.parse('${_config.apiUrl}/categories');
    try {
      final response = await _client.get(endpoint, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
        return ApiResponse(success: true, data: list);
      }
      return ApiResponse(success: false, statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString());
    }
  }

  /// Fetch remote words for category
  Future<ApiResponse<List<Map<String, dynamic>>>> fetchWords({int? categoryId}) async {
    final query = categoryId != null ? '?category_id=$categoryId' : '';
    final endpoint = Uri.parse('${_config.apiUrl}/words$query');
    try {
      final response = await _client.get(endpoint, headers: _headers).timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final list = (jsonDecode(response.body) as List).cast<Map<String, dynamic>>();
        return ApiResponse(success: true, data: list);
      }
      return ApiResponse(success: false, statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString());
    }
  }

  /// Synchronize learning progress with Cloud API
  Future<ApiResponse<Map<String, dynamic>>> syncProgress({
    required List<Map<String, dynamic>> progressRecords,
    required List<Map<String, dynamic>> quizResults,
  }) async {
    final endpoint = Uri.parse('${_config.apiUrl}/sync');
    try {
      final response = await _client
          .post(
            endpoint,
            headers: _headers,
            body: jsonEncode({
              'progress': progressRecords,
              'quizzes': quizResults,
              'client_timestamp': DateTime.now().toIso8601String(),
            }),
          )
          .timeout(const Duration(seconds: 5));

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final body = jsonDecode(response.body) as Map<String, dynamic>;
        _config.lastSyncTime = DateTime.now();
        return ApiResponse(success: true, data: body);
      }
      return ApiResponse(success: false, statusCode: response.statusCode);
    } catch (e) {
      return ApiResponse(success: false, message: e.toString());
    }
  }

  /// Check online health / latency test
  Future<int?> pingHealth() async {
    final stopwatch = Stopwatch()..start();
    try {
      final endpoint = Uri.parse('${_config.apiUrl}/health');
      final res = await _client.get(endpoint).timeout(const Duration(milliseconds: 2500));
      stopwatch.stop();
      if (res.statusCode == 200) {
        _config.isOnline = true;
        return stopwatch.elapsedMilliseconds;
      }
    } catch (_) {
      // In offline/mock mode
    }
    _config.isOnline = false;
    return null;
  }
}
