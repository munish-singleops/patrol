import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/src/http_interception/captured_request.dart';
import 'package:patrol/src/http_interception/captured_response.dart';
import 'package:patrol/src/http_interception/http_interception_controller.dart';
import 'package:patrol/src/http_interception/mock_configuration.dart';
import 'package:patrol/src/http_interception/mock_response.dart';
import 'package:patrol/src/http_interception/patrol_http_overrides.dart';
import 'package:patrol/src/http_interception/request_matcher.dart';

void main() {
  group('HttpInterceptionController', () {
    late HttpInterceptionController controller;

    setUp(() {
      controller = HttpInterceptionController.instance;
      // Ensure clean state before each test
      if (controller.isActive) {
        controller.stopInterception();
      }
      controller.clearMocks();
      controller.clearCaptureLog();
    });

    tearDown(() {
      // Clean up after each test
      if (controller.isActive) {
        controller.stopInterception();
      }
      controller.clearMocks();
      controller.clearCaptureLog();
    });

    group('singleton', () {
      test('returns the same instance', () {
        final instance1 = HttpInterceptionController.instance;
        final instance2 = HttpInterceptionController.instance;

        expect(instance1, same(instance2));
      });
    });

    group('lifecycle management', () {
      test('starts inactive by default', () {
        expect(controller.isActive, isFalse);
      });

      test('startInterception() activates interception', () {
        controller.startInterception();

        expect(controller.isActive, isTrue);
        expect(HttpOverrides.current, isA<PatrolHttpOverrides>());
      });

      test('startInterception() is idempotent', () {
        controller.startInterception();
        final overrides1 = HttpOverrides.current;

        controller.startInterception();
        final overrides2 = HttpOverrides.current;

        expect(controller.isActive, isTrue);
        expect(overrides1, same(overrides2));
      });

      test('stopInterception() deactivates interception', () {
        controller.startInterception();
        controller.stopInterception();

        expect(controller.isActive, isFalse);
      });

      test('stopInterception() is idempotent', () {
        controller.stopInterception();

        expect(controller.isActive, isFalse);
        // Should not throw
      });

      test('stopInterception() clears capture log', () {
        controller.startInterception();
        controller.recordRequest(_createCapturedRequest());
        expect(controller.getCapturedRequests(), hasLength(1));

        controller.stopInterception();

        expect(controller.getCapturedRequests(), isEmpty);
      });

      test('reset() stops interception and clears everything', () {
        controller.startInterception();
        controller.addMock(
          MockConfiguration(
            matcher: RequestMatcher.url('https://api.example.com/users'),
            response: MockResponse.ok(),
          ),
        );
        controller.recordRequest(_createCapturedRequest());

        controller.reset();

        expect(controller.isActive, isFalse);
        expect(controller.getCapturedRequests(), isEmpty);
        // Mocks should be cleared (we'll verify this indirectly)
      });
    });

    group('capture log management', () {
      test('recordRequest() adds request to capture log', () {
        final request = _createCapturedRequest();

        controller.recordRequest(request);

        expect(controller.getCapturedRequests(), contains(request));
      });

      test('getCapturedRequests() returns requests in chronological order', () {
        final request1 = _createCapturedRequest(
          url: Uri.parse('https://api.example.com/first'),
        );
        final request2 = _createCapturedRequest(
          url: Uri.parse('https://api.example.com/second'),
        );
        final request3 = _createCapturedRequest(
          url: Uri.parse('https://api.example.com/third'),
        );

        controller.recordRequest(request1);
        controller.recordRequest(request2);
        controller.recordRequest(request3);

        final captured = controller.getCapturedRequests();
        expect(captured, hasLength(3));
        expect(captured[0].url.toString(), contains('first'));
        expect(captured[1].url.toString(), contains('second'));
        expect(captured[2].url.toString(), contains('third'));
      });

      test('getCapturedRequests() returns unmodifiable list', () {
        controller.recordRequest(_createCapturedRequest());

        final captured = controller.getCapturedRequests();

        expect(() => captured.add(_createCapturedRequest()), throwsUnsupportedError);
      });

      test('clearCaptureLog() removes all captured requests', () {
        controller.recordRequest(_createCapturedRequest());
        controller.recordRequest(_createCapturedRequest());
        expect(controller.getCapturedRequests(), hasLength(2));

        controller.clearCaptureLog();

        expect(controller.getCapturedRequests(), isEmpty);
      });

      test('clearCaptureLog() preserves mocks', () {
        final mock = MockConfiguration(
          matcher: RequestMatcher.url('https://api.example.com/users'),
          response: MockResponse.ok(),
        );
        controller.addMock(mock);
        controller.recordRequest(_createCapturedRequest());

        controller.clearCaptureLog();

        expect(controller.getCapturedRequests(), isEmpty);
        // Mock should still be there
        final mockRequest = _createMockHttpClientRequest(
          uri: Uri.parse('https://api.example.com/users'),
        );
        expect(controller.findMatchingMock(mockRequest), isNotNull);
      });
    });

    group('mock configuration', () {
      test('addMock() adds mock configuration', () {
        final mock = MockConfiguration(
          matcher: RequestMatcher.url('https://api.example.com/users'),
          response: MockResponse.ok(),
        );

        controller.addMock(mock);

        final request = _createMockHttpClientRequest(
          uri: Uri.parse('https://api.example.com/users'),
        );
        expect(controller.findMatchingMock(request), equals(mock));
      });

      test('findMatchingMock() returns most recent matching mock', () {
        final mock1 = MockConfiguration(
          matcher: RequestMatcher.url('https://api.example.com/users'),
          response: MockResponse.json({'version': 1}),
        );
        final mock2 = MockConfiguration(
          matcher: RequestMatcher.url('https://api.example.com/users'),
          response: MockResponse.json({'version': 2}),
        );

        controller.addMock(mock1);
        controller.addMock(mock2);

        final request = _createMockHttpClientRequest(
          uri: Uri.parse('https://api.example.com/users'),
        );
        final found = controller.findMatchingMock(request);

        expect(found, equals(mock2));
      });

      test('findMatchingMock() returns null when no mock matches', () {
        final mock = MockConfiguration(
          matcher: RequestMatcher.url('https://api.example.com/users'),
          response: MockResponse.ok(),
        );
        controller.addMock(mock);

        final request = _createMockHttpClientRequest(
          uri: Uri.parse('https://api.example.com/posts'),
        );

        expect(controller.findMatchingMock(request), isNull);
      });

      test('clearMocks() removes all mocks', () {
        controller.addMock(
          MockConfiguration(
            matcher: RequestMatcher.url('https://api.example.com/users'),
            response: MockResponse.ok(),
          ),
        );
        controller.addMock(
          MockConfiguration(
            matcher: RequestMatcher.url('https://api.example.com/posts'),
            response: MockResponse.ok(),
          ),
        );

        controller.clearMocks();

        final request1 = _createMockHttpClientRequest(
          uri: Uri.parse('https://api.example.com/users'),
        );
        final request2 = _createMockHttpClientRequest(
          uri: Uri.parse('https://api.example.com/posts'),
        );
        expect(controller.findMatchingMock(request1), isNull);
        expect(controller.findMatchingMock(request2), isNull);
      });
    });

    group('findRequests', () {
      test('finds requests matching URL', () {
        final request1 = _createCapturedRequest(
          url: Uri.parse('https://api.example.com/users'),
        );
        final request2 = _createCapturedRequest(
          url: Uri.parse('https://api.example.com/posts'),
        );
        controller.recordRequest(request1);
        controller.recordRequest(request2);

        final found = controller.findRequests(
          RequestMatcher.url('https://api.example.com/users'),
        );

        expect(found, hasLength(1));
        expect(found.first.url.toString(), contains('users'));
      });

      test('finds requests matching method', () {
        final request1 = _createCapturedRequest(method: 'GET');
        final request2 = _createCapturedRequest(method: 'POST');
        final request3 = _createCapturedRequest(method: 'POST');
        controller.recordRequest(request1);
        controller.recordRequest(request2);
        controller.recordRequest(request3);

        final found = controller.findRequests(RequestMatcher(method: 'POST'));

        expect(found, hasLength(2));
        expect(found.every((r) => r.method == 'POST'), isTrue);
      });

      test('finds requests matching URL pattern', () {
        final request1 = _createCapturedRequest(
          url: Uri.parse('https://api.example.com/v1/users'),
        );
        final request2 = _createCapturedRequest(
          url: Uri.parse('https://api.example.com/v2/users'),
        );
        final request3 = _createCapturedRequest(
          url: Uri.parse('https://api.example.com/posts'),
        );
        controller.recordRequest(request1);
        controller.recordRequest(request2);
        controller.recordRequest(request3);

        final found = controller.findRequests(
          RequestMatcher.urlPattern('https://api.example.com/*/users'),
        );

        expect(found, hasLength(2));
      });

      test('returns empty list when no requests match', () {
        controller.recordRequest(_createCapturedRequest());

        final found = controller.findRequests(
          RequestMatcher.url('https://nonexistent.com'),
        );

        expect(found, isEmpty);
      });
    });
  });
}

// Helper functions
CapturedRequest _createCapturedRequest({
  String method = 'GET',
  Uri? url,
  Map<String, List<String>>? headers,
}) {
  return CapturedRequest(
    method: method,
    url: url ?? Uri.parse('https://api.example.com/test'),
    headers: headers ?? {},
    body: [],
    timestamp: DateTime.now(),
    response: CapturedResponse(
      statusCode: 200,
      headers: {},
      body: [],
      timestamp: DateTime.now(),
    ),
    isMocked: false,
  );
}

HttpClientRequest _createMockHttpClientRequest({
  required Uri uri,
  String method = 'GET',
  Map<String, String>? headers,
}) {
  return _MockHttpClientRequest(uri, method, headers ?? {});
}

class _MockHttpClientRequest implements HttpClientRequest {
  _MockHttpClientRequest(this.uri, this.method, this._headers);

  @override
  final Uri uri;

  @override
  final String method;

  final Map<String, String> _headers;

  @override
  HttpHeaders get headers => _MockHttpHeaders(_headers);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockHttpHeaders implements HttpHeaders {
  _MockHttpHeaders(this._headers);

  final Map<String, String> _headers;

  @override
  String? value(String name) => _headers[name];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
