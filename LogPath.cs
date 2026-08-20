using System.Runtime.InteropServices;

namespace zoom_detector;

/// <summary>
/// Resolves where the rolling log file goes on each operating system.
/// </summary>
public static class LogPath
{
    private const string LogFileName = "zoom-detector-.log";

    /// <summary>
    /// Returns the log file template path, honouring an explicit override.
    /// </summary>
    /// <param name="configuredDirectory">
    /// A directory from configuration, or null to use the platform default.
    /// </param>
    public static string Resolve(string? configuredDirectory = null)
    {
        if (!string.IsNullOrWhiteSpace(configuredDirectory))
        {
            return Path.Combine(
                Environment.ExpandEnvironmentVariables(configuredDirectory),
                LogFileName);
        }

        return Path.Combine(DefaultDirectory(), LogFileName);
    }

    /// <summary>
    /// The conventional log directory for the current operating system.
    /// </summary>
    private static string DefaultDirectory()
    {
        // macOS keeps user logs in a dedicated directory that the Console app
        // reads, so prefer it over Application Support.
        if (RuntimeInformation.IsOSPlatform(OSPlatform.OSX))
        {
            return Path.Combine(
                Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                "Library",
                "Logs",
                "zoom-detector");
        }

        // Linux has no equivalent user log directory, and journald is not
        // available to a plain file sink, so follow the XDG state convention.
        if (RuntimeInformation.IsOSPlatform(OSPlatform.Linux))
        {
            var stateHome = Environment.GetEnvironmentVariable("XDG_STATE_HOME");
            if (string.IsNullOrWhiteSpace(stateHome))
            {
                stateHome = Path.Combine(
                    Environment.GetFolderPath(Environment.SpecialFolder.UserProfile),
                    ".local",
                    "state");
            }

            return Path.Combine(stateHome, "zoom-detector", "log");
        }

        // Windows, and any other platform: LocalApplicationData resolves to
        // AppData\Local, which is where a per-user service writes its logs.
        return Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "zoom-detector",
            "logs");
    }
}
