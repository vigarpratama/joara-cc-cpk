// lib/utils/api_service.dart
// Klien HTTP untuk 3 microservice Joara: user-service, order-service, payment-service.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, [this.statusCode]);
  @override
  String toString() => message;
}

class ApiService {
  static const _timeout = Duration(seconds: 15);
  static const _tokenKey = 'api_token';

  // ---------- token ----------
  static Future<String?> getToken() async => (await SharedPreferences.getInstance()).getString(_tokenKey);
  static Future<void> _saveToken(String token) async => (await SharedPreferences.getInstance()).setString(_tokenKey, token);
  static Future<void> clearToken() async => (await SharedPreferences.getInstance()).remove(_tokenKey);

  static void _showError(String msg) {
    final m = ApiConfig.messengerKey.currentState;
    if (m == null) return;
    m.hideCurrentSnackBar();
    m.showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red.shade700, duration: const Duration(seconds: 4)));
  }

  // ---------- inti request ----------
  // silent = true: jangan munculkan snackbar (dipakai login/register karena layarnya sudah menampilkan error sendiri)
  static Future<dynamic> _request(String method, String url, {
    Map<String, dynamic>? body,
    bool auth = true,
    Map<String, String>? extraHeaders,
    bool silent = false,
  }) async {
    try {
      final headers = <String, String>{'Content-Type': 'application/json', ...?extraHeaders};
      if (auth) {
        final token = await getToken();
        if (token == null) throw ApiException('Belum terhubung ke server, silakan login ulang', 401);
        headers['Authorization'] = 'Bearer $token';
      }
      final req = http.Request(method, Uri.parse(url))..headers.addAll(headers);
      if (body != null) req.body = jsonEncode(body);
      final streamed = await req.send().timeout(_timeout);
      final res = await http.Response.fromStream(streamed);
      dynamic data;
      try { data = res.body.isEmpty ? null : jsonDecode(res.body); } catch (_) { data = null; }
      if (res.statusCode >= 400) {
        var msg = (data is Map && data['error'] != null) ? data['error'].toString() : 'Server membalas ${res.statusCode}';
        if (res.statusCode == 401 && auth) msg = 'Sesi berakhir, silakan login ulang';
        throw ApiException(msg, res.statusCode);
      }
      return data;
    } on ApiException catch (e) {
      if (!silent) _showError(e.message);
      rethrow;
    } on TimeoutException {
      final e = ApiException('Server tidak merespons (timeout). Cek koneksi / alamat server.');
      if (!silent) _showError(e.message);
      throw e;
    } on SocketException {
      final e = ApiException('Tidak bisa terhubung ke server. Pastikan backend jalan dan alamatnya benar.');
      if (!silent) _showError(e.message);
      throw e;
    } on http.ClientException {
      final e = ApiException('Tidak bisa terhubung ke server. Pastikan backend jalan dan alamatnya benar.');
      if (!silent) _showError(e.message);
      throw e;
    }
  }

  // ---------- user-service ----------
  static Future<Map<String, dynamic>> register({
    required String name, required String email, required String phone,
    required String password, required String role,
  }) async {
    final d = await _request('POST', '${ApiConfig.userUrl}/auth/register', auth: false, silent: true,
      body: {'name': name, 'email': email, 'phone': phone, 'password': password, 'role': role});
    await _saveToken(d['token']);
    return Map<String, dynamic>.from(d['user']);
  }

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final d = await _request('POST', '${ApiConfig.userUrl}/auth/login', auth: false, silent: true,
      body: {'email': email, 'password': password});
    await _saveToken(d['token']);
    return Map<String, dynamic>.from(d['user']);
  }

  // Akun admin toko / superadmin (kredensial dicek lokal di app, lalu disamakan ke backend)
  static Future<Map<String, dynamic>> staffSync({
    required String role, required String username, required String password,
    String name = '', String storeId = '',
  }) async {
    final d = await _request('POST', '${ApiConfig.userUrl}/auth/staff-sync', auth: false,
      extraHeaders: {'x-app-key': ApiConfig.appKey},
      body: {'role': role, 'username': username, 'password': password, 'name': name, 'storeId': storeId});
    await _saveToken(d['token']);
    return Map<String, dynamic>.from(d['user']);
  }

  // ---------- order-service ----------
  static Future<Map<String, dynamic>> createOrder(Map<String, dynamic> body) async {
    final d = await _request('POST', '${ApiConfig.orderUrl}/orders', body: body);
    return Map<String, dynamic>.from(d);
  }

  static Future<List<Map<String, dynamic>>> listOrders({String? status, String? storeId}) async {
    final q = <String, String>{if (status != null) 'status': status, if (storeId != null) 'storeId': storeId};
    final uri = Uri.parse('${ApiConfig.orderUrl}/orders').replace(queryParameters: q.isEmpty ? null : q);
    final d = await _request('GET', uri.toString());
    return (d as List).map((e) => Map<String, dynamic>.from(e)).toList();
  }

  static Future<Map<String, dynamic>> updateOrderStatus(String orderId, String status) async {
    final d = await _request('PATCH', '${ApiConfig.orderUrl}/orders/$orderId/status', body: {'status': status});
    return Map<String, dynamic>.from(d);
  }

  static Future<Map<String, dynamic>> assignOrder(String orderId, {String kurirPhone = ''}) async {
    final d = await _request('PATCH', '${ApiConfig.orderUrl}/orders/$orderId/assign', body: {'kurirPhone': kurirPhone});
    return Map<String, dynamic>.from(d);
  }

  // ---------- payment-service ----------
  static Future<Map<String, dynamic>> createQris(String orderId) async {
    final d = await _request('POST', '${ApiConfig.paymentUrl}/payments/qris', body: {'orderId': orderId}, silent: true);
    return Map<String, dynamic>.from(d);
  }

  // null = belum ada pembayaran untuk pesanan ini
  static Future<Map<String, dynamic>?> getPaymentByOrder(String orderId) async {
    try {
      final d = await _request('GET', '${ApiConfig.paymentUrl}/payments/order/$orderId', silent: true);
      return Map<String, dynamic>.from(d);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> mockPay(String paymentId) async {
    final d = await _request('POST', '${ApiConfig.paymentUrl}/payments/$paymentId/mock-pay');
    return Map<String, dynamic>.from(d);
  }

  static Future<Map<String, dynamic>> markPaid(String orderId) async {
    final d = await _request('PATCH', '${ApiConfig.orderUrl}/orders/$orderId/mark-paid');
    return Map<String, dynamic>.from(d);
  }
}
