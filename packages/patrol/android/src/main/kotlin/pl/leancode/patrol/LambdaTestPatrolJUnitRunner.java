package pl.leancode.patrol;

import android.util.Log;
import pl.leancode.patrol.contracts.PatrolAppServiceClientException;

import java.net.Inet4Address;
import java.net.NetworkInterface;
import java.net.SocketException;
import java.util.Enumeration;
import java.util.Objects;

public class LambdaTestPatrolJUnitRunner extends PatrolJUnitRunner {
    @Override
    public PatrolAppServiceClient createAppServiceClient() {
        waitForPatrolAppService();

        // Same address order as BrowserstackPatrolJUnitRunner: true IPv4 loopback
        // first (Patrol runs in-process with the app), then tun0, then default host.
        PatrolAppServiceClient viaLoopback = tryPatrolAppServiceClient("127.0.0.1");
        if (viaLoopback != null) {
            return viaLoopback;
        }

        String tun0 = getLoopback();
        if (tun0 != null && !tun0.isEmpty()) {
            Logger.INSTANCE.i(
                "LambdaTestPatrolJUnitRunner: 127.0.0.1 unreachable, trying tun0 " + tun0);
            PatrolAppServiceClient viaTun = tryPatrolAppServiceClient(tun0);
            if (viaTun != null) {
                return viaTun;
            }
        }

        Logger.INSTANCE.i("LambdaTestPatrolJUnitRunner: falling back to default host (localhost)");
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
                "LambdaTestPatrolJUnitRunner: PatrolAppService OK via " + address);
            return client;
        } catch (PatrolAppServiceClientException ex) {
            Logger.INSTANCE.i(
                "LambdaTestPatrolJUnitRunner: PatrolAppService failed via " + address + ": "
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
