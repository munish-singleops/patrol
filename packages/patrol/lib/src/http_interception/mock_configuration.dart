import 'mock_response.dart';
import 'request_matcher.dart';

/// Internal representation of a mock configuration.
///
/// Pairs a [RequestMatcher] with a [MockResponse] and tracks usage.
class MockConfiguration {
  /// Creates a new [MockConfiguration].
  MockConfiguration({
    required this.matcher,
    required this.response,
    this.repeatLast = true,
  });

  /// The matcher that determines which requests this mock applies to.
  final RequestMatcher matcher;

  /// The response to return for matching requests.
  final MockResponse response;

  /// Whether to repeat the last response when sequence is exhausted.
  /// If false, requests will pass through to the real network.
  final bool repeatLast;

  var _used = false;

  /// Whether this mock has been used.
  bool get used => _used;

  /// Marks this mock as used.
  void markUsed() => _used = true;

  /// Resets the used flag.
  void reset() => _used = false;
}
