import 'package:flutter_test/flutter_test.dart';

import '../custom_finders/patrol_integration_tester.dart';
import 'captured_request.dart';
import 'http_interception_controller.dart';
import 'mock_configuration.dart';
import 'mock_response.dart';
import 'request_matcher.dart';

/// API for HTTP interception and mocking in Patrol tests.
///
/// Access via `$.http` in your Patrol tests.
class HttpInterceptionApi {
  /// Creates a new [HttpInterceptionApi].
  HttpInterceptionApi(this.tester);

  /// The Patrol tester instance.
  final PatrolIntegrationTester tester;

  final HttpInterceptionController _controller =
      HttpInterceptionController.instance;

  /// Starts HTTP interception.
  ///
  /// All HTTP requests made by the app will be captured.
  void startInterception() {
    _controller.startInterception();
    tester.log('HTTP interception started');
  }

  /// Stops HTTP interception.
  ///
  /// Clears the capture log and restores normal HTTP behavior.
  void stopInterception() {
    _controller.stopInterception();
    tester.log('HTTP interception stopped');
  }

  /// Clears the capture log without stopping interception or clearing mocks.
  void clearCaptureLog() {
    _controller.clearCaptureLog();
    tester.log('HTTP capture log cleared');
  }

  /// Clears all mock configurations.
  void clearMocks() {
    _controller.clearMocks();
    tester.log('HTTP mocks cleared');
  }

  /// Configures a mock response for requests matching [matcher].
  ///
  /// Example:
  /// ```dart
  /// $.http.mock(
  ///   matcher: RequestMatcher.url('https://api.example.com/users'),
  ///   response: MockResponse.json({'users': []}),
  /// );
  /// ```
  void mock({
    required RequestMatcher matcher,
    required MockResponse response,
    bool repeatLast = true,
  }) {
    final config = MockConfiguration(
      matcher: matcher,
      response: response,
      repeatLast: repeatLast,
    );
    _controller.addMock(config);
    tester.log('Mock configured for ${matcher.description}');
  }

  /// Configures a sequence of mock responses for requests matching [matcher].
  ///
  /// Each subsequent request will receive the next response in the sequence.
  ///
  /// Example:
  /// ```dart
  /// $.http.mockSequence(
  ///   matcher: RequestMatcher.url('https://api.example.com/page'),
  ///   responses: [
  ///     MockResponse.json({'page': 1, 'items': [...]}),
  ///     MockResponse.json({'page': 2, 'items': [...]}),
  ///     MockResponse.json({'page': 3, 'items': []}),
  ///   ],
  /// );
  /// ```
  void mockSequence({
    required RequestMatcher matcher,
    required List<MockResponse> responses,
    bool repeatLast = true,
  }) {
    for (var i = 0; i < responses.length; i++) {
      final isLast = i == responses.length - 1;
      mock(
        matcher: matcher,
        response: responses[i],
        repeatLast: isLast && repeatLast,
      );
    }
    tester.log(
      'Mock sequence configured for ${matcher.description} '
      '(${responses.length} responses)',
    );
  }

  /// Resets a mock sequence so it can be reused from the beginning.
  void resetMockSequence(RequestMatcher matcher) {
    _controller.resetMockSequence(matcher);
    tester.log('Mock sequence reset for ${matcher.description}');
  }

  /// Returns all captured requests in chronological order.
  List<CapturedRequest> getCapturedRequests() {
    return _controller.getCapturedRequests();
  }

  /// Finds requests matching the given [matcher].
  List<CapturedRequest> findRequests(RequestMatcher matcher) {
    return _controller.findRequests(matcher);
  }

  /// Asserts that at least one request matching [matcher] was captured.
  ///
  /// Throws [TestFailure] if no matching request is found.
  void expectRequest(RequestMatcher matcher, {String? reason}) {
    final requests = findRequests(matcher);
    if (requests.isEmpty) {
      final message = StringBuffer()
        ..writeln(
          'Expected to find request matching ${matcher.description}, '
          'but found none.',
        );
      if (reason != null) {
        message.writeln('Reason: $reason');
      }
      message.writeln(
        'Captured ${_controller.getCapturedRequests().length} requests total.',
      );
      throw TestFailure(message.toString());
    }
  }

  /// Asserts that exactly [count] requests matching [matcher] were captured.
  ///
  /// Throws [TestFailure] if the count doesn't match.
  void expectRequestCount(
    RequestMatcher matcher,
    int count, {
    String? reason,
  }) {
    final requests = findRequests(matcher);
    if (requests.length != count) {
      final message = StringBuffer()
        ..writeln(
          'Expected $count requests matching ${matcher.description}, '
          'but found ${requests.length}.',
        );
      if (reason != null) {
        message.writeln('Reason: $reason');
      }
      throw TestFailure(message.toString());
    }
  }

  /// Asserts that no requests matching [matcher] were captured.
  ///
  /// Throws [TestFailure] if any matching request is found.
  void expectNoRequest(RequestMatcher matcher, {String? reason}) {
    final requests = findRequests(matcher);
    if (requests.isNotEmpty) {
      final message = StringBuffer()
        ..writeln(
          'Expected no requests matching ${matcher.description}, '
          'but found ${requests.length}.',
        );
      if (reason != null) {
        message.writeln('Reason: $reason');
      }
      throw TestFailure(message.toString());
    }
  }

  /// Prints all captured requests to the console for debugging.
  void printCapturedRequests() {
    final requests = getCapturedRequests();
    // Using print for debugging output - this is intentional for test debugging
    // ignore: avoid_print
    print('=== Captured HTTP Requests (${requests.length}) ===');
    for (var i = 0; i < requests.length; i++) {
      final req = requests[i];
      // Debug output for test inspection
      // ignore: avoid_print
      print('[$i] ${req.method} ${req.url}');
      // ignore: avoid_print
      print('    Status: ${req.response?.statusCode ?? "pending"}');
      // ignore: avoid_print
      print('    Mocked: ${req.isMocked}');
      // ignore: avoid_print
      print('    Time: ${req.timestamp}');
    }
  }
}
