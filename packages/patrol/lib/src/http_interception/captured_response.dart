import 'dart:convert';
import 'dart:io';

/// Represents a captured HTTP response.
class CapturedResponse {
  /// Creates a new [CapturedResponse].
  CapturedResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.timestamp,
    this.error,
  });

  /// Creates a [CapturedResponse] from an [HttpClientResponse].
  factory CapturedResponse.fromHttpClientResponse(
    HttpClientResponse response,
    List<int> bodyBytes,
  ) {
    final headers = <String, List<String>>{};
    response.headers.forEach((name, values) {
      headers[name] = values;
    });

    return CapturedResponse(
      statusCode: response.statusCode,
      headers: headers,
      body: bodyBytes,
      timestamp: DateTime.now(),
    );
  }

  /// The HTTP status code (200, 404, 500, etc.).
  final int statusCode;

  /// All response headers as key-value pairs.
  final Map<String, List<String>> headers;

  /// The response body content as raw bytes.
  final List<int> body;

  /// Timestamp of when the response was received.
  final DateTime timestamp;

  /// Error information if the request failed with a network error.
  final Object? error;

  /// Returns the response body as a UTF-8 decoded string.
  String get bodyAsString => utf8.decode(body);

  /// Returns the response body parsed as JSON.
  ///
  /// Throws [FormatException] if the body is not valid JSON.
  dynamic get bodyAsJson {
    try {
      return json.decode(bodyAsString);
    } catch (e) {
      throw FormatException('Response body is not valid JSON: $e');
    }
  }

  /// Returns true if the status code indicates success (2xx).
  bool get isSuccess => statusCode >= 200 && statusCode < 300;

  /// Returns true if the status code indicates an error (4xx or 5xx).
  bool get isError => statusCode >= 400;
}
