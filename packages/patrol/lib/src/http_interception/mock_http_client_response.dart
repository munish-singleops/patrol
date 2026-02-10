import 'dart:async';
import 'dart:io';

import 'patrol_http_client_request.dart';

/// Mock implementation of [HttpClientResponse] for mocked responses.
class MockHttpClientResponse extends Stream<List<int>>
    implements HttpClientResponse {
  /// Creates a new [MockHttpClientResponse].
  MockHttpClientResponse({
    required this.statusCode,
    required Map<String, String> headers,
    required List<int> body,
    required this.request,
  })  : _headers = _MockHttpHeaders(headers),
        _body = body;

  @override
  final int statusCode;

  final _MockHttpHeaders _headers;
  final List<int> _body;

  /// The request that initiated this response.
  final PatrolHttpClientRequest request;

  @override
  StreamSubscription<List<int>> listen(
    void Function(List<int> event)? onData, {
    Function? onError,
    void Function()? onDone,
    bool? cancelOnError,
  }) {
    // Create a stream controller to emit the body
    final controller = StreamController<List<int>>();

    // Schedule the body emission
    Future<void>.microtask(() {
      if (!controller.isClosed) {
        controller
          ..add(_body)
          ..close();
      }
    });

    return controller.stream.listen(
      onData,
      onError: onError,
      onDone: onDone,
      cancelOnError: cancelOnError,
    );
  }

  @override
  HttpHeaders get headers => _headers;

  @override
  X509Certificate? get certificate => null;

  @override
  HttpConnectionInfo? get connectionInfo => null;

  @override
  int get contentLength => _body.length;

  @override
  List<Cookie> get cookies => [];

  @override
  Future<Socket> detachSocket() {
    throw UnsupportedError('Cannot detach socket from mock response');
  }

  @override
  bool get isRedirect => false;

  @override
  bool get persistentConnection => false;

  @override
  String get reasonPhrase => _getReasonPhrase(statusCode);

  @override
  Future<HttpClientResponse> redirect([
    String? method,
    Uri? url,
    bool? followLoops,
  ]) {
    throw UnsupportedError('Cannot redirect mock response');
  }

  @override
  List<RedirectInfo> get redirects => [];

  @override
  HttpClientResponseCompressionState get compressionState =>
      HttpClientResponseCompressionState.notCompressed;

  String _getReasonPhrase(int statusCode) {
    switch (statusCode) {
      case 200:
        return 'OK';
      case 201:
        return 'Created';
      case 204:
        return 'No Content';
      case 400:
        return 'Bad Request';
      case 401:
        return 'Unauthorized';
      case 403:
        return 'Forbidden';
      case 404:
        return 'Not Found';
      case 500:
        return 'Internal Server Error';
      default:
        return 'Unknown';
    }
  }
}

class _MockHttpHeaders implements HttpHeaders {
  _MockHttpHeaders(Map<String, String> headers)
      : _headers = headers.map((key, value) => MapEntry(key, [value]));

  final Map<String, List<String>> _headers;

  @override
  List<String>? operator [](String name) => _headers[name.toLowerCase()];

  @override
  void add(String name, Object value, {bool preserveHeaderCase = false}) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  void clear() {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  void forEach(void Function(String name, List<String> values) action) {
    _headers.forEach(action);
  }

  @override
  void noFolding(String name) {
    // No-op for mock
  }

  @override
  void remove(String name, Object value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  void removeAll(String name) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  void set(String name, Object value, {bool preserveHeaderCase = false}) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  String? value(String name) => _headers[name.toLowerCase()]?.first;

  @override
  int get contentLength => int.tryParse(value('content-length') ?? '') ?? -1;

  @override
  set contentLength(int value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  bool get chunkedTransferEncoding => false;

  @override
  set chunkedTransferEncoding(bool value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  ContentType? get contentType {
    final value = this.value('content-type');
    if (value == null) {
      return null;
    }
    return ContentType.parse(value);
  }

  @override
  set contentType(ContentType? value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  DateTime? get date {
    final value = this.value('date');
    if (value == null) {
      return null;
    }
    return HttpDate.parse(value);
  }

  @override
  set date(DateTime? value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  DateTime? get expires {
    final value = this.value('expires');
    if (value == null) {
      return null;
    }
    return HttpDate.parse(value);
  }

  @override
  set expires(DateTime? value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  String? get host => value('host');

  @override
  set host(String? value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  DateTime? get ifModifiedSince {
    final value = this.value('if-modified-since');
    if (value == null) {
      return null;
    }
    return HttpDate.parse(value);
  }

  @override
  set ifModifiedSince(DateTime? value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  bool get persistentConnection => false;

  @override
  set persistentConnection(bool value) {
    throw UnsupportedError('Cannot modify mock headers');
  }

  @override
  int? get port {
    return int.tryParse(value('port') ?? '');
  }

  @override
  set port(int? value) {
    throw UnsupportedError('Cannot modify mock headers');
  }
}
