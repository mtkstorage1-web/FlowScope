package mtk.flowscope.ui.settings

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Brush
import androidx.compose.material.icons.filled.AutoAwesome
import androidx.compose.material.icons.filled.PlayCircle
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Restore
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material.icons.filled.Tune
import androidx.compose.material.icons.filled.VolumeUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import mtk.flowscope.audio.SoundCue
import mtk.flowscope.audio.SoundManager
import mtk.flowscope.audio.SoundProfile
import mtk.flowscope.theme.AnimationSpeed
import mtk.flowscope.theme.AppSettings
import mtk.flowscope.theme.AppTheme
import mtk.flowscope.theme.EffectIntensity
import mtk.flowscope.theme.RingDesign
import mtk.flowscope.theme.RingMode
import mtk.flowscope.theme.ThemeConfiguration
import mtk.flowscope.theme.ThemeCustomization
import mtk.flowscope.theme.ThemeCustomizationStore
import mtk.flowscope.theme.ThemeManager
import mtk.flowscope.ui.components.themedSurface
import mtk.flowscope.util.adjusted

/** Ported from `SettingsView.swift`. */
@Composable
fun SettingsScreen(
    themeManager: ThemeManager,
    settings: AppSettings,
    config: ThemeConfiguration,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val customStore = remember { ThemeCustomizationStore.get(context) }
    var showResetConfirm by remember { mutableStateOf(false) }

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(vertical = 16.dp),
    ) {
        Text(
            "Settings",
            color = config.textPrimary,
            fontSize = 32.sp,
            fontWeight = FontWeight.Bold,
            fontFamily = config.fontDesign.fontFamily,
            modifier = Modifier.padding(start = 16.dp, bottom = 16.dp),
        )

        ThemePreviewCard(config)

        Section("Theme", Icons.Filled.Palette, config) {
            ThemeSelectionGrid(themeManager, config)
        }

        Section("Customize ${themeManager.currentTheme.displayName}", Icons.Filled.Brush, config) {
            ThemeCustomizerPanel(themeManager, customStore, config)
        }

        Section("Visual Effects", Icons.Filled.AutoAwesome, config) {
            SegmentedRow(
                title = "Effect Intensity",
                options = EffectIntensity.entries,
                selected = settings.effectIntensity,
                label = { it.label },
                config = config,
            ) { settings.effectIntensity = it }

            Caption(intensityHint(settings.effectIntensity), config)

            SegmentedRow(
                title = "Animation Speed",
                options = AnimationSpeed.entries,
                selected = settings.animationSpeed,
                label = { it.label },
                config = config,
            ) { settings.animationSpeed = it }

            ToggleRow(
                "Depth / Parallax",
                "Renders a second slower layer behind the effects.",
                settings.parallaxEnabled,
                config,
            ) { settings.parallaxEnabled = it }

            ToggleRow(
                "Animated Digits",
                "Breathing, flicker and glow on the timer.",
                settings.animatedDigits,
                config,
            ) { settings.animatedDigits = it }

            ToggleRow(
                "Glow",
                "Outer bloom on digits, rings and buttons.",
                settings.glowEnabled,
                config,
            ) { settings.glowEnabled = it }

            SliderRow(
                title = "Background Blur",
                valueLabel = "${settings.backgroundBlur.toInt()}%",
                value = settings.backgroundBlur.toFloat(),
                range = 0f..100f,
                subtitle = "Softens the animated background so the timer stands out. 0% is sharp.",
                config = config,
            ) { settings.backgroundBlur = it.toDouble() }
        }

        Section("Focus Ring & Timing", Icons.Filled.Timer, config) {
            SegmentedRow(
                title = "Ring Shows",
                options = RingMode.entries,
                selected = settings.ringMode,
                label = { it.label },
                config = config,
            ) { settings.ringMode = it }

            Caption(settings.ringMode.explanation, config)

            if (settings.ringMode == RingMode.Cycle) {
                OptionStepper(
                    "Cycle Length",
                    settings.cycleMinutes,
                    AppSettings.cycleOptions,
                    config,
                ) { settings.cycleMinutes = it }
                Caption(
                    "The ring fills once every ${settings.cycleMinutes} minutes, then starts a " +
                        "new lap. \"Left in cycle\" counts down to that.",
                    config,
                )
            }

            if (settings.ringMode == RingMode.SessionGoal) {
                OptionStepper(
                    "Session Goal",
                    settings.goalMinutes,
                    AppSettings.goalOptions,
                    config,
                ) { settings.goalMinutes = it }
                Caption(
                    "The ring fills once over your ${settings.goalMinutes}-minute target.",
                    config,
                )
            }

            ToggleRow(
                "Cycle Complete Alert",
                "Flash, haptic and chime when a lap finishes.",
                settings.cycleAlert,
                config,
            ) { settings.cycleAlert = it }
        }

        Section("Sound & Haptics", Icons.Filled.VolumeUp, config) {
            ToggleRow(
                "Sound Effects",
                "Synthesized cues that match your theme.",
                settings.soundEnabled,
                config,
            ) { settings.soundEnabled = it }

            if (settings.soundEnabled) {
                SliderRow(
                    title = "Volume",
                    valueLabel = "${(settings.soundVolume * 100).toInt()}%",
                    value = settings.soundVolume.toFloat(),
                    range = 0f..1f,
                    subtitle = null,
                    config = config,
                ) { settings.soundVolume = it.toDouble() }

                Spacer(Modifier.height(10.dp))
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(horizontal = 16.dp)
                        .clip(RoundedCornerShape(config.cornerRadius))
                        .background(config.primary.copy(alpha = 0.18f))
                        .clickable {
                            SoundManager.get(context)
                                .play(SoundCue.CycleComplete, themeManager.currentTheme)
                        }
                        .padding(vertical = 12.dp),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Icon(Icons.Filled.PlayCircle, null, tint = config.primary)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "Preview Sound",
                        color = config.primary,
                        fontSize = 14.sp,
                        fontWeight = FontWeight.SemiBold,
                        fontFamily = config.fontDesign.fontFamily,
                    )
                }
                Caption(
                    "Profile for ${themeManager.currentTheme.displayName}: " +
                        SoundProfile.matching(themeManager.currentTheme).label,
                    config,
                )
            }

            ToggleRow(
                "Haptics",
                "Vibration on taps, logs and cycle completion.",
                settings.hapticsEnabled,
                config,
            ) { settings.hapticsEnabled = it }
        }

        Section("Layout & Behavior", Icons.Filled.Tune, config) {
            ToggleRow(
                "Floating Log Control",
                "Draggable satisfaction slider on every tab.",
                settings.floatingControlEnabled,
                config,
            ) { settings.floatingControlEnabled = it }

            ToggleRow(
                "Ongoing Notification",
                "Keeps the running session alive and visible outside the app.",
                settings.liveActivityEnabled,
                config,
            ) { settings.liveActivityEnabled = it }

            ToggleRow(
                "Keep Screen Awake",
                "Prevent the screen turning off while a session runs.",
                settings.keepScreenAwake,
                config,
            ) { settings.keepScreenAwake = it }

            ToggleRow(
                "Hide Status Bar",
                "Fullscreen focus mode.",
                settings.hideStatusBar,
                config,
            ) { settings.hideStatusBar = it }
        }

        Spacer(Modifier.height(10.dp))

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp)
                .clip(RoundedCornerShape(config.cornerRadius))
                .background(Color(0xFFFF453A).copy(alpha = 0.8f))
                .clickable { showResetConfirm = true }
                .padding(16.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(Icons.Filled.Restore, null, tint = Color.White)
            Spacer(Modifier.width(8.dp))
            Text(
                "Reset Everything",
                color = Color.White,
                fontSize = 16.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
        }

        Spacer(Modifier.height(60.dp))
    }

    if (showResetConfirm) {
        AlertDialog(
            onDismissRequest = { showResetConfirm = false },
            title = { Text("Reset all settings?") },
            text = {
                Text(
                    "Restores the default theme, effects, timing and feedback. " +
                        "Your sessions are not affected.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    settings.resetAll()
                    customStore.resetAll()
                    themeManager.resetToDefault()
                    showResetConfirm = false
                }) { Text("Reset Everything", color = Color(0xFFFF453A)) }
            },
            dismissButton = {
                TextButton(onClick = { showResetConfirm = false }) {
                    Text("Cancel", color = config.primary)
                }
            },
            containerColor = config.surface,
            titleContentColor = config.textPrimary,
            textContentColor = config.textSecondary,
        )
    }
}

private fun intensityHint(intensity: EffectIntensity): String = when (intensity) {
    EffectIntensity.Off -> "Effects off — plain gradient background."
    EffectIntensity.Subtle -> "Barely-there motion, easiest on the battery."
    EffectIntensity.Balanced -> "The designed look for every theme."
    EffectIntensity.Intense -> "Brighter, denser particle fields."
    EffectIntensity.Maximum -> "Everything at full strength. Heaviest on the GPU."
}

// MARK: - Building blocks

@Composable
private fun Section(
    title: String,
    icon: ImageVector,
    config: ThemeConfiguration,
    content: @Composable () -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(top = 26.dp)) {
        Row(
            modifier = Modifier.padding(horizontal = 16.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Icon(icon, null, tint = config.primary, modifier = Modifier.size(18.dp))
            Spacer(Modifier.width(8.dp))
            Text(
                title,
                color = config.textPrimary,
                fontSize = 18.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        content()
    }
}

@Composable
private fun Caption(text: String, config: ThemeConfiguration) {
    Text(
        text,
        color = config.textSecondary,
        fontSize = 11.sp,
        fontFamily = config.fontDesign.fontFamily,
        modifier = Modifier.padding(horizontal = 20.dp, vertical = 6.dp),
    )
}

@Composable
private fun <T> SegmentedRow(
    title: String,
    options: List<T>,
    selected: T,
    label: (T) -> String,
    config: ThemeConfiguration,
    onSelect: (T) -> Unit,
) {
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 6.dp)) {
        Text(
            title,
            color = config.textPrimary,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            options.forEach { option ->
                val isSelected = option == selected
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (isSelected) config.primary else config.surface)
                        .clickable { onSelect(option) }
                        .padding(horizontal = 14.dp, vertical = 8.dp),
                ) {
                    Text(
                        label(option),
                        color = if (isSelected) Color.Black else config.textSecondary,
                        fontSize = 13.sp,
                        fontWeight = if (isSelected) FontWeight.SemiBold else FontWeight.Normal,
                        fontFamily = config.fontDesign.fontFamily,
                    )
                }
            }
        }
    }
}

@Composable
private fun ToggleRow(
    title: String,
    subtitle: String,
    checked: Boolean,
    config: ThemeConfiguration,
    onChange: (Boolean) -> Unit,
) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .themedSurface(config)
            .padding(14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                title,
                color = config.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = config.fontDesign.fontFamily,
            )
            Text(
                subtitle,
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        Switch(
            checked = checked,
            onCheckedChange = onChange,
            colors = SwitchDefaults.colors(
                checkedThumbColor = Color.Black,
                checkedTrackColor = config.primary,
                uncheckedThumbColor = config.textSecondary,
                uncheckedTrackColor = config.surface,
            ),
        )
    }
}

@Composable
private fun SliderRow(
    title: String,
    valueLabel: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    subtitle: String?,
    config: ThemeConfiguration,
    onChange: (Float) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .themedSurface(config)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                title,
                color = config.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = config.fontDesign.fontFamily,
                modifier = Modifier.weight(1f),
            )
            Text(
                valueLabel,
                color = config.textSecondary,
                fontSize = 12.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            colors = SliderDefaults.colors(
                thumbColor = config.primary,
                activeTrackColor = config.primary,
                inactiveTrackColor = config.primary.copy(alpha = 0.25f),
            ),
        )
        if (subtitle != null) {
            Text(
                subtitle,
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
    }
}

@Composable
private fun OptionStepper(
    title: String,
    value: Int,
    options: List<Int>,
    config: ThemeConfiguration,
    onSelect: (Int) -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp, vertical = 6.dp)
            .themedSurface(config)
            .padding(14.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                title,
                color = config.textPrimary,
                fontSize = 14.sp,
                fontWeight = FontWeight.Medium,
                fontFamily = config.fontDesign.fontFamily,
                modifier = Modifier.weight(1f),
            )
            Text(
                "$value min",
                color = config.primary,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            options.forEach { option ->
                val isSelected = option == value
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(
                            if (isSelected) config.primary else config.primary.copy(alpha = 0.12f),
                        )
                        .clickable { onSelect(option) }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                ) {
                    Text(
                        "$option",
                        color = if (isSelected) Color.Black else config.textSecondary,
                        fontSize = 12.sp,
                        fontFamily = config.fontDesign.fontFamily,
                    )
                }
            }
        }
    }
}

// MARK: - Theme preview card

@Composable
private fun ThemePreviewCard(config: ThemeConfiguration) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .themedSurface(config)
            .padding(16.dp),
    ) {
        Text(
            "Deep Work",
            color = config.textPrimary,
            fontSize = 15.sp,
            fontWeight = config.fontWeight,
            fontFamily = config.fontDesign.fontFamily,
        )
        Text(
            "Coding",
            color = config.textSecondary,
            fontSize = 12.sp,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.height(10.dp))
        Text(
            "32:18",
            color = config.primary,
            fontSize = 36.sp,
            fontWeight = config.digits.fontWeight,
            fontFamily = config.digits.fontDesign.fontFamily,
        )
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            config.chartColors.forEach { color ->
                Box(
                    Modifier
                        .size(width = 34.dp, height = 6.dp)
                        .clip(CircleShape)
                        .background(color),
                )
            }
        }
    }
}

// MARK: - Theme grid

/** Grid of the ten theme swatches, ported from `ThemeSelectionView.swift`. */
@Composable
private fun ThemeSelectionGrid(themeManager: ThemeManager, config: ThemeConfiguration) {
    Column(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp)) {
        AppTheme.entries.chunked(4).forEach { row ->
            Row(
                modifier = Modifier.fillMaxWidth().padding(vertical = 9.dp),
                horizontalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                row.forEach { theme ->
                    ThemeSwatch(
                        themeConfig = themeManager.configuration(theme),
                        isSelected = themeManager.currentTheme == theme,
                        modifier = Modifier.weight(1f),
                    ) { themeManager.switchTheme(theme) }
                }
                repeat(4 - row.size) { Spacer(Modifier.weight(1f)) }
            }
        }
    }
}

@Composable
private fun ThemeSwatch(
    themeConfig: ThemeConfiguration,
    isSelected: Boolean,
    modifier: Modifier = Modifier,
    onClick: () -> Unit,
) {
    Column(
        modifier = modifier.clickable(onClick = onClick),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(contentAlignment = Alignment.Center, modifier = Modifier.size(68.dp)) {
            if (isSelected) {
                Box(
                    Modifier
                        .size(68.dp)
                        .clip(CircleShape)
                        .border(3.dp, themeConfig.primary, CircleShape),
                )
            }
            Box(
                modifier = Modifier
                    .size(56.dp)
                    .clip(CircleShape)
                    .background(
                        androidx.compose.ui.graphics.Brush.linearGradient(
                            listOf(
                                themeConfig.primary,
                                themeConfig.secondary,
                                themeConfig.backgroundBottom,
                            ),
                        ),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    themeConfig.theme.icon,
                    contentDescription = themeConfig.theme.displayName,
                    tint = Color.White,
                    modifier = Modifier.size(20.dp),
                )
            }
        }
        Spacer(Modifier.height(6.dp))
        Text(
            themeConfig.theme.displayName,
            color = if (isSelected) themeConfig.primary else themeConfig.textSecondary,
            fontSize = 10.sp,
            maxLines = 1,
            fontFamily = themeConfig.fontDesign.fontFamily,
        )
    }
}

// MARK: - Theme customizer

@Composable
private fun ThemeCustomizerPanel(
    themeManager: ThemeManager,
    store: ThemeCustomizationStore,
    config: ThemeConfiguration,
) {
    val theme = themeManager.currentTheme
    // Reading the revision keeps this panel in sync with the store.
    @Suppress("UNUSED_EXPRESSION") store.revision
    val custom = store.customization(theme)

    fun update(transform: (ThemeCustomization) -> ThemeCustomization) {
        store.set(transform(store.customization(theme)), theme)
        themeManager.refreshPalette()
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 16.dp)
            .themedSurface(config)
            .padding(14.dp),
    ) {
        Text(
            "Quick Colors",
            color = config.textPrimary,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(10.dp),
        ) {
            // Hue offsets that move the whole palette to a new colour family.
            listOf(
                "Original" to 0.0,
                "Blue" to 210.0,
                "Violet" to 260.0,
                "Green" to 120.0,
                "Pink" to 320.0,
                "Gold" to 45.0,
            ).forEach { (label, shift) ->
                val isSelected = custom.hueShift == shift
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Box(
                        modifier = Modifier
                            .size(34.dp)
                            .clip(CircleShape)
                            .background(
                                config.primary.adjusted(
                                    shift - custom.hueShift,
                                    saturationScale = 1.0,
                                    brightnessScale = 1.0,
                                ),
                            )
                            .then(
                                if (isSelected) {
                                    Modifier.border(2.dp, config.textPrimary, CircleShape)
                                } else {
                                    Modifier
                                },
                            )
                            .clickable { update { it.copy(hueShift = shift) } },
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        label,
                        color = config.textSecondary,
                        fontSize = 9.sp,
                        fontFamily = config.fontDesign.fontFamily,
                    )
                }
            }
        }

        Spacer(Modifier.height(14.dp))

        CustomSlider("Hue", custom.hueShift.toFloat(), -180f..180f, config) {
            update { c -> c.copy(hueShift = it.toDouble()) }
        }
        CustomSlider("Saturation", custom.saturation.toFloat(), 0f..1.6f, config) {
            update { c -> c.copy(saturation = it.toDouble()) }
        }
        CustomSlider("Brightness", custom.brightness.toFloat(), 0.6f..1.5f, config) {
            update { c -> c.copy(brightness = it.toDouble()) }
        }

        Spacer(Modifier.height(10.dp))
        Text(
            "Ring Design",
            color = config.textPrimary,
            fontSize = 14.sp,
            fontWeight = FontWeight.Medium,
            fontFamily = config.fontDesign.fontFamily,
        )
        Spacer(Modifier.height(8.dp))
        Row(
            modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            RingDesign.entries.forEach { design ->
                val isSelected = custom.ringDesign == design
                Box(
                    modifier = Modifier
                        .clip(CircleShape)
                        .background(if (isSelected) config.primary else config.primary.copy(alpha = 0.12f))
                        .clickable { update { it.copy(ringDesignId = design.id) } }
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                ) {
                    Text(
                        design.label,
                        color = if (isSelected) Color.Black else config.textSecondary,
                        fontSize = 11.sp,
                        fontFamily = config.fontDesign.fontFamily,
                    )
                }
            }
        }

        Spacer(Modifier.height(12.dp))
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(config.cornerRadius))
                .background(config.primary.copy(alpha = 0.15f))
                .clickable {
                    store.reset(theme)
                    themeManager.refreshPalette()
                }
                .padding(vertical = 10.dp),
            horizontalArrangement = Arrangement.Center,
        ) {
            Text(
                "Reset ${theme.displayName}",
                color = config.primary,
                fontSize = 13.sp,
                fontWeight = FontWeight.SemiBold,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
    }
}

@Composable
private fun CustomSlider(
    title: String,
    value: Float,
    range: ClosedFloatingPointRange<Float>,
    config: ThemeConfiguration,
    onChange: (Float) -> Unit,
) {
    Column(Modifier.fillMaxWidth()) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(
                title,
                color = config.textSecondary,
                fontSize = 12.sp,
                fontFamily = config.fontDesign.fontFamily,
                modifier = Modifier.weight(1f),
            )
            Text(
                String.format("%.2f", value),
                color = config.textSecondary,
                fontSize = 11.sp,
                fontFamily = config.fontDesign.fontFamily,
            )
        }
        Slider(
            value = value,
            onValueChange = onChange,
            valueRange = range,
            colors = SliderDefaults.colors(
                thumbColor = config.primary,
                activeTrackColor = config.primary,
                inactiveTrackColor = config.primary.copy(alpha = 0.25f),
            ),
        )
    }
}
