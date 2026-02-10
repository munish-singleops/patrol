import 'package:e2e_app/keys.dart';
import 'package:patrol/src/http_interception/request_matcher.dart';

import 'common.dart';

void main() {
  patrol('expectRequest passes when request exists', ($) async {
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

    // Verify request was made
    $.http.expectRequest(
      RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      reason: 'GET request should have been made',
    );

    $.http.stopInterception();
  });

  patrol('expectRequest fails when request does not exist', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make request to different URL
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Verify expectRequest throws for non-existent request
    expect(
      () => $.http.expectRequest(
        RequestMatcher.url('https://example.com/nonexistent'),
      ),
      throwsA(isA<TestFailure>()),
    );

    $.http.stopInterception();
  });

  patrol('expectRequestCount passes with correct count', ($) async {
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

    // Verify exact count
    $.http.expectRequestCount(
      RequestMatcher.pattern('*/users/*'),
      2,
      reason: 'Should have made 2 user requests',
    );

    $.http.stopInterception();
  });

  patrol('expectRequestCount fails with incorrect count', ($) async {
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

    // Verify expectRequestCount throws for wrong count
    expect(
      () => $.http.expectRequestCount(
        RequestMatcher.pattern('*/users/*'),
        5,
      ),
      throwsA(isA<TestFailure>()),
    );

    $.http.stopInterception();
  });

  patrol('expectNoRequest passes when request does not exist', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make request to specific URL
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();
    await Future.delayed(const Duration(seconds: 1));
    await $.pumpAndSettle();

    // Verify no request to different URL
    $.http.expectNoRequest(
      RequestMatcher.url('https://example.com/nonexistent'),
      reason: 'Should not have made request to example.com',
    );

    $.http.stopInterception();
  });

  patrol('expectNoRequest fails when request exists', ($) async {
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

    // Verify expectNoRequest throws when request exists
    expect(
      () => $.http.expectNoRequest(
        RequestMatcher.url('https://jsonplaceholder.typicode.com/users/1'),
      ),
      throwsA(isA<TestFailure>()),
    );

    $.http.stopInterception();
  });

  patrol('printCapturedRequests outputs debug info', ($) async {
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

    // Print captured requests (for manual verification in logs)
    $.http.printCapturedRequests();

    // Just verify it doesn't throw
    expect($.http.getCapturedRequests().length, greaterThan(0));

    $.http.stopInterception();
  });
}
