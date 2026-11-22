using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;

internal static class TargetChecks
{
    private static void Check(string scenario, bool recovery, bool accept)
    {
        var calls = new List<string>();
        string firewall = new string('a', 64);
        Func<string[],string> fixture = args => {
            string key = args.Last();
            calls.Add(args[0] + ":" + key);
            if (args.Contains("cat")) return scenario == "forwarding-off" ? "0" : "1";
            if (args.Contains("route")) return scenario == "wrong-route"
                ? key + " via 192.168.10.1 dev eth0 src 192.168.10.50"
                : key + " via 192.168.10.254 dev eth0 src 192.168.10.50";
            if (args[0] == "exec")
                return scenario == "high" ? "high" : "low";
            if (args[0] == "network")
            {
                string subnet = key == "guest-net" ? "192.168.10.0/24" : "192.168.20.0/24";
                return (scenario == "foreign-network" ? "bridge|other|" : "bridge|docker|") + subnet + ";";
            }
            string service = key.Substring("swagpc-".Length);
            var nets = new Dictionary<string,string> {
                {"firewall", "business-net=192.168.20.254/24;guest-net=192.168.10.254/24;"},
                {"waf", "business-net=192.168.20.15/24;"},
                {"dvwa", "business-net=192.168.20.10/24;"},
                {"kali", "guest-net=192.168.10.50/24;"}
            };
            string config = Path.GetFullPath("docker/docker-compose.yml");
            if (scenario == "override") config += ",docker-compose.segmented.yml";
            return string.Join("\n", new[] {
                scenario == "invalid-id" ? "not-a-container-id" : firewall, "/" + key,
                scenario == "stopped" ? "false" : "true",
                scenario == "foreign-project" ? "other" : "docker", service, config,
                scenario == "wrong-address" && service == "dvwa" ? "app-net=192.168.30.10/24;" : nets[service]
            });
        };
        bool accepted;
        try { accepted = CafeSecurity.VerifyTarget(recovery, fixture)["firewall"] == firewall; }
        catch (InvalidOperationException) { accepted = false; }
        if (accepted != accept || (recovery && calls.Count != 1))
            throw new Exception("Unexpected decision: " + scenario);
        Console.WriteLine("PASS " + scenario);
    }

    private static void Traffic(string scenario, bool accept)
    {
        int counter = 0;
        var ids = CafeSecurity.Required.ToDictionary(service => service);
        Func<string[],string> fixture = args => {
            if (args[1] == "dvwa") return scenario == "origin-down" ? "unavailable" : "HTTP/1.1 200 OK";
            if (args[1] == "firewall")
            {
                if (scenario != "no-drops") counter++;
                return counter + " 40 DROP all -- * * 192.168.10.0/24 192.168.20.0/24 /* SWAGPC_CAFE_WAF_V1_DENY */";
            }
            if (args.Last().Contains(":8080")) return scenario == "proxy-down" ? "000 7" : "200 0";
            return scenario == "bypass" ? "200 0" : scenario == "refused" ? "000 7" : "000 28";
        };
        bool passed = true;
        try { CafeSecurity.VerifyTraffic(ids, fixture); }
        catch (InvalidOperationException) { passed = false; }
        if (passed != accept) throw new Exception("Unexpected traffic result: " + scenario);
        Console.WriteLine("PASS " + scenario);
    }

    private static void Main()
    {
        Traffic("defended", true);
        foreach (string failure in new[] { "origin-down", "proxy-down", "no-drops", "refused", "bypass" })
            Traffic(failure, false);
        Check("base", false, true);
        foreach (string scenario in new[] { "foreign-project", "foreign-network", "invalid-id",
            "override", "stopped", "wrong-address", "high", "forwarding-off", "wrong-route" })
            Check(scenario, false, false);
        Check("recovery-without-app", true, true);
        Check("foreign-project", true, false);
    }
}
