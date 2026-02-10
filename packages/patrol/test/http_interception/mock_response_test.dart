import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/src/http_interception/mock_response.dart';

void main() {
  group('MockResponse', () {
    test('creates basic mock response', () {
      final response = MockResponse(
        statusCode: 200,
        headers: {'content-type': 'application/json'},
        body: '{"success":true}',
      );

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], equals('application/json'));
      expect(response.body, equals('{"success":true}'));
    });

    group('convenience constructors', () {
      test('ok() creates 200 response', () {
        final response = MockResponse.ok(body: 'Success');

        expect(response.statusCode, equals(200));
        expect(response.body, equals('Success'));
      });

      test('json() creates JSON response with correct headers', () {
        final response = MockResponse.json({'name': 'John', 'age': 30});

        expect(response.statusCode, equals(200));
        expect(response.headers['content-type'], equals('application/json'));
        expect(response.bodyJson, equals({'name': 'John', 'age': 30}));
      });

      test('json() accepts custom status code', () {
        final response = MockResponse.json({'error': 'Not found'}, statusCode: 404);

        expect(response.statusCode, equals(404));
        expect(response.bodyJson, equals({'error': 'Not found'}));
      });

      test('error() creates error response', () {
        final response = MockResponse.error(404, message: 'Not found');

        expect(response.statusCode, equals(404));
        expect(response.body, equals('Not found'));
      });

      test('timeout() creates timeout error', () {
        final response = MockResponse.timeout();

        expect(response.statusCode, equals(0));
        expect(response.error, isA<TimeoutException>());
      });

      test('connectionRefused() creates connection error', () {
        final response = MockResponse.connectionRefused();

        expect(response.statusCode, equals(0));
        expect(response.error, isA<SocketException>());
      });

      test('dnsFailure() creates DNS error', () {
        final response = MockResponse.dnsFailure();

        expect(response.statusCode, equals(0));
        expect(response.error, isA<SocketException>());
      });

      test('certificateError() creates SSL error', () {
        final response = MockResponse.certificateError();

        expect(response.statusCode, equals(0));
        expect(response.error, isA<HandshakeException>());
      });
    });

    group('getBodyBytes()', () {
      test('returns bodyBytes when set', () {
        final bytes = [1, 2, 3, 4, 5];
        final response = MockResponse(
          statusCode: 200,
          bodyBytes: bytes,
        );

        expect(response.getBodyBytes(), equals(bytes));
      });

      test('encodes body string to bytes', () {
        final response = MockResponse(
          statusCode: 200,
          body: 'Hello',
        );

        expect(response.getBodyBytes(), equals(utf8.encode('Hello')));
      });

      test('encodes bodyJson to bytes', () {
        final response = MockResponse(
          statusCode: 200,
          bodyJson: {'name': 'John'},
        );

        final expectedBytes = utf8.encode('{"name":"John"}');
        expect(response.getBodyBytes(), equals(expectedBytes));
      });

      test('returns empty list when no body is set', () {
        final response = MockResponse(statusCode: 204);

        expect(response.getBodyBytes(), equals([]));
      });
    });

    test('supports delay configuration', () {
      final response = MockResponse(
        statusCode: 200,
        body: 'Delayed response',
        delay: const Duration(milliseconds: 100),
      );

      expect(response.delay, equals(const Duration(milliseconds: 100)));
    });

    test('supports error configuration', () {
      final error = Exception('Custom error');
      final response = MockResponse(
        statusCode: 0,
        error: error,
      );

      expect(response.error, equals(error));
    });

    test('asserts only one body type is specified', () {
      expect(
        () => MockResponse(
          statusCode: 200,
          body: 'text',
          bodyJson: {'key': 'value'},
        ),
        throwsAssertionError,
      );

      expect(
        () => MockResponse(
          statusCode: 200,
          body: 'text',
          bodyBytes: [1, 2, 3],
        ),
        throwsAssertionError,
      );

      expect(
        () => MockResponse(
          statusCode: 200,
          bodyJson: {'key': 'value'},
          error: Exception('error'),
        ),
        throwsAssertionError,
      );
    });
  });
}
