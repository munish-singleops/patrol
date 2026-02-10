import 'dart:io';

/// Defines criteria for matching HTTP requests.
class RequestMatcher {
  /// Creates a new [RequestMatcher] with the specified criteria.
  RequestMatcher({
    this.url,
    this.urlPattern,
    this.urlRegex,
    this.method,
    this.headers,
    this.host,
  });

  /// Creates a matcher that matches an exact URL.
  factory RequestMatcher.url(String url) => RequestMatcher(url: url);

  /// Creates a matcher that matches a URL pattern with wildcards.
  ///
  /// Example: `https://api.example.com/*/users` matches any path segment.
  factory RequestMatcher.urlPattern(String pattern) =>
      RequestMatcher(urlPattern: pattern);

  /// Creates a matcher that matches a URL using a regular expression.
  factory RequestMatcher.urlRegex(RegExp regex) =>
      RequestMatcher(urlRegex: regex);

  /// Creates a matcher that matches requests to a specific host.
  factory RequestMatcher.host(String host) => RequestMatcher(host: host);

  /// Exact URL to match.
  final String? url;

  /// URL pattern with wildcard support (* matches any characters).
  final String? urlPattern;

  /// Regular expression to match against the URL.
  final RegExp? urlRegex;

  /// HTTP method to match (GET, POST, etc.).
  final String? method;

  /// Headers that must be present with matching values.
  final Map<String, String>? headers;

  /// Host to match.
  final String? host;

  /// Checks if this matcher matches the given [request].
  bool matches(HttpClientRequest request) {
    // Check URL exact match
    if (url != null && request.uri.toString() != url) {
      return false;
    }

    // Check URL pattern (with wildcards)
    if (urlPattern != null) {
      final regex = _patternToRegex(urlPattern!);
      if (!regex.hasMatch(request.uri.toString())) {
        return false;
      }
    }

    // Check URL regex
    if (urlRegex != null && !urlRegex!.hasMatch(request.uri.toString())) {
      return false;
    }

    // Check method
    if (method != null && request.method != method) {
      return false;
    }

    // Check host
    if (host != null && request.uri.host != host) {
      return false;
    }

    // Check headers
    if (headers != null) {
      for (final entry in headers!.entries) {
        final requestHeaderValue = request.headers.value(entry.key);
        if (requestHeaderValue != entry.value) {
          return false;
        }
      }
    }

    return true;
  }

  /// Checks if this matcher matches the given URL and method.
  ///
  /// This is used for Dio interception where we don't have HttpClientRequest.
  bool matchesUrlAndMethod(String requestUrl, String requestMethod) {
    // Check URL exact match
    if (url != null && requestUrl != url) {
      return false;
    }

    // Check URL pattern (with wildcards)
    if (urlPattern != null) {
      final regex = _patternToRegex(urlPattern!);
      if (!regex.hasMatch(requestUrl)) {
        return false;
      }
    }

    // Check URL regex
    if (urlRegex != null && !urlRegex!.hasMatch(requestUrl)) {
      return false;
    }

    // Check method
    if (method != null && requestMethod != method) {
      return false;
    }

    // Check host
    if (host != null) {
      final uri = Uri.parse(requestUrl);
      if (uri.host != host) {
        return false;
      }
    }

    // Note: Header matching not supported for string-based matching
    // as we don't have access to headers in this context

    return true;
  }

  /// Converts a wildcard pattern to a regular expression.
  RegExp _patternToRegex(String pattern) {
    // Escape special regex characters except *
    final escaped = RegExp.escape(pattern);
    // Replace escaped \* with .* to match any characters
    final withWildcards = escaped.replaceAll(r'\*', '.*');
    return RegExp('^$withWildcards\$');
  }

  /// Returns a human-readable description of this matcher.
  String get description {
    final parts = <String>[];
    if (url != null) {
      parts.add('url=$url');
    }
    if (urlPattern != null) {
      parts.add('pattern=$urlPattern');
    }
    if (urlRegex != null) {
      parts.add('regex=${urlRegex!.pattern}');
    }
    if (method != null) {
      parts.add('method=$method');
    }
    if (host != null) {
      parts.add('host=$host');
    }
    if (headers != null) {
      parts.add('headers=$headers');
    }
    return parts.join(', ');
  }
}
