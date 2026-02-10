import 'package:e2e_app/keys.dart';
import 'package:patrol/src/http_interception/mock_response.dart';
import 'package:patrol/src/http_interception/request_matcher.dart';

import 'common.dart';

void main() {
  patrol('dio requests are intercepted', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make Dio request
    await $(K.dioRequestButton).tap();
    await $.pumpAndSettle();

    // Wait for response
    await Future.delayed(const Duration(seconds: 2));
    await $.pumpAndSettle();

    // Verify request was captured
    final requests = $.http.getCapturedRequests();
    final dioRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );

    // Verify request data
    expect(dioRequest.method, 'GET');
    expect(dioRequest.url, contains('jsonplaceholder.typicode.com'));
    expect(dioRequest.response, isNotNull);
    expect(dioRequest.response!.statusCode, 200);

    $.http.stopInterception();
  });

  patrol('dio requests can be mocked', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure mock response
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse.json({
        'id': 1,
        'name': 'Mocked Dio User',
        'email': 'dio-mocked@example.com',
      }),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make Dio request
    await $(K.dioRequestButton).tap();
    await $.pumpAndSettle();

    // Wait for response
    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    // Verify mocked data appears in UI
    expect($('Mocked Dio User'), findsOneWidget);
    expect($('dio-mocked@example.com'), findsOneWidget);

    // Verify request was marked as mocked
    final requests = $.http.getCapturedRequests();
    final mockedRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(mockedRequest.isMocked, isTrue);

    $.http.stopInterception();
  });

  patrol('dio error mocks work correctly', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure timeout error mock
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse.timeout(),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make Dio request
    await $(K.dioRequestButton).tap();
    await $.pumpAndSettle();

    // Wait for error
    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    // Verify error appears in UI
    expect($('Error:'), findsOneWidget);

    // Verify error was captured
    final requests = $.http.getCapturedRequests();
    final errorRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(errorRequest.isMocked, isTrue);
    expect(errorRequest.error, isNotNull);

    $.http.stopInterception();
  });

  patrol('mixed http and dio requests are both intercepted', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make http package request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    $.http.clearCaptureLog();

    // Make Dio request
    await $(K.dioRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Verify both were captured
    final requests = $.http.getCapturedRequests();
    expect(requests.length, greaterThanOrEqualTo(1));

    // Both should have captured the same endpoint
    final capturedRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.response, isNotNull);

    $.http.stopInterception();
  });
}
