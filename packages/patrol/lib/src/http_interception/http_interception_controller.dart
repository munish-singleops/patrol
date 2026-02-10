import 'dart:io';

import 'captured_request.dart';
import 'mock_configuration.dart';
import 'patrol_http_overrides.dart';
import 'request_matcher.dart';

/// Central coordinator for HTTP interception functionality.
///
/// This singleton manages the lifecycle of HTTP interception, stores mock
/// configurations, and maintains the capture log of intercepted requests.
class HttpInterceptionController {
  HttpInterceptionController._();

  /// Singleton instance of the controller.
  static final instance = HttpInterceptionController._();

  var _isActive = false;
  final List<CapturedRequest> _captureLog = [];
  final List<MockConfiguration> _mocks = [];
  HttpOverrides? _previousOverrides;

  /// Whether HTTP interception is currently active.
  bool get isActive => _isActive;

  /// Starts HTTP interception.
  ///
  /// Installs [PatrolHttpOverrides] globally to intercept all HTTP requests.
  /// If interception is already active, this is a no-op.
  void startInterception() {
    if (_isActive) {
      return; // Already active, no-op
    }

    _previousOverrides = HttpOverrides.current;
    HttpOverrides.global = PatrolHttpOverrides(this);
    _isActive = true;
  }

  /// Stops HTTP interception.
  ///
  /// Restores the previous [HttpOverrides] and clears the capture log.
  /// If interception is not active, this is a no-op.
  void stopInterception() {
    if (!_isActive) {
      return; // Not active, no-op
    }

    HttpOverrides.global = _previousOverrides;
    _previousOverrides = null;
    _isActive = false;
    _captureLog.clear();
  }

  /// Clears the capture log without stopping interception or clearing mocks.
  void clearCaptureLog() {
    _captureLog.clear();
  }

  /// Resets the controller to its initial state.
  ///
  /// Stops interception, clears the capture log, and removes all mocks.
  void reset() {
    stopInterception();
    _mocks.clear();
  }

  /// Adds a mock configuration.
  ///
  /// When a request matches the mock's matcher, the configured response
  /// will be returned instead of making a real network request.
  void addMock(MockConfiguration mock) {
    _mocks.add(mock);
  }

  /// Clears all mock configurations.
  void clearMocks() {
    _mocks.clear();
  }

  /// Finds a matching mock for the given [request].
  ///
  /// Returns the most recently added mock that matches the request,
  /// or null if no mock matches. Supports mock sequences by tracking
  /// usage and applying repeatLast behavior.
  ///
  /// Accepts either [HttpClientRequest] or string [url] and [method].
  MockConfiguration? findMatchingMock(
    dynamic request, [
    String? method,
  ]) {
    MockConfiguration? lastMatch;
    
    // Iterate in reverse to get the most recent mock first
    for (var i = _mocks.length - 1; i >= 0; i--) {
      final mock = _mocks[i];
      final matches = request is HttpClientRequest
          ? mock.matcher.matches(request)
          : mock.matcher.matchesUrlAndMethod(request as String, method!);
      
      if (matches) {
        if (!mock.used) {
          // Found an unused mock, mark it and return it
          mock.markUsed();
          return mock;
        }
        // Keep track of the last matching mock for repeatLast behavior
        lastMatch ??= mock;
      }
    }
    
    // If we found a matching mock but all are used, check repeatLast
    if (lastMatch != null && lastMatch.repeatLast) {
      return lastMatch;
    }
    
    return null;
  }

  /// Resets mock sequences for the given [matcher].
  ///
  /// This allows mock sequences to be reused from the beginning.
  void resetMockSequence(RequestMatcher matcher) {
    for (final mock in _mocks) {
      if (mock.matcher == matcher) {
        mock.reset();
      }
    }
  }

  /// Returns all captured requests in chronological order.
  List<CapturedRequest> getCapturedRequests() {
    return List.unmodifiable(_captureLog);
  }

  /// Finds requests matching the given [matcher].
  ///
  /// Returns all captured requests where the matcher's criteria are satisfied.
  List<CapturedRequest> findRequests(RequestMatcher matcher) {
    return _captureLog.where((captured) {
      // Create a temporary mock request to use the matcher's logic
      final mockRequest = _MockHttpClientRequest(
        captured.url,
        captured.method,
        captured.headers,
      );
      return matcher.matches(mockRequest);
    }).toList();
  }

  /// Records a captured request to the capture log.
  ///
  /// This is called internally by the HTTP client wrappers.
  void recordRequest(CapturedRequest request) {
    _captureLog.add(request);
  }
}

// Helper class to create a mock HttpClientRequest for matcher testing
class _MockHttpClientRequest implements HttpClientRequest {
  _MockHttpClientRequest(this.uri, this.method, this._headers);

  @override
  final Uri uri;

  @override
  final String method;

  final Map<String, List<String>> _headers;

  @override
  HttpHeaders get headers => _MockHttpHeaders(_headers);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  _MockHttpHeaders(this._headers);

  final Map<String, List<String>> _headers;

  @override
  String? value(String name) => _headers[name]?.first;

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
