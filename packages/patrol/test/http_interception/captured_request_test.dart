import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:patrol/src/http_interception/captured_request.dart';
import 'package:patrol/src/http_interception/captured_response.dart';

void main() {
  group('CapturedRequest', () {
    test('stores request data correctly', () {
      final timestamp = DateTime.now();
      final request = CapturedRequest(
        method: 'POST',
        url: Uri.parse('https://api.example.com/users'),
        headers: {
          'content-type': ['application/json'],
          'authorization': ['Bearer token123'],
        },
        body: utf8.encode('{"name":"John"}'),
        timestamp: timestamp,
        isMocked: false,
      );

      expect(request.method, equals('POST'));
      expect(request.url.toString(), equals('https://api.example.com/users'));
      expect(request.headers['content-type'], equals(['application/json']));
      expect(request.headers['authorization'], equals(['Bearer token123']));
      expect(request.timestamp, equals(timestamp));
      expect(request.isMocked, isFalse);
    });

    group('bodyAsString', () {
      test('decodes body as UTF-8 string', () {
        final request = CapturedRequest(
          method: 'POST',
          url: Uri.parse('https://api.example.com/users'),
          headers: {},
          body: utf8.encode('Hello, World!'),
          timestamp: DateTime.now(),
          isMocked: false,
        );

        expect(request.bodyAsString, equals('Hello, World!'));
      });

      test('handles empty body', () {
        final request = CapturedRequest(
          method: 'GET',
          url: Uri.parse('https://api.example.com/users'),
          headers: {},
          body: [],
          timestamp: DateTime.now(),
          isMocked: false,
        );

        expect(request.bodyAsString, equals(''));
      });
    });

    group('bodyAsJson', () {
      test('parses JSON body', () {
        final request = CapturedRequest(
          method: 'POST',
          url: Uri.parse('https://api.example.com/users'),
          headers: {},
          body: utf8.encode('{"name":"John","age":30}'),
          timestamp: DateTime.now(),
          isMocked: false,
        );

        final json = request.bodyAsJson as Map<String, dynamic>;
        expect(json, isA<Map<String, dynamic>>());
        expect(json['name'], equals('John'));
        expect(json['age'], equals(30));
      });

      test('throws FormatException for invalid JSON', () {
        final request = CapturedRequest(
          method: 'POST',
          url: Uri.parse('https://api.example.com/users'),
          headers: {},
          body: utf8.encode('not valid json'),
          timestamp: DateTime.now(),
          isMocked: false,
        );

        expect(() => request.bodyAsJson, throwsFormatException);
      });
    });

    group('bodyAsFormData', () {
      test('parses form-encoded body', () {
        final request = CapturedRequest(
          method: 'POST',
          url: Uri.parse('https://api.example.com/login'),
          headers: {
            'content-type': ['application/x-www-form-urlencoded'],
          },
          body: utf8.encode('username=john&password=secret'),
          timestamp: DateTime.now(),
          isMocked: false,
        );

        final formData = request.bodyAsFormData;
        expect(formData['username'], equals('john'));
        expect(formData['password'], equals('secret'));
      });

      test('throws FormatException when content-type is not form-encoded', () {
        final request = CapturedRequest(
          method: 'POST',
          url: Uri.parse('https://api.example.com/users'),
          headers: {
            'content-type': ['application/json'],
          },
          body: utf8.encode('{"name":"John"}'),
          timestamp: DateTime.now(),
          isMocked: false,
        );

        expect(() => request.bodyAsFormData, throwsFormatException);
      });

      test('throws FormatException when content-type header is missing', () {
        final request = CapturedRequest(
          method: 'POST',
          url: Uri.parse('https://api.example.com/users'),
          headers: {},
          body: utf8.encode('username=john'),
          timestamp: DateTime.now(),
          isMocked: false,
        );

        expect(() => request.bodyAsFormData, throwsFormatException);
      });
    });

    test('associates response with request', () {
      final response = CapturedResponse(
        statusCode: 200,
        headers: {},
        body: [],
        timestamp: DateTime.now(),
      );

      final request = CapturedRequest(
        method: 'GET',
        url: Uri.parse('https://api.example.com/users'),
        headers: {},
        body: [],
        timestamp: DateTime.now(),
        response: response,
        isMocked: false,
      );

      expect(request.response, equals(response));
      expect(request.response?.statusCode, equals(200));
    });
  });
}
