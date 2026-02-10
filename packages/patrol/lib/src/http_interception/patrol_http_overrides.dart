import 'dart:io';

import 'http_interception_controller.dart';
import 'patrol_http_client.dart';

/// Custom [HttpOverrides] implementation that intercepts HTTP client creation.
///
/// This class wraps the default HTTP client with [PatrolHttpClient] to enable
/// request/response interception and mocking.
class PatrolHttpOverrides extends HttpOverrides {
  /// Creates a new [PatrolHttpOverrides] with the given [controller].
  PatrolHttpOverrides(this.controller);

  /// The controller that manages interception state and mocks.
  final HttpInterceptionController controller;

  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    return PatrolHttpClient(client, controller);
  }
}
