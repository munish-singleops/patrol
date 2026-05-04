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

        // Same rationale as BrowserstackPatrolJUnitRunner: prefer tun0 for long runDartTest HTTP.
        String tun0 = getLoopback();
        if (tun0 != null && !tun0.isEmpty()) {
            Logger.INSTANCE.i(
                "LambdaTestPatrolJUnitRunner: using tun0 address " + tun0 + " for PatrolAppService");
            try {
                PatrolAppServiceClient client = new PatrolAppServiceClient(tun0);
                client.listDartTests();
                return client;
            } catch (PatrolAppServiceClientException ex) {
                ex.printStackTrace();
                throw new RuntimeException(
                    "LambdaTestPatrolJUnitRunner: PatrolAppService unreachable via tun0 " + tun0,
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
