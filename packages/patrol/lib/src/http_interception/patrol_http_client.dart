import 'dart:io';

import 'http_interception_controller.dart';
import 'patrol_http_client_request.dart';

/// Wrapper around [HttpClient] that intercepts request creation.
class PatrolHttpClient implements HttpClient {
  /// Creates a new [PatrolHttpClient] wrapping the inner client.
  PatrolHttpClient(this._inner, this.controller);

  final HttpClient _inner;

  /// The controller that manages interception state and mocks.
  final HttpInterceptionController controller;

  @override
  Future<HttpClientRequest> openUrl(String method, Uri url) async {
    final request = await _inner.openUrl(method, url);
    return PatrolHttpClientRequest(request, controller, method, url);
  }

  // Delegate all other HttpClient methods to _inner
  @override
  bool get autoUncompress => _inner.autoUncompress;

  @override
  set autoUncompress(bool value) => _inner.autoUncompress = value;

  @override
  Duration? get connectionTimeout => _inner.connectionTimeout;

  @override
  set connectionTimeout(Duration? value) => _inner.connectionTimeout = value;

  @override
  Duration get idleTimeout => _inner.idleTimeout;

  @override
  set idleTimeout(Duration value) => _inner.idleTimeout = value;

  @override
  int? get maxConnectionsPerHost => _inner.maxConnectionsPerHost;

  @override
  set maxConnectionsPerHost(int? value) =>
      _inner.maxConnectionsPerHost = value;

  @override
  String? get userAgent => _inner.userAgent;

  @override
  set userAgent(String? value) => _inner.userAgent = value;

  @override
  void addCredentials(
    Uri url,
    String realm,
    HttpClientCredentials credentials,
  ) {
    _inner.addCredentials(url, realm, credentials);
  }

  @override
  void addProxyCredentials(
    String host,
    int port,
    String realm,
    HttpClientCredentials credentials,
  ) {
    _inner.addProxyCredentials(host, port, realm, credentials);
  }

  @override
  set authenticate(
    Future<bool> Function(Uri url, String scheme, String? realm)? f,
  ) {
    _inner.authenticate = f;
  }

  @override
  set authenticateProxy(
    Future<bool> Function(
      String host,
      int port,
      String scheme,
      String? realm,
    )? f,
  ) {
    _inner.authenticateProxy = f;
  }

  @override
  set badCertificateCallback(
    bool Function(X509Certificate cert, String host, int port)? callback,
  ) {
    _inner.badCertificateCallback = callback;
  }

  @override
  void close({bool force = false}) {
    _inner.close(force: force);
  }

  @override
  set connectionFactory(
    Future<ConnectionTask<Socket>> Function(
      Uri url,
      String? proxyHost,
      int? proxyPort,
    )? f,
  ) {
    _inner.connectionFactory = f;
  }

  @override
  Future<HttpClientRequest> delete(String host, int port, String path) {
    return _inner.delete(host, port, path);
  }

  @override
  Future<HttpClientRequest> deleteUrl(Uri url) {
    return _inner.deleteUrl(url);
  }

  @override
  set findProxy(String Function(Uri url)? f) {
    _inner.findProxy = f;
  }

  @override
  Future<HttpClientRequest> get(String host, int port, String path) {
    return _inner.get(host, port, path);
  }

  @override
  Future<HttpClientRequest> getUrl(Uri url) {
    return _inner.getUrl(url);
  }

  @override
  Future<HttpClientRequest> head(String host, int port, String path) {
    return _inner.head(host, port, path);
  }

  @override
  Future<HttpClientRequest> headUrl(Uri url) {
    return _inner.headUrl(url);
  }

  @override
  set keyLog(void Function(String line)? callback) {
    _inner.keyLog = callback;
  }

  @override
  Future<HttpClientRequest> open(
    String method,
    String host,
    int port,
    String path,
  ) {
    return _inner.open(method, host, port, path);
  }

  @override
  Future<HttpClientRequest> patch(String host, int port, String path) {
    return _inner.patch(host, port, path);
  }

  @override
  Future<HttpClientRequest> patchUrl(Uri url) {
    return _inner.patchUrl(url);
  }

  @override
  Future<HttpClientRequest> post(String host, int port, String path) {
    return _inner.post(host, port, path);
  }

  @override
  Future<HttpClientRequest> postUrl(Uri url) {
    return _inner.postUrl(url);
  }

  @override
  Future<HttpClientRequest> put(String host, int port, String path) {
    return _inner.put(host, port, path);
  }

  @override
  Future<HttpClientRequest> putUrl(Uri url) {
    return _inner.putUrl(url);
  }
}
