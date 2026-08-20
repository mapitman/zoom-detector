namespace zoom_detector;

/// <summary>
/// Whether the process runs as a background daemon or as an interactive
/// console application. Daemon mode suppresses the Spectre.Console display.
/// </summary>
public record RunMode(bool IsDaemon);
