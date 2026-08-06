package mtk.flowscope.audio

import android.content.Context
import android.media.AudioAttributes
import android.media.AudioFormat
import android.media.AudioTrack
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import mtk.flowscope.theme.AppSettings
import mtk.flowscope.theme.AppTheme
import kotlin.math.PI
import kotlin.math.exp
import kotlin.math.min
import kotlin.math.sin
import kotlin.math.tanh

/**
 * Theme-aware sound design, synthesised at runtime — no audio files to ship,
 * and every cue can be tuned per theme. Ported from `SoundManager.swift`, with
 * AVAudioEngine's additive synthesis rebuilt on [AudioTrack].
 *
 * Cues use the MEDIA usage with a short one-shot track, so they mix with the
 * user's music rather than interrupting it.
 */
enum class SoundCue {
    SessionStart, SessionPause, SessionResume, SessionEnd, MoodLogged, CycleComplete, ThemeSwitch
}

/** Per-theme sonic character, so Lightning cracks and Aurora shimmers. */
enum class SoundProfile(val id: String, val label: String) {
    Crystalline("crystalline", "Crystalline"),
    Warm("warm", "Warm"),
    Electric("electric", "Electric"),
    Retro("retro", "Retro"),
    Cosmic("cosmic", "Cosmic");

    /** Base frequency (Hz) for a pleasant interval in this profile. */
    val rootFrequency: Double
        get() = when (this) {
            Crystalline -> 880.0
            Warm -> 392.0
            Electric -> 660.0
            Retro -> 523.0
            Cosmic -> 466.0
        }

    /** Harmonic weights — how bright/complex the timbre is. */
    val harmonics: List<Double>
        get() = when (this) {
            Crystalline -> listOf(1.0, 0.35, 0.18, 0.09)
            Warm -> listOf(1.0, 0.5, 0.12)
            Electric -> listOf(1.0, 0.7, 0.5, 0.35, 0.2)
            Retro -> listOf(1.0, 0.0, 0.6, 0.0, 0.35) // hollow, square-ish
            Cosmic -> listOf(1.0, 0.25, 0.4, 0.15, 0.08)
        }

    companion object {
        fun matching(theme: AppTheme): SoundProfile = when (theme) {
            AppTheme.Lightning, AppTheme.Laser -> Electric
            AppTheme.Flame, AppTheme.Lava, AppTheme.BurningEmber -> Warm
            AppTheme.Cyberpunk, AppTheme.Neon80s -> Retro
            AppTheme.Aurora, AppTheme.Galaxy -> Cosmic
            AppTheme.DarkMatter -> Crystalline
        }
    }
}

class SoundManager private constructor(private val context: Context) {

    private val sampleRate = 44_100
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    fun play(cue: SoundCue, theme: AppTheme) {
        val settings = AppSettings.get(context)
        if (!settings.soundEnabled) return
        val volume = settings.soundVolume.toFloat()
        if (volume <= 0.01f) return

        val profile = SoundProfile.matching(theme)
        scope.launch {
            runCatching { render(notes(cue), profile, volume).let(::emit) }
        }
    }

    /** (frequency multiplier, start time, duration) per partial of the cue. */
    private fun notes(cue: SoundCue): List<Triple<Double, Double, Double>> = when (cue) {
        // rising perfect fifth
        SoundCue.SessionStart -> listOf(Triple(1.0, 0.0, 0.18), Triple(1.5, 0.09, 0.26))
        SoundCue.SessionResume -> listOf(Triple(1.0, 0.0, 0.14), Triple(1.25, 0.07, 0.2))
        // falling step
        SoundCue.SessionPause -> listOf(Triple(1.0, 0.0, 0.14), Triple(0.84, 0.07, 0.2))
        // descending resolve
        SoundCue.SessionEnd -> listOf(
            Triple(1.5, 0.0, 0.16), Triple(1.25, 0.1, 0.18), Triple(1.0, 0.2, 0.42),
        )
        // short blip
        SoundCue.MoodLogged -> listOf(Triple(2.0, 0.0, 0.09))
        // triumphant triad
        SoundCue.CycleComplete -> listOf(
            Triple(1.0, 0.0, 0.5), Triple(1.25, 0.06, 0.46),
            Triple(1.5, 0.12, 0.5), Triple(2.0, 0.18, 0.55),
        )
        // quick sweep
        SoundCue.ThemeSwitch -> listOf(Triple(1.33, 0.0, 0.1), Triple(2.0, 0.05, 0.16))
    }

    /**
     * Additive synthesis with an exponential decay envelope and a soft stereo
     * spread, soft-clipped so stacked partials never crackle.
     */
    private fun render(
        notes: List<Triple<Double, Double, Double>>,
        profile: SoundProfile,
        volume: Float,
    ): ShortArray {
        val total = (notes.maxOf { it.second + it.third }) + 0.05
        val frames = (total * sampleRate).toInt()
        // Interleaved stereo.
        val out = ShortArray(frames * 2)

        val harmonics = profile.harmonics
        val harmonicSum = harmonics.sum()

        val left = DoubleArray(frames)
        val right = DoubleArray(frames)

        for ((multiplier, start, duration) in notes) {
            val frequency = profile.rootFrequency * multiplier
            val startFrame = (start * sampleRate).toInt()
            val noteFrames = (duration * sampleRate).toInt()
            // Slight stereo widening per partial.
            val pan = ((multiplier % 1.0) - 0.5) * 0.3

            for (i in 0 until noteFrames) {
                val frame = startFrame + i
                if (frame >= frames) break

                val progress = i.toDouble() / noteFrames
                // Fast attack, exponential decay — reads as a struck/plucked tone.
                val attack = min(1.0, progress / 0.02)
                val envelope = attack * exp(-4.5 * progress)

                var sample = 0.0
                val phase = 2 * PI * frequency * i / sampleRate
                harmonics.forEachIndexed { index, weight ->
                    if (weight > 0) sample += weight * sin(phase * (index + 1))
                }
                sample = sample / harmonicSum * envelope * 0.22

                left[frame] += sample * (1 - pan)
                right[frame] += sample * (1 + pan)
            }
        }

        for (frame in 0 until frames) {
            out[frame * 2] = (tanh(left[frame]) * volume * Short.MAX_VALUE).toInt().toShort()
            out[frame * 2 + 1] = (tanh(right[frame]) * volume * Short.MAX_VALUE).toInt().toShort()
        }
        return out
    }

    private fun emit(pcm: ShortArray) {
        val bytes = pcm.size * 2
        val track = AudioTrack.Builder()
            .setAudioAttributes(
                AudioAttributes.Builder()
                    .setUsage(AudioAttributes.USAGE_MEDIA)
                    .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
                    .build(),
            )
            .setAudioFormat(
                AudioFormat.Builder()
                    .setEncoding(AudioFormat.ENCODING_PCM_16BIT)
                    .setSampleRate(sampleRate)
                    .setChannelMask(AudioFormat.CHANNEL_OUT_STEREO)
                    .build(),
            )
            .setBufferSizeInBytes(bytes)
            .setTransferMode(AudioTrack.MODE_STATIC)
            .build()

        track.write(pcm, 0, pcm.size)
        track.setNotificationMarkerPosition(pcm.size / 2)
        track.setPlaybackPositionUpdateListener(
            object : AudioTrack.OnPlaybackPositionUpdateListener {
                override fun onMarkerReached(t: AudioTrack?) {
                    runCatching { t?.stop(); t?.release() }
                }

                override fun onPeriodicNotification(t: AudioTrack?) = Unit
            },
        )
        track.play()
    }

    companion object {
        @Volatile
        private var instance: SoundManager? = null

        fun get(context: Context): SoundManager =
            instance ?: synchronized(this) {
                instance ?: SoundManager(context.applicationContext).also { instance = it }
            }
    }
}
