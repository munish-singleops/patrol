import '../custom_finders/patrol_integration_tester.dart';
import 'http_interception_api.dart';

/// Extension on [PatrolIntegrationTester] to provide HTTP interception API.
extension HttpInterceptionExtension on PatrolIntegrationTester {
  /// Access HTTP interception and mocking capabilities.
  ///
  /// Example:
  /// ```dart
  /// patrolTest('test with HTTP mocking', ($) async {
  ///   $.http.startInterception();
  ///   
  ///   $.http.mock(
  ///     matcher: RequestMatcher.url('https://api.example.com/users'),
  ///     response: MockResponse.json({'users': []}),
  ///   );
  ///   
  ///   // Your test code...
  ///   
  ///   $.http.expectRequest(RequestMatcher.url('https://api.example.com/users'));
  /// });
  /// ```
  HttpInterceptionApi get http => HttpInterceptionApi(this);
}
