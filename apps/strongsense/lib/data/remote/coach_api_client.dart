import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:strongsense_core/strongsense_core.dart';

/// Error returned by (or raised while reaching) the coach service.
class CoachApiException implements Exception {
  const CoachApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'CoachApiException($code, $statusCode): $message';
}

/// Normalizes a user-entered URL and maps localhost to the Android emulator
/// loopback address when needed.
String normalizeCoachBaseUrl(String raw) {
  var url = raw.trim();
  if (url.isEmpty) {
    return url;
  }
  if (!url.startsWith('http://') && !url.startsWith('https://')) {
    url = 'http://$url';
  }
  while (url.endsWith('/')) {
    url = url.substring(0, url.length - 1);
  }
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
    url = url
        .replaceFirst('://127.0.0.1', '://10.0.2.2')
        .replaceFirst('://localhost', '://10.0.2.2');
  }
  return url;
}

class CoachApiClient {
  CoachApiClient({required String baseUrl, http.Client? client})
    : baseUrl = normalizeCoachBaseUrl(baseUrl),
      _client = client ?? http.Client();

  final String baseUrl;
  final http.Client _client;

  static const Duration planTimeout = Duration(seconds: 25);
  static const Duration healthTimeout = Duration(seconds: 6);

  Future<CoachHealth> health() async {
    final uri = Uri.parse('$baseUrl${CoachContract.healthPath}');
    try {
      final response = await _client
          .get(
            uri,
            headers: const <String, String>{'accept': 'application/json'},
          )
          .timeout(healthTimeout);
      if (response.statusCode != 200) {
        throw _errorFromResponse(response);
      }
      return CoachHealth.fromJson(_decodeObject(response.body));
    } on CoachApiException {
      rethrow;
    } on TimeoutException {
      throw const CoachApiException(
        code: 'timeout',
        message: 'The coach server did not answer in time.',
      );
    } catch (_) {
      throw const CoachApiException(
        code: 'network_error',
        message: 'Could not reach the coach server.',
      );
    }
  }

  Future<CoachResponse> requestPlan(CoachRequest request) async {
    final uri = Uri.parse('$baseUrl${CoachContract.planPath}');
    final body = jsonEncode(request.toJson());

    http.Response? response;
    Object? lastError;
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        response = await _client
            .post(
              uri,
              headers: const <String, String>{
                'content-type': 'application/json; charset=utf-8',
                'accept': 'application/json',
              },
              body: body,
            )
            .timeout(planTimeout);
        break;
      } on TimeoutException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = error;
      }
    }

    if (response == null) {
      if (lastError is TimeoutException) {
        throw const CoachApiException(
          code: 'timeout',
          message: 'The AI coach took too long to answer.',
        );
      }
      throw const CoachApiException(
        code: 'network_error',
        message: 'Could not reach the coach server.',
      );
    }

    if (response.statusCode != 200) {
      throw _errorFromResponse(response);
    }

    try {
      return CoachResponse.fromJson(_decodeObject(response.body));
    } on FormatException catch (error) {
      throw CoachApiException(
        code: 'invalid_response',
        message: error.message,
        statusCode: response.statusCode,
      );
    }
  }

  CoachApiException _errorFromResponse(http.Response response) {
    var code = 'http_${response.statusCode}';
    var message = 'The coach server returned an error.';
    try {
      final decoded = _decodeObject(response.body);
      final detail = decoded['detail'];
      if (detail is Map) {
        code = '${detail['code'] ?? code}';
        message = '${detail['message'] ?? message}';
      }
    } catch (_) {
      // Keep the generic message.
    }
    return CoachApiException(
      code: code,
      message: message,
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeObject(String body) {
    final decoded = jsonDecode(body);
    if (decoded is Map<String, dynamic>) {
      return decoded;
    }
    if (decoded is Map) {
      return decoded.map((key, value) => MapEntry(key.toString(), value));
    }
    throw const FormatException('Expected a JSON object');
  }

  void close() => _client.close();
}
