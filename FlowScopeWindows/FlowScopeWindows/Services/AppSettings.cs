using FlowScopeWindows.Theme;

namespace FlowScopeWindows.Services;

/// <summary>
/// User preferences, backed by the roaming-capable local settings store.
/// Mirrors <c>AppSettings.swift</c> / <c>AppSettings.kt</c>.
/// </summary>
public sealed class AppSettings : Observable
{
    public static AppSettings Shared { get; } = new();

    private readonly KeyValueStore _store = KeyValueStore.Shared;

    private AppSettings()
    {
        _theme = AppThemeInfo.FromId(Read("theme", AppTheme.Flame.Id()));
        _soundEnabled = Read("soundEnabled", true);
        _soundVolume = Read("soundVolume", 0.6);
        _hapticsEnabled = Read("hapticsEnabled", true);
        _keepScreenAwake = Read("keepScreenAwake", true);
        _floatingControlEnabled = Read("floatingControlEnabled", true);
        _focusCycleMinutes = Read("focusCycleMinutes", 25);
        _moodPromptMinutes = Read("moodPromptMinutes", 0);
    }

    private AppTheme _theme;
    public AppTheme Theme
    {
        get => _theme;
        set { if (Set(ref _theme, value)) Write("theme", value.Id()); }
    }

    private bool _soundEnabled;
    public bool SoundEnabled
    {
        get => _soundEnabled;
        set { if (Set(ref _soundEnabled, value)) Write("soundEnabled", value); }
    }

    private double _soundVolume;
    public double SoundVolume
    {
        get => _soundVolume;
        set { if (Set(ref _soundVolume, value)) Write("soundVolume", value); }
    }

    private bool _hapticsEnabled;
    public bool HapticsEnabled
    {
        get => _hapticsEnabled;
        set { if (Set(ref _hapticsEnabled, value)) Write("hapticsEnabled", value); }
    }

    /// <summary>Holds off the display timeout while a session is running.</summary>
    private bool _keepScreenAwake;
    public bool KeepScreenAwake
    {
        get => _keepScreenAwake;
        set { if (Set(ref _keepScreenAwake, value)) Write("keepScreenAwake", value); }
    }

    private bool _floatingControlEnabled;
    public bool FloatingControlEnabled
    {
        get => _floatingControlEnabled;
        set { if (Set(ref _floatingControlEnabled, value)) Write("floatingControlEnabled", value); }
    }

    /// <summary>Length of one focus cycle; 0 disables cycle completion cues.</summary>
    private int _focusCycleMinutes;
    public int FocusCycleMinutes
    {
        get => _focusCycleMinutes;
        set { if (Set(ref _focusCycleMinutes, value)) Write("focusCycleMinutes", value); }
    }

    /// <summary>How often to nudge for a mood check-in; 0 disables nudges.</summary>
    private int _moodPromptMinutes;
    public int MoodPromptMinutes
    {
        get => _moodPromptMinutes;
        set { if (Set(ref _moodPromptMinutes, value)) Write("moodPromptMinutes", value); }
    }

    private T Read<T>(string key, T fallback) => _store.Get(key, fallback);

    private void Write<T>(string key, T value) => _store.Set(key, value);
}
