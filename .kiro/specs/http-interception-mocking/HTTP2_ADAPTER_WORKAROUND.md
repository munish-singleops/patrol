# Patrol HTTP Interception with Http2Adapter - Quick Guide

## Problem Statement

**Issue**: Patrol's `$.http.startInterception()` only captures HTTP requests that go through `dart:io HttpClient`. Apps using Dio with `Http2Adapter` bypass the standard HttpClient, so their API requests are NOT captured by Patrol's interception.

**Symptoms**:
- `$.http.getCapturedRequests()` returns very few or no requests
- Only requests from packages that use standard HttpClient are captured (e.g., LaunchDarkly)
- Main app API requests (using Dio + Http2Adapter) are missing from capture log

## Root Cause

Patrol's HTTP interception works by installing a global `HttpOverrides` that intercepts `HttpClient` creation at the Dart VM level. However, `Http2Adapter` uses its own HTTP/2 implementation that doesn't go through `dart:io HttpClient`, so it's invisible to Patrol's interception mechanism.

## Solution: PatrolDioInterceptor (Built-in)

Patrol now includes a built-in Dio interceptor that works at the Dio level, compatible with ANY adapter including Http2Adapter.

### Step 1: Add Interceptor to Your Dio Instance

Simply add the `PatrolDioInterceptor` to your Dio instances:

```dart
import 'package:patrol/patrol.dart';

Dio _buildDio() {
  final dio = Dio(baseOptions);
  
  // Keep your existing adapter (Http2Adapter works fine!)
  dio.httpClientAdapter = Http2Adapter(
    ConnectionManager(
      idleTimeout: const Duration(seconds: 15),
      onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
    ),
  );
  
  // Add Patrol interceptor for test support
  dio.interceptors.add(PatrolDioInterceptor());
  
  return dio;
}
```

### Step 2: Use in Patrol Tests

```dart
patrolTest('Login with Credentials and Logout Tests', ($) async {
  // Start interception
  $.http.startInterception();
  
  // Initialize and launch app
  Pages.initialize($);
  await launchApp(Pages.$);
  
  // Run your test - requests will be captured!
  await Pages.login.verifyEasySignInPage();
  await Pages.login.navigateToUsernameAndPasswordLoginPage();
  await Pages.login.loginWithUsernameAndPassword();
  
  // Verify requests were captured
  final requests = $.http.getCapturedRequests();
  $.log('Total requests captured: ${requests.length}');
  for (final request in requests) {
    $.log('Request: ${request.method} ${request.url}');
  }
  
  // Cleanup
  $.http.stopInterception();
});
```

### Advantages
- ✅ Works with Http2Adapter (no adapter switching needed)
- ✅ One line of code to add: `dio.interceptors.add(PatrolDioInterceptor())`
- ✅ Captures ALL Dio requests regardless of adapter
- ✅ Supports full mocking capabilities
- ✅ Production code unchanged
- ✅ Built into Patrol (no copying code needed)

## Alternative Solution: Adapter Switching

If you prefer not to add the interceptor, you can switch adapters during tests. This approach is more complex and requires app code changes.

## Implementation Steps

### Step 1: Create Test Configuration Flag

Create `lib/src/config/patrol_test_config.dart`:

```dart
/// Configuration flag for Patrol integration tests.
/// 
/// When true, the app will use IOHttpClientAdapter instead of Http2Adapter
/// for Dio, allowing Patrol's HTTP interception to capture requests.
bool _useInterceptableHttpAdapterForPatrol = false;

/// Returns whether to use an interceptable HTTP adapter for Patrol tests.
bool get useInterceptableHttpAdapterForPatrol => _useInterceptableHttpAdapterForPatrol;

/// Sets whether to use an interceptable HTTP adapter for Patrol tests.
/// 
/// Call this with `true` BEFORE app initialization in Patrol tests that need
/// to capture HTTP requests. Call with `false` after the test completes.
void setUseInterceptableHttpAdapterForPatrol(bool value) {
  _useInterceptableHttpAdapterForPatrol = value;
}
```

### Step 2: Modify Dio Builder to Support Both Adapters

Find where your app creates Dio instances (typically in an API service or DI setup). Modify the Dio builder to branch on the test flag:

**Before:**
```dart
Dio _buildDio() {
  final dio = Dio(baseOptions);
  dio.httpClientAdapter = Http2Adapter(
    ConnectionManager(
      idleTimeout: const Duration(seconds: 15),
      onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
    ),
  );
  return dio;
}
```

**After:**
```dart
import 'package:your_app/src/config/patrol_test_config.dart';

Dio _buildDio() {
  final dio = Dio(baseOptions);
  
  if (useInterceptableHttpAdapterForPatrol) {
    // Use IOHttpClientAdapter for Patrol tests (interceptable)
    dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        // Apply same configurations as Http2Adapter
        client.badCertificateCallback = (cert, host, port) => true;
        client.idleTimeout = const Duration(seconds: 15);
        // Add any proxy settings if needed
        return client;
      },
    );
  } else {
    // Use Http2Adapter for production (better performance)
    dio.httpClientAdapter = Http2Adapter(
      ConnectionManager(
        idleTimeout: const Duration(seconds: 15),
        onClientCreate: (_, config) => config.onBadCertificate = (_) => true,
      ),
    );
  }
  
  return dio;
}
```

### Step 3: Update Patrol Tests

Modify your Patrol integration tests to enable the flag before app initialization:

**Before:**
```dart
patrolTest('Login with Credentials and Logout Tests', ($) async {
  Pages.initialize($);
  $.http.startInterception();
  await launchApp(Pages.$);
  
  // Test code...
  
  $.http.stopInterception();
});
```

**After:**
```dart
import 'package:your_app/src/config/patrol_test_config.dart';

patrolTest('Login with Credentials and Logout Tests', ($) async {
  // 1. Start interception FIRST
  $.http.startInterception();
  
  // 2. Enable interceptable adapter BEFORE app initialization
  setUseInterceptableHttpAdapterForPatrol(true);
  
  // 3. Now initialize and launch app
  Pages.initialize($);
  await launchApp(Pages.$);
  
  // 4. Run your test
  await Pages.login.verifyEasySignInPage();
  await Pages.login.navigateToUsernameAndPasswordLoginPage();
  await Pages.login.loginWithUsernameAndPassword();
  
  // 5. Verify requests were captured
  final requests = $.http.getCapturedRequests();
  $.log('Total requests captured: ${requests.length}');
  for (var request in requests) {
    $.log('Request: ${request.method} ${request.url}');
  }
  
  // 6. Cleanup
  $.http.stopInterception();
  setUseInterceptableHttpAdapterForPatrol(false);
});
```

### Step 4: Add Cleanup in tearDown (Optional but Recommended)

```dart
void main() {
  setUpAll(() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.clear();
  });
  
  tearDown(() {
    // Ensure flag is reset after each test
    setUseInterceptableHttpAdapterForPatrol(false);
  });

  patrolTest('Login with Credentials and Logout Tests', ($) async {
    $.http.startInterception();
    setUseInterceptableHttpAdapterForPatrol(true);
    
    // Test code...
    
    $.http.stopInterception();
    setUseInterceptableHttpAdapterForPatrol(false);
  });
}
```

## Verification

After implementing the fix, you should see ALL HTTP requests captured:

```
📝 Total requests captured: 5
📝 Request: POST https://crew-qa.golmn.com/auth/password
📝   Status: 200
📝 Request: POST https://crew-qa.golmn.com/auth/signin
📝   Status: 200
📝 Request: GET https://crew-qa.golmn.com/info
📝   Status: 200
📝 Request: GET https://crew-qa.golmn.com/company
📝   Status: 200
📝 Request: POST https://mobile.launchdarkly.com/mobile
📝   Status: 202
```

## Important Notes

1. **Order Matters**: Always call in this order:
   - `$.http.startInterception()`
   - `setUseInterceptableHttpAdapterForPatrol(true)`
   - App initialization/launch
   
2. **Performance**: `IOHttpClientAdapter` is slightly slower than `Http2Adapter`, but this only affects tests, not production.

3. **Production Safety**: The flag defaults to `false`, so production builds always use the optimized `Http2Adapter`.

4. **Multiple Dio Instances**: If your app creates multiple Dio instances, apply this pattern to ALL of them.

5. **Dependency Injection**: If using DI (GetIt, Provider, etc.), ensure the flag is set before the DI container initializes.

## Troubleshooting

### Still Not Capturing Requests?

1. **Check flag timing**: Ensure `setUseInterceptableHttpAdapterForPatrol(true)` is called BEFORE any Dio instances are created.

2. **Check Dio creation**: Search your codebase for all `Dio()` constructor calls and verify they all check the flag.

3. **Check for cached instances**: If Dio is a singleton, ensure it's recreated when the flag changes, or clear the singleton before the test.

4. **Add debug logging**:
   ```dart
   $.log('Flag value: $useInterceptableHttpAdapterForPatrol');
   $.log('Adapter type: ${dio.httpClientAdapter.runtimeType}');
   ```

### Requests Still Missing?

If some requests are still missing after the fix:
- They might be made by a different Dio instance that doesn't check the flag
- They might be made before `setUseInterceptableHttpAdapterForPatrol(true)` is called
- They might use a completely different HTTP library (not Dio)

## Reference Implementation

For a complete working example, see:
- `crew-mobile` project's Patrol test setup
- `docs/patrol_http_interception_with_http2_adapter.md` (if available)

## Summary for Other Projects

**Quick Copy-Paste Summary:**

```
Our app uses Dio with Http2Adapter. Patrol's $.http.startInterception() only 
captures requests through dart:io HttpClient; Http2Adapter bypasses it.

Fix:
1. Add test flag: lib/src/config/patrol_test_config.dart
2. Modify Dio builder to use IOHttpClientAdapter when flag is true
3. In tests: $.http.startInterception() → setFlag(true) → launch app
4. Cleanup: $.http.stopInterception() → setFlag(false)

This switches to interceptable adapter only during tests, keeping Http2Adapter 
for production performance.
```
