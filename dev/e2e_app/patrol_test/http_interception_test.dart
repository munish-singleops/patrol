import 'package:e2e_app/keys.dart';

import 'common.dart';

void main() {
  patrol('basic HTTP interception captures request data', ($) async {
    await createApp($);

    // Start HTTP interception
    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make a GET request
    await $(K.getRequestButton).tap();
    await $.pumpAndSettle();

    // Wait for response
    await Future.delayed(const Duration(seconds: 2));
    await $.pumpAndSettle();

    // Verify request was captured
    final requests = $.http.getCapturedRequests();
    expect(requests.length, greaterThan(0));

    // Find the specific request
    final capturedRequest = requests.firstWhere(
      (r) => r.url.contains('jsonplaceholder.typicode.com/users/1'),
    );

    // Verify request data
    expect(capturedRequest.method, 'GET');
    expect(capturedRequest.url, contains('jsonplaceholder.typicode.com'));
    expect(capturedRequest.url, contains('/users/1'));
    expect(capturedRequest.headers, isNotEmpty);
    expect(capturedRequest.timestamp, isNotNull);

    // Verify response was captured
    expect(capturedRequest.response, isNotNull);
    expect(capturedRequest.response!.statusCode, 200);
    expect(capturedRequest.response!.body, isNotEmpty);

    $.http.stopInterception();
  });

  patrol('POST request capture includes body and headers', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make a POST request
    await $(K.postRequestButton).tap();
    await $.pumpAndSettle();

    // Wait for response
    await Future.delayed(const Duration(seconds: 2));
    await $.pumpAndSettle();

    // Find the POST request
    final requests = $.http.getCapturedRequests();
    final postRequest = requests.firstWhere(
      (r) => r.method == 'POST' && r.url.contains('/posts'),
    );

    // Verify POST-specific data
    expect(postRequest.method, 'POST');
    expect(postRequest.headers['content-type'], contains('application/json'));
    expect(postRequest.bodyAsString, isNotEmpty);

    // Verify body can be parsed as JSON
    final bodyJson = postRequest.bodyAsJson;
    expect(bodyJson['title'], 'Test Post');
    expect(bodyJson['body'], 'This is a test');
    expect(bodyJson['userId'], 1);

    $.http.stopInterception();
  });

  patrol('multiple requests are captured in order', ($) async {
    await createApp($);

    $.http.startInterception();

    // Navigate to HTTP screen
    await $('Open HTTP test screen').tap();
    await $.pumpAndSettle();

    // Make multiple requests
    await $(K.multipleRequestsButton).tap();
    await $.pumpAndSettle();

    // Wait for all responses
    await Future.delayed(const Duration(seconds: 3));
    await $.pumpAndSettle();

    // Verify all requests were captured
    final requests = $.http.getCapturedRequests();
    final relevantRequests = requests.where(
      (r) => r.url.contains('jsonplaceholder.typicode.com'),
    ).toList();

    expect(relevantRequests.length, greaterThanOrEqualTo(3));

    // Verify chronological order (timestamps should be increasing)
    for (var i = 1; i < relevantRequests.length; i++) {
      expect(
        relevantRequests[i].timestamp.isAfter(relevantRequests[i - 1].timestamp) ||
            relevantRequests[i].timestamp.isAtSameMomentAs(relevantRequests[i - 1].timestamp),
        isTrue,
      );
    }

    $.http.stopInterception();
  });
}
