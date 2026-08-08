using Microsoft.UI.Xaml;
using Microsoft.UI.Xaml.Controls;
using Microsoft.UI.Xaml.Controls.Primitives;

namespace FlowScopeWindows.Controls;

public sealed partial class MoodDialog : ContentDialog
{
    public MoodDialog()
    {
        InitializeComponent();
        RequestedTheme = ElementTheme.Dark;
        UpdateLabels(50);
    }

    public int Satisfaction
    {
        get => (int)MoodSlider.Value;
        set
        {
            MoodSlider.Value = Math.Clamp(value, 0, 100);
            UpdateLabels(MoodSlider.Value);
        }
    }

    public string Note => NoteBox.Text.Trim();

    private void OnMoodChanged(object sender, RangeBaseValueChangedEventArgs e) =>
        UpdateLabels(e.NewValue);

    private void UpdateLabels(double value)
    {
        if (ValueText is null) return;

        ValueText.Text = ((int)value).ToString();
        DescriptorText.Text = value switch
        {
            >= 85 => "In flow",
            >= 70 => "Focused",
            >= 50 => "Steady",
            >= 30 => "Drifting",
            _ => "Struggling",
        };
    }
}
