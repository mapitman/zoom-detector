using System.Diagnostics;

namespace zoom_detector;

public static class ZoomService
{
    public static bool IsMeetingRunning()
    {
        var processes = Process.GetProcesses()
            .Where(p => p.ProcessName.StartsWith("cpthost", StringComparison.OrdinalIgnoreCase));
        return processes.Any();
    }
}