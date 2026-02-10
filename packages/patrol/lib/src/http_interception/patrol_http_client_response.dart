import 'dart:async';
import 'dart:io';

import 'captured_request.dart';
import 'captured_response.dart';
import 'http_interception_controller.dart';
import 'patrol_http_client_request.dart';

/// Wrapper around [HttpClientResponse] that captures response data.
class PatrolHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  /// Creates a new [PatrolHttpClientResponse].
  PatrolHttpClientResponse(
    this._inner,
    this.controller,
    this.request,
  );

  final HttpClientResponse _inner;

  /// The controller that manages interception state and mocks.
  final HttpInterceptionController controller;

  /// The request that initiated this response.
  final PatrolHttpClientRequest request;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    final bodyBytes = <int>[];

    return _inner.listen(
      (data) {
        bodyBytes.addAll(data);
        onData?.call(data);
      },
      onError: onError,
      onDone: () {
        // Record complete capture when response is done
        _recordCapture(bodyBytes);
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }

  void _recordCapture(List<int> bodyBytes) {
    final capturedResponse = CapturedResponse(
      statusCode: statusCode,
      headers: _convertHeaders(headers),
      body: bodyBytes,
      timestamp: DateTime.now(),
    );

    final capturedRequest = CapturedRequest(
      method: request.requestMethod,
      url: request.requestUrl,
      headers: _convertHeaders(request.headers),
      body: request.capturedBodyBytes,
      timestamp: request.captureStartTime,
      response: capturedResponse,
      isMocked: false,
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

  // Delegate all HttpClientResponse properties to _inner
  @override
  X509Certificate? get certificate => _inner.certificate;

  @override
  HttpConnectionInfo? get connectionInfo => _inner.connectionInfo;

  @override
  int get contentLength => _inner.contentLength;

  @override
  List<Cookie> get cookies => _inner.cookies;

  @override
  Future<Socket> detachSocket() => _inner.detachSocket();

  @override
  HttpHeaders get headers => _inner.headers;

  @override
  bool get isRedirect => _inner.isRedirect;

  @override
  bool get persistentConnection => _inner.persistentConnection;

  @override
  String get reasonPhrase => _inner.reasonPhrase;

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    return _inner.redirect(method, url, followLoops);
  }

  @override
  List<RedirectInfo> get redirects => _inner.redirects;

  @override
  int get statusCode => _inner.statusCode;

  @override
  HttpClientResponseCompressionState get compressionState =>
      _inner.compressionState;
}
