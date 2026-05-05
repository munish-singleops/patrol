///
//  Generated code. Do not modify.
//  source: schema.dart
//

package pl.leancode.patrol.contracts

import com.google.gson.Gson
import java.net.HttpURLConnection
import java.net.Proxy
import java.net.URL
import java.nio.charset.StandardCharsets
import java.util.concurrent.TimeUnit

class PatrolAppServiceClient(address: String, port: Int, private val timeout: Long, private val timeUnit: TimeUnit) {

    fun listDartTests(): Contracts.ListDartTestsResponse {
        val response = performRequest("listDartTests")
        return json.fromJson(response, Contracts.ListDartTestsResponse::class.java)
    }

    fun runDartTest(request: Contracts.RunDartTestRequest): Contracts.RunDartTestResponse {
        val response = performRequest("runDartTest", json.toJson(request))
        return json.fromJson(response, Contracts.RunDartTestResponse::class.java)
    }

    /**
     * Starts [runDartTest] without waiting for the Dart test to finish. Used with
     * [runDartTestPoll] so each HTTP request stays short (cloud device gateways).
     */
    fun runDartTestStart(request: Contracts.RunDartTestRequest) {
        performRequest("runDartTestStart", json.toJson(request), readTimeoutOverrideMs = 120_000)
    }

    /** Returns JSON: `{"pending":true}` or a final `RunDartTestResponse` JSON object. */
    fun runDartTestPoll(): String {
        return performRequest("runDartTestPoll", requestBody = null, readTimeoutOverrideMs = 120_000)
    }

    private fun performRequest(
        path: String,
        requestBody: String? = null,
        readTimeoutOverrideMs: Int? = null,
    ): String {
        val endpoint = "$serverUrl$path"
        val url = URL(endpoint)
        val conn = url.openConnection(Proxy.NO_PROXY) as HttpURLConnection
        val timeoutMillis = timeUnit.toMillis(timeout).coerceAtMost(Int.MAX_VALUE.toLong()).toInt()
        conn.connectTimeout = timeoutMillis
        conn.readTimeout = readTimeoutOverrideMs ?: timeoutMillis
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
                throw PatrolAppServiceClientException("Invalid response $code, $body")
            }
            body
        } finally {
            conn.disconnect()
        }
    }

    val serverUrl = "http://$address:$port/"

    private val json = Gson()
}

class PatrolAppServiceClientException(message: String) : Exception(message)
