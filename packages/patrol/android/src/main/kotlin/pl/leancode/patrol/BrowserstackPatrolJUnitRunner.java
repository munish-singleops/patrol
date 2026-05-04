package pl.leancode.patrol;

import android.util.Log;
import pl.leancode.patrol.contracts.PatrolAppServiceClientException;

import java.net.Inet4Address;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;
import java.util.Objects;

public class BrowserstackPatrolJUnitRunner extends PatrolJUnitRunner {
    @Override
    public PatrolAppServiceClient createAppServiceClient() {
        waitForPatrolAppService();

        // Prefer tun0 (device loopback IP) whenever BrowserStack exposes it.
        // listDartTests() over localhost often succeeds quickly, but runDartTest()
        // holds one HTTP request open for the entire Dart test; BrowserStack's
        // path for localhost can return HTTP 504 (~4 min) on long tests while
        // tun0 stays on-device and avoids that proxy/gateway timeout.
        String tun0 = getLoopback();
        if (tun0 != null && !tun0.isEmpty()) {
            Logger.INSTANCE.i(
                "BrowserstackPatrolJUnitRunner: using tun0 address " + tun0 + " for PatrolAppService");
            try {
                PatrolAppServiceClient client = new PatrolAppServiceClient(tun0);
                client.listDartTests();
                return client;
            } catch (PatrolAppServiceClientException ex) {
                ex.printStackTrace();
                throw new RuntimeException(
                    "BrowserstackPatrolJUnitRunner: PatrolAppService unreachable via tun0 " + tun0
                        + " (do not fall back to localhost on BrowserStack — long tests get HTTP 504).",
                    ex);
            }
        }

        PatrolAppServiceClient client = new PatrolAppServiceClient();
        try {
            client.listDartTests();
        } catch (PatrolAppServiceClientException ex) {
            ex.printStackTrace();
            Logger.INSTANCE.i("PatrolAppServiceClientException in createAppServiceClient " + ex.getMessage());
            throw new RuntimeException(ex);
        }
        return client;
    }

    public String getLoopback() {
        try {
            Enumeration<NetworkInterface> interfaces = NetworkInterface.getNetworkInterfaces();
            while (interfaces.hasMoreElements()) {
                NetworkInterface i = interfaces.nextElement();
                Log.d("LOOPBACK", i.getDisplayName());
                if (Objects.equals(i.getDisplayName(), "tun0")) {
                    for (java.net.InterfaceAddress a : i.getInterfaceAddresses()) {
                        if (a.getAddress() instanceof Inet4Address) {
                            return a.getAddress().toString().substring(1);
                        }
                    }
                }

            }
        } catch (SocketException e) {
        }

        return null;
    }
}
