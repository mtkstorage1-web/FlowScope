namespace FlowScopeWindows.Models;

/// <summary>
/// One "how does this feel right now?" check-in, anchored to a point inside a
/// session rather than to wall-clock time — that is what lets the graph plot
/// satisfaction against elapsed focus.
/// </summary>
public sealed class MoodLog
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>Seconds since the owning session started.</summary>
    public double Timestamp { get; set; }

    /// <summary>0–100.</summary>
    public int Satisfaction { get; set; }

    public string Note { get; set; } = string.Empty;

    public TimeSpan Offset => TimeSpan.FromSeconds(Timestamp);
}
