/// Powerful Flutter-native UI testing framework overcoming limitations of
/// existing Flutter testing tools. Ready for action!
library;

export 'package:patrol_finders/patrol_finders.dart' hide PatrolTester;

export 'src/binding.dart';
// Exporting patrol methods to be used in tests.
// ignore: invalid_export_of_internal_element
export 'src/common.dart';
export 'src/custom_finders/patrol_integration_tester.dart';
export 'src/http_interception/captured_request.dart';
export 'src/http_interception/captured_response.dart';
export 'src/http_interception/http_interception_extension.dart';
export 'src/http_interception/mock_response.dart';
export 'src/http_interception/request_matcher.dart';
export 'src/native/native.dart';
export 'src/platform/contracts/contracts.dart'
    show
        AndroidNativeView,
        AppleApp,
        GoogleApp,
        IOSElementType,
        IOSNativeView,
        KeyboardBehavior;
export 'src/platform/patrol_app_service.dart';
export 'src/platform/platform_automator.dart';
export 'src/platform/selector.dart';
export 'src/platform/web/upload_file_data.dart';
