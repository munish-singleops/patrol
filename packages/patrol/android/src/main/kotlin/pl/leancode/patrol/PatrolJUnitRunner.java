// Terminology note:
// "Run a test" is used interchangeably with "execute a test".
// "Run a Dart test" is used interchangeably with "request execution of a Dart test" and "execute a Dart test".
// "ATO" is short for "Android Test Orchestrator".

package pl.leancode.patrol;

import static org.junit.Assume.*;

import android.app.Instrumentation;
import android.content.Intent;
import android.os.Bundle;
import androidx.test.platform.app.InstrumentationRegistry;
import androidx.test.runner.AndroidJUnitRunner;

import pl.leancode.patrol.contracts.Contracts;
import pl.leancode.patrol.contracts.PatrolAppServiceClientException;

import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutionException;

import static pl.leancode.patrol.contracts.Contracts.DartGroupEntry;
import static pl.leancode.patrol.contracts.Contracts.RunDartTestResponse;

/**
 * <p>
 * A customized AndroidJUnitRunner that enables Patrol on Android.
 * </p>
 */
public class PatrolJUnitRunner extends AndroidJUnitRunner {
    public PatrolAppServiceClient patrolAppServiceClient;
    private Map<String, Boolean> dartTestCaseSkipMap = new HashMap<>();

    /** Activity used to launch the app; required to recover when PatrolAppService (:8082) is gone. */
    private Class<?> configuredActivityClass;

    @Override
    protected boolean shouldWaitForActivitiesToComplete() {
        return false;
    }

    @Override
    public void onCreate(Bundle arguments) {
        super.onCreate(arguments);

        // This is only true when the ATO requests a list of tests from the app during the initial run.
        boolean isInitialRun = Boolean.parseBoolean(arguments.getString("listTestsForOrchestrator"));

        Logger.INSTANCE.i("--------------------------------");
        Logger.INSTANCE.i("PatrolJUnitRunner.onCreate() " + (isInitialRun ? "(initial run)" : ""));
    }

    /**
     * <p>
     * The native test runner needs to know what tests exist before it can execute them.
     * To gather the tests, the native test runner (by default: AndroidJUnitRunner) runs
     * the instrumentation during the ATO's initial run and collects the tests.
     * </p>
     *
     * <p>
     * This default behavior doesn't work with Flutter apps. That's because in Flutter
     * apps, the tests are in the app itself, so running only the instrumentation
     * during the initial run is not enough.
     * The app must also be run, and queried for Dart tests.
     * That's what this method does.
     * </p>
     */
    public void setUp(Class<?> activityClass) {
        Logger.INSTANCE.i("PatrolJUnitRunner.setUp(): activityClass = " + activityClass.getCanonicalName());

        configuredActivityClass = activityClass;

        // This code launches the app under test. It's based on ActivityTestRule#launchActivity.
        // It's simpler because we don't have the need for that much synchronization.
        // Currently, the only synchronization point we're interested in is when the app under test returns the list of tests.
        Instrumentation instrumentation = InstrumentationRegistry.getInstrumentation();

        PatrolServer patrolServer = new PatrolServer();
        patrolServer.start(); // Gets killed when the instrumentation process dies. We're okay with this.

        launchAppUnderTest(instrumentation, activityClass);

        patrolAppServiceClient = createAppServiceClient();
    }

    /**
     * Cold-starts (or foregrounds) the Flutter app under test. Used from {@link #setUp} and from
     * {@link #ensureAppAndDartServiceAlive} when {@code localhost:8082} is unreachable — e.g. the
     * app process was killed between parameterized {@code @Test} methods while instrumentation
     * stayed alive.
     */
    protected static void launchAppUnderTest(Instrumentation instrumentation, Class<?> activityClass) {
        Intent intent = instrumentation.getTargetContext().getPackageManager()
                .getLaunchIntentForPackage(instrumentation.getTargetContext().getPackageName());

        if (intent == null) {
            intent = new Intent(Intent.ACTION_MAIN);
            intent.setClassName(instrumentation.getTargetContext(), activityClass.getCanonicalName());
        }

        intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TASK);
        instrumentation.getTargetContext().startActivity(intent);
    }

    /**
     * Re-launch the app and block until Dart's PatrolAppService calls {@code markPatrolAppServiceReady}.
     * Does not start a second {@link PatrolServer} — only use after an initial {@link #setUp}.
     */
    protected void ensureAppAndDartServiceAlive() {
        if (configuredActivityClass == null) {
            throw new IllegalStateException(
                    "PatrolJUnitRunner.ensureAppAndDartServiceAlive: setUp(activityClass) was not called");
        }
        Logger.INSTANCE.i("PatrolJUnitRunner.ensureAppAndDartServiceAlive(): relaunch + wait for PatrolAppService");
        PatrolServer.resetAppReadyLatch();
        Instrumentation instrumentation = InstrumentationRegistry.getInstrumentation();
        launchAppUnderTest(instrumentation, configuredActivityClass);
        waitForPatrolAppService();
        patrolAppServiceClient = createAppServiceClient();
    }

    private static boolean isPatrolAppServiceConnectFailure(Throwable t) {
        Throwable e = t;
        while (e != null) {
            if (e instanceof java.net.SocketException) {
                return true;
            }
            String m = e.getMessage();
            if (m != null
                    && (m.contains("Failed to connect")
                            || m.contains("Connection refused")
                            || m.contains("ECONNREFUSED"))) {
                return true;
            }
            e = e.getCause();
        }
        return false;
    }

    public PatrolAppServiceClient createAppServiceClient() {
        return new PatrolAppServiceClient();
    }

    /**
     * <p>
     * Waits until PatrolAppService, running in the Dart side of the app, reports
     * that it's ready to be asked about the list of Dart tests.
     * </p>
     *
     * <p>
     * PatrolAppService becomes ready once the special Dart test named "patrol_test_explorer" finishes running.
     * </p>
     */
    public void waitForPatrolAppService() {
        final String TAG = "PatrolJUnitRunner.setUp(): ";

        Logger.INSTANCE.i(TAG + "Waiting for PatrolAppService to report its readiness...");
        PatrolServer.awaitAppReady();

        Logger.INSTANCE.i(TAG + "PatrolAppService is ready to report Dart tests");
    }

    public Object[] listDartTests() {
        return listDartTestsWithRecovery(0);
    }

    private Object[] listDartTestsWithRecovery(int attempt) {
        final String TAG = "PatrolJUnitRunner.listDartTests(): ";
        final int maxAttempts = 3;

        try {
            final DartGroupEntry dartTestGroup = patrolAppServiceClient.listDartTests();
            List<DartGroupEntry> dartTestCases = ContractsExtensionsKt.listTestsFlat(dartTestGroup, "");
            List<String> dartTestCaseNamesList = new ArrayList<>();
            for (DartGroupEntry dartTestCase : dartTestCases) {
                dartTestCaseSkipMap.put(dartTestCase.getName(), dartTestCase.getSkip());
                dartTestCaseNamesList.add(dartTestCase.getName());
            }
            Object[] dartTestCaseNames = dartTestCaseNamesList.toArray();
            Logger.INSTANCE.i(TAG + "Got Dart tests: " + Arrays.toString(dartTestCaseNames));
            return dartTestCaseNames;
        } catch (PatrolAppServiceClientException e) {
            Logger.INSTANCE.e(TAG + "Failed to list Dart tests: ", e);
            throw new RuntimeException(e);
        } catch (Throwable t) {
            if (attempt < maxAttempts - 1 && isPatrolAppServiceConnectFailure(t) && configuredActivityClass != null) {
                Logger.INSTANCE.e(
                        TAG + "PatrolAppService unreachable (attempt " + (attempt + 1) + "/" + maxAttempts + "), recovering",
                        t);
                ensureAppAndDartServiceAlive();
                return listDartTestsWithRecovery(attempt + 1);
            }
            Logger.INSTANCE.e(TAG + "Failed to list Dart tests: ", t);
            throw new RuntimeException(t);
        }
    }

    /**
     * Requests execution of a Dart test and waits for it to finish.
     * Throws AssertionError if the test fails.
     */
    public RunDartTestResponse runDartTest(String name) {
        return runDartTestWithRecovery(name, 0);
    }

    private RunDartTestResponse runDartTestWithRecovery(String name, int attempt) {
        final String TAG = "PatrolJUnitRunner.runDartTest(" + name + "): ";
        final int maxAttempts = 3;

        final Boolean skip = dartTestCaseSkipMap.get(name);
        if (skip) {
            Logger.INSTANCE.i(TAG + "Test skipped");
            assumeFalse(skip);
        }

        try {
            Logger.INSTANCE.i(TAG + "Requested execution");
            RunDartTestResponse response = patrolAppServiceClient.runDartTest(name);
            if (response.getResult() == Contracts.RunDartTestResponseResult.failure) {
                throw new AssertionError("Dart test failed: " + name + "\n" + response.getDetails());
            }
            Logger.INSTANCE.i(TAG + "Test execution succeeded");
            return response;
        } catch (PatrolAppServiceClientException e) {
            Logger.INSTANCE.e(TAG + e.getMessage(), e.getCause());
            throw new RuntimeException(e);
        } catch (AssertionError e) {
            throw e;
        } catch (Throwable t) {
            if (attempt < maxAttempts - 1 && isPatrolAppServiceConnectFailure(t) && configuredActivityClass != null) {
                Logger.INSTANCE.e(
                        TAG + "PatrolAppService unreachable (attempt " + (attempt + 1) + "/" + maxAttempts + "), recovering",
                        t);
                ensureAppAndDartServiceAlive();
                return runDartTestWithRecovery(name, attempt + 1);
            }
            Logger.INSTANCE.e(TAG + t.getMessage(), t.getCause());
            throw new RuntimeException(t);
        }
    }
}
