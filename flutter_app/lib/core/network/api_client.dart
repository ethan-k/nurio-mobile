import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_exception.dart';

class ApiClient {
  ApiClient({required this.baseUri, http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  final Uri baseUri;
  final http.Client _httpClient;

  String? accessToken;

  Future<Map<String, dynamic>> getJson(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);

    final response = await _httpClient.get(
      uri,
      headers: _buildHeaders(authenticated: authenticated),
    );

    return _decodeJsonResponse(response);
  }

  Future<Map<String, dynamic>> postJson(
    String path, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);

    final response = await _httpClient.post(
      uri,
      headers: _buildHeaders(authenticated: authenticated),
      body: jsonEncode(body ?? const <String, dynamic>{}),
    );

    return _decodeJsonResponse(response);
  }

  Future<void> delete(
    String path, {
    Map<String, dynamic>? queryParameters,
    bool authenticated = false,
  }) async {
    final uri = _buildUri(path, queryParameters: queryParameters);

    final response = await _httpClient.delete(
      uri,
      headers: _buildHeaders(authenticated: authenticated),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw _mapError(response);
    }
  }

  Uri _buildUri(String path, {Map<String, dynamic>? queryParameters}) {
    final normalizedPath = path.startsWith('/') ? path : '/$path';
    final uri = baseUri.resolve(normalizedPath);

    final flattenedQuery = <String, String>{};
    if (queryParameters != null) {
      for (final entry in queryParameters.entries) {
        final value = entry.value;
        if (value == null) {
          continue;
        }

        if (value is Iterable) {
          if (value.isEmpty) {
            continue;
          }

          flattenedQuery[entry.key] = value.join(',');
          continue;
        }

        flattenedQuery[entry.key] = value.toString();
      }
    }

    if (flattenedQuery.isEmpty) {
      return uri;
    }

    return uri.replace(queryParameters: flattenedQuery);
  }

  Map<String, String> _buildHeaders({required bool authenticated}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
    };

    if (authenticated && accessToken != null && accessToken!.isNotEmpty) {
      headers['Authorization'] = 'Bearer $accessToken';
    }

    return headers;
  }

  Map<String, dynamic> _decodeJsonResponse(http.Response response) {
    final decodedBody = _decodeBody(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedBody;
    }

    throw _mapError(response, decodedBody: decodedBody);
  }

  ApiException _mapError(
    http.Response response, {
    Map<String, dynamic>? decodedBody,
  }) {
    final parsedBody = decodedBody ?? _decodeBody(response.body);
    final message = parsedBody['error']?.toString().trim();

    return ApiException(
      message: message == null || message.isEmpty ? 'Request failed' : message,
      statusCode: response.statusCode,
    );
  }

  Map<String, dynamic> _decodeBody(String rawBody) {
    if (rawBody.trim().isEmpty) {
      return <String, dynamic>{};
    }

    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }

      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{};
    }
  }
}
