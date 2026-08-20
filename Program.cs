using Serilog;

namespace zoom_detector;

public class Program
{
    public static void Main(string[] args)
    {
        var daemonMode = args.Any(a => a is "--daemon" or "-d");

        var builder = Host.CreateApplicationBuilder(args);
        builder.Configuration
            .AddYamlFile("appsettings.yml", false);
        builder.Services.AddOptions<MqttConfig>()
            .Bind(builder.Configuration.GetSection("mqtt"));

        // Daemon mode replaces the Spectre.Console display with a rolling log
        // file, so the process can run in the background with no terminal
        // attached. Interactive mode keeps the console output and logs nothing.
        builder.Services.AddSingleton(new RunMode(daemonMode));

        if (daemonMode)
        {
            // Each operating system keeps user logs somewhere different, so
            // resolve the path rather than hard-coding one. A logging:directory
            // setting in appsettings.yml overrides the platform default.
            var logPath = LogPath.Resolve(builder.Configuration["logging:directory"]);

            builder.Logging.ClearProviders();
            builder.Services.AddSerilog(configuration => configuration
                // A serilog section in appsettings.yml can override this, but
                // the default stands on its own so a fresh clone still logs.
                .MinimumLevel.Information()
                .MinimumLevel.Override("Microsoft", Serilog.Events.LogEventLevel.Warning)
                .MinimumLevel.Override("System", Serilog.Events.LogEventLevel.Warning)
                .ReadFrom.Configuration(builder.Configuration)
                .WriteTo.File(
                    logPath,
                    rollingInterval: RollingInterval.Day,
                    retainedFileCountLimit: 14,
                    fileSizeLimitBytes: 10 * 1024 * 1024,
                    rollOnFileSizeLimit: true,
                    outputTemplate: "{Timestamp:yyyy-MM-dd HH:mm:ss} [{Level:u3}] {Message:lj}{NewLine}{Exception}"));
        }

        builder.Services.AddHostedService<Worker>();
        var host = builder.Build();
        host.Run();
    }
}
