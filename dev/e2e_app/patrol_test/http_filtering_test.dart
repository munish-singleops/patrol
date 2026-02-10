import 'package:e2e_app/keys.dart';
import 'package:patrol/src/http_interception/request_matcher.dart';

import 'common.dart';

void main() {
  patrol('findRequests filters by exact URL', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make multiple requests
    await $(K.multipleRequestsButton).tap();
    await $.pumpAndSettle();

    await Future.delayed(const Duration(seconds: 2));
    await $.pumpAndSettle();

    // Filter by exact URL
    final user1Requests = $.http.findRequests(
      RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
    );

    expect(user1Requests.length, 1);
    expect(user1Requests.first.url, 'https://jsonplaceholder.typicode.com/users/1');

    $.http.stopInterception();
  });

  patrol('findRequests filters by pattern', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make multiple requests
    await $(K.multipleRequestsButton).tap();
    await $.pumpAndSettle();

    await Future.delayed(const Duration(seconds: 2));
    await $.pumpAndSettle();

    // Filter by pattern
    final userRequests = $.http.findRequests(
      RequestMatcher.pattern('*/users/*'),
    );

    expect(userRequests.length, greaterThanOrEqualTo(2));
    for (final req in userRequests) {
      expect(req.url, contains('/users/'));
    }

    $.http.stopInterception();
  });

  patrol('findRequests filters by method', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Make POST request
    await $(K.postRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Filter by method
    final getRequests = $.http.findRequests(RequestMatcher.method('GET'));
    final postRequests = $.http.findRequests(RequestMatcher.method('POST'));

    expect(getRequests.length, greaterThanOrEqualTo(1));
    expect(postRequests.length, greaterThanOrEqualTo(1));

    for (final req in getRequests) {
      expect(req.method, 'GET');
    }
    for (final req in postRequests) {
      expect(req.method, 'POST');
    }

    $.http.stopInterception();
  });

  patrol('findRequests filters by host', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make requests
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Filter by host
    final jsonPlaceholderRequests = $.http.findRequests(
      RequestMatcher.host('jsonplaceholder.typicode.com'),
    );

    expect(jsonPlaceholderRequests.length, greaterThanOrEqualTo(1));
    for (final req in jsonPlaceholderRequests) {
      expect(req.url, contains('jsonplaceholder.typicode.com'));
    }

    $.http.stopInterception();
  });

  patrol('clearCaptureLog removes captured requests', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Verify requests were captured
    final requestsBefore = $.http.getCapturedRequests();
    expect(requestsBefore.length, greaterThan(0));

    // Clear capture log
    $.http.clearCaptureLog();

    // Verify log is empty
    final requestsAfter = $.http.getCapturedRequests();
    expect(requestsAfter.length, 0);

    $.http.stopInterception();
  });
}
