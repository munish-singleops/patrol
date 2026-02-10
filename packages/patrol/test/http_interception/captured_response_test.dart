import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/src/http_interception/captured_response.dart';

void main() {
  group('CapturedResponse', () {
    test('stores response data correctly', () {
      final timestamp = DateTime.now();
      final response = CapturedResponse(
        statusCode: 200,
        headers: {
          'content-type': ['application/json'],
          'cache-control': ['no-cache'],
        },
        body: utf8.encode('{"success":true}'),
        timestamp: timestamp,
      );

      expect(response.statusCode, equals(200));
      expect(response.headers['content-type'], equals(['application/json']));
      expect(response.headers['cache-control'], equals(['no-cache']));
      expect(response.timestamp, equals(timestamp));
      expect(response.error, isNull);
    });

    group('bodyAsString', () {
      test('decodes body as UTF-8 string', () {
        final response = CapturedResponse(
          statusCode: 200,
          headers: {},
          body: utf8.encode('Response body'),
          timestamp: DateTime.now(),
        );

        expect(response.bodyAsString, equals('Response body'));
      });

      test('handles empty body', () {
        final response = CapturedResponse(
          statusCode: 204,
          headers: {},
          body: [],
          timestamp: DateTime.now(),
        );

        expect(response.bodyAsString, equals(''));
      });
    });

    group('bodyAsJson', () {
      test('parses JSON body', () {
        final response = CapturedResponse(
          statusCode: 200,
          headers: {},
          body: utf8.encode('{"users":[{"id":1,"name":"John"}]}'),
          timestamp: DateTime.now(),
        );

        final json = response.bodyAsJson as Map<String, dynamic>;
        expect(json, isA<Map<String, dynamic>>());
        expect(json['users'], isA<List<dynamic>>());
        final users = json['users'] as List<dynamic>;
        final firstUser = users[0] as Map<String, dynamic>;
        expect(firstUser['name'], equals('John'));
      });

      test('throws FormatException for invalid JSON', () {
        final response = CapturedResponse(
          statusCode: 200,
          headers: {},
          body: utf8.encode('not valid json'),
          timestamp: DateTime.now(),
        );

        expect(() => response.bodyAsJson, throwsFormatException);
      });
    });

    group('isSuccess', () {
      test('returns true for 2xx status codes', () {
        expect(
          CapturedResponse(
            statusCode: 200,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isSuccess,
          isTrue,
        );

        expect(
          CapturedResponse(
            statusCode: 201,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isSuccess,
          isTrue,
        );

        expect(
          CapturedResponse(
            statusCode: 299,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isSuccess,
          isTrue,
        );
      });

      test('returns false for non-2xx status codes', () {
        expect(
          CapturedResponse(
            statusCode: 199,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isSuccess,
          isFalse,
        );

        expect(
          CapturedResponse(
            statusCode: 300,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isSuccess,
          isFalse,
        );

        expect(
          CapturedResponse(
            statusCode: 404,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isSuccess,
          isFalse,
        );
      });
    });

    group('isError', () {
      test('returns true for 4xx and 5xx status codes', () {
        expect(
          CapturedResponse(
            statusCode: 400,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isError,
          isTrue,
        );

        expect(
          CapturedResponse(
            statusCode: 404,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isError,
          isTrue,
        );

        expect(
          CapturedResponse(
            statusCode: 500,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isError,
          isTrue,
        );
      });

      test('returns false for non-error status codes', () {
        expect(
          CapturedResponse(
            statusCode: 200,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isError,
          isFalse,
        );

        expect(
          CapturedResponse(
            statusCode: 399,
            headers: {},
            body: [],
            timestamp: DateTime.now(),
          ).isError,
          isFalse,
        );
      });
    });

    test('stores error information', () {
      final error = Exception('Network error');
      final response = CapturedResponse(
        statusCode: 0,
        headers: {},
        body: [],
        timestamp: DateTime.now(),
        error: error,
      );

      expect(response.error, equals(error));
    });
  });
}
