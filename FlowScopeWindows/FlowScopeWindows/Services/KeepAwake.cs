using System.Runtime.InteropServices;

namespace FlowScopeWindows.Services;

/// <summary>
/// Holds off display sleep while a session is running — the Windows analogue
/// of <c>isIdleTimerDisabled</c> on iOS and a power-management activity on Mac.
/// </summary>
public static class KeepAwake
{
    [Flags]
    private enum ExecutionState : uint
    {
        Continuous = 0x80000000,
        SystemRequired = 0x00000001,
        DisplayRequired = 0x00000002,
    }

    [DllImport("kernel32.dll", SetLastError = true)]
    private static extern uint SetThreadExecutionState(ExecutionState flags);

    private static bool _enabled;

    public static void SetEnabled(bool enabled)
    {
        if (enabled == _enabled) return;
        _enabled = enabled;

        // Clearing the flags (Continuous alone) restores normal idle behaviour.
        SetThreadExecutionState(enabled
            ? ExecutionState.Continuous | ExecutionState.SystemRequired | ExecutionState.DisplayRequired
            : ExecutionState.Continuous);
    }
}
