import 'dart:convert';

import 'package:http/http.dart' as http;

class ApiService {
  // Android emulator:
  static const String baseUrl = 'http://10.0.2.2:3000';

  // For a physical phone, replace the address above with
  // your computer's local IP address, for example:
  //
  // http://192.168.1.100:3000


// login function
  static Future<Map<String, dynamic>> login({
    required String employeeId,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/login'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'employee_id': employeeId,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  // register function
  static Future<Map<String, dynamic>> register({
    required String employeeId,
    required String fullName,
    required String password,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/register'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'employee_id': employeeId,
        'full_name': fullName,
        'password': password,
      }),
    );

    return _handleResponse(response);
  }

  // time in function
  static Future<Map<String, dynamic>> timeIn({
    required String userUid,
    required double latitude,
    required double longitude,
    DateTime? createdAt,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/attendance/time-in'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_uid': userUid,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt?.toUtc().toIso8601String(),
      }),
    );

    return _handleResponse(response);
  }

  // time out
  static Future<Map<String, dynamic>> timeOut({
    required String userUid,
    required double latitude,
    required double longitude,
    DateTime? createdAt,
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/attendance/time-out'),
      headers: {
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'user_uid': userUid,
        'latitude': latitude,
        'longitude': longitude,
        'created_at': createdAt?.toUtc().toIso8601String(),
      }),
    );

    return _handleResponse(response);
  }

  // get attendance history
  static Future<Map<String, dynamic>> getAttendanceHistory({
    required String userUid,
  }) async {
    final response = await http.get(
      Uri.parse(
        '$baseUrl/api/attendance/history/$userUid',
      ),
    );

    return _handleResponse(response);
  }

  // get profile details
  static Future<Map<String, dynamic>> getProfile({
    required String userUid,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/users/$userUid'),
    );

    return _handleResponse(response);
  }

  // get attendance status
  static Future<Map<String, dynamic>> getAttendanceStatus({
    required String userUid,
  }) async {
    final response = await http.get(
      Uri.parse('$baseUrl/api/attendance/status/$userUid'),
    );

    return _handleResponse(response);
  }

  static Map<String, dynamic> _handleResponse(
    http.Response response,
  ) {
    final data = jsonDecode(response.body);

    return {
      'statusCode': response.statusCode,
      ...Map<String, dynamic>.from(data),
    };
  }
}