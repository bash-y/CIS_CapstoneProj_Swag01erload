using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;

internal static class CafeSecurity
{
    private static readonly string[] Required = { "firewall", "dvwa", "waf", "kali" };

    private static int Main(string[] args)
    {
        if (args.Length != 1 || (args[0] != "preflight" && args[0] != "status"))
        {
            Console.WriteLine("CafeSecurity.exe preflight | status | --help");
            Console.WriteLine("Run from the cafe repository root. Both commands are read-only.");
            return args.Length == 1 && args[0] == "--help" ? 0 : 2;
        }

        try
        {
            if (!File.Exists("docker/docker-compose.yml") ||
                !File.Exists("defense/firewall/route-waf-only.sh"))
                throw new InvalidOperationException("Run from the cafe repository root.");

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

            CheckServices(docker, "config --services", "declared");
            if (args[0] == "status")
                CheckServices(docker, "ps --status running --services", "running");
            Console.WriteLine("WAF enforcement and DVWA security level require separate lab checks.");
            return 0;
        }
        catch (Exception error)
        {
            Console.Error.WriteLine("Check incomplete: " + error.Message);
            return 1;
        }
    }

    private static void CheckServices(string docker, string query, string state)
    {
        var start = new ProcessStartInfo(docker,
            "--host npipe:////./pipe/dockerDesktopLinuxEngine compose -p docker -f docker/docker-compose.yml " + query);
        start.UseShellExecute = false;
        start.RedirectStandardOutput = true;
        start.RedirectStandardError = true;
        start.CreateNoWindow = true;
        start.EnvironmentVariables.Remove("DOCKER_CONTEXT");
        start.EnvironmentVariables.Remove("DOCKER_HOST");
        using (var process = Process.Start(start))
        {
            var output = process.StandardOutput.ReadToEndAsync();
            var errors = process.StandardError.ReadToEndAsync();
            if (!process.WaitForExit(30000))
            {
                process.Kill();
                throw new InvalidOperationException("Docker timed out checking " + state + " services.");
            }
            errors.GetAwaiter().GetResult();
            if (process.ExitCode != 0)
                throw new InvalidOperationException("Docker could not list " + state +
                    " services (exit " + process.ExitCode + "). Check Docker Desktop and the Compose file.");
            var services = new HashSet<string>(output.Result.Split(
                new[] { '\r', '\n' }, StringSplitOptions.RemoveEmptyEntries));
            var missing = Required.Where(service => !services.Contains(service)).ToArray();
            if (missing.Length > 0)
                throw new InvalidOperationException("Services missing from " + state +
                    " list: " + string.Join(", ", missing));
            Console.WriteLine("Required services " + state + ": " + string.Join(", ", Required));
        }
    }
}
