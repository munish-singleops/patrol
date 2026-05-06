package pl.leancode.patrol

import java.util.concurrent.CountDownLatch
import java.util.concurrent.atomic.AtomicBoolean
import java.util.concurrent.atomic.AtomicReference
import org.http4k.core.ContentType
import org.http4k.filter.ServerFilters
import org.http4k.server.Http4kServer
import org.http4k.server.KtorCIO
import org.http4k.server.asServer

class PatrolServer {
    private val defaultPort = 8081

    private var server: Http4kServer? = null
    private var automatorServer: AutomatorServer? = null

    val port: Int
        get() {
            val portStr = BuildConfig.PATROL_TEST_PORT
            if (portStr == null) {
                Logger.i("PATROL_TEST_PORT is null, falling back to default ($defaultPort)")
                return defaultPort
            }
            return portStr.toIntOrNull() ?: run {
                Logger.i("PATROL_TEST_PORT is not a valid integer, falling back to default ($defaultPort)")
                defaultPort
            }
        }

    fun start() {
        Logger.i("Starting server...")

        automatorServer = AutomatorServer(Automator.instance)
        server = automatorServer!!.router
            .withFilter(catcher)
            .withFilter(printer)
            .withFilter(ServerFilters.SetContentType(ContentType.TEXT_PLAIN))
            .asServer(KtorCIO(port))
            .start()

        Logger.i("Created and started PatrolServer, port: $port")

        Runtime.getRuntime().addShutdownHook(
            Thread {
                Logger.i("Stopping server...")
                server?.close()
                Logger.i("Server stopped")
            }
        )
    }

    companion object {
        /**
         * Replaces [android.os.ConditionVariable] so we can **reset** readiness between app
         * relaunches (older APIs cannot reset a ConditionVariable cleanly). One [CountDownLatch(1)] per
         * launch cycle; Dart calls [signalAppReady] once when [PatrolAppService] is listening.
         */
        private val appReadyLatch = AtomicReference(CountDownLatch(1))
        private val appReadySignaled = AtomicBoolean(false)

        @JvmStatic
        fun resetAppReadyLatch() {
            appReadySignaled.set(false)
            appReadyLatch.set(CountDownLatch(1))
        }

        @JvmStatic
        fun awaitAppReady() {
            appReadyLatch.get().await()
        }

        @JvmStatic
        fun signalAppReady() {
            if (appReadySignaled.compareAndSet(false, true)) {
                appReadyLatch.get().countDown()
            }
        }
    }
}

typealias DartTestResults = Map<String, String>
