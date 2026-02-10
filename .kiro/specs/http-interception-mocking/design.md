# Design Document: HTTP Interception and Mocking

## Overview

This design describes the implementation of HTTP interception and mocking capabilities for the Patrol testing framework. The feature will enable test developers to capture, inspect, and mock HTTP/HTTPS requests and responses during test execution.

### Key Design Principles

1. **Non-invasive**: HTTP interception works at the Dart VM level without requiring application code changes
2. **Platform-agnostic**: Consistent API across Android, iOS, macOS, and Web platforms
3. **Fluent API**: Integrates seamlessly with Patrol's existing test syntax using the `$` parameter
4. **Zero-overhead when disabled**: No performance impact when interception is not active
5. **Schema-driven**: Follows Patrol's architecture with contracts defined in `schema.dart`

### Architecture Approach

The implementation leverages Dart's `HttpOverrides` mechanism to intercept HTTP requests at the Dart VM level. This approach:
- Works with all Dart HTTP clients (dart:io HttpClient, package:http, dio, etc.)
- Requires no native platform code (pure Dart implementation)
- Provides consistent behavior across all platforms
- Has minimal performance overhead

## Architecture

### High-Level Components

```
┌─────────────────────────────────────────────────────────────┐
│                    Patrol Test ($)                          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │  $.http.startInterception()                          │  │
│  │  $.http.mock(...)                                    │  │
│  │  $.http.getCapturedRequests()                        │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              HttpInterceptionController                      │
│  • Manages interception lifecycle                           │
│  • Stores mock configurations                               │
│  • Maintains capture log                                    │
│  • Coordinates with HttpOverrides                           │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              PatrolHttpOverrides                            │
│  • Extends HttpOverrides                                    │
│  • Intercepts HttpClient creation                           │
│  • Returns PatrolHttpClient wrapper                         │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│              PatrolHttpClient                               │
│  • Wraps dart:io HttpClient                                │
│  • Intercepts request creation                              │
│  • Returns PatrolHttpClientRequest wrapper                  │
└─────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌─────────────────────────────────────────────────────────────┐
│         PatrolHttpClientRequest/Response                    │
│  • Captures request/response data                           │
│  • Applies mocks when configured                            │
│  • Logs to capture log                                      │
└─────────────────────────────────────────────────────────────┘
```

### Component Interaction Flow

1. **Test Setup**: Test calls `$.http.startInterception()` to enable HTTP interception
2. **Override Installation**: `HttpInterceptionController` installs `PatrolHttpOverrides` globally
3. **Request Initiation**: Application makes HTTP request using any Dart HTTP client
4. **Client Wrapping**: `PatrolHttpOverrides` wraps the HttpClient with `PatrolHttpClient`
5. **Request Interception**: `PatrolHttpClient` wraps requests with `PatrolHttpClientRequest`
6. **Mock Matching**: Request is checked against configured mocks
7. **Response Handling**: Either mock response is returned or real request proceeds
8. **Capture Logging**: Request and response details are logged to capture log
9. **Test Assertion**: Test accesses capture log via `$.http.getCapturedRequests()`

## Components and Interfaces

### 1. HttpInterceptionController

Central coordinator for HTTP interception functionality.

```dart
class HttpInterceptionController {
  // Singleton instance
  static final HttpInterceptionController instance = HttpInterceptionController._();
  
  // Private state
  bool _isActive = false;
  final List<CapturedRequest> _captureLog = [];
  final List<MockConfiguration> _mocks = [];
  HttpOverrides? _previousOverrides;
  
  // Lifecycle management
  void startInterception();
  void stopInterception();
  void clearCaptureLog();
  void reset(); // Clear everything
  
  // Mock configuration
  void addMock(MockConfiguration mock);
  void clearMocks();
  MockConfiguration? findMatchingMock(HttpClientRequest request);
  
  // Capture log access
  List<CapturedRequest> getCapturedRequests();
  List<CapturedRequest> findRequests(RequestMatcher matcher);
  
  // Internal methods
  void _recordRequest(CapturedRequest request);
  bool get isActive => _isActive;
}
```

### 2. PatrolHttpOverrides

Custom HttpOverrides implementation that intercepts HttpClient creation.

```dart
class PatrolHttpOverrides extends HttpOverrides {
  PatrolHttpOverrides(this.controller);
  
  final HttpInterceptionController controller;
  
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return PatrolHttpClient(client, controller);
  }
}
```

### 3. PatrolHttpClient

Wrapper around HttpClient that intercepts request creation.

```dart
class PatrolHttpClient implements HttpClient {
  PatrolHttpClient(this._inner, this.controller);
  
  final HttpClient _inner;
  final HttpInterceptionController controller;
  
  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await _inner.openUrl(method, url);
    return PatrolHttpClientRequest(request, controller, method, url);
  }
  
  // Delegate all other HttpClient methods to _inner
  @override
  bool get autoUncompress => _inner.autoUncompress;
  
  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;
  
  // ... (delegate all other methods)
}
```

### 4. PatrolHttpClientRequest

Wrapper around HttpClientRequest that captures request data and applies mocks.

```dart
class PatrolHttpClientRequest implements HttpClientRequest {
  PatrolHttpClientRequest(
    this._inner,
    this.controller,
    this.method,
    this.url,
  ) {
    _captureStartTime = DateTime.now();
  }
  
  final HttpClientRequest _inner;
  final HttpInterceptionController controller;
  final String method;
  final Uri url;
  late DateTime _captureStartTime;
  final List<int> _bodyBytes = [];
  
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
    final wrappedResponse = PatrolHttpClientResponse(
      response,
      controller,
      this,
    );
    
    return wrappedResponse;
  }
  
  @override
  void add(List<int> data) {
    _bodyBytes.addAll(data);
    _inner.add(data);
  }
  
  Future<HttpClientResponse> _createMockedResponse(MockConfiguration mock) async {
    // Apply delay if configured
    if (mock.delay != null) {
      await Future.delayed(mock.delay!);
    }
    
    // Create mock response
    final mockResponse = MockHttpClientResponse(
      statusCode: mock.statusCode,
      headers: mock.headers,
      body: mock.body,
      request: this,
    );
    
    // Record to capture log
    _recordCapture(mockResponse, isMocked: true);
    
    return mockResponse;
  }
  
  void _recordCapture(HttpClientResponse response, {required bool isMocked}) {
    final capturedRequest = CapturedRequest(
      method: method,
      url: url,
      headers: headers,
      body: _bodyBytes,
      timestamp: _captureStartTime,
      response: CapturedResponse.fromHttpClientResponse(response),
      isMocked: isMocked,
    );
    
    controller._recordRequest(capturedRequest);
  }
  
  // Delegate all other methods to _inner
}
```

### 5. PatrolHttpClientResponse

Wrapper around HttpClientResponse that captures response data.

```dart
class PatrolHttpClientResponse extends Stream<List<int>> implements HttpClientResponse {
  PatrolHttpClientResponse(
    this._inner,
    this.controller,
    this.request,
  );
  
  final HttpClientResponse _inner;
  final HttpInterceptionController controller;
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
        // Record capture when response is complete
        request._recordCapture(this, isMocked: false);
        onDone?.call();
      },
      cancelOnError: cancelOnError,
    );
  }
  
  // Delegate all HttpClientResponse properties to _inner
  @override
  int get statusCode => _inner.statusCode;
  
  @override
  HttpHeaders get headers => _inner.headers;
  
  // ... (delegate all other properties)
}
```

### 6. Test API Extension

Extension on PatrolIntegrationTester to provide HTTP interception API.

```dart
extension HttpInterceptionExtension on PatrolIntegrationTester {
  HttpInterceptionApi get http => HttpInterceptionApi(this);
}

class HttpInterceptionApi {
  HttpInterceptionApi(this.tester);
  
  final PatrolIntegrationTester tester;
  final HttpInterceptionController _controller = HttpInterceptionController.instance;
  
  // Lifecycle
  void startInterception() {
    _controller.startInterception();
    tester.log('HTTP interception started');
  }
  
  void stopInterception() {
    _controller.stopInterception();
    tester.log('HTTP interception stopped');
  }
  
  void clearCaptureLog() {
    _controller.clearCaptureLog();
  }
  
  // Mock configuration
  void mock({
    required RequestMatcher matcher,
    required MockResponse response,
  }) {
    final config = MockConfiguration(
      matcher: matcher,
      response: response,
    );
    _controller.addMock(config);
    tester.log('Mock configured for ${matcher.description}');
  }
  
  void mockSequence({
    required RequestMatcher matcher,
    required List<MockResponse> responses,
  }) {
    for (final response in responses) {
      mock(matcher: matcher, response: response);
    }
  }
  
  void clearMocks() {
    _controller.clearMocks();
  }
  
  // Capture log access
  List<CapturedRequest> getCapturedRequests() {
    return _controller.getCapturedRequests();
  }
  
  List<CapturedRequest> findRequests(RequestMatcher matcher) {
    return _controller.findRequests(matcher);
  }
  
  // Verification helpers
  void expectRequest(RequestMatcher matcher, {String? reason}) {
    final requests = findRequests(matcher);
    if (requests.isEmpty) {
      throw TestFailure(
        'Expected to find request matching ${matcher.description}, but found none.\n'
        'Captured ${_controller.getCapturedRequests().length} requests total.',
      );
    }
  }
  
  void expectRequestCount(RequestMatcher matcher, int count, {String? reason}) {
    final requests = findRequests(matcher);
    if (requests.length != count) {
      throw TestFailure(
        'Expected $count requests matching ${matcher.description}, '
        'but found ${requests.length}.',
      );
    }
  }
  
  void expectNoRequest(RequestMatcher matcher, {String? reason}) {
    final requests = findRequests(matcher);
    if (requests.isNotEmpty) {
      throw TestFailure(
        'Expected no requests matching ${matcher.description}, '
        'but found ${requests.length}.',
      );
    }
  }
  
  // Debugging
  void printCapturedRequests() {
    final requests = getCapturedRequests();
    print('=== Captured HTTP Requests (${requests.length}) ===');
    for (var i = 0; i < requests.length; i++) {
      final req = requests[i];
      print('[$i] ${req.method} ${req.url}');
      print('    Status: ${req.response?.statusCode ?? "pending"}');
      print('    Mocked: ${req.isMocked}');
      print('    Time: ${req.timestamp}');
    }
  }
}
```

## Data Models

### CapturedRequest

Represents a captured HTTP request and its response.

```dart
class CapturedRequest {
  CapturedRequest({
    required this.method,
    required this.url,
    required this.headers,
    required this.body,
    required this.timestamp,
    this.response,
    required this.isMocked,
  });
  
  final String method;
  final Uri url;
  final Map<String, List<String>> headers;
  final List<int> body;
  final DateTime timestamp;
  final CapturedResponse? response;
  final bool isMocked;
  
  // Convenience methods
  String get bodyAsString => utf8.decode(body);
  
  dynamic get bodyAsJson {
    try {
      return json.decode(bodyAsString);
    } catch (e) {
      throw FormatException('Request body is not valid JSON: $e');
    }
  }
  
  Map<String, String> get bodyAsFormData {
    // Parse application/x-www-form-urlencoded
    final contentType = headers['content-type']?.first ?? '';
    if (!contentType.contains('application/x-www-form-urlencoded')) {
      throw FormatException('Request body is not form-encoded');
    }
    
    return Uri.splitQueryString(bodyAsString);
  }
}
```

### CapturedResponse

Represents a captured HTTP response.

```dart
class CapturedResponse {
  CapturedResponse({
    required this.statusCode,
    required this.headers,
    required this.body,
    required this.timestamp,
    this.error,
  });
  
  factory CapturedResponse.fromHttpClientResponse(HttpClientResponse response) {
    // Implementation captures response data
  }
  
  final int statusCode;
  final Map<String, List<String>> headers;
  final List<int> body;
  final DateTime timestamp;
  final Object? error;
  
  // Convenience methods
  String get bodyAsString => utf8.decode(body);
  
  dynamic get bodyAsJson {
    try {
      return json.decode(bodyAsString);
    } catch (e) {
      throw FormatException('Response body is not valid JSON: $e');
    }
  }
  
  bool get isSuccess => statusCode >= 200 && statusCode < 300;
  bool get isError => statusCode >= 400;
}
```

### RequestMatcher

Defines criteria for matching HTTP requests.

```dart
class RequestMatcher {
  RequestMatcher({
    this.url,
    this.urlPattern,
    this.urlRegex,
    this.method,
    this.headers,
    this.host,
  });
  
  // Convenience constructors
  factory RequestMatcher.url(String url) => RequestMatcher(url: url);
  factory RequestMatcher.urlPattern(String pattern) => RequestMatcher(urlPattern: pattern);
  factory RequestMatcher.urlRegex(RegExp regex) => RequestMatcher(urlRegex: regex);
  factory RequestMatcher.host(String host) => RequestMatcher(host: host);
  
  final String? url;
  final String? urlPattern; // Supports * wildcards
  final RegExp? urlRegex;
  final String? method;
  final Map<String, String>? headers;
  final String? host;
  
  bool matches(HttpClientRequest request) {
    // Check URL exact match
    if (url != null && request.uri.toString() != url) {
      return false;
    }
    
    // Check URL pattern (with wildcards)
    if (urlPattern != null) {
      final regex = _patternToRegex(urlPattern!);
      if (!regex.hasMatch(request.uri.toString())) {
        return false;
      }
    }
    
    // Check URL regex
    if (urlRegex != null && !urlRegex!.hasMatch(request.uri.toString())) {
      return false;
    }
    
    // Check method
    if (method != null && request.method != method) {
      return false;
    }
    
    // Check host
    if (host != null && request.uri.host != host) {
      return false;
    }
    
    // Check headers
    if (headers != null) {
      for (final entry in headers!.entries) {
        final requestHeaderValue = request.headers.value(entry.key);
        if (requestHeaderValue != entry.value) {
          return false;
        }
      }
    }
    
    return true;
  }
  
  RegExp _patternToRegex(String pattern) {
    // Convert wildcard pattern to regex
    // Example: "https://api.example.com/*/users" -> "https://api\.example\.com/.*/users"
    final escaped = RegExp.escape(pattern);
    final withWildcards = escaped.replaceAll(r'\*', '.*');
    return RegExp('^$withWildcards\$');
  }
  
  String get description {
    final parts = <String>[];
    if (url != null) parts.add('url=$url');
    if (urlPattern != null) parts.add('pattern=$urlPattern');
    if (urlRegex != null) parts.add('regex=${urlRegex!.pattern}');
    if (method != null) parts.add('method=$method');
    if (host != null) parts.add('host=$host');
    if (headers != null) parts.add('headers=$headers');
    return parts.join(', ');
  }
}
```

### MockResponse

Defines a mock HTTP response.

```dart
class MockResponse {
  MockResponse({
    required this.statusCode,
    this.headers = const {},
    this.body,
    this.bodyJson,
    this.bodyBytes,
    this.delay,
    this.error,
  }) : assert(
    [body, bodyJson, bodyBytes, error].where((x) => x != null).length <= 1,
    'Only one of body, bodyJson, bodyBytes, or error can be specified',
  );
  
  // Convenience constructors
  factory MockResponse.ok({String? body, dynamic json}) {
    return MockResponse(
      statusCode: 200,
      body: body,
      bodyJson: json,
    );
  }
  
  factory MockResponse.json(dynamic data, {int statusCode = 200}) {
    return MockResponse(
      statusCode: statusCode,
      bodyJson: data,
      headers: {'content-type': 'application/json'},
    );
  }
  
  factory MockResponse.error(int statusCode, {String? message}) {
    return MockResponse(
      statusCode: statusCode,
      body: message,
    );
  }
  
  factory MockResponse.timeout() {
    return MockResponse(
      statusCode: 0,
      error: TimeoutException('Mocked timeout'),
    );
  }
  
  factory MockResponse.connectionRefused() {
    return MockResponse(
      statusCode: 0,
      error: SocketException('Mocked connection refused'),
    );
  }
  
  final int statusCode;
  final Map<String, String> headers;
  final String? body;
  final dynamic bodyJson;
  final List<int>? bodyBytes;
  final Duration? delay;
  final Object? error;
  
  List<int> getBodyBytes() {
    if (bodyBytes != null) return bodyBytes!;
    if (body != null) return utf8.encode(body!);
    if (bodyJson != null) return utf8.encode(json.encode(bodyJson));
    return [];
  }
}
```

### MockConfiguration

Internal representation of a mock configuration.

```dart
class MockConfiguration {
  MockConfiguration({
    required this.matcher,
    required this.response,
  });
  
  final RequestMatcher matcher;
  final MockResponse response;
  bool _used = false;
  
  bool get used => _used;
  void markUsed() => _used = true;
}
```

### ConditionalMockResponse

Callback-based mock response for dynamic scenarios.

```dart
typedef MockResponseCallback = MockResponse? Function(CapturedRequest request);

class ConditionalMockResponse extends MockResponse {
  ConditionalMockResponse(this.callback) : super(statusCode: 0);
  
  final MockResponseCallback callback;
  
  MockResponse? evaluate(CapturedRequest request) {
    return callback(request);
  }
}
```

## Error Handling

### Error Scenarios

1. **Interception Already Active**: Calling `startInterception()` when already active
   - Behavior: Log warning, no-op
   - Rationale: Idempotent operation prevents test failures

2. **Interception Not Active**: Calling `stopInterception()` when not active
   - Behavior: Log warning, no-op
   - Rationale: Idempotent operation prevents test failures

3. **Mock Configuration Error**: Invalid mock configuration (e.g., negative status code)
   - Behavior: Throw ArgumentError immediately
   - Rationale: Fail fast to catch test errors early

4. **Request Matching Error**: Error in matcher logic
   - Behavior: Log error, allow request to proceed
   - Rationale: Don't break application under test

5. **Response Capture Error**: Error capturing response data
   - Behavior: Log error, record partial data
   - Rationale: Capture what we can, don't break application

6. **Body Parsing Error**: Invalid format when parsing body (e.g., bodyAsJson on non-JSON)
   - Behavior: Throw FormatException with clear message
   - Rationale: Test developer needs to know about format mismatch

### Error Recovery

The HTTP interception system is designed to be resilient:
- Internal errors never propagate to the application under test
- Errors are logged using Patrol's logging system
- When in doubt, allow requests to proceed normally
- Provide clear error messages for test developer mistakes

## Testing Strategy

### Unit Testing Approach

Unit tests will focus on:
1. **RequestMatcher logic**: Verify URL matching, pattern matching, regex matching
2. **MockResponse construction**: Verify different response types (JSON, text, bytes, errors)
3. **CapturedRequest/Response parsing**: Verify body parsing methods (JSON, form data, text)
4. **HttpInterceptionController state management**: Verify lifecycle, mock storage, capture log
5. **Error handling**: Verify graceful degradation and error messages

### Property-Based Testing Approach

Property-based tests will verify universal correctness properties across randomized inputs. Each property test will run a minimum of 100 iterations with randomly generated data.

The testing library will be **test** (built-in Dart testing) with **test_api** for property-based testing using custom generators, or **fast_check** if available for Dart.

### Test Configuration

- Minimum 100 iterations per property test
- Each property test tagged with: **Feature: http-interception-mocking, Property {N}: {description}**
- Unit tests for specific examples and edge cases
- Integration tests using the e2e_app to verify end-to-end behavior

### Integration Testing

Integration tests in `dev/e2e_app` will:
1. Create test screens that make HTTP requests
2. Write Patrol tests that intercept and mock those requests
3. Verify the application behaves correctly with mocked responses
4. Test across all supported platforms (Android, iOS, macOS, Web)



## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Property 1: Complete Request Capture

*For any* HTTP request made when interception is enabled, the captured request should contain all request data including method, complete URL (scheme, host, path, query parameters), all headers, body content (if present), and a valid timestamp.

**Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6**

### Property 2: Complete Response Capture

*For any* HTTP response received for an intercepted request, the captured response should contain the status code, all response headers, body content (if present), a valid timestamp, and be correctly associated with its originating request.

**Validates: Requirements 2.1, 2.2, 2.3, 2.4, 2.5**

### Property 3: Interception Transparency When Disabled

*For any* HTTP request made when interception is disabled or not configured, the request should proceed normally without being captured in the capture log.

**Validates: Requirements 1.7**

### Property 4: Error Capture

*For any* HTTP request that fails with a network error, the captured request should include the error type and error message in the capture log.

**Validates: Requirements 2.6**

### Property 5: Exact URL Matching

*For any* request matcher configured with an exact URL, only requests with URLs that exactly match the configured URL should be intercepted.

**Validates: Requirements 3.1**

### Property 6: Wildcard Pattern Matching

*For any* request matcher configured with a wildcard pattern, all requests with URLs matching the pattern should be intercepted, and requests not matching should not be intercepted.

**Validates: Requirements 3.2**

### Property 7: Regex URL Matching

*For any* request matcher configured with a regular expression, all requests with URLs matching the regex should be intercepted, and requests not matching should not be intercepted.

**Validates: Requirements 3.3**

### Property 8: HTTP Method Filtering

*For any* request matcher configured with an HTTP method filter, only requests using that specific HTTP method should be intercepted.

**Validates: Requirements 3.4**

### Property 9: Header Filtering

*For any* request matcher configured with header filters, only requests containing all specified headers with matching values should be intercepted.

**Validates: Requirements 3.5**

### Property 10: Host Filtering

*For any* request matcher configured with a host filter, only requests to that specific host should be intercepted.

**Validates: Requirements 3.6**

### Property 11: Multiple Matcher OR Logic

*For any* set of multiple request matchers configured, a request matching any one of the matchers should be intercepted.

**Validates: Requirements 3.7**

### Property 12: Default Intercept All Behavior

*For any* HTTP request made when interception is enabled with no matchers configured, the request should be intercepted and captured.

**Validates: Requirements 3.8**

### Property 13: Mock Response Substitution

*For any* request that matches a configured mock, the mock response should be returned instead of making an actual network request, and no real network traffic should occur.

**Validates: Requirements 4.1**

### Property 14: Mock Response Configuration Completeness

*For any* mock response configured with status code, headers, and body (string, JSON, or binary), the returned mock response should contain exactly the configured values.

**Validates: Requirements 4.2, 4.3, 4.4, 4.5, 4.6**

### Property 15: Mocked Request Capture

*For any* request that receives a mocked response, the request and mock response should be recorded in the capture log with the isMocked flag set to true.

**Validates: Requirements 4.7**

### Property 16: Mock Precedence

*For any* request matching multiple overlapping mock configurations, the most recently configured mock should be used.

**Validates: Requirements 4.8**

### Property 17: Mock Response Delay

*For any* mock response configured with a delay duration, the time between request initiation and response receipt should be at least the configured delay duration.

**Validates: Requirements 4.9**

### Property 18: Chronological Capture Order

*For any* sequence of HTTP requests made during a test, the capture log should return them in the same chronological order they were initiated.

**Validates: Requirements 5.2**

### Property 19: Capture Log Filtering

*For any* capture log query with filtering criteria (URL pattern, HTTP method, or status code), all returned requests should match the filter criteria, and all captured requests matching the criteria should be returned.

**Validates: Requirements 5.3, 5.4, 5.5**

### Property 20: Captured Request Data Completeness

*For any* captured request accessed from the capture log, all request fields (method, URL, headers, body, timestamp) should be accessible and match the original request data.

**Validates: Requirements 5.6**

### Property 21: Captured Response Data Completeness

*For any* captured response accessed from the capture log, all response fields (status code, headers, body, timestamp) should be accessible and match the original response data.

**Validates: Requirements 5.7**

### Property 22: Error Message Clarity

*For any* error encountered during HTTP interception (configuration errors, parsing errors, internal errors), the error message should clearly indicate the cause and context of the error.

**Validates: Requirements 6.5, 9.6, 12.6**

### Property 23: Multi-Client Interception

*For any* HTTP requests made using different HTTP client libraries simultaneously (dart:io HttpClient, package:http, dio, etc.), all requests should be intercepted and captured regardless of which client made them.

**Validates: Requirements 8.6**

### Property 24: Error Resilience

*For any* internal error encountered by the HTTP interceptor during request processing, the error should be logged and the request should proceed normally without propagating the error to the application.

**Validates: Requirements 9.5**

### Property 25: Request Interception Logging

*For any* HTTP request intercepted when interception is active, a log message should be produced containing at minimum the request URL and method.

**Validates: Requirements 10.1, 10.6**

### Property 26: Mock Response Logging

*For any* request that receives a mocked response, a log message should be produced indicating that the response was mocked.

**Validates: Requirements 10.2**

### Property 27: Verbose Header Logging

*For any* HTTP request intercepted when verbose logging is enabled, the log output should include both request and response headers.

**Validates: Requirements 10.5**

### Property 28: Mock Sequence Ordering

*For any* request matcher with multiple mock responses configured in sequence, subsequent matching requests should receive responses in the order the mocks were configured.

**Validates: Requirements 11.1**

### Property 29: Mock Sequence Exhaustion Behavior

*For any* request matcher with a mock sequence that has been exhausted (all responses used), the next matching request should either receive the last response repeated or proceed to make a real request, based on configuration.

**Validates: Requirements 11.2**

### Property 30: Mock Sequence Reset

*For any* mock sequence that has been partially or fully consumed, calling the reset method should cause the next matching request to receive the first mock response in the sequence again.

**Validates: Requirements 11.3**

### Property 31: Capture Log Clearing Preserves Mocks

*For any* configured mocks and captured requests, clearing the capture log should remove all captured requests while preserving all mock configurations.

**Validates: Requirements 13.6**

### Property 32: Interception Accumulation

*For any* test where interception is enabled multiple times without clearing, captured requests should accumulate across all periods of active interception.

**Validates: Requirements 13.5**

### Property 33: Interception Deactivation Cleanup

*For any* active interception session, explicitly disabling interception should stop capturing new requests and clear the capture log.

**Validates: Requirements 13.3**

### Property 34: Error Mock Configuration

*For any* mock response configured to throw a network error (timeout, connection refused, DNS failure, SSL error), making a matching request should throw the specified error type to the application.

**Validates: Requirements 14.1, 14.2, 14.3, 14.4, 14.5**

### Property 35: Error Mock Capture

*For any* request that receives an error mock response, the request and error should be recorded in the capture log with error details.

**Validates: Requirements 14.6**

### Property 36: Request Body Parsing

*For any* captured request with a body, parsing the body as JSON, form data, text, or binary should succeed if the body is in the requested format, and should throw a clear FormatException if the format doesn't match.

**Validates: Requirements 15.1, 15.2, 15.4, 15.5, 15.6**

### Property 37: Conditional Mock Callback Invocation

*For any* mock configured with a callback function, the callback should be invoked with the complete captured request data when a matching request is made.

**Validates: Requirements 16.2, 16.6**

### Property 38: Conditional Mock Response Handling

*For any* mock callback that returns a MockResponse, that response should be used; if the callback returns null, the request should proceed normally; if the callback throws an error, the error should propagate to the test.

**Validates: Requirements 16.3, 16.4, 16.5**

