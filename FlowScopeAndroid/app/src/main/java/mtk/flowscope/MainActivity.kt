package mtk.flowscope

import android.Manifest
import android.os.Build
import android.os.Bundle
import android.view.WindowManager
import androidx.activity.ComponentActivity
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CalendarMonth
import androidx.compose.material.icons.filled.ListAlt
import androidx.compose.material.icons.filled.Palette
import androidx.compose.material.icons.filled.Timer
import androidx.compose.material3.Icon
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.NavigationBarItemDefaults
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.view.WindowCompat
import androidx.core.view.WindowInsetsCompat
import androidx.core.view.WindowInsetsControllerCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.viewmodel.compose.viewModel
import mtk.flowscope.data.SessionRepository
import mtk.flowscope.data.SessionWithMoodLogs
import mtk.flowscope.session.SessionManager
import mtk.flowscope.theme.AppSettings
import mtk.flowscope.theme.ThemeManager
import mtk.flowscope.theme.ThemedBackground
import mtk.flowscope.ui.calendar.CalendarScreen
import mtk.flowscope.ui.graph.SessionGraphSheet
import mtk.flowscope.ui.settings.SettingsScreen
import mtk.flowscope.ui.timer.FloatingSessionControl
import mtk.flowscope.ui.timer.TimerScreen
import mtk.flowscope.ui.worklog.WorkLogScreen

/**
 * Ported from `FlowScopeApp.swift`.
 *
 * SwiftUI's `TabView` becomes a Material `NavigationBar`, and the
 * `scenePhase == .active` hook becomes a lifecycle observer that recomputes
 * elapsed time and applies any widget mood taps made while backgrounded.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()
        WindowCompat.setDecorFitsSystemWindows(window, false)

        setContent { FlowScopeRoot() }
    }
}

private enum class Tab(val title: String) {
    Focus("Focus"), WorkLog("Work Log"), History("History"), Appearance("Appearance")
}

@Composable
private fun FlowScopeRoot() {
    val context = LocalContext.current
    val activity = context as ComponentActivity

    val themeManager = remember { ThemeManager.get(context) }
    val settings = remember { AppSettings.get(context) }
    val repository = remember { SessionRepository.get(context) }
    val sessionManager: SessionManager = viewModel()

    val config = themeManager.configuration
    val sessions by repository.sessions.collectAsState()

    var selectedTab by remember { mutableIntStateOf(0) }
    var selectedSession by remember { mutableStateOf<SessionWithMoodLogs?>(null) }

    // Ask for notification permission once, so the ongoing session notification
    // (Android's Live Activity stand-in) can actually appear.
    val permissionLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { sessionManager.refreshFromForeground() }

    LaunchedEffect(Unit) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            permissionLauncher.launch(Manifest.permission.POST_NOTIFICATIONS)
        }
    }

    // Applies satisfaction taps made from the widget or notification while the
    // app was backgrounded, and recomputes elapsed time from wall-clock.
    val lifecycleOwner = LocalLifecycleOwner.current
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) {
                sessionManager.refreshFromForeground()
                repository.refresh()
            }
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    // Keep-awake and status-bar visibility follow the user's settings.
    DisposableEffect(sessionManager.isRunning, settings.keepScreenAwake) {
        val keepOn = sessionManager.isRunning && settings.keepScreenAwake
        if (keepOn) {
            activity.window.addFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        } else {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
        onDispose {
            activity.window.clearFlags(WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON)
        }
    }

    DisposableEffect(settings.hideStatusBar) {
        val controller = WindowInsetsControllerCompat(activity.window, activity.window.decorView)
        if (settings.hideStatusBar) {
            controller.hide(WindowInsetsCompat.Type.statusBars())
            controller.systemBarsBehavior =
                WindowInsetsControllerCompat.BEHAVIOR_SHOW_TRANSIENT_BARS_BY_SWIPE
        } else {
            controller.show(WindowInsetsCompat.Type.statusBars())
        }
        onDispose { }
    }

    Box(Modifier.fillMaxSize().background(config.backgroundBottom)) {
        // The animated themed background sits behind every tab.
        ThemedBackground(configuration = config, settings = settings)

        Scaffold(
            containerColor = Color.Transparent,
            bottomBar = {
                NavigationBar(
                    containerColor = config.backgroundTop.copy(alpha = 0.92f),
                    tonalElevation = 0.dp,
                ) {
                    Tab.entries.forEachIndexed { index, tab ->
                        val icon = when (tab) {
                            Tab.Focus -> Icons.Filled.Timer
                            Tab.WorkLog -> Icons.Filled.ListAlt
                            Tab.History -> Icons.Filled.CalendarMonth
                            Tab.Appearance -> Icons.Filled.Palette
                        }
                        NavigationBarItem(
                            selected = selectedTab == index,
                            onClick = { selectedTab = index },
                            icon = { Icon(icon, contentDescription = tab.title) },
                            label = {
                                Text(
                                    tab.title,
                                    fontSize = 10.sp,
                                    fontFamily = config.fontDesign.fontFamily,
                                )
                            },
                            colors = NavigationBarItemDefaults.colors(
                                selectedIconColor = config.tabs.selectedColors.first(),
                                selectedTextColor = config.tabs.selectedColors.first(),
                                unselectedIconColor = config.tabs.unselectedColor,
                                unselectedTextColor = config.tabs.unselectedColor,
                                indicatorColor = config.tabs.backgroundTint,
                            ),
                        )
                    }
                }
            },
        ) { innerPadding ->
            Column(Modifier.fillMaxSize().padding(innerPadding)) {
                when (Tab.entries[selectedTab]) {
                    Tab.Focus -> TimerScreen(sessionManager, config, settings)
                    Tab.WorkLog -> WorkLogScreen(sessions, config, onSelectSession = { selectedSession = it })
                    Tab.History -> CalendarScreen(sessions, config, onSelectSession = { selectedSession = it })
                    Tab.Appearance -> SettingsScreen(themeManager, settings, config)
                }
            }
        }

        // Floating quick-log control: stays available on every tab while a
        // session runs. Hidden on Appearance, where it would cover the grid.
        if (sessionManager.isRunning &&
            selectedTab != 3 &&
            settings.floatingControlEnabled
        ) {
            FloatingSessionControl(
                config = config,
                onLog = { sessionManager.logMood(it) },
                modifier = Modifier
                    .align(Alignment.BottomEnd)
                    .padding(end = 16.dp, bottom = 110.dp),
            )
        }
    }

    selectedSession?.let { session ->
        SessionGraphSheet(
            session = session,
            config = config,
            onDismiss = { selectedSession = null },
        )
    }
}
