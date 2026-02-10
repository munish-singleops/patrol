import 'dart:convert';

import 'package:dio/dio.dart';

import 'captured_request.dart';
import 'captured_response.dart';
import 'http_interception_controller.dart';

/// Dio interceptor that enables Patrol HTTP interception for any Dio adapter.
///
/// This interceptor works with Http2Adapter and any other Dio adapter,
/// allowing Patrol's HTTP interception to work even when HttpOverrides cannot.
///
/// This interceptor is automatically available when using Patrol.
/// To use it, simply add it to your Dio instance:
///
/// ```dart
/// import 'package:patrol/patrol.dart';
///
/// final dio = Dio();
/// dio.interceptors.add(PatrolDioInterceptor());
/// ```
class PatrolDioInterceptor extends Interceptor {
  /// Creates a new [PatrolDioInterceptor].
  PatrolDioInterceptor();

  final HttpInterceptionController _controller =
      HttpInterceptionController.instance;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) {
    // Only intercept if interception is active
    if (!_controller.isActive) {
      handler.next(options);
      return;
    }

    final url = options.uri.toString();
    final method = options.method;

    // Check for matching mock
    final mockConfig = _controller.findMatchingMock(url, method);

    if (mockConfig != null) {
      final mock = mockConfig.response;

      // Handle error mocks
      if (mock.error != null) {
        // Record the error mock
        final capturedRequest = CapturedRequest(
          method: method,
          url: url,
          headers: options.headers.map(
            (k, dynamic v) => MapEntry(k, v.toString()),
          ),
          body: _encodeBody(options.data),
          timestamp: DateTime.now(),
          isMocked: true,
          error: mock.error,
        );
        _controller.recordRequest(capturedRequest);

        // Throw the error
        handler.reject(
          DioException(
            requestOptions: options,
            error: mock.error,
            type: _getDioErrorType(mock.error!),
          ),
        );
        return;
      }

      // Handle successful mocks
      final capturedRequest = CapturedRequest(
        method: method,
        url: url,
        headers: options.headers.map(
          (k, dynamic v) => MapEntry(k, v.toString()),
        ),
        body: _encodeBody(options.data),
        timestamp: DateTime.now(),
        isMocked: true,
        response: CapturedResponse(
          statusCode: mock.statusCode,
          headers: mock.headers,
          body: mock.body,
          timestamp: DateTime.now(),
        ),
      );
      _controller.recordRequest(capturedRequest);

      // Apply delay if specified
      if (mock.delay != null && mock.delay! > Duration.zero) {
        Future<void>.delayed(mock.delay!).then((_) {
          handler.resolve(
            Response<dynamic>(
              requestOptions: options,
              statusCode: mock.statusCode,
              headers: Headers.fromMap(
                mock.headers.map((k, v) => MapEntry(k, <String>[v])),
              ),
              data: _decodeBody(mock.body, options.responseType),
            ),
          );
        });
      } else {
        handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: mock.statusCode,
            headers: Headers.fromMap(
              mock.headers.map((k, v) => MapEntry(k, <String>[v])),
            ),
            data: _decodeBody(mock.body, options.responseType),
          ),
        );
      }
      return;
    }

    // No mock found, proceed with real request but capture it
    final capturedRequest = CapturedRequest(
      method: method,
      url: url,
      headers: options.headers.map(
        (k, dynamic v) => MapEntry(k, v.toString()),
      ),
      body: _encodeBody(options.data),
      timestamp: DateTime.now(),
      isMocked: false,
    );

    // Store request for later association with response
    options.extra['_patrol_captured_request'] = capturedRequest;

    handler.next(options);
  }

  @override
  void onResponse(
    Response<dynamic> response,
    ResponseInterceptorHandler handler,
  ) {
    if (!_controller.isActive) {
      handler.next(response);
      return;
    }

    // Get the captured request from extras
    final capturedRequest =
        response.requestOptions.extra['_patrol_captured_request']
            as CapturedRequest?;

    if (capturedRequest != null) {
      // Create captured response
      final capturedResponse = CapturedResponse(
        statusCode: response.statusCode ?? 0,
        headers: _extractHeaders(response.headers),
        body: _encodeBody(response.data),
        timestamp: DateTime.now(),
      );

      // Update the captured request with response
      final updatedRequest = CapturedRequest(
        method: capturedRequest.method,
        url: capturedRequest.url,
        headers: capturedRequest.headers,
        body: capturedRequest.body,
        timestamp: capturedRequest.timestamp,
        isMocked: false,
        response: capturedResponse,
      );

      _controller.recordRequest(updatedRequest);
    }

    handler.next(response);
  }

  @override
  void onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) {
    if (!_controller.isActive) {
      handler.next(err);
      return;
    }

    // Get the captured request from extras
    final capturedRequest =
        err.requestOptions.extra['_patrol_captured_request']
            as CapturedRequest?;

    if (capturedRequest != null) {
      // Update the captured request with error
      final updatedRequest = CapturedRequest(
        method: capturedRequest.method,
        url: capturedRequest.url,
        headers: capturedRequest.headers,
        body: capturedRequest.body,
        timestamp: capturedRequest.timestamp,
        isMocked: false,
        error: err.error ?? err,
      );

      _controller.recordRequest(updatedRequest);
    }

    handler.next(err);
  }

  List<int> _encodeBody(dynamic data) {
    if (data == null) {
      return [];
    }
    if (data is List<int>) {
      return data;
    }
    if (data is String) {
      return utf8.encode(data);
    }
    if (data is Map || data is List) {
      return utf8.encode(jsonEncode(data));
    }
    return utf8.encode(data.toString());
  }

  dynamic _decodeBody(List<int> body, ResponseType responseType) {
    if (body.isEmpty) {
      return null;
    }

    final str = utf8.decode(body);

    switch (responseType) {
      case ResponseType.json:
        try {
          return jsonDecode(str);
        } catch (_) {
          return str;
        }
      case ResponseType.plain:
        return str;
      case ResponseType.bytes:
        return body;
      case ResponseType.stream:
        return Stream<List<int>>.value(body);
    }
  }

  Map<String, String> _extractHeaders(Headers headers) {
    final result = <String, String>{};
    headers.forEach((String name, List<String> values) {
      if (values.isNotEmpty) {
        result[name] = values.join(', ');
      }
    });
    return result;
  }

  DioExceptionType _getDioErrorType(Object error) {
    final errorStr = error.toString().toLowerCase();
    if (errorStr.contains('timeout')) {
      return DioExceptionType.connectionTimeout;
    }
    if (errorStr.contains('connection refused')) {
      return DioExceptionType.connectionError;
    }
    if (errorStr.contains('failed host lookup')) {
      return DioExceptionType.connectionError;
    }
    if (errorStr.contains('certificate')) {
      return DioExceptionType.badCertificate;
    }
    return DioExceptionType.unknown;
  }
}
