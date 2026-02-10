import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/src/http_interception/request_matcher.dart';

void main() {
  group('RequestMatcher', () {
    group('exact URL matching', () {
      test('matches exact URL', () {
        final matcher = RequestMatcher.url('https://api.example.com/users');
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users'),
        );

        expect(matcher.matches(request), isTrue);
      });

      test('does not match different URL', () {
        final matcher = RequestMatcher.url('https://api.example.com/users');
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/posts'),
        );

        expect(matcher.matches(request), isFalse);
      });
    });

    group('URL pattern matching with wildcards', () {
      test('matches URL with wildcard in path', () {
        final matcher = RequestMatcher.urlPattern('https://api.example.com/*/users');
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/v1/users'),
        );

        expect(matcher.matches(request), isTrue);
      });

      test('matches URL with multiple wildcards', () {
        final matcher = RequestMatcher.urlPattern('https://*/api/*/users');
        final request = _createMockRequest(
          uri: Uri.parse('https://example.com/api/v1/users'),
        );

        expect(matcher.matches(request), isTrue);
      });

      test('does not match URL that does not fit pattern', () {
        final matcher = RequestMatcher.urlPattern('https://api.example.com/*/users');
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/posts'),
        );

        expect(matcher.matches(request), isFalse);
      });
    });

    group('regex URL matching', () {
      test('matches URL with regex', () {
        final matcher = RequestMatcher.urlRegex(RegExp(r'https://api\.example\.com/users/\d+'));
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users/123'),
        );

        expect(matcher.matches(request), isTrue);
      });

      test('does not match URL that does not fit regex', () {
        final matcher = RequestMatcher.urlRegex(RegExp(r'https://api\.example\.com/users/\d+'));
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users/abc'),
        );

        expect(matcher.matches(request), isFalse);
      });
    });

    group('HTTP method filtering', () {
      test('matches specific HTTP method', () {
        final matcher = RequestMatcher(method: 'POST');
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users'),
          method: 'POST',
        );

        expect(matcher.matches(request), isTrue);
      });

      test('does not match different HTTP method', () {
        final matcher = RequestMatcher(method: 'POST');
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users'),
          method: 'GET',
        );

        expect(matcher.matches(request), isFalse);
      });
    });

    group('host filtering', () {
      test('matches specific host', () {
        final matcher = RequestMatcher.host('api.example.com');
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users'),
        );

        expect(matcher.matches(request), isTrue);
      });

      test('does not match different host', () {
        final matcher = RequestMatcher.host('api.example.com');
        final request = _createMockRequest(
          uri: Uri.parse('https://other.example.com/users'),
        );

        expect(matcher.matches(request), isFalse);
      });
    });

    group('header filtering', () {
      test('matches when all required headers are present', () {
        final matcher = RequestMatcher(
          headers: {'Authorization': 'Bearer token123'},
        );
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users'),
          headers: {'Authorization': 'Bearer token123'},
        );

        expect(matcher.matches(request), isTrue);
      });

      test('does not match when required header is missing', () {
        final matcher = RequestMatcher(
          headers: {'Authorization': 'Bearer token123'},
        );
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users'),
        );

        expect(matcher.matches(request), isFalse);
      });

      test('does not match when header value is different', () {
        final matcher = RequestMatcher(
          headers: {'Authorization': 'Bearer token123'},
        );
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/users'),
          headers: {'Authorization': 'Bearer different'},
        );

        expect(matcher.matches(request), isFalse);
      });
    });

    group('combined criteria', () {
      test('matches when all criteria are met', () {
        final matcher = RequestMatcher(
          urlPattern: 'https://api.example.com/*/users',
          method: 'POST',
          host: 'api.example.com',
        );
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/v1/users'),
          method: 'POST',
        );

        expect(matcher.matches(request), isTrue);
      });

      test('does not match when one criterion fails', () {
        final matcher = RequestMatcher(
          urlPattern: 'https://api.example.com/*/users',
          method: 'POST',
          host: 'api.example.com',
        );
        final request = _createMockRequest(
          uri: Uri.parse('https://api.example.com/v1/users'),
          // Wrong method
        );

        expect(matcher.matches(request), isFalse);
      });
    });

    group('description', () {
      test('includes all configured criteria', () {
        final matcher = RequestMatcher(
          url: 'https://api.example.com/users',
          method: 'POST',
          host: 'api.example.com',
        );

        final description = matcher.description;
        expect(description, contains('url=https://api.example.com/users'));
        expect(description, contains('method=POST'));
        expect(description, contains('host=api.example.com'));
      });
    });
  });
}

// Helper to create a mock HttpClientRequest for testing
HttpClientRequest _createMockRequest({
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
