// TODO: Use a logger instead of print
// ignore_for_file: avoid_print

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:patrol/src/common.dart';
import 'package:patrol/src/platform/contracts/contracts.dart';
import 'package:patrol/src/platform/contracts/patrol_app_service_server.dart';
import 'package:patrol_log/patrol_log.dart';
import 'package:shelf/shelf.dart' as shelf;
import 'package:shelf/shelf_io.dart' as shelf_io;

const _idleTimeout = Duration(hours: 2);

class _TestExecutionResult {
  const _TestExecutionResult({required this.passed, required this.details});

  final bool passed;
  final String? details;
}

/// Initializes the app service.
Future<void> initAppService() async {
  // No-op for IO.
}

/// Starts the gRPC server that runs the [PatrolAppService].
Future<void> runAppService(PatrolAppService service) async {
  final pipeline = const shelf.Pipeline()
      .addMiddleware(shelf.logRequests())
      .addHandler(service.handle);

  final server = await shelf_io.serve(
    pipeline,
    InternetAddress.anyIPv4,
    service.port,
    poweredByHeader: null,
  );

  server.idleTimeout = _idleTimeout;

  final address = server.address;

  print(
    'PatrolAppService started, address: ${address.address}, host: ${address.host}, port: ${server.port}',
  );
}

/// Implements a stateful HTTP service for querying and executing Dart tests.
///
/// This is an internal class and you don't want to use it. It's public so that
/// the generated code can access it.
class PatrolAppService extends PatrolAppServiceServer {
  /// Creates a new [PatrolAppService].
  PatrolAppService({required this.topLevelDartTestGroup})
    : port = const int.fromEnvironment(
        'PATROL_APP_SERVER_PORT',
        defaultValue: 8082,
      );

  /// Port the server will use to listen for incoming HTTP traffic.
  final int port;

  /// The ambient test group that wraps all the other groups and tests in the
  /// bundled Dart test file.
  final DartGroupEntry topLevelDartTestGroup;

  /// A completer that completes with the name of the Dart test file that was
  /// requested to execute by the native side.
  var _testExecutionRequested = Completer<String>();

  /// A future that completes with the name of the Dart test file that was
  /// requested to execute by the native side.
  Future<String> get testExecutionRequested => _testExecutionRequested.future;

  var _testExecutionCompleted = Completer<_TestExecutionResult>();

  /// A future that completes when the Dart test file (whose execution was
  /// requested by the native side) completes.
  ///
  /// Returns true if the test passed, false otherwise.
  Future<_TestExecutionResult> get testExecutionCompleted {
    return _testExecutionCompleted.future;
  }

  final _patrolLog = PatrolLogWriter();

  /// Native Android (BrowserStack) can enforce ~200s limits on a single HTTP
  /// response. `runDartTestStart` + `runDartTestPoll` split work into short requests.
  Completer<RunDartTestResponse>? _nativePollOutcome;

  void _resetCompletersForNextNativeRun() {
    _testExecutionRequested = Completer<String>();
    _testExecutionCompleted = Completer<_TestExecutionResult>();
  }

  @override
  FutureOr<shelf.Response> handle(shelf.Request request) {
    if (request.url.path == 'runDartTestStart' && request.method == 'POST') {
      return _handleRunDartTestStart(request);
    }
    if (request.url.path == 'runDartTestPoll' && request.method == 'GET') {
      return _handleRunDartTestPoll();
    }
    return super.handle(request);
  }

  Future<shelf.Response> _handleRunDartTestStart(shelf.Request request) async {
    if (_nativePollOutcome != null && !_nativePollOutcome!.isCompleted) {
      return shelf.Response(
        409,
        body: '{"error":"run_dart_test_start_already_in_progress"}',
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }
    final stringContent = await request.readAsString(utf8);
    final jsonMap = jsonDecode(stringContent);
    final requestObj = RunDartTestRequest.fromJson(
      jsonMap as Map<String, dynamic>,
    );

    _nativePollOutcome = Completer<RunDartTestResponse>();
    final c = _nativePollOutcome!;
    unawaited(_runNativeStartBody(requestObj, c));

    return shelf.Response.ok(
      '{"pending":true}',
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Future<void> _runNativeStartBody(
    RunDartTestRequest requestObj,
    Completer<RunDartTestResponse> c,
  ) async {
    try {
      final r = await runDartTest(requestObj);
      c.complete(r);
    } catch (e, st) {
      _resetCompletersForNextNativeRun();
      if (!c.isCompleted) {
        c.completeError(e, st);
      }
    }
  }

  Future<shelf.Response> _handleRunDartTestPoll() async {
    final c = _nativePollOutcome;
    if (c == null) {
      return shelf.Response.notFound(
        '{"error":"no_active_run_dart_test_start"}',
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }
    if (!c.isCompleted) {
      return shelf.Response.ok(
        '{"pending":true}',
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }
    try {
      final r = await c.future;
      _nativePollOutcome = null;
      _resetCompletersForNextNativeRun();
      return shelf.Response.ok(
        jsonEncode(r.toJson()),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    } catch (e, st) {
      _nativePollOutcome = null;
      _resetCompletersForNextNativeRun();
      return shelf.Response(
        500,
        body: jsonEncode({
          'error': e.toString(),
          'stackTrace': st.toString(),
        }),
        headers: const {'content-type': 'application/json; charset=utf-8'},
      );
    }
  }

  /// Marks [dartFileName] as completed with the given [passed] status.
  ///
  /// If an exception was thrown during the test, [details] should contain the
  /// useful information.
  Future<void> markDartTestAsCompleted({
    required String dartFileName,
    required bool passed,
    required String? details,
  }) async {
    print('PatrolAppService.markDartTestAsCompleted(): $dartFileName');
    assert(
      _testExecutionRequested.isCompleted,
      'Tried to mark a test as completed, but no tests were requested to run',
    );

    final requestedDartTestName = await testExecutionRequested;
    assert(
      requestedDartTestName == dartFileName,
      'Tried to mark test $dartFileName as completed, but the test '
      'that was most recently requested to run was $requestedDartTestName',
    );

    _testExecutionCompleted.complete(
      _TestExecutionResult(passed: passed, details: details),
    );
  }

  /// Returns when the native side requests execution of a Dart test. If the
  /// native side requsted execution of [dartTest], returns true. Otherwise
  /// returns false.
  ///
  /// It's used inside of [patrolTest] to halt execution of test body until
  /// [runDartTest] is called.
  ///
  /// The native side requests execution by RPC-ing [runDartTest] and providing
  /// name of a Dart test that it wants to currently execute [dartTest].
  Future<bool> waitForExecutionRequest(String dartTest) async {
    print('PatrolAppService: registered "$dartTest"');

    final requestedDartTest = await testExecutionRequested;
    if (requestedDartTest != dartTest) {
      // If the requested test is not the one we're waiting for now, it
      // means that dartTest was already executed. Return false so that callers
      // can skip the already executed test.

      print(
        'PatrolAppService: registered test "$dartTest" was not matched by requested test "$requestedDartTest"',
      );

      return false;
    }

    print('PatrolAppService: requested execution of test "$dartTest"');

    return true;
  }

  @override
  Future<ListDartTestsResponse> listDartTests() async {
    print('PatrolAppService.listDartTests() called');
    return ListDartTestsResponse(group: topLevelDartTestGroup);
  }

  @override
  Future<RunDartTestResponse> runDartTest(RunDartTestRequest request) async {
    assert(_testExecutionCompleted.isCompleted == false);
    // patrolTest() always calls this method.

    print('PatrolAppService.runDartTest(${request.name}) called');
    _testExecutionRequested.complete(request.name);

    final testExecutionResult = await testExecutionCompleted;

    if (!testExecutionResult.passed) {
      _patrolLog.log(
        TestEntry(name: request.name, status: TestEntryStatus.failure),
      );
      testExecutionResult.details
          ?.split('\n')
          .forEach((e) => _patrolLog.log(ErrorEntry(message: e)));
    } else {
      _patrolLog.log(
        TestEntry(name: request.name, status: TestEntryStatus.success),
      );
    }

    return RunDartTestResponse(
      result: testExecutionResult.passed
          ? RunDartTestResponseResult.success
          : RunDartTestResponseResult.failure,
      details: testExecutionResult.details,
    );
  }
}
