using System.Text.Json;
using FlowScopeWindows.Data;
using FlowScopeWindows.Models;
using Microsoft.UI.Xaml;

namespace FlowScopeWindows.Services;

/// <summary>
/// The running session: start/pause/resume/stop, mood logging, and recovery of
/// a session that survived the app being closed.
///
/// Elapsed time is always derived from wall-clock stamps rather than counted
/// by the tick handler, so a missed tick, a sleep/resume, or a clock change
/// can't make the timer drift — same rule as SessionManager.swift.
/// </summary>
public sealed class SessionManager : Observable
{
    public static SessionManager Shared { get; } = new();

    private const string LiveStateKey = "liveSessionState.v2";

    private readonly DispatcherTimer _ticker = new() { Interval = TimeSpan.FromSeconds(1) };
    private readonly KeyValueStore _store = new("livesession.json");

    /// <summary>Time banked by run segments that have already been paused.</summary>
    private double _accumulated;

    /// <summary>When the current run segment began; null while paused.</summary>
    private DateTimeOffset? _runningSince;

    private DateTimeOffset _sessionStart = DateTimeOffset.Now;
    private Guid _sessionId = Guid.NewGuid();
    private int _lastCycleIndex;
    private int _ticksSincePersist;

    private SessionManager()
    {
        _ticker.Tick += (_, _) => Tick();
        RestoreIfNeeded();
    }

    // MARK: - Observable state

    private bool _isRunning;
    public bool IsRunning
    {
        get => _isRunning;
        private set
        {
            if (!Set(ref _isRunning, value)) return;
            Raise(nameof(IsActive));
            KeepAwake.SetEnabled(value && AppSettings.Shared.KeepScreenAwake);
        }
    }

    private bool _isPaused;
    public bool IsPaused
    {
        get => _isPaused;
        private set { if (Set(ref _isPaused, value)) Raise(nameof(IsActive)); }
    }

    /// <summary>True whenever a session exists, running or paused.</summary>
    public bool IsActive => IsRunning || IsPaused;

    private double _elapsedSeconds;
    public double ElapsedSeconds
    {
        get => _elapsedSeconds;
        private set { if (Set(ref _elapsedSeconds, value)) Raise(nameof(ElapsedDisplay)); }
    }

    /// <summary>mm:ss under an hour, h:mm:ss beyond it.</summary>
    public string ElapsedDisplay
    {
        get
        {
            var span = TimeSpan.FromSeconds(ElapsedSeconds);
            return span.TotalHours >= 1
                ? $"{(int)span.TotalHours}:{span.Minutes:D2}:{span.Seconds:D2}"
                : $"{span.Minutes:D2}:{span.Seconds:D2}";
        }
    }

    private string _sessionName = string.Empty;
    public string SessionName
    {
        get => _sessionName;
        private set => Set(ref _sessionName, value);
    }

    private string _sessionCategory = "General";
    public string SessionCategory
    {
        get => _sessionCategory;
        private set => Set(ref _sessionCategory, value);
    }

    public List<MoodLog> MoodLogs { get; private set; } = new();

    public int MoodCount => MoodLogs.Count;

    /// <summary>Latest satisfaction reading, or 50 before the first check-in.</summary>
    public int CurrentMood => MoodLogs.Count == 0 ? 50 : MoodLogs[^1].Satisfaction;

    /// <summary>Raised when a focus cycle completes, for the on-screen flash.</summary>
    public event EventHandler? CycleCompleted;

    /// <summary>Raised when it's time to nudge for a mood check-in.</summary>
    public event EventHandler? MoodPromptDue;

    // MARK: - Lifecycle

    public void StartSession(string name = "Untitled Session", string category = "General")
    {
        _sessionId = Guid.NewGuid();
        _sessionStart = DateTimeOffset.Now;
        _accumulated = 0;
        _runningSince = DateTimeOffset.Now;
        _lastCycleIndex = 0;
        MoodLogs = new List<MoodLog>();

        SessionName = string.IsNullOrWhiteSpace(name) ? "Untitled Session" : name.Trim();
        SessionCategory = string.IsNullOrWhiteSpace(category) ? "General" : category.Trim();
        ElapsedSeconds = 0;
        IsPaused = false;
        IsRunning = true;

        _ticker.Start();
        PersistLiveState();
        Raise(nameof(MoodCount));
        Raise(nameof(CurrentMood));
    }

    public void PauseSession()
    {
        if (!IsRunning) return;

        // Bank the segment before dropping the anchor, or the time is lost.
        _accumulated += (DateTimeOffset.Now - (_runningSince ?? DateTimeOffset.Now)).TotalSeconds;
        _runningSince = null;

        _ticker.Stop();
        IsRunning = false;
        IsPaused = true;
        RecomputeElapsed();
        PersistLiveState();
    }

    public void ResumeSession()
    {
        if (!IsPaused) return;

        _runningSince = DateTimeOffset.Now;
        IsPaused = false;
        IsRunning = true;
        _ticker.Start();
        PersistLiveState();
    }

    /// <summary>Ends the session and files it in the work log.</summary>
    public async Task StopSessionAsync()
    {
        if (!IsActive) return;

        RecomputeElapsed();

        var session = new Session
        {
            Id = _sessionId,
            StartTime = _sessionStart,
            EndTime = DateTimeOffset.Now,
            TotalDuration = ElapsedSeconds,
            Name = SessionName,
            Category = SessionCategory,
            MoodLogs = MoodLogs.ToList(),
        };

        _ticker.Stop();
        IsRunning = false;
        IsPaused = false;
        _runningSince = null;
        _accumulated = 0;
        ElapsedSeconds = 0;
        MoodLogs = new List<MoodLog>();
        SessionName = string.Empty;
        ClearLiveState();
        Raise(nameof(MoodCount));
        Raise(nameof(CurrentMood));

        await SessionStore.Shared.AddAsync(session);
    }

    // MARK: - Mood

    public void LogMood(int satisfaction, string note = "")
    {
        if (!IsActive) return;

        MoodLogs.Add(new MoodLog
        {
            Timestamp = ElapsedSeconds,
            Satisfaction = Math.Clamp(satisfaction, 0, 100),
            Note = note,
        });

        Raise(nameof(MoodCount));
        Raise(nameof(CurrentMood));
        PersistLiveState();
    }

    // MARK: - Ticking

    private void Tick()
    {
        RecomputeElapsed();
        CheckCycleBoundary();
        CheckMoodPrompt();

        // Snapshot every few seconds rather than every tick: recovery only
        // needs to be close, and elapsed time is recomputed from the stamps on
        // restore anyway, so a few seconds of staleness costs nothing.
        if (++_ticksSincePersist >= 5)
        {
            _ticksSincePersist = 0;
            PersistLiveState();
        }
    }

    private void RecomputeElapsed()
    {
        var live = _runningSince is { } since
            ? Math.Max(0, (DateTimeOffset.Now - since).TotalSeconds)
            : 0;
        ElapsedSeconds = _accumulated + live;
    }

    private void CheckCycleBoundary()
    {
        var cycleMinutes = AppSettings.Shared.FocusCycleMinutes;
        if (cycleMinutes <= 0) return;

        var index = (int)(ElapsedSeconds / (cycleMinutes * 60));
        if (index > _lastCycleIndex)
        {
            _lastCycleIndex = index;
            CycleCompleted?.Invoke(this, EventArgs.Empty);
            SoundService.Shared.Play(SoundCue.CycleComplete);
        }
    }

    private DateTimeOffset _lastMoodPrompt = DateTimeOffset.MinValue;

    private void CheckMoodPrompt()
    {
        var every = AppSettings.Shared.MoodPromptMinutes;
        if (every <= 0) return;

        if (DateTimeOffset.Now - _lastMoodPrompt >= TimeSpan.FromMinutes(every))
        {
            _lastMoodPrompt = DateTimeOffset.Now;
            MoodPromptDue?.Invoke(this, EventArgs.Empty);
        }
    }

    // MARK: - Crash / close recovery

    private sealed record LiveSnapshot(
        Guid SessionId,
        string Name,
        string Category,
        DateTimeOffset SessionStart,
        double Accumulated,
        DateTimeOffset? RunningSince,
        List<MoodLog> Moods);

    private void PersistLiveState()
    {
        var snapshot = new LiveSnapshot(
            _sessionId, SessionName, SessionCategory, _sessionStart,
            _accumulated, _runningSince, MoodLogs.ToList());

        _store.Set(LiveStateKey, JsonSerializer.Serialize(snapshot));
    }

    private void ClearLiveState() => _store.Remove(LiveStateKey);

    /// <summary>
    /// Reattaches to a session that outlived the app. Without this, closing the
    /// window mid-session would silently throw away the focus time.
    /// </summary>
    private void RestoreIfNeeded()
    {
        var json = _store.Get<string?>(LiveStateKey, null);
        if (string.IsNullOrEmpty(json)) return;

        LiveSnapshot? snapshot;
        try
        {
            snapshot = JsonSerializer.Deserialize<LiveSnapshot>(json);
        }
        catch (JsonException)
        {
            ClearLiveState();
            return;
        }

        if (snapshot is null) return;

        _sessionId = snapshot.SessionId;
        _sessionStart = snapshot.SessionStart;
        _accumulated = snapshot.Accumulated;
        _runningSince = snapshot.RunningSince;
        MoodLogs = snapshot.Moods;
        SessionName = snapshot.Name;
        SessionCategory = snapshot.Category;

        RecomputeElapsed();

        if (snapshot.RunningSince is not null)
        {
            IsPaused = false;
            IsRunning = true;
            _ticker.Start();
        }
        else
        {
            IsRunning = false;
            IsPaused = true;
        }
    }
}
