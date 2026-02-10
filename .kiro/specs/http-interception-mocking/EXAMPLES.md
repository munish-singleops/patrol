# HTTP Interception and Mocking - Usage Examples

## Example 1: Basic Request Capture

```dart
patrolTest('capture login request', ($) async {
  $.http.startInterception();
  
  await $(#emailField).enterText('user@example.com');
  await $(#passwordField).enterText('password123');
  await $(#loginButton).tap();
  
  // Verify the login request was made
  final requests = $.http.getCapturedRequests();
  expect(requests.length, 1);
  expect(requests.first.method, 'POST');
  expect(requests.first.url, contains('/auth/login'));
  
  // Check request body
  final body = requests.first.bodyAsJson;
  expect(body['email'], 'user@example.com');
  
  $.http.stopInterception();
});
```

## Example 2: Mock JSON API Response

```dart
patrolTest('display mocked user data', ($) async {
  $.http.startInterception();
  
  // Mock the API response
  $.http.mock(
    matcher: RequestMatcher.url('https://api.example.com/user/profile'),
    response: MockResponse.json({
      'id': 123,
      'name': 'Test User',
      'email': 'test@example.com',
    }),
  );
  
  await $(#profileButton).tap();
  
  // App displays mocked data
  expect($('Test User'), findsOneWidget);
  expect($('test@example.com'), findsOneWidget);
  
  $.http.stopInterception();
});
```


## Example 3: Test Error Handling

```dart
patrolTest('handle network timeout', ($) async {
  $.http.startInterception();
  
  // Mock a timeout error
  $.http.mock(
    matcher: RequestMatcher.url('https://api.example.com/data'),
    response: MockResponse.timeout(),
  );
  
  await $(#loadDataButton).tap();
  
  // Verify error message is shown
  expect($('Connection timeout'), findsOneWidget);
  expect($('Please try again'), findsOneWidget);
  
  $.http.stopInterception();
});
```

## Example 4: Mock Sequence for Pagination

```dart
patrolTest('paginate through results', ($) async {
  $.http.startInterception();
  
  // Mock sequence of paginated responses
  $.http.mockSequence(
    matcher: RequestMatcher.pattern('*/api/items*'),
    responses: [
      MockResponse.json({'page': 1, 'items': ['Item 1', 'Item 2']}),
      MockResponse.json({'page': 2, 'items': ['Item 3', 'Item 4']}),
      MockResponse.json({'page': 3, 'items': []}),
    ],
  );
  
  await $(#loadItemsButton).tap();
  expect($('Item 1'), findsOneWidget);
  
  await $(#nextPageButton).tap();
  expect($('Item 3'), findsOneWidget);
  
  await $(#nextPageButton).tap();
  expect($('No more items'), findsOneWidget);
  
  $.http.stopInterception();
});
```

## Example 5: Filter Captured Requests

```dart
patrolTest('verify analytics tracking', ($) async {
  $.http.startInterception();
  
  // User performs various actions
  await $(#homeButton).tap();
  await $(#settingsButton).tap();
  await $(#profileButton).tap();
  
  // Filter only analytics requests
  final analyticsRequests = $.http.findRequests(
    RequestMatcher.pattern('*/analytics/*'),
  );
  
  expect(analyticsRequests.length, 3);
  expect(analyticsRequests[0].url, contains('page_view'));
  expect(analyticsRequests[1].url, contains('settings_opened'));
  expect(analyticsRequests[2].url, contains('profile_viewed'));
  
  $.http.stopInterception();
});
```

## Example 6: Verification Helpers

```dart
patrolTest('verify API calls with helpers', ($) async {
  $.http.startInterception();
  
  await $(#loginButton).tap();
  
  // Assert specific request was made
  $.http.expectRequest(
    RequestMatcher.url('https://api.example.com/auth/login'),
    reason: 'Login button should trigger auth API',
  );
  
  // Assert exact count
  $.http.expectRequestCount(
    RequestMatcher.method('POST'),
    1,
    reason: 'Should make exactly one POST request',
  );
  
  // Assert request was NOT made
  $.http.expectNoRequest(
    RequestMatcher.url('https://api.example.com/premium'),
    reason: 'Free users should not access premium endpoint',
  );
  
  $.http.stopInterception();
});
```

## Example 7: Mock with Delay

```dart
patrolTest('show loading indicator during request', ($) async {
  $.http.startInterception();
  
  // Mock response with 2 second delay
  $.http.mock(
    matcher: RequestMatcher.url('https://api.example.com/data'),
    response: MockResponse.json(
      {'data': 'result'},
      delay: Duration(seconds: 2),
    ),
  );
  
  await $(#fetchButton).tap();
  
  // Loading indicator should be visible
  expect($('Loading...'), findsOneWidget);
  
  await $.pump(Duration(seconds: 2));
  
  // Data should now be displayed
  expect($('Loading...'), findsNothing);
  expect($('result'), findsOneWidget);
  
  $.http.stopInterception();
});
```

## Example 8: Test Different HTTP Methods

```dart
patrolTest('capture various HTTP methods', ($) async {
  $.http.startInterception();
  
  // Trigger different types of requests
  await $(#getButton).tap();
  await $(#postButton).tap();
  await $(#putButton).tap();
  await $(#deleteButton).tap();
  
  // Verify each method was used
  final getRequests = $.http.findRequests(RequestMatcher.method('GET'));
  final postRequests = $.http.findRequests(RequestMatcher.method('POST'));
  final putRequests = $.http.findRequests(RequestMatcher.method('PUT'));
  final deleteRequests = $.http.findRequests(RequestMatcher.method('DELETE'));
  
  expect(getRequests.length, 1);
  expect(postRequests.length, 1);
  expect(putRequests.length, 1);
  expect(deleteRequests.length, 1);
  
  $.http.stopInterception();
});
```

## Example 9: Mock Different Status Codes

```dart
patrolTest('handle various HTTP status codes', ($) async {
  $.http.startInterception();
  
  // Mock 404 Not Found
  $.http.mock(
    matcher: RequestMatcher.url('https://api.example.com/missing'),
    response: MockResponse(
      statusCode: 404,
      body: utf8.encode('Not Found'),
    ),
  );
  
  // Mock 500 Server Error
  $.http.mock(
    matcher: RequestMatcher.url('https://api.example.com/error'),
    response: MockResponse(
      statusCode: 500,
      body: utf8.encode('Internal Server Error'),
    ),
  );
  
  await $(#test404Button).tap();
  expect($('Resource not found'), findsOneWidget);
  
  await $(#test500Button).tap();
  expect($('Server error'), findsOneWidget);
  
  $.http.stopInterception();
});
```

## Example 10: Debug with printCapturedRequests

```dart
patrolTest('debug HTTP traffic', ($) async {
  $.http.startInterception();
  
  // Perform test actions
  await $(#loginButton).tap();
  await $(#loadDataButton).tap();
  
  // Print all captured requests for debugging
  $.http.printCapturedRequests();
  
  // Output will show:
  // 📝 Captured Requests (2):
  // 📝 1. POST https://api.example.com/auth/login
  // 📝    Status: 200
  // 📝 2. GET https://api.example.com/data
  // 📝    Status: 200
  
  $.http.stopInterception();
});
```
