package pl.leancode.patrol

import com.google.gson.Gson
import com.google.gson.JsonParser
import pl.leancode.patrol.contracts.Contracts
import pl.leancode.patrol.contracts.PatrolAppServiceClientException
import java.util.concurrent.TimeUnit
import pl.leancode.patrol.contracts.PatrolAppServiceClient as Client

/**
 * Enables querying Dart tests, running them, waiting for them to finish, and getting their results
 */
class PatrolAppServiceClient {

    private var client: Client

    private val gson = Gson()

    // https://github.com/leancodepl/patrol/issues/1683
    private val timeout = 2L
    private val timeUnit = TimeUnit.HOURS

    private val defaultPort = 8082
    val port: Int
        get() {
            val portStr = BuildConfig.PATROL_APP_PORT
            if (portStr == null) {
                Logger.i("PATROL_APP_PORT is null, falling back to default ($defaultPort)")
                return defaultPort
            }
            return portStr.toIntOrNull() ?: run {
                Logger.i("PATROL_APP_PORT is not a valid integer, falling back to default ($defaultPort)")
                defaultPort
            }
        }

    constructor() {
        client = Client(address = "localhost", port = port, timeout = timeout, timeUnit = timeUnit)
        Logger.i("Created PatrolAppServiceClient: ${client.serverUrl}")
    }

    constructor(address: String) {
        client = Client(address = address, port = port, timeout = timeout, timeUnit = timeUnit)
        Logger.i("Created PatrolAppServiceClient: ${client.serverUrl}")
    }

    @Throws(PatrolAppServiceClientException::class)
    fun listDartTests(): Contracts.DartGroupEntry {
        Logger.i("PatrolAppServiceClient.listDartTests()")
        val result = client.listDartTests()
        return result.group
    }

    @Throws(PatrolAppServiceClientException::class)
    fun runDartTest(name: String): Contracts.RunDartTestResponse {
        Logger.i("PatrolAppServiceClient.runDartTest($name) via start+poll")
        val req = Contracts.RunDartTestRequest(name)
        client.runDartTestStart(req)
        while (true) {
            val body = client.runDartTestPoll()
            val root = JsonParser.parseString(body).asJsonObject
            if (root.has("pending") && root.get("pending").asBoolean) {
                Thread.sleep(5_000L)
                continue
            }
            if (root.has("error")) {
                throw PatrolAppServiceClientException(
                    "runDartTestPoll error: $body",
                )
            }
            return gson.fromJson(body, Contracts.RunDartTestResponse::class.java)
        }
    }
}
