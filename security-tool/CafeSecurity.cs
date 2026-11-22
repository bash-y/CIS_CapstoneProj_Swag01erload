using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Threading.Tasks;

internal static class CafeSecurity
{
    internal static readonly string[] Required = { "firewall", "dvwa", "waf", "kali" };
    private static readonly string[] Commands = { "preflight", "status", "check-target", "verify-waf", "apply-waf", "rollback-waf" };
    private static readonly string[] Compose = { "compose", "-p", "docker", "-f", "docker/docker-compose.yml" };

    private static int Main(string[] args)
    {
        if (args.Length != 1 || !Commands.Contains(args[0]))
        {
            Console.WriteLine("CafeSecurity.exe preflight | status | check-target | verify-waf | apply-waf | rollback-waf | --help");
            Console.WriteLine("Run from security-tool or the cafe repository root. apply-waf and rollback-waf change the lab router.");
            return args.Length == 1 && args[0] == "--help" ? 0 : 2;
        }

        try
        {
            var current = new DirectoryInfo(Environment.CurrentDirectory);
            if (current.Name.Equals("security-tool", StringComparison.OrdinalIgnoreCase) &&
                current.Parent != null && File.Exists(Path.Combine(current.Parent.FullName, "docker/docker-compose.yml")))
                Directory.SetCurrentDirectory(current.Parent.FullName);

            if (!File.Exists("docker/docker-compose.yml") || !File.Exists("defense/firewall/route-waf-only.sh"))
                throw new InvalidOperationException("Run from security-tool or the cafe repository root.");
            string docker = new[] {
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ProgramFiles),
                             @"Docker\Docker\resources\bin\docker.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
                             @"Programs\DockerDesktop\resources\bin\docker.exe"),
                Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                             @"AppData\Local\Programs\DockerDesktop\resources\bin\docker.exe")
            }.FirstOrDefault(File.Exists);
            if (docker == null)
                throw new InvalidOperationException("Docker Desktop CLI was not found.");

            string mode = args[0];
            if (mode == "preflight" || mode == "status")
            {
                CheckServices(docker, "declared", "config", "--services");
                if (mode == "status")
                    CheckServices(docker, "running", "ps", "--status", "running", "--services");
                Console.WriteLine("Service inventory only. WAF enforcement requires a live traffic check.");
                return 0;
            }

            using (var operation = new Mutex(false, @"Global\SwagPcCafeWafPolicy"))
            {
                bool acquired;
                try { acquired = operation.WaitOne(0); }
                catch (AbandonedMutexException) { acquired = true; }
                if (!acquired)
                    throw new InvalidOperationException("Another cafe WAF operation is active.");
                try { return Execute(docker, mode); }
                finally { operation.ReleaseMutex(); }
            }
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("Operation incomplete: " + error.Message);
            return 1;
        }
    }

    private static int Execute(string docker, string mode)
    {
        Func<string[], string> inspect = cmd => Run(docker, cmd, null);
        var targets = VerifyTarget(mode == "rollback-waf", inspect);
        if (mode == "check-target")
        {
            Console.WriteLine("Verified the base lab container identities, attachments and DVWA Low default.");
            return 0;
        }
        if (mode == "verify-waf")
        {
            VerifyTraffic(targets, inspect);
            return 0;
        }
        using (Stream resource = Assembly.GetExecutingAssembly().GetManifestResourceStream("waf-policy.sh"))
        {
            if (resource == null)
                throw new InvalidOperationException("Missing embedded firewall policy. Rebuild using build.ps1.");
            using (var reader = new StreamReader(resource))
            {
                string verb = mode == "apply-waf" ? "apply" : "rollback";
                string script = reader.ReadToEnd().Replace("\r\n", "\n");
                Func<string, string> policy = action => Run(docker,
                    new[] { "exec", "-i", targets["firewall"], "sh", "-s", "--", action }, script);
                if (verb == "apply")
                    ApplyAndVerify(policy, () => VerifyTraffic(targets, inspect));
                else
                    Console.WriteLine(policy("rollback"));
            }
        }
        return 0;
    }

    internal static void ApplyAndVerify(Func<string,string> policy, Action check)
    {
        string outcome = policy("apply");
        Console.WriteLine(outcome);
        try { check(); }
        catch (Exception failure)
        {
            if (outcome == "WAF routing: scoped rules installed; prior policy journal retained")
            {
                try { Console.WriteLine(policy("rollback")); }
                catch (Exception recovery)
                {
                    throw new InvalidOperationException(failure.Message + " Recovery failed: " + recovery.Message);
                }
            }
            throw;
        }
    }

    private static void CheckServices(string docker, string state, params string[] query)
    {
        string result = Run(docker, Compose.Concat(query).ToArray(), null);
        var names = result.Split(new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries);
        var missing = Required.Except(names).ToArray();
        if (missing.Length != 0)
            throw new InvalidOperationException("Missing " + state + " services: " + string.Join(", ", missing));
        Console.WriteLine("Required services " + state + ": " + string.Join(", ", Required));
    }

    // Only request identity and network fields. Container environment variables may contain credentials.
    private const string Identity = "{{.Id}}\n{{.Name}}\n{{.State.Running}}\n" +
        "{{index .Config.Labels \"com.docker.compose.project\"}}\n" +
        "{{index .Config.Labels \"com.docker.compose.service\"}}\n" +
        "{{index .Config.Labels \"com.docker.compose.project.config_files\"}}\n" +
        "{{range $name, $net := .NetworkSettings.Networks}}{{$name}}={{$net.IPAddress}}/{{$net.IPPrefixLen}};{{end}}";

    internal static Dictionary<string,string> VerifyTarget(bool recovery, Func<string[], string> run)
    {
        var networks = new Dictionary<string,string[]> {
            { "firewall", new[] { "guest-net=192.168.10.254/24", "business-net=192.168.20.254/24" } },
            { "dvwa", new[] { "business-net=192.168.20.10/24" } },
            { "waf", new[] { "business-net=192.168.20.15/24" } },
            { "kali", new[] { "guest-net=192.168.10.50/24" } }
        };
        var ids = new Dictionary<string,string>();
        string expectedConfig = Path.GetFullPath("docker/docker-compose.yml");
        foreach (string service in recovery ? new[] { "firewall" } : Required)
        {
            string name = "swagpc-" + service;
            string[] lines = run(new[] { "container", "inspect", "--format", Identity, name })
                .TrimEnd().Replace("\r\n", "\n").Split('\n');
            if (lines.Length != 7 || !Regex.IsMatch(lines[0], "^[0-9a-f]{64}$") ||
                lines[1] != "/" + name || lines[2] != "true" || lines[3] != "docker" ||
                lines[4] != service ||
                !string.Equals(lines[5].Replace('/', '\\'), expectedConfig, StringComparison.OrdinalIgnoreCase) ||
                !lines[6].Split(new[] { ';' }, StringSplitOptions.RemoveEmptyEntries).OrderBy(n => n)
                    .SequenceEqual(networks[service].OrderBy(n => n)))
                throw new InvalidOperationException("Unsupported identity, checkout or network layout for " + name + ".");
            ids.Add(service, lines[0]);
        }
        if (!recovery)
        {
            const string networkDetails = "{{.Driver}}|{{index .Labels \"com.docker.compose.project\"}}|" +
                "{{range .IPAM.Config}}{{.Subnet}};{{end}}";
            foreach (string name in new[] { "guest-net", "business-net" })
            {
                string subnet = name == "guest-net" ? "192.168.10.0/24" : "192.168.20.0/24";
                if (run(new[] { "network", "inspect", "--format", networkDetails, name }).Trim() !=
                    "bridge|docker|" + subnet + ";")
                    throw new InvalidOperationException("Unsupported network owner, driver or subnet for " + name + ".");
            }
            if (run(new[] { "exec", ids["firewall"], "cat", "/proc/sys/net/ipv4/ip_forward" }).Trim() != "1")
                throw new InvalidOperationException("The cafe router is not forwarding IPv4 packets.");
            foreach (string destination in new[] { "192.168.20.15", "192.168.20.10" })
            {
                string route = run(new[] { "exec", ids["kali"], "ip", "-4", "route", "get", destination });
                if (!Regex.IsMatch(route, @"\bvia 192\.168\.10\.254\b") ||
                    !Regex.IsMatch(route, @"\bsrc 192\.168\.10\.50\b"))
                    throw new InvalidOperationException("The Guest route to " + destination + " does not use the cafe router.");
            }
            const string level = "require '/var/www/html/config/config.inc.php'; " +
                "echo isset($_DVWA['default_security_level']) ? $_DVWA['default_security_level'] : 'unknown';";
            if (run(new[] { "exec", ids["dvwa"], "php", "-r", level }).Trim() != "low")
                throw new InvalidOperationException("DVWA must have a verified Low default.");
        }
        return ids;
    }

    internal static void VerifyTraffic(Dictionary<string,string> ids, Func<string[], string> run)
    {
        const string originHealth = "$h = get_headers('http://127.0.0.1/login.php'); " +
            "echo is_array($h) ? $h[0] : 'unavailable';";
        string health = run(new[] { "exec", ids["dvwa"], "php", "-r", originHealth });
        if (!Regex.IsMatch(health, @"^HTTP/\d\.\d 200\b"))
            throw new InvalidOperationException("DVWA did not return HTTP 200 for its local login page.");

        const string curl = "curl --noproxy '*' -s --connect-timeout 3 --max-time 5 " +
            "-o /dev/null -w '%{http_code}' ";
        // Each curl opens a new connection. Keep exit status separate from HTTP status.
        Func<string,string> probe = url => run(new[] { "exec", ids["kali"], "sh", "-c",
            curl + url + "; printf ' %s' \"$?\"" });
        if (probe("http://192.168.20.15:8080/login.php") != "200 0")
            throw new InvalidOperationException("The Guest login-page request through the WAF did not return HTTP 200.");

        Func<ulong> drops = () => {
            string listing = run(new[] { "exec", ids["firewall"], "iptables", "-w", "5", "-nvxL", "FORWARD" });
            var lines = listing.Split('\n').Where(line => line.Contains("/* SWAGPC_CAFE_WAF_V1_DENY */")).ToArray();
            if (lines.Length != 1)
                throw new InvalidOperationException("The managed Guest deny counter is missing or ambiguous.");
            var count = Regex.Match(lines[0], @"^\s*(\d+)\s+\d+\s+DROP\s");
            ulong packets;
            if (!count.Success || !ulong.TryParse(count.Groups[1].Value, out packets))
                throw new InvalidOperationException("Cannot read the managed Guest deny counter.");
            return packets;
        };
        ulong before = drops();
        if (probe("http://192.168.20.10/login.php") != "000 28" || drops() <= before)
            throw new InvalidOperationException("Direct-origin timeout and increased Guest deny counter were not both observed.");
        Console.WriteLine("Origin healthy; Guest WAF login page returned 200; fresh direct connection timed out and Guest deny counter increased.");
    }

    // All arguments, including Go templates and the PHP expression, go directly to docker.exe.
    private static string Quote(string value)
    {
        return "\"" + Regex.Replace(value, "(\\\\*)\"", "$1$1\\\"")
            .TrimEnd('\\') + new string('\\', 2 * (value.Length - value.TrimEnd('\\').Length)) + "\"";
    }

    private static string Run(string docker, string[] command, string input)
    {
        var args = new[] { "--host", "npipe:////./pipe/dockerDesktopLinuxEngine" }.Concat(command);
        var start = new ProcessStartInfo(docker, string.Join(" ", args.Select(Quote)));
        start.UseShellExecute = false;
        start.RedirectStandardInput = input != null;
        start.RedirectStandardOutput = true;
        start.RedirectStandardError = true;
        start.CreateNoWindow = true;
        start.EnvironmentVariables.Remove("DOCKER_CONTEXT");
        start.EnvironmentVariables.Remove("DOCKER_HOST");
        using (var process = Process.Start(start))
        {
            var output = process.StandardOutput.ReadToEndAsync();
            var errors = process.StandardError.ReadToEndAsync();
            Task writer = input == null ? Task.FromResult(0) : Task.Run(async () => {
                try {
                    byte[] bytes = new UTF8Encoding(false).GetBytes(input);
                    await process.StandardInput.BaseStream.WriteAsync(bytes, 0, bytes.Length);
                } finally { process.StandardInput.Close(); }
            });
            if (!process.WaitForExit(30000))
            {
                process.Kill();
                throw new InvalidOperationException("Docker timed out. Check the router state before retrying.");
            }
            if (process.ExitCode != 0)
            {
                // Print only messages emitted by our embedded policy, never raw inspect/config output.
                var diagnostics = errors.Result.Split('\n').Where(l => l.StartsWith("WAF routing:")).ToArray();
                throw new InvalidOperationException("Docker " + command[0] + " exited " + process.ExitCode +
                    ". " + string.Join(" ", diagnostics));
            }
            writer.GetAwaiter().GetResult();
            return output.Result.TrimEnd();
        }
    }
}
