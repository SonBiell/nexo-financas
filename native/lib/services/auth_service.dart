import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

class AuthException implements Exception {
  final String message;
  const AuthException(this.message);
}

class AuthService {
  static const baseUrl = String.fromEnvironment('NEXO_API_URL', defaultValue: 'https://bgabriell.pythonanywhere.com/api/v2');
  static const _storage = FlutterSecureStorage();

  Future<Map<String, dynamic>> login(String identity, String password) async {
    final response = await http.post(Uri.parse('$baseUrl/auth/login'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'identity': identity, 'password': password}));
    return _acceptAuthentication(response);
  }

  Future<Map<String, dynamic>> register({required String fullName, required String email, required String username, required String password}) async {
    final response = await http.post(Uri.parse('$baseUrl/auth/register'), headers: {'Content-Type': 'application/json'}, body: jsonEncode({'full_name': fullName, 'email': email, 'username': username, 'password': password}));
    return _acceptAuthentication(response);
  }

  Future<Map<String, dynamic>> _acceptAuthentication(http.Response response) async {
    final data = jsonDecode(response.body.isEmpty ? '{}' : response.body) as Map<String, dynamic>;
    if (response.statusCode < 200 || response.statusCode >= 300) throw AuthException(data['error']?.toString() ?? 'Não foi possível acessar o Nexo.');
    await _storage.write(key: 'auth_token', value: data['token'].toString());
    return data['user'] as Map<String, dynamic>;
  }
}

