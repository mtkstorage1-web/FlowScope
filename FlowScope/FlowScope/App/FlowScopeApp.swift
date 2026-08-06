import SwiftUI
import SwiftData

@main
struct FlowScopeApp: App {
    // MARK: - SwiftData Container
    let modelContainer: ModelContainer
    
    // MARK: - App State
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var dataManager = DataManager.shared
    @StateObject private var theme = AppThemeManager.shared
    
    // MARK: - Init
    init() {
        do {
            let schema = Schema([
                Session.self,
                MoodLog.self
            ])
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            
            self.modelContainer = try ModelContainer(for: schema, configurations: [modelConfiguration])
            
            // Set up DataManager with model context
            DataManager.shared.setModelContext(modelContainer.mainContext)
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(dataManager)
                .environmentObject(theme)
                .preferredColorScheme(theme.colorScheme)
                .modelContainer(modelContainer)
        }
        .onChange(of: scenePhase) { _, newPhase in
            // Applies any satisfaction taps made on the Home Screen widget,
            // Lock Screen, or Dynamic Island while the app was backgrounded.
            if newPhase == .active {
                // Recomputes elapsed time from wall-clock, reattaches any
                // orphaned Live Activity, and applies widget mood taps.
                sessionManager.refreshFromForeground()
            }
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var theme: AppThemeManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var selectedTab = 0

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            TabView(selection: $selectedTab) {
                TimerView()
                    .tabItem {
                        Label("Focus", systemImage: "timer")
                    }
                    .tag(0)

                WorkLogView()
                    .tabItem {
                        Label("Work Log", systemImage: "list.clipboard")
                    }
                    .tag(1)

                CalendarView()
                    .tabItem {
                        Label("History", systemImage: "calendar")
                    }
                    .tag(2)

                SettingsView()
                    .tabItem {
                        Label("Appearance", systemImage: "paintbrush.fill")
                    }
                    .tag(3)
            }
            .accentColor(theme.accentColor)

            // Floating quick-log control: stays available on every tab, including
            // Focus, while a session is running. Hideable via its own handle.
            // Hidden on Appearance (tab 3) where it would cover the theme grid.
            if sessionManager.isRunning && selectedTab != 3 && settings.floatingControlEnabled {
                FloatingSessionControl()
                    .padding(.trailing, 16)
                    .padding(.bottom, 90)
            }
        }
        .animation(.spring(response: 0.35), value: sessionManager.isRunning)
        .onChange(of: sessionManager.isRunning) { _, running in
            UIApplication.shared.isIdleTimerDisabled = running && settings.keepScreenAwake
        }
    }
}
