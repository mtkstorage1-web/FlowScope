using System.Text.Json;
using FlowScopeWindows.Models;
using FlowScopeWindows.Services;

namespace FlowScopeWindows.Data;

/// <summary>
/// Persists finished sessions as a single JSON document under the app's local
/// data folder — the Windows counterpart to SwiftData on Apple platforms and
/// Room on Android.
///
/// JSON rather than SQLite on purpose: the working set is a few thousand
/// sessions at most, it keeps the app free of native dependencies (so an
/// unpackaged `dotnet run` just works), and the file is the export format.
/// </summary>
public sealed class SessionStore : Observable
{
    public static SessionStore Shared { get; } = new();

    private static readonly JsonSerializerOptions JsonOptions = new()
    {
        WriteIndented = true,
    };

    private readonly string _path;
    private readonly SemaphoreSlim _writeLock = new(1, 1);

    public List<Session> Sessions { get; private set; } = new();

    private SessionStore()
    {
        _path = LocalStorage.PathFor("sessions.json");
    }

    public async Task LoadAsync()
    {
        try
        {
            if (!File.Exists(_path))
            {
                Sessions = new List<Session>();
            }
            else
            {
                await using var stream = File.OpenRead(_path);
                Sessions = await JsonSerializer.DeserializeAsync<List<Session>>(stream, JsonOptions)
                           ?? new List<Session>();
            }
        }
        catch (Exception)
        {
            // A corrupt store must not stop the app from opening — start empty
            // and let the next save rewrite the file.
            Sessions = new List<Session>();
        }

        Sessions.Sort((a, b) => b.StartTime.CompareTo(a.StartTime));
        Raise(nameof(Sessions));
    }

    public async Task AddAsync(Session session)
    {
        Sessions.Insert(0, session);
        Raise(nameof(Sessions));
        await SaveAsync();
    }

    public async Task DeleteAsync(Session session)
    {
        Sessions.RemoveAll(s => s.Id == session.Id);
        Raise(nameof(Sessions));
        await SaveAsync();
    }

    public async Task UpdateAsync(Session session)
    {
        var index = Sessions.FindIndex(s => s.Id == session.Id);
        if (index >= 0) Sessions[index] = session;
        Raise(nameof(Sessions));
        await SaveAsync();
    }

    public async Task SaveAsync()
    {
        await _writeLock.WaitAsync();
        try
        {
            // Write to a sibling then swap, so a crash mid-write can't leave a
            // half-serialized sessions.json behind.
            var temp = _path + ".tmp";
            await using (var stream = File.Create(temp))
            {
                await JsonSerializer.SerializeAsync(stream, Sessions, JsonOptions);
            }
            File.Move(temp, _path, overwrite: true);
        }
        finally
        {
            _writeLock.Release();
        }
    }

    // MARK: - Derived statistics

    public IEnumerable<Session> ForDay(DateTimeOffset day) =>
        Sessions.Where(s => s.StartTime.Date == day.Date);

    public int TotalFocusMinutes => (int)Sessions.Sum(s => s.TotalDuration) / 60;

    public int AverageMood =>
        Sessions.Count == 0 ? 0 : (int)Math.Round(Sessions.Average(s => s.AverageMood));
}
