import 'dart:convert';

import 'captured_response.dart';

/// Represents a captured HTTP request and its response.
class CapturedRequest {
  /// Creates a new [CapturedRequest].
  CapturedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
    required this.timestamp,
    this.response,
    required this.isMocked,
  });

  /// The HTTP method (GET, POST, PUT, DELETE, PATCH, etc.).
  final String method;

  /// The complete request URL including scheme, host, path, and query parameters.
  final Uri url;

  /// All request headers as key-value pairs.
  final Map<String, List<String>> headers;

  /// The request body content as raw bytes.
  final List<int> body;

  /// Timestamp of when the request was initiated.
  final DateTime timestamp;

  /// The response received for this request, if available.
  final CapturedResponse? response;

  /// Whether this request was mocked (true) or made a real network call (false).
  final bool isMocked;

  /// Returns the request body as a UTF-8 decoded string.
  String get bodyAsString => utf8.decode(body);

  /// Returns the request body parsed as JSON.
  ///
  /// Throws [FormatException] if the body is not valid JSON.
  dynamic get bodyAsJson {
    try {
      return json.decode(bodyAsString);
    } catch (e) {
      throw FormatException('Request body is not valid JSON: $e');
    }
  }

  /// Returns the request body parsed as form-encoded data.
  ///
  /// Throws [FormatException] if the body is not form-encoded.
  Map<String, String> get bodyAsFormData {
    final contentType = headers['content-type']?.first ?? '';
    if (!contentType.contains('application/x-www-form-urlencoded')) {
      throw FormatException(
        'Request body is not form-encoded. Content-Type: $contentType',
      );
    }

    return Uri.splitQueryString(bodyAsString);
  }
}
