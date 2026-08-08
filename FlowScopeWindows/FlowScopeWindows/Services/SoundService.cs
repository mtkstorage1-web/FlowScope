using System.Runtime.InteropServices;
using Windows.Media.Audio;
using Windows.Media.MediaProperties;

namespace FlowScopeWindows.Services;

public enum SoundCue
{
    Start,
    Pause,
    Resume,
    MoodLogged,
    CycleComplete,
    Stop,
}

/// <summary>
/// Synthesises the app's short cues rather than shipping audio files, matching
/// how SoundManager.swift drives AVAudioEngine. One AudioGraph is built lazily
/// and reused; if audio is unavailable the whole service degrades to silence
/// instead of throwing into the UI thread.
/// </summary>
public sealed class SoundService
{
    public static SoundService Shared { get; } = new();

    private const int SampleRate = 44_100;

    private AudioGraph? _graph;
    private AudioDeviceOutputNode? _output;
    private bool _unavailable;

    private SoundService() { }

    /// <summary>Frequency ramp and length for each cue.</summary>
    private static (double[] Frequencies, double Seconds) Recipe(SoundCue cue) => cue switch
    {
        SoundCue.Start => (new[] { 523.25, 783.99 }, 0.18),          // C5 → G5, rising
        SoundCue.Pause => (new[] { 587.33, 440.00 }, 0.16),          // D5 → A4, falling
        SoundCue.Resume => (new[] { 440.00, 587.33 }, 0.16),
        SoundCue.MoodLogged => (new[] { 880.00 }, 0.09),             // single blip
        SoundCue.CycleComplete => (new[] { 659.25, 880.00, 1046.50 }, 0.42),
        SoundCue.Stop => (new[] { 659.25, 440.00, 329.63 }, 0.30),
        _ => (new[] { 440.00 }, 0.1),
    };

    public async void Play(SoundCue cue)
    {
        if (_unavailable || !AppSettings.Shared.SoundEnabled) return;

        var volume = AppSettings.Shared.SoundVolume;
        if (volume <= 0.01) return;

        try
        {
            if (!await EnsureGraphAsync()) return;

            var (frequencies, seconds) = Recipe(cue);
            var buffer = Render(frequencies, seconds, volume);

            var node = _graph!.CreateFrameInputNode();
            node.AddOutgoingConnection(_output!);

            var sent = false;
            node.QuantumStarted += (sender, _) =>
            {
                if (sent) return;
                sent = true;
                sender.AddFrame(buffer);
            };

            node.Start();
            _graph.Start();

            // Let the cue finish, then drop the node so they don't accumulate.
            await Task.Delay(TimeSpan.FromSeconds(seconds + 0.15));
            node.Stop();
            node.Dispose();
        }
        catch (Exception)
        {
            _unavailable = true;
        }
    }

    private async Task<bool> EnsureGraphAsync()
    {
        if (_graph is not null) return true;

        var settings = new AudioGraphSettings(Windows.Media.Render.AudioRenderCategory.SoundEffects)
        {
            QuantumSizeSelectionMode = QuantumSizeSelectionMode.LowestLatency,
        };

        var graphResult = await AudioGraph.CreateAsync(settings);
        if (graphResult.Status != AudioGraphCreationStatus.Success) return false;

        var outputResult = await graphResult.Graph.CreateDeviceOutputNodeAsync();
        if (outputResult.Status != AudioDeviceNodeCreationStatus.Success) return false;

        _graph = graphResult.Graph;
        _output = outputResult.DeviceOutputNode;
        return true;
    }

    /// <summary>
    /// Builds one mono frame: the frequencies played in sequence, each with a
    /// short attack and a long decay so the cue reads as a chime, not a beep.
    /// </summary>
    private static Windows.Media.AudioFrame Render(double[] frequencies, double seconds, double volume)
    {
        var totalSamples = (int)(SampleRate * seconds);
        var perNote = Math.Max(1, totalSamples / frequencies.Length);
        var frame = new Windows.Media.AudioFrame((uint)(totalSamples * sizeof(float)));

        using var buffer = frame.LockBuffer(Windows.Media.AudioBufferAccessMode.Write);
        using var reference = buffer.CreateReference();

        unsafe
        {
            ((IMemoryBufferByteAccess)reference).GetBuffer(out var dataInBytes, out _);
            var data = (float*)dataInBytes;

            for (var i = 0; i < totalSamples; i++)
            {
                var noteIndex = Math.Min(frequencies.Length - 1, i / perNote);
                var positionInNote = (i % perNote) / (double)perNote;

                // 8% attack, then exponential decay.
                var envelope = positionInNote < 0.08
                    ? positionInNote / 0.08
                    : Math.Pow(1 - (positionInNote - 0.08) / 0.92, 2.2);

                var phase = 2 * Math.PI * frequencies[noteIndex] * (i / (double)SampleRate);
                data[i] = (float)(Math.Sin(phase) * envelope * volume * 0.35);
            }
        }

        return frame;
    }

    [ComImport]
    [Guid("5B0D3235-4DBA-4D44-865E-8F1D0E4FD04D")]
    [InterfaceType(ComInterfaceType.InterfaceIsIUnknown)]
    private unsafe interface IMemoryBufferByteAccess
    {
        void GetBuffer(out byte* buffer, out uint capacity);
    }
}
