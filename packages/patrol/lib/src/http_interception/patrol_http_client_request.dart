import 'dart:convert';
import 'dart:io';

import 'captured_request.dart';
import 'captured_response.dart';
import 'http_interception_controller.dart';
import 'mock_configuration.dart';
import 'mock_http_client_response.dart';
import 'patrol_http_client_response.dart';

/// Wrapper around [HttpClientRequest] that captures request data and applies mocks.
class PatrolHttpClientRequest implements HttpClientRequest {
  /// Creates a new [PatrolHttpClientRequest].
  PatrolHttpClientRequest(
    this._inner,
    this.controller,
    this._method,
    this._url,
  ) {
    _captureStartTime = DateTime.now();
  }

  final HttpClientRequest _inner;

  /// The controller that manages interception state and mocks.
  final HttpInterceptionController controller;

  /// The HTTP method for this request.
  final String _method;

  /// The URL for this request.
  final Uri _url;

  late DateTime _captureStartTime;
  final List<int> _bodyBytes = [];

  /// Gets the HTTP method for this request.
  String get requestMethod => _method;

  /// Gets the URL for this request.
  Uri get requestUrl => _url;

  /// Gets the captured body bytes.
  List<int> get capturedBodyBytes => _bodyBytes;

  /// Gets the capture start time.
  DateTime get captureStartTime => _captureStartTime;

  @override
  String get method => _method;

  @override
  Uri get uri => _url;

  @override
  Future<HttpClientResponse> close() async {
    // Check for mock configuration
    final mock = controller.findMatchingMock(_inner);

    if (mock != null) {
      // Return mocked response
      return _createMockedResponse(mock);
    }

    // Proceed with real request
    final response = await _inner.close();
    return PatrolHttpClientResponse(
      response,
      controller,
      this,
    );
  }

  Future<HttpClientResponse> _createMockedResponse(
    MockConfiguration mockConfig,
  ) async {
    final mockResponse = mockConfig.response;

    // Apply delay if configured
    if (mockResponse.delay != null) {
      await Future<void>.delayed(mockResponse.delay!);
    }

    // Check if this is an error mock
    if (mockResponse.error != null) {
      final error = mockResponse.error!;
      // Record the error in capture log
      _recordCapture(
        null,
        isMocked: true,
        error: error,
      );
      // Throw the error
      // ignore: only_throw_errors
      throw error;
    }

    // Create mock response
    final response = MockHttpClientResponse(
      statusCode: mockResponse.statusCode,
      headers: mockResponse.headers,
      body: mockResponse.getBodyBytes(),
      request: this,
    );

    // Record to capture log
    _recordCapture(response, isMocked: true);

    return response;
  }

  void _recordCapture(
    HttpClientResponse? response, {
    required bool isMocked,
    Object? error,
  }) {
    final capturedResponse = response != null
        ? CapturedResponse(
            statusCode: response.statusCode,
            headers: _convertHeaders(response.headers),
            body: [], // Body will be captured by response wrapper
            timestamp: DateTime.now(),
          )
        : CapturedResponse(
            statusCode: 0,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
            error: error,
          );

    final capturedRequest = CapturedRequest(
      method: _method,
      url: _url,
      headers: _convertHeaders(headers),
      body: _bodyBytes,
      timestamp: _captureStartTime,
      response: capturedResponse,
      isMocked: isMocked,
    );

    controller.recordRequest(capturedRequest);
  }

  Map<String, List<String>> _convertHeaders(HttpHeaders headers) {
    final result = <String, List<String>>{};
    headers.forEach((name, values) {
      result[name] = values;
    });
    return result;
  }

  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
    _inner.add(data);
  }

  @override
  void addError(Object error, [StackTrace? stackTrace]) {
    _inner.addError(error, stackTrace);
  }

  @override
  void abort([Object? exception, StackTrace? stackTrace]) {
    _inner.abort(exception, stackTrace);
  }

  @override
  Future<void> addStream(Stream<List<int>> stream) {
    return stream.listen(
      (data) {
        _bodyBytes.addAll(data);
        _inner.add(data);
      },
      onError: _inner.addError,
      onDone: () {},
      cancelOnError: true,
    ).asFuture<void>();
  }

  @override
  Encoding get encoding => _inner.encoding;

  @override
  set encoding(Encoding value) => _inner.encoding = value;

  @override
  void write(Object? object) {
    final str = object.toString();
    final bytes = encoding.encode(str);
    _bodyBytes.addAll(bytes);
    _inner.write(object);
  }

  @override
  void writeAll(Iterable<Object?> objects, [String separator = '']) {
    var first = true;
    for (final object in objects) {
      if (!first) {
        write(separator);
      }
      first = false;
      write(object);
    }
  }

  @override
  void writeCharCode(int charCode) {
    write(String.fromCharCode(charCode));
  }

  @override
  void writeln([Object? object = '']) {
    write(object);
    write('\n');
  }

  @override
  Future<HttpClientResponse> get done => close();

  @override
  Future<void> flush() => _inner.flush();

  // Delegate all other properties to _inner
  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  bool get bufferOutput => _inner.bufferOutput;

  @override
  set bufferOutput(bool value) => _inner.bufferOutput = value;

  @override
  int get contentLength => _inner.contentLength;

  @override
  set contentLength(int value) => _inner.contentLength = value;

  @override
  bool get followRedirects => _inner.followRedirects;

  @override
  set followRedirects(bool value) => _inner.followRedirects = value;

  @override
  int get maxRedirects => _inner.maxRedirects;

  @override
  set maxRedirects(int value) => _inner.maxRedirects = value;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  set persistentConnection(bool value) => _inner.persistentConnection = value;
}
