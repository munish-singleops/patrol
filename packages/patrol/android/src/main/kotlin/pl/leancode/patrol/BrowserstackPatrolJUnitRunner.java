package pl.leancode.patrol;

import android.util.Log;

import java.net.Inet4Address;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;
import java.util.Objects;

public class BrowserstackPatrolJUnitRunner extends PatrolJUnitRunner {
    @Override
    public PatrolAppServiceClient createAppServiceClient() {
        waitForPatrolAppService();

        // With runDartTestStart + runDartTestPoll, each HTTP call is short, so tun0/privoxy
        // is less likely to hit the old ~200s 504. Prefer default "localhost" first: on some
        // cloud devices 127.0.0.1 can fail intermittently for polls even when it worked for
        // listDartTests. Then try explicit IPv4 loopback, then tun0 (BrowserStack tunnel).
        PatrolAppServiceClient viaDefault = tryPatrolAppServiceClientDefault();
        if (viaDefault != null) {
            return viaDefault;
        }

        PatrolAppServiceClient viaLoopback = tryPatrolAppServiceClient("127.0.0.1");
        if (viaLoopback != null) {
            return viaLoopback;
        }

        String tun0 = getLoopback();
        if (tun0 != null && !tun0.isEmpty()) {
            Logger.INSTANCE.i(
                "BrowserstackPatrolJUnitRunner: loopback failed, trying tun0 " + tun0);
            PatrolAppServiceClient viaTun = tryPatrolAppServiceClient(tun0);
            if (viaTun != null) {
                return viaTun;
            }
        }

        throw new IllegalStateException(
            "BrowserstackPatrolJUnitRunner: PatrolAppService unreachable via localhost, "
                + "127.0.0.1, and tun0 (see earlier log lines)");
    }

    private PatrolAppServiceClient tryPatrolAppServiceClientDefault() {
        try {
            PatrolAppServiceClient client = new PatrolAppServiceClient();
            client.listDartTests();
            Logger.INSTANCE.i(
                "BrowserstackPatrolJUnitRunner: PatrolAppService OK via default (localhost)");
            return client;
        } catch (Exception ex) {
            Logger.INSTANCE.i(
                "BrowserstackPatrolJUnitRunner: default host failed: " + ex.getMessage());
            return null;
        }
    }

    private PatrolAppServiceClient tryPatrolAppServiceClient(String address) {
        try {
            PatrolAppServiceClient client = new PatrolAppServiceClient(address);
            client.listDartTests();
            Logger.INSTANCE.i(
                "BrowserstackPatrolJUnitRunner: PatrolAppService OK via " + address);
            return client;
        } catch (Exception ex) {
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
