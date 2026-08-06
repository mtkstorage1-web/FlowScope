package mtk.flowscope.widget

import android.content.Context
import androidx.glance.appwidget.GlanceAppWidgetManager
import androidx.glance.appwidget.updateAll
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch

private val widgetScope = CoroutineScope(SupervisorJob() + Dispatchers.Default)

/**
 * The equivalent of `WidgetCenter.shared.reloadAllTimelines()` — asks every
 * placed FlowScope widget to redraw from the latest shared snapshot.
 */
fun refreshAllWidgets(context: Context) {
    widgetScope.launch {
        runCatching {
            StatusWidget().updateAll(context)
            StreakWidget().updateAll(context)
            MoodTrendWidget().updateAll(context)
            WeeklyWidget().updateAll(context)
            QuickStartWidget().updateAll(context)
            CategoriesWidget().updateAll(context)
        }
    }
}

/** True when at least one FlowScope widget is on the home screen. */
suspend fun hasPlacedWidgets(context: Context): Boolean = runCatching {
    val manager = GlanceAppWidgetManager(context)
    manager.getGlanceIds(StatusWidget::class.java).isNotEmpty()
}.getOrElse { false }
