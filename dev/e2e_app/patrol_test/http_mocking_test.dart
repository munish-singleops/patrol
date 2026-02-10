import 'package:e2e_app/keys.dart';
import 'package:patrol/src/http_interception/mock_response.dart';
import 'package:patrol/src/http_interception/request_matcher.dart';

import 'common.dart';

void main() {
  patrol('mock JSON response is returned to app', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure mock response
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse.json({
        'id': 1,
        'name': 'Mocked User',
        'email': 'mocked@example.com',
      }),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();

    // Wait for response
    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    // Verify mocked data appears in UI
    expect($('Mocked User'), findsOneWidget);
    expect($('mocked@example.com'), findsOneWidget);

    // Verify request was marked as mocked
    final requests = $.http.getCapturedRequests();
    final mockedRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(mockedRequest.isMocked, isTrue);
    expect(mockedRequest.response!.statusCode, 200);

    $.http.stopInterception();
  });

  patrol('mock response with custom status code and headers', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure mock with custom status and headers
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse(
        statusCode: 201,
        headers: {'X-Custom-Header': 'test-value'},
        body: '{"id": 1, "name": "Custom Mock"}',
      ),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();

    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    // Verify custom status code
    final requests = $.http.getCapturedRequests();
    final mockedRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );
    expect(mockedRequest.response!.statusCode, 201);
    expect(mockedRequest.response!.headers['x-custom-header'], 'test-value');

    $.http.stopInterception();
  });

  patrol('wildcard pattern matching works', ($) async {
    await createApp($);

    $.http.startInterception();

    // Mock all requests to /users/* endpoints
    $.http.mock(
      matcher: RequestMatcher.pattern('*/users/*'),
      response: MockResponse.json({'mocked': true}),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make multiple requests
    await $(K.multipleRequestsButton).tap();
    await $.pumpAndSettle();

    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Verify user requests were mocked
    final requests = $.http.getCapturedRequests();
    final userRequests = requests.where(
      (r) => r.url.contains('/users/'),
    ).toList();

    expect(userRequests.length, greaterThanOrEqualTo(2));
    for (final req in userRequests) {
      expect(req.isMocked, isTrue);
    }

    // Verify posts request was NOT mocked (doesn't match pattern)
    final postRequests = requests.where(
      (r) => r.url.contains('/posts/'),
    ).toList();
    if (postRequests.isNotEmpty) {
      expect(postRequests.first.isMocked, isFalse);
    }

    $.http.stopInterception();
  });

  patrol('method filtering works', ($) async {
    await createApp($);

    $.http.startInterception();

    // Mock only POST requests
    $.http.mock(
      matcher: RequestMatcher.method('POST'),
      response: MockResponse.json({'mocked': 'POST'}),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make GET request - should NOT be mocked
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Make POST request - should be mocked
    await $(K.postRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    final requests = $.http.getCapturedRequests();
    
    final getRequest = requests.firstWhere((r) => r.method == 'GET');
    expect(getRequest.isMocked, isFalse);

    final postRequest = requests.firstWhere((r) => r.method == 'POST');
    expect(postRequest.isMocked, isTrue);

    $.http.stopInterception();
  });

  patrol('clearMocks removes mock configurations', ($) async {
    await createApp($);

    $.http.startInterception();

    // Configure mock
    $.http.mock(
      matcher: RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      response: MockResponse.json({'mocked': true}),
    );

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // First request should be mocked
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(milliseconds: 500));
    await $.pumpAndSettle();

    final firstRequests = $.http.getCapturedRequests();
    expect(firstRequests.first.isMocked, isTrue);

    // Clear mocks
    $.http.clearMocks();
    $.http.clearCaptureLog();

    // Second request should NOT be mocked
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    final secondRequests = $.http.getCapturedRequests();
    expect(secondRequests.first.isMocked, isFalse);

    $.http.stopInterception();
  });
}
