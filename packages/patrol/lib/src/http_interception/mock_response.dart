import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// Defines a mock HTTP response.
class MockResponse {
  /// Creates a new [MockResponse].
  MockResponse({
    required this.statusCode,
    this.headers = const {},
    this.body,
    this.bodyJson,
    this.bodyBytes,
    this.delay,
    this.error,
  }) : assert(
          [body, bodyJson, bodyBytes, error].where((x) => x != null).length <=
              1,
          'Only one of body, bodyJson, bodyBytes, or error can be specified',
        );

  /// Creates a successful response (200 OK).
  factory MockResponse.ok({String? body, dynamic json}) {
    return MockResponse(
      statusCode: 200,
      body: body,
      bodyJson: json,
    );
  }

  /// Creates a JSON response with the specified data.
  factory MockResponse.json(dynamic data, {int statusCode = 200}) {
    return MockResponse(
      statusCode: statusCode,
      bodyJson: data,
      headers: {'content-type': 'application/json'},
    );
  }

  /// Creates an error response with the specified status code.
  factory MockResponse.error(int statusCode, {String? message}) {
    return MockResponse(
      statusCode: statusCode,
      body: message,
    );
  }

  /// Creates a mock timeout error.
  factory MockResponse.timeout() {
    return MockResponse(
      statusCode: 0,
      error: TimeoutException('Mocked timeout'),
    );
  }

  /// Creates a mock connection refused error.
  factory MockResponse.connectionRefused() {
    return MockResponse(
      statusCode: 0,
      error: const SocketException('Mocked connection refused'),
    );
  }

  /// Creates a mock DNS resolution failure.
  factory MockResponse.dnsFailure() {
    return MockResponse(
      statusCode: 0,
      error: const SocketException('Mocked DNS resolution failure'),
    );
  }

  /// Creates a mock SSL/TLS certificate error.
  factory MockResponse.certificateError() {
    return MockResponse(
      statusCode: 0,
      error: const HandshakeException('Mocked certificate error'),
    );
  }

  /// The HTTP status code.
  final int statusCode;

  /// Response headers.
  final Map<String, String> headers;

  /// Response body as a string.
  final String? body;

  /// Response body as JSON data (will be encoded).
  final dynamic bodyJson;

  /// Response body as raw bytes.
  final List<int>? bodyBytes;

  /// Optional delay before returning the response.
  final Duration? delay;

  /// Optional error to throw instead of returning a response.
  final Object? error;

  /// Returns the response body as bytes.
  List<int> getBodyBytes() {
    if (bodyBytes != null) {
      return bodyBytes!;
    }
    if (body != null) {
      return utf8.encode(body!);
    }
    if (bodyJson != null) {
      return utf8.encode(json.encode(bodyJson));
    }
    return [];
  }
}
