using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;

namespace FlowScopeWindows.Controls;

public sealed partial class SessionSetupDialog : ContentDialog
{
    private static readonly string[] Suggestions =
        { "Work", "Study", "Exercise", "Creative", "Chores", "Reading" };

    public SessionSetupDialog()
    {
        InitializeComponent();

        RequestedTheme = ElementTheme.Dark;

        foreach (var suggestion in Suggestions)
        {
            var chip = new Button
            {
                Content = suggestion,
                CornerRadius = new CornerRadius(14),
                Padding = new Thickness(12, 4, 12, 4),
            };
            chip.Click += (_, _) => CategoryBox.Text = suggestion;
            CategoryChips.Items.Add(chip);
        }
    }

    public string SessionName =>
        string.IsNullOrWhiteSpace(NameBox.Text) ? "Untitled Session" : NameBox.Text.Trim();

    public string Category =>
        string.IsNullOrWhiteSpace(CategoryBox.Text) ? "General" : CategoryBox.Text.Trim();
}
