# Implementation Plan: HTTP Interception and Mocking

## Overview

This implementation plan breaks down the HTTP interception and mocking feature into discrete coding tasks. The implementation follows a pure Dart approach using `HttpOverrides` to intercept HTTP requests at the Dart VM level, requiring no native platform code. Tasks are ordered to build incrementally, with testing integrated throughout.

## Tasks

- [x] 1. Set up core data models and types
  - Create `CapturedRequest` class with all request fields (method, URL, headers, body, timestamp)
  - Create `CapturedResponse` class with all response fields (status code, headers, body, timestamp, error)
  - Create `RequestMatcher` class with matching logic (exact URL, pattern, regex, method, headers, host)
  - Create `MockResponse` class with convenience constructors (ok, json, error, timeout, connectionRefused)
  - Create `MockConfiguration` class to pair matchers with responses
  - Add convenience methods to `CapturedRequest` and `CapturedResponse` (bodyAsString, bodyAsJson, bodyAsFormData)
  - _Requirements: 1.2, 1.3, 1.4, 1.5, 2.1, 2.2, 2.3, 3.1, 3.2, 3.3, 3.4, 3.5, 3.6, 4.2, 4.3, 4.4, 4.5, 4.6, 15.1, 15.2, 15.4, 15.5_

- [ ]* 1.1 Write property tests for RequestMatcher
  - **Property 5: Exact URL Matching** - For any request matcher configured with an exact URL, only requests with URLs that exactly match should be intercepted
  - **Property 6: Wildcard Pattern Matching** - For any request matcher with wildcard pattern, matching URLs should be intercepted
  - **Property 7: Regex URL Matching** - For any request matcher with regex, matching URLs should be intercepted
  - **Property 8: HTTP Method Filtering** - For any request matcher with method filter, only matching methods should be intercepted
  - **Property 9: Header Filtering** - For any request matcher with header filters, only requests with matching headers should be intercepted
  - **Property 10: Host Filtering** - For any request matcher with host filter, only matching hosts should be intercepted
  - **Validates: Requirements 3.1, 3.2, 3.3, 3.4, 3.5, 3.6**

- [ ]* 1.2 Write property tests for body parsing methods
  - **Property 36: Request Body Parsing** - For any captured request with a body, parsing should succeed in the correct format and throw FormatException for mismatches
  - **Validates: Requirements 15.1, 15.2, 15.4, 15.5, 15.6**

- [x] 2. Implement HttpInterceptionController
  - [x] 2.1 Create singleton HttpInterceptionController class
    - Implement lifecycle methods (startInterception, stopInterception, reset)
    - Implement capture log storage and access (getCapturedRequests, clearCaptureLog)
    - Implement mock configuration storage (addMock, clearMocks, findMatchingMock)
    - Implement request filtering (findRequests with RequestMatcher)
    - Add isActive state tracking
    - _Requirements: 1.1, 1.7, 3.7, 3.8, 5.1, 5.2, 5.3, 5.4, 5.5, 13.1, 13.2, 13.3, 13.5, 13.6_

  - [ ]* 2.2 Write property tests for HttpInterceptionController
    - **Property 12: Default Intercept All Behavior** - For any request when no matchers configured, request should be intercepted
    - **Property 11: Multiple Matcher OR Logic** - For any set of matchers, request matching any should be intercepted
    - **Property 18: Chronological Capture Order** - For any sequence of requests, capture log should return them in chronological order
    - **Property 19: Capture Log Filtering** - For any capture log query with filters, all returned requests should match criteria
    - **Property 31: Capture Log Clearing Preserves Mocks** - Clearing capture log should remove requests but preserve mocks
    - **Property 32: Interception Accumulation** - Enabling multiple times should accumulate captures
    - **Property 33: Interception Deactivation Cleanup** - Disabling should stop capturing and clear log
    - **Validates: Requirements 3.7, 3.8, 5.2, 5.3, 5.4, 5.5, 13.3, 13.5, 13.6**

- [x] 3. Implement HTTP client wrappers
  - [x] 3.1 Create PatrolHttpOverrides class
    - Extend HttpOverrides
    - Override createHttpClient to return PatrolHttpClient
    - Store reference to HttpInterceptionController
    - _Requirements: 1.1, 7.1, 7.2, 7.3, 7.4, 8.1, 8.2, 8.3, 8.4, 8.5_

  - [x] 3.2 Create PatrolHttpClient class
    - Implement HttpClient interface
    - Wrap inner HttpClient instance
    - Override openUrl to return PatrolHttpClientRequest
    - Delegate all other methods to inner client
    - _Requirements: 1.1, 8.6_

  - [x] 3.3 Create PatrolHttpClientRequest class
    - Implement HttpClientRequest interface
    - Capture request data (method, URL, headers, body bytes)
    - Override close() to check for mocks and create responses
    - Implement mock response creation with delay support
    - Record captures to controller
    - Delegate all other methods to inner request
    - _Requirements: 1.2, 1.3, 1.4, 1.5, 1.6, 4.1, 4.7, 4.9_

  - [x] 3.4 Create PatrolHttpClientResponse class
    - Implement HttpClientResponse interface as Stream
    - Wrap inner HttpClientResponse
    - Capture response body bytes in listen()
    - Record complete capture when response done
    - Delegate all properties to inner response
    - _Requirements: 2.1, 2.2, 2.3, 2.4, 2.5_

  - [x] 3.5 Create MockHttpClientResponse class
    - Implement HttpClientResponse interface for mocked responses
    - Return configured status code, headers, and body
    - Support streaming body bytes
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5, 4.6_

  - [ ]* 3.6 Write property tests for request/response capture
    - **Property 1: Complete Request Capture** - For any request when interception enabled, captured request should contain all data
    - **Property 2: Complete Response Capture** - For any response, captured response should contain all data and be associated with request
    - **Property 3: Interception Transparency When Disabled** - For any request when disabled, request should proceed without capture
    - **Property 20: Captured Request Data Completeness** - For any captured request, all fields should be accessible
    - **Property 21: Captured Response Data Completeness** - For any captured response, all fields should be accessible
    - **Validates: Requirements 1.1, 1.2, 1.3, 1.4, 1.5, 1.6, 1.7, 2.1, 2.2, 2.3, 2.4, 2.5, 5.6, 5.7**

- [x] 4. Checkpoint - Ensure basic interception works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 5. Implement mock response functionality
  - [x] 5.1 Add mock matching logic to PatrolHttpClientRequest
    - Query controller for matching mock in close()
    - Return mock response if found
    - Apply mock precedence (most recent wins)
    - Support mock response delays
    - _Requirements: 4.1, 4.8, 4.9_

  - [x] 5.2 Implement error mock responses
    - Add error field to MockResponse
    - Create convenience constructors for timeout, connectionRefused, DNS failure, SSL errors
    - Throw configured errors in PatrolHttpClientRequest
    - Record error mocks in capture log
    - _Requirements: 2.6, 14.1, 14.2, 14.3, 14.4, 14.5, 14.6_

  - [x] 5.3 Implement mock sequence support
    - Track mock usage in MockConfiguration
    - Support multiple mocks for same matcher
    - Implement sequence exhaustion behavior (repeat last or passthrough)
    - Add sequence reset functionality
    - _Requirements: 11.1, 11.2, 11.3_

  - [ ]* 5.4 Write property tests for mock responses
    - **Property 13: Mock Response Substitution** - For any request matching a mock, mock response should be returned without real network traffic
    - **Property 14: Mock Response Configuration Completeness** - For any mock configured with status/headers/body, returned response should match exactly
    - **Property 15: Mocked Request Capture** - For any mocked request, it should be recorded with isMocked=true
    - **Property 16: Mock Precedence** - For any request matching multiple mocks, most recent should be used
    - **Property 17: Mock Response Delay** - For any mock with delay, response time should be at least the delay duration
    - **Property 28: Mock Sequence Ordering** - For any matcher with multiple mocks, responses should be returned in order
    - **Property 29: Mock Sequence Exhaustion Behavior** - For any exhausted sequence, behavior should match configuration
    - **Property 30: Mock Sequence Reset** - For any consumed sequence, reset should restart from first mock
    - **Validates: Requirements 4.1, 4.2, 4.3, 4.4, 4.5, 4.6, 4.7, 4.8, 4.9, 11.1, 11.2, 11.3**

  - [ ]* 5.5 Write property tests for error mocks
    - **Property 4: Error Capture** - For any request failing with network error, error should be captured
    - **Property 34: Error Mock Configuration** - For any error mock, matching request should throw specified error
    - **Property 35: Error Mock Capture** - For any error mock, request and error should be recorded in capture log
    - **Validates: Requirements 2.6, 14.1, 14.2, 14.3, 14.4, 14.5, 14.6**

- [ ] 6. Implement conditional mock responses
  - [ ] 6.1 Create ConditionalMockResponse class
    - Define MockResponseCallback typedef
    - Extend MockResponse with callback support
    - Implement callback invocation with captured request
    - Handle callback return values (MockResponse, null)
    - Handle callback errors
    - _Requirements: 16.1, 16.2, 16.3, 16.4, 16.5, 16.6_

  - [ ] 6.2 Integrate conditional mocks into mock matching
    - Check for ConditionalMockResponse in findMatchingMock
    - Invoke callback with request data
    - Use returned response or passthrough on null
    - Propagate callback errors
    - _Requirements: 16.2, 16.3, 16.4, 16.5_

  - [ ]* 6.3 Write property tests for conditional mocks
    - **Property 37: Conditional Mock Callback Invocation** - For any callback mock, callback should be invoked with complete request data
    - **Property 38: Conditional Mock Response Handling** - For any callback return value, behavior should match (use response, passthrough, propagate error)
    - **Validates: Requirements 16.2, 16.3, 16.4, 16.5, 16.6**

- [x] 7. Implement test API extension
  - [x] 7.1 Create HttpInterceptionApi class
    - Implement startInterception() and stopInterception()
    - Implement clearCaptureLog() and clearMocks()
    - Implement mock() and mockSequence() methods
    - Implement getCapturedRequests() and findRequests()
    - Implement verification helpers (expectRequest, expectRequestCount, expectNoRequest)
    - Implement printCapturedRequests() for debugging
    - Integrate with PatrolLogWriter for logging
    - _Requirements: 5.1, 5.2, 5.3, 5.4, 5.5, 6.1, 6.4, 10.4, 12.1, 12.2, 12.3, 12.4, 12.5_

  - [x] 7.2 Create HttpInterceptionExtension on PatrolIntegrationTester
    - Add http getter returning HttpInterceptionApi
    - Ensure integration with existing $ parameter
    - _Requirements: 6.1_

  - [ ]* 7.3 Write unit tests for verification helpers
    - Test expectRequest with matching and non-matching requests
    - Test expectRequestCount with various counts
    - Test expectNoRequest with present and absent requests
    - Verify error messages are detailed and helpful
    - _Requirements: 12.1, 12.2, 12.3, 12.6_

- [ ] 8. Implement logging and observability
  - [ ] 8.1 Add logging to HttpInterceptionController
    - Log when interception starts/stops
    - Log each intercepted request (URL and method)
    - Log when mock responses are returned
    - Log internal errors with context
    - Support verbose mode for header logging
    - _Requirements: 10.1, 10.2, 10.5, 10.6_

  - [ ] 8.2 Add logging to HttpInterceptionApi
    - Log mock configurations
    - Log capture log operations
    - Integrate with Patrol's logging system
    - _Requirements: 10.1, 10.2_

  - [ ]* 8.3 Write property tests for logging
    - **Property 25: Request Interception Logging** - For any intercepted request, log should contain URL and method
    - **Property 26: Mock Response Logging** - For any mocked response, log should indicate mocking
    - **Property 27: Verbose Header Logging** - For any request with verbose logging, headers should be in log output
    - **Validates: Requirements 10.1, 10.2, 10.5, 10.6**

- [ ] 9. Implement error handling and resilience
  - [ ] 9.1 Add error handling to HTTP wrappers
    - Wrap all interception logic in try-catch
    - Log errors and allow requests to proceed on internal errors
    - Provide clear error messages for configuration errors
    - Validate mock configurations and throw ArgumentError for invalid configs
    - _Requirements: 6.5, 9.5, 9.6_

  - [ ] 9.2 Add format validation to body parsing methods
    - Throw FormatException with clear messages for format mismatches
    - Include context in error messages (what was expected vs what was found)
    - _Requirements: 15.6_

  - [ ]* 9.3 Write property tests for error handling
    - **Property 22: Error Message Clarity** - For any error, message should clearly indicate cause and context
    - **Property 24: Error Resilience** - For any internal error, error should be logged and request should proceed
    - **Validates: Requirements 6.5, 9.5, 9.6, 12.6**

- [ ] 10. Checkpoint - Ensure all core functionality works
  - Ensure all tests pass, ask the user if questions arise.

- [x] 11. Create integration tests in e2e_app
  - [x] 11.1 Add HTTP test screen to e2e_app
    - Create screen with buttons that trigger HTTP requests
    - Use package:http for requests
    - Display request/response data in UI
    - _Requirements: 7.1, 7.2, 7.3, 7.4, 8.1, 8.2_

  - [x] 11.2 Write Patrol test for basic interception
    - Start interception
    - Trigger HTTP request from app
    - Verify request is captured
    - Verify all request data is present
    - _Requirements: 1.1, 1.2, 1.3, 1.4, 1.5, 1.6_

  - [x] 11.3 Write Patrol test for mock responses
    - Configure mock response
    - Trigger HTTP request from app
    - Verify mock response is returned
    - Verify app displays mocked data
    - _Requirements: 4.1, 4.2, 4.3, 4.4, 4.5_

  - [x] 11.4 Write Patrol test for error mocking
    - Configure error mock (timeout)
    - Trigger HTTP request from app
    - Verify app handles error correctly
    - _Requirements: 14.1, 14.5_

  - [x] 11.5 Write Patrol test for request filtering
    - Make multiple requests to different endpoints
    - Use findRequests with various matchers
    - Verify filtering works correctly
    - _Requirements: 5.3, 5.4, 5.5_

  - [x] 11.6 Write Patrol test for verification helpers
    - Use expectRequest, expectRequestCount, expectNoRequest
    - Verify they work correctly in real test scenarios
    - _Requirements: 12.1, 12.2, 12.3_

  - [x] 11.7 Test with dio package
    - Add dio dependency to e2e_app
    - Create screen that uses dio for requests
    - Verify interception works with dio
    - _Requirements: 8.3_

  - [ ]* 11.8 Write property test for multi-client interception
    - **Property 23: Multi-Client Interception** - For any requests using different HTTP clients, all should be intercepted
    - **Validates: Requirements 8.6**

- [ ] 12. Add documentation and examples
  - [ ] 12.1 Create API documentation
    - Document HttpInterceptionApi methods
    - Document RequestMatcher constructors and usage
    - Document MockResponse constructors and usage
    - Add code examples for common scenarios
    - _Requirements: 6.1, 6.2, 6.3_

  - [ ] 12.2 Create usage examples
    - Example: Basic request capture and verification
    - Example: Mocking JSON API responses
    - Example: Testing error handling with error mocks
    - Example: Using conditional mocks for dynamic scenarios
    - Example: Mock sequences for pagination testing
    - _Requirements: 6.1, 6.2, 6.3_

  - [ ] 12.3 Document limitations
    - Clearly state WebSocket interception is not supported
    - Document that this applies only to HTTP/HTTPS requests
    - Note any platform-specific considerations
    - _Requirements: 17.1, 17.2, 17.3_

- [ ] 13. Final checkpoint - Ensure all tests pass
  - Ensure all tests pass, ask the user if questions arise.

## Notes

- Tasks marked with `*` are optional and can be skipped for faster MVP
- Each task references specific requirements for traceability
- Property tests validate universal correctness properties with minimum 100 iterations
- Unit tests validate specific examples and edge cases
- Integration tests verify end-to-end behavior across platforms
- The implementation uses pure Dart (HttpOverrides) so no native platform code is needed
- All property tests should be tagged with: **Feature: http-interception-mocking, Property {N}: {description}**
