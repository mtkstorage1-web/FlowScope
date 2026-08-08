using FlowScopeWindows.Data;
using FlowScopeWindows.Models;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;

namespace FlowScopeWindows.Views;

public sealed partial class WorkLogPage : Page
{
    public WorkLogPage()
    {
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        Refresh();
    }

    private void Refresh()
    {
        var store = SessionStore.Shared;
        var all = store.Sessions;

        SessionCountText.Text = all.Count.ToString();
        TotalTimeText.Text = FormatMinutes(store.TotalFocusMinutes);
        AverageMoodText.Text = $"{store.AverageMood}%";

        SessionList.ItemsSource = Filtered(all).ToList();
    }

    private IEnumerable<Session> Filtered(IEnumerable<Session> sessions)
    {
        var band = (BandFilter.SelectedItem as ComboBoxItem)?.Content as string ?? "All";
        var query = SearchBox?.Text?.Trim() ?? string.Empty;

        var result = band switch
        {
            "High Focus" => sessions.Where(s => s.Band == FocusBand.High),
            "Medium Focus" => sessions.Where(s => s.Band == FocusBand.Medium),
            "Low Focus" => sessions.Where(s => s.Band == FocusBand.Low),
            _ => sessions,
        };

        if (!string.IsNullOrEmpty(query))
        {
            result = result.Where(s =>
                s.Name.Contains(query, StringComparison.OrdinalIgnoreCase) ||
                s.Category.Contains(query, StringComparison.OrdinalIgnoreCase));
        }

        return result;
    }

    private static string FormatMinutes(int minutes) =>
        minutes >= 60 ? $"{minutes / 60}h {minutes % 60}m" : $"{minutes}m";

    private void OnFilterChanged(object sender, SelectionChangedEventArgs e) => Refresh();

    private void OnSearchChanged(AutoSuggestBox sender, AutoSuggestBoxTextChangedEventArgs args)
    {
        if (args.Reason == AutoSuggestionBoxTextChangeReason.UserInput) Refresh();
    }

    private async void OnSessionClick(object sender, ItemClickEventArgs e)
    {
        if (e.ClickedItem is not Session session) return;

        var detail = new ContentDialog
        {
            XamlRoot = XamlRoot,
            Title = session.Name,
            PrimaryButtonText = "Delete",
            CloseButtonText = "Close",
            DefaultButton = ContentDialogButton.Close,
            Content = BuildDetail(session),
        };

        if (await detail.ShowAsync() == ContentDialogResult.Primary)
        {
            await SessionStore.Shared.DeleteAsync(session);
            Refresh();
        }
    }

    /// <summary>
    /// The mood trail is the point of a session record, so the detail view
    /// lists every check-in against its offset rather than just a total.
    /// </summary>
    private static StackPanel BuildDetail(Session session)
    {
        var panel = new StackPanel { Spacing = 8, Width = 420 };

        panel.Children.Add(new TextBlock
        {
            Text = $"{session.Category} · {session.DurationInMinutes} min · avg {session.AverageMood}%",
        });

        panel.Children.Add(new TextBlock
        {
            Text = session.StartTime.ToString("dddd, d MMM yyyy HH:mm"),
            Opacity = 0.7,
        });

        if (session.MoodLogs.Count == 0)
        {
            panel.Children.Add(new TextBlock { Text = "No mood logs recorded.", Opacity = 0.6 });
            return panel;
        }

        foreach (var log in session.MoodLogs.OrderBy(m => m.Timestamp))
        {
            var line = $"{log.Offset:mm\\:ss} — {log.Satisfaction}%";
            if (!string.IsNullOrWhiteSpace(log.Note)) line += $"  “{log.Note}”";
            panel.Children.Add(new TextBlock { Text = line, TextWrapping = Microsoft.UI.Xaml.TextWrapping.Wrap });
        }

        return panel;
    }
}
