using FlowScopeWindows.Data;
using FlowScopeWindows.Theme;
using Microsoft.UI.Xaml;

namespace FlowScopeWindows;

public partial class App : Application
{
    public static MainWindow? Window { get; private set; }

    public App()
    {
        InitializeComponent();
    }

    protected override async void OnLaunched(LaunchActivatedEventArgs args)
    {
        // Paint the saved theme before the first frame, so the window never
        // flashes the placeholder palette from App.xaml.
        ThemeManager.Shared.PublishResources();

        await SessionStore.Shared.LoadAsync();

        Window = new MainWindow();
        Window.Activate();
    }
}
