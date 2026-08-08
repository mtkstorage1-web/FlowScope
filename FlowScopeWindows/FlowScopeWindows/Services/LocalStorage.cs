using System.Text.Json;

namespace FlowScopeWindows.Services;

/// <summary>
/// App-data paths and a tiny key/value store.
///
/// Deliberately not <c>Windows.Storage.ApplicationData</c>: that API requires
/// package identity and throws outright in an unpackaged app, which is how
/// this project is configured. Plain files under LocalApplicationData work in
/// both modes.
/// </summary>
public static class LocalStorage
{
    public static string Folder { get; } = EnsureFolder();

    private static string EnsureFolder()
    {
        var path = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),
            "FlowScope");

        Directory.CreateDirectory(path);
        return path;
    }

    public static string PathFor(string fileName) => Path.Combine(Folder, fileName);
}

/// <summary>A JSON-backed settings dictionary, flushed on every write.</summary>
public sealed class KeyValueStore
{
    public static KeyValueStore Shared { get; } = new("settings.json");

    private readonly string _path;
    private readonly Dictionary<string, JsonElement> _values;

    public KeyValueStore(string fileName)
    {
        _path = LocalStorage.PathFor(fileName);

        try
        {
            _values = File.Exists(_path)
                ? JsonSerializer.Deserialize<Dictionary<string, JsonElement>>(File.ReadAllText(_path)) ?? new()
                : new();
        }
        catch (Exception)
        {
            // A corrupt settings file must not block startup — fall back to
            // defaults and let the next write replace it.
            _values = new();
        }
    }

    public T Get<T>(string key, T fallback)
    {
        if (!_values.TryGetValue(key, out var element)) return fallback;

        try
        {
            return element.Deserialize<T>() ?? fallback;
        }
        catch (JsonException)
        {
            return fallback;
        }
    }

    public void Set<T>(string key, T value)
    {
        _values[key] = JsonSerializer.SerializeToElement(value);
        Flush();
    }

    public void Remove(string key)
    {
        if (_values.Remove(key)) Flush();
    }

    private void Flush()
    {
        try
        {
            File.WriteAllText(_path, JsonSerializer.Serialize(_values));
        }
        catch (IOException)
        {
            // Losing a preference write is not worth taking the app down.
        }
    }
}
