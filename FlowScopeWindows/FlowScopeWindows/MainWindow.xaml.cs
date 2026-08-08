using FlowScopeWindows.Views;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Media;
using Microsoft.UI.Windowing;
using Windows.Graphics;

namespace FlowScopeWindows;

public sealed partial class MainWindow : Window
{
    public MainWindow()
    {
        InitializeComponent();

        Title = "FlowScope";

        // Mica is the Windows 11 window material; the themed gradient sits on
        // top of it at partial strength so each theme still reads as itself.
        SystemBackdrop = new MicaBackdrop { Kind = Microsoft.UI.Composition.SystemBackdrops.MicaKind.Base };

        ExtendsContentIntoTitleBar = true;
        SetTitleBar(AppTitleBar);

        var appWindow = AppWindow;
        appWindow.Resize(new SizeInt32(1180, 820));

        if (appWindow.Presenter is OverlappedPresenter presenter)
        {
            presenter.PreferredMinimumWidth = 900;
            presenter.PreferredMinimumHeight = 640;
        }

        ContentFrame.Navigate(typeof(TimerPage));
    }

    private void OnNavSelectionChanged(NavigationView sender, NavigationViewSelectionChangedEventArgs args)
    {
        if (args.SelectedItem is not NavigationViewItem item) return;

        var page = item.Tag as string switch
        {
            "focus" => typeof(TimerPage),
            "worklog" => typeof(WorkLogPage),
            "history" => typeof(HistoryPage),
            "appearance" => typeof(AppearancePage),
            _ => typeof(TimerPage),
        };

        if (ContentFrame.CurrentSourcePageType != page)
        {
            ContentFrame.Navigate(page);
        }
    }
}
