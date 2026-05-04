import 'package:patrol_gen/src/generators/android/android_config.dart';
import 'package:patrol_gen/src/generators/output_file.dart';
import 'package:patrol_gen/src/schema.dart';

class AndroidHttp4kClientGenerator {
  OutputFile generate(Service service, AndroidConfig config) {
    final buffer = StringBuffer()
      ..write(_contentPrefix(config))
      ..writeln(_generateClientClass(service))
      ..writeln()
      ..writeln(_generateExceptionClass(service));

    return OutputFile(
      filename: config.clientFileName(service.name),
      content: buffer.toString(),
    );
  }

  String _contentPrefix(AndroidConfig config) {
    return '''
///
//  Generated code. Do not modify.
//  source: schema.dart
//

package ${config.package};

import com.google.gson.Gson
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

''';
  }

  String _generateClientClass(Service service) {
    const url = r'"http://$address:$port/"';
    final endpoints = service.endpoints.map(_createEndpoint).join('\n\n');

    const urlWithPath = r'"$serverUrl$path"';

    return '''
class ${service.name}Client(address: String, port: Int, private val timeout: Long, private val timeUnit: TimeUnit) {

$endpoints

    private fun performRequest(path: String, requestBody: String? = null): String {
        val endpoint = $urlWithPath
        val url = URL(endpoint)
        val conn = url.openConnection(Proxy.NO_PROXY) as HttpURLConnection
        val timeoutMillis = timeUnit.toMillis(timeout).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        conn.connectTimeout = timeoutMillis
        conn.readTimeout = timeoutMillis
        conn.useCaches = false
        if (requestBody != null) {
            conn.requestMethod = "POST"
            conn.doOutput = true
            conn.setRequestProperty("Content-Type", "application/json; charset=utf-8")
            conn.outputStream.use { os ->
                os.write(requestBody.toByteArray(StandardCharsets.UTF_8))
                os.flush()
            }
        } else {
            conn.requestMethod = "GET"
        }
        return try {
            val code = conn.responseCode
            val bodyStream = if (code >= 400) conn.errorStream else conn.inputStream
            val body = bodyStream?.use { it.readBytes().toString(StandardCharsets.UTF_8) } ?: ""
            if (code != 200) {
                throw ${service.name}ClientException("Invalid response \$code, \$body")
            }
            body
        } finally {
            conn.disconnect()
        }
    }

    val serverUrl = $url

    private val json = Gson()
}''';
  }

  String _createEndpoint(Endpoint endpoint) {
    final parameterDef = endpoint.request != null
        ? 'request: Contracts.${endpoint.request!.name}'
        : '';
    final returnDef = endpoint.response != null
        ? ': Contracts.${endpoint.response!.name}'
        : '';

    final serializeParameter =
        endpoint.request != null ? ', json.toJson(request)' : '';

    final body = endpoint.response != null
        ? '''
        val response = performRequest("${endpoint.name}"$serializeParameter)
        return json.fromJson(response, Contracts.${endpoint.response!.name}::class.java)'''
        : '''
        performRequest("${endpoint.name}"$serializeParameter)''';

    return '''
    fun ${endpoint.name}($parameterDef)$returnDef {
$body
    }''';
  }

  String _generateExceptionClass(Service service) {
    return '''
class ${service.name}ClientException(message: String) : Exception(message)''';
  }
}
