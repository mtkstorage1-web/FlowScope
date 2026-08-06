package mtk.flowscope

import android.app.Application
import mtk.flowscope.data.SessionRepository
import mtk.flowscope.theme.AppSettings
import mtk.flowscope.theme.ThemeManager

/**
 * Warms the singletons the widgets and the foreground service depend on, so a
 * cold start triggered by a widget tap still has a palette and stats to read.
 */
class FlowScopeApp : Application() {
    override fun onCreate() {
        super.onCreate()
        AppSettings.get(this)
        ThemeManager.get(this)
        SessionRepository.get(this)
    }
}
