using System.Text.Json.Serialization;

namespace FlowScopeWindows.Models;

/// <summary>
/// A completed focus session. Mirrors the SwiftData <c>Session</c> model on
/// iOS/macOS and the Room <c>SessionEntity</c> on Android, so an export from
/// one platform stays readable on the others.
/// </summary>
public sealed class Session
{
    public Guid Id { get; set; } = Guid.NewGuid();

    public DateTimeOffset StartTime { get; set; } = DateTimeOffset.Now;

    /// <summary>Null while the session is still open.</summary>
    public DateTimeOffset? EndTime { get; set; }

    /// <summary>Total focused time in seconds (excludes paused stretches).</summary>
    public double TotalDuration { get; set; }

    public string Name { get; set; } = "Untitled Session";

    public string Category { get; set; } = "General";

    public List<MoodLog> MoodLogs { get; set; } = new();

    [JsonIgnore]
    public int DurationInMinutes => (int)(TotalDuration / 60);

    /// <summary>
    /// The number the whole app is really about: how the work felt, averaged
    /// across every check-in. Zero when nothing was logged.
    /// </summary>
    [JsonIgnore]
    public int AverageMood =>
        MoodLogs.Count == 0 ? 0 : (int)Math.Round(MoodLogs.Average(m => m.Satisfaction));

    // x:Bind is strongly typed, so the list template binds these rather than
    // formatting numbers in XAML.

    [JsonIgnore]
    public string AverageMoodDisplay => $"{AverageMood}%";

    [JsonIgnore]
    public string DurationDisplay =>
        DurationInMinutes >= 60
            ? $"{DurationInMinutes / 60}h {DurationInMinutes % 60}m"
            : $"{DurationInMinutes}m";

    [JsonIgnore]
    public string StartedDisplay => StartTime.ToString("ddd, d MMM · HH:mm");

    [JsonIgnore]
    public FocusBand Band => AverageMood switch
    {
        >= 70 => FocusBand.High,
        >= 40 => FocusBand.Medium,
        _ => FocusBand.Low,
    };
}

public enum FocusBand
{
    Low,
    Medium,
    High,
}
