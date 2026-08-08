using System.ComponentModel;
using System.Runtime.CompilerServices;

namespace FlowScopeWindows.Services;

/// <summary>
/// Minimal INotifyPropertyChanged base. The app has few enough view models
/// that pulling in a full MVVM framework would cost more than it saves.
/// </summary>
public abstract class Observable : INotifyPropertyChanged
{
    public event PropertyChangedEventHandler? PropertyChanged;

    protected void Raise([CallerMemberName] string? name = null) =>
        PropertyChanged?.Invoke(this, new PropertyChangedEventArgs(name));

    protected bool Set<T>(ref T field, T value, [CallerMemberName] string? name = null)
    {
        if (EqualityComparer<T>.Default.Equals(field, value)) return false;
        field = value;
        Raise(name);
        return true;
    }
}
