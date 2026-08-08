using FlowScopeWindows.Data;
using FlowScopeWindows.Theme;
using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Navigation;

namespace FlowScopeWindows.Views;

public sealed partial class HistoryPage : Page
{
    private DateTimeOffset _month = new(DateTime.Today.Year, DateTime.Today.Month, 1, 0, 0, 0, DateTimeOffset.Now.Offset);
    private DateTimeOffset _selectedDay = DateTimeOffset.Now;

    public HistoryPage()
    {
        InitializeComponent();
    }

    protected override void OnNavigatedTo(NavigationEventArgs e)
    {
        base.OnNavigatedTo(e);
        BuildMonth();
        ShowDay(_selectedDay);
    }

    private void OnPrevMonth(object sender, RoutedEventArgs e)
    {
        _month = _month.AddMonths(-1);
        BuildMonth();
    }

    private void OnNextMonth(object sender, RoutedEventArgs e)
    {
        _month = _month.AddMonths(1);
        BuildMonth();
    }

    /// <summary>
    /// Each day cell is tinted by that day's average focus, so a month reads
    /// as a heat strip rather than a bare calendar.
    /// </summary>
    private void BuildMonth()
    {
        MonthLabel.Text = _month.ToString("MMMM yyyy");
        DayGrid.Items.Clear();

        var daysInMonth = DateTime.DaysInMonth(_month.Year, _month.Month);
        var leadingBlanks = ((int)new DateTime(_month.Year, _month.Month, 1).DayOfWeek + 6) % 7;

        for (var i = 0; i < leadingBlanks; i++)
        {
            DayGrid.Items.Add(new Border { Width = 44, Height = 44, IsHitTestVisible = false });
        }

        for (var day = 1; day <= daysInMonth; day++)
        {
            var date = new DateTimeOffset(_month.Year, _month.Month, day, 0, 0, 0, _month.Offset);
            var sessions = SessionStore.Shared.ForDay(date).ToList();
            var average = sessions.Count == 0 ? 0 : (int)sessions.Average(s => s.AverageMood);

            var cell = new Border
            {
                Width = 44,
                Height = 44,
                CornerRadius = new CornerRadius(8),
                Tag = date,
                Background = sessions.Count == 0
                    ? null
                    : new Microsoft.UI.Xaml.Media.SolidColorBrush(
                        ThemeManager.Shared.Configuration.Primary.WithOpacity(0.2 + average / 100.0 * 0.7)),
                Child = new TextBlock
                {
                    Text = day.ToString(),
                    HorizontalAlignment = HorizontalAlignment.Center,
                    VerticalAlignment = VerticalAlignment.Center,
                    Foreground = ThemeManager.Shared.TextPrimaryBrush,
                },
            };

            DayGrid.Items.Add(cell);
        }
    }

    private void OnDaySelected(object sender, SelectionChangedEventArgs e)
    {
        if (DayGrid.SelectedItem is Border { Tag: DateTimeOffset date })
        {
            _selectedDay = date;
            ShowDay(date);
        }
    }

    private void ShowDay(DateTimeOffset day)
    {
        var sessions = SessionStore.Shared.ForDay(day).ToList();

        DayHeading.Text = sessions.Count == 0
            ? $"{day:dddd, d MMMM} — nothing logged"
            : $"{day:dddd, d MMMM} — {sessions.Count} session{(sessions.Count == 1 ? "" : "s")}";

        DaySessions.ItemsSource = sessions
            .Select(s => $"{s.Name} · {s.DurationDisplay} · {s.AverageMoodDisplay}")
            .ToList();
    }
}
