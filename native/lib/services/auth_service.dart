import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class AuthService {
  static const baseUrl = String.fromEnvironment('NEXO_API_URL',
      defaultValue: 'https://bgabriell.pythonanywhere.com/api/v2');
  static const _storage = FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String identity, String password) async {
    final response = await http.post(Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'identity': identity, 'password': password}));
    return _acceptAuthentication(response);
  }

  Future<Map<String, dynamic>> register(
      {required String fullName,
      required String email,
      required String username,
      required String password}) async {
    final response = await http.post(Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'full_name': fullName,
          'email': email,
          'username': username,
          'password': password
        }));
    return _acceptAuthentication(response);
  }

  Future<Map<String, dynamic>> dashboard() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      throw const AuthException('Sua sessÃ£o expirou. Entre novamente.');
    }
    final response = await http.get(Uri.parse('$baseUrl/dashboard'),
        headers: {'Authorization': 'Bearer $token'});
    final data = jsonDecode(response.body.isEmpty ? '{}' : response.body)
        as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(data['error']?.toString() ??
          'NÃ£o foi possÃ­vel carregar o Dashboard.');
    }
    return data;
  }

  Future<void> logout() async {
    final token = await _storage.read(key: 'auth_token');
    if (token != null) {
      await http.post(Uri.parse('$baseUrl/auth/logout'),
          headers: {'Authorization': 'Bearer $token'});
    }
    await _storage.delete(key: 'auth_token');
  }

  Future<Map<String, dynamic>> categories() => _get('/categories');
  Future<Map<String, dynamic>> createCategory(Map<String, dynamic> body) =>
      _send('POST', '/categories', body);
  Future<Map<String, dynamic>> updateCategory(
          int id, Map<String, dynamic> body) =>
      _send('PUT', '/categories/$id', body);
  Future<void> deleteCategory(int id) => _delete('/categories/$id');

  Future<Map<String, dynamic>> transactions({String? month}) =>
      _get('/transactions${month == null ? '' : '?month=$month'}');
  Future<Map<String, dynamic>> createTransaction(Map<String, dynamic> body) =>
      _send('POST', '/transactions', body);
  Future<void> deleteTransaction(int id) => _delete('/transactions/$id');

  Future<Map<String, dynamic>> expenses() => _get('/expenses');
  Future<Map<String, dynamic>> createExpense(Map<String, dynamic> body) =>
      _send('POST', '/expenses', body);
  Future<Map<String, dynamic>> payExpense(int id) =>
      _send('POST', '/expenses/$id/pay', const {});
  Future<Map<String, dynamic>> restoreExpense(int id) =>
      _send('POST', '/expenses/$id/restore', const {});
  Future<void> deleteExpense(int id) => _delete('/expenses/$id');

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'auth_token');
    if (token == null) {
      throw const AuthException('Sua sessÃ£o expirou. Entre novamente.');
    }
    return {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json'
    };
  }

  Future<Map<String, dynamic>> _get(String path) async {
    final response =
        await http.get(Uri.parse('$baseUrl$path'), headers: await _headers());
    return _decode(response);
  }

  Future<Map<String, dynamic>> _send(
      String method, String path, Map<String, dynamic> body) async {
    final request = http.Request(method, Uri.parse('$baseUrl$path'))
      ..headers.addAll(await _headers())
      ..body = jsonEncode(body);
    final streamed = await request.send();
    return _decode(await http.Response.fromStream(streamed));
  }

  Future<void> _delete(String path) async {
    final response = await http.delete(Uri.parse('$baseUrl$path'),
        headers: await _headers());
    if (response.statusCode < 200 || response.statusCode >= 300) {
      final data = jsonDecode(response.body.isEmpty ? '{}' : response.body)
          as Map<String, dynamic>;
      throw AuthException(
          data['error']?.toString() ?? 'NÃ£o foi possÃ­vel concluir a operaÃ§Ã£o.');
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    final data = jsonDecode(response.body.isEmpty ? '{}' : response.body)
        as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
          data['error']?.toString() ?? 'NÃ£o foi possÃ­vel concluir a operaÃ§Ã£o.');
    }
    return data;
  }

  Future<Map<String, dynamic>> _acceptAuthentication(
      http.Response response) async {
    final data = jsonDecode(response.body.isEmpty ? '{}' : response.body)
        as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AuthException(
          data['error']?.toString() ?? 'NÃ£o foi possÃ­vel acessar o Nexo.');
    }
    await _storage.write(key: 'auth_token', value: data['token'].toString());
    return data['user'] as Map<String, dynamic>;
  }
}
