import 'package:e2e_app/keys.dart';
import 'package:patrol/src/http_interception/mock_response.dart';
import 'package:patrol/src/http_interception/request_matcher.dart';

import 'common.dart';

void main() {
  patrol('timeout error mock is thrown', ($) async {
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

    // Make GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();

    // Wait for error to be displayed
    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    // Verify error appears in UI
    expect($('Error:'), findsOneWidget);
    expect($('TimeoutException'), findsOneWidget);

    // Verify error was captured
    final requests = $.http.getCapturedRequests();
    final errorRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(errorRequest.isMocked, isTrue);
    expect(errorRequest.response, isNull);
    expect(errorRequest.error, isNotNull);
    expect(errorRequest.error.toString(), contains('TimeoutException'));

    $.http.stopInterception();
  });

  patrol('connection refused error mock is thrown', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure connection refused error mock
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse.connectionRefused(),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();

    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    // Verify error appears in UI
    expect($('Error:'), findsOneWidget);
    expect($('SocketException'), findsOneWidget);

    // Verify error was captured
    final requests = $.http.getCapturedRequests();
    final errorRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(errorRequest.isMocked, isTrue);
    expect(errorRequest.error, isNotNull);
    expect(errorRequest.error.toString(), contains('Connection refused'));

    $.http.stopInterception();
  });

  patrol('DNS failure error mock is thrown', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure DNS failure error mock
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse.dnsFailure(),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();

    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    // Verify error appears in UI
    expect($('Error:'), findsOneWidget);
    expect($('SocketException'), findsOneWidget);

    // Verify error was captured
    final requests = $.http.getCapturedRequests();
    final errorRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(errorRequest.isMocked, isTrue);
    expect(errorRequest.error, isNotNull);
    expect(errorRequest.error.toString(), contains('Failed host lookup'));

    $.http.stopInterception();
  });

  patrol('certificate error mock is thrown', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure certificate error mock
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse.certificateError(),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();

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
    expect(errorRequest.error.toString(), contains('CERTIFICATE_VERIFY_FAILED'));

    $.http.stopInterception();
  });

  patrol('error mock with custom error', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure custom error mock
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse.error(Exception('Custom test error')),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();

    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    // Verify error appears in UI
    expect($('Error:'), findsOneWidget);
    expect($('Custom test error'), findsOneWidget);

    // Verify error was captured
    final requests = $.http.getCapturedRequests();
    final errorRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(errorRequest.isMocked, isTrue);
    expect(errorRequest.error, isNotNull);
    expect(errorRequest.error.toString(), contains('Custom test error'));

    $.http.stopInterception();
  });
}
