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

        // BrowserStack injects a tunnel interface (often "tun0") and HTTP machinery
        // (privoxy). HTTP to tun0's IPv4 can be steered through that proxy and return
        // HTML 504 on long runDartTest() calls. Instrumentation and the Flutter app
        // run in the same process for Patrol, so the Dart PatrolAppService is bound on
        // loopback — prefer IPv4 127.0.0.1 (avoids ::1 / hostname quirks) before tun0.
        PatrolAppServiceClient viaLoopback = tryPatrolAppServiceClient("127.0.0.1");
        if (viaLoopback != null) {
            return viaLoopback;
        }

        String tun0 = getLoopback();
        if (tun0 != null && !tun0.isEmpty()) {
            Logger.INSTANCE.i(
                "BrowserstackPatrolJUnitRunner: 127.0.0.1 unreachable, trying tun0 " + tun0);
            PatrolAppServiceClient viaTun = tryPatrolAppServiceClient(tun0);
            if (viaTun != null) {
                return viaTun;
            }
        }

        Logger.INSTANCE.i("BrowserstackPatrolJUnitRunner: falling back to default host (localhost)");
        try {
            PatrolAppServiceClient client = new PatrolAppServiceClient();
            client.listDartTests();
            return client;
        } catch (PatrolAppServiceClientException ex) {
            ex.printStackTrace();
            Logger.INSTANCE.i(
                "PatrolAppServiceClientException in createAppServiceClient " + ex.getMessage());
            throw new RuntimeException(ex);
        }
    }

    private PatrolAppServiceClient tryPatrolAppServiceClient(String address) {
        try {
            PatrolAppServiceClient client = new PatrolAppServiceClient(address);
            client.listDartTests();
            Logger.INSTANCE.i(
                "BrowserstackPatrolJUnitRunner: PatrolAppService OK via " + address);
            return client;
        } catch (PatrolAppServiceClientException ex) {
            Logger.INSTANCE.i(
                "BrowserstackPatrolJUnitRunner: PatrolAppService failed via " + address + ": "
                    + ex.getMessage());
            return null;
        }
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
