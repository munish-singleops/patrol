# HTTP Interception and Mocking Feature

Complete HTTP request capture and mocking system for Patrol tests.

## Quick Start

```dart
patrolTest('my test', ($) async {
  // Start capturing requests
  $.http.startInterception();
  
  // Mock an API response
  $.http.mock(
    matcher: RequestMatcher.url('https://api.example.com/data'),
    response: MockResponse.json({'result': 'success'}),
  );
  
  // Run your test...
  await $(#button).tap();
  
  // Verify requests
  $.http.expectRequest(RequestMatcher.url('https://api.example.com/data'));
  
  // Stop capturing
  $.http.stopInterception();
});
```

## Documentation

- **IMPLEMENTATION_SUMMARY.md** - Complete feature overview and API reference
- **EXAMPLES.md** - 10 practical usage examples
- **HTTP2_ADAPTER_WORKAROUND.md** - Solution for Dio + Http2Adapter compatibility
- **requirements.md** - Detailed requirements and acceptance criteria
- **design.md** - Technical design and architecture
- **tasks.md** - Implementation task breakdown

## Key Features

✅ Capture all HTTP requests (method, URL, headers, body)
✅ Mock responses with custom status, headers, body
✅ Mock errors (timeout, connection refused, DNS failure)
✅ Mock sequences for pagination testing
✅ Filter requests by URL pattern, method, headers
✅ Verification helpers (expectRequest, expectRequestCount)
✅ Works with dart:io, package:http, dio
✅ Pure Dart implementation (no native code)

## Http2Adapter Users

If your app uses Dio with Http2Adapter, simply add one line to your Dio setup:

```dart
import 'package:patrol/patrol.dart';

dio.interceptors.add(PatrolDioInterceptor());
```

See **HTTP2_ADAPTER_WORKAROUND.md** for details.

## Testing

All 73 unit tests pass:
```bash
cd packages/patrol
flutter test test/http_interception/
```

Integration tests in `dev/e2e_app/patrol_test/http_*.dart`

## Status

✅ Core implementation complete
✅ Unit tests passing
✅ Integration tests passing
✅ Ready for production use

Optional tasks (property-based tests, logging, documentation) can be added later.
