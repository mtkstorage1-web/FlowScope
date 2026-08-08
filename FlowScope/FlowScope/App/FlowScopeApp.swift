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
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 620)
                #endif
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
        #if os(macOS)
        .defaultSize(width: 1080, height: 760)
        .windowResizability(.contentMinSize)
        .commands { sessionCommands }
        #endif
    }

    #if os(macOS)
    /// Mac users expect the running session to be controllable from the menu
    /// bar and by keyboard, not only from the window.
    @CommandsBuilder
    private var sessionCommands: some Commands {
        CommandMenu("Session") {
            Button(sessionManager.isPaused ? "Resume" : "Pause") {
                if sessionManager.isPaused {
                    sessionManager.resumeSession()
                } else {
                    sessionManager.pauseSession()
                }
            }
            .keyboardShortcut("p", modifiers: [.command])
            .disabled(!sessionManager.isRunning && !sessionManager.isPaused)

            Divider()

            Button("End Session") {
                sessionManager.stopSession()
            }
            .keyboardShortcut(".", modifiers: [.command])
            .disabled(!sessionManager.isRunning && !sessionManager.isPaused)
        }
    }
    #endif
}

// MARK: - Root

/// The four top-level destinations, shared by the iOS tab bar and the Mac
/// sidebar so the two stay in step.
enum AppSection: Int, CaseIterable, Identifiable {
    case focus, workLog, history, appearance

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .focus:      return "Focus"
        case .workLog:    return "Work Log"
        case .history:    return "History"
        case .appearance: return "Appearance"
        }
    }

    var systemImage: String {
        switch self {
        case .focus:      return "timer"
        case .workLog:    return "list.clipboard"
        case .history:    return "calendar"
        case .appearance: return "paintbrush.fill"
        }
    }

    @ViewBuilder
    var destination: some View {
        switch self {
        case .focus:      TimerView()
        case .workLog:    WorkLogView()
        case .history:    CalendarView()
        case .appearance: SettingsView()
        }
    }
}

struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var theme: AppThemeManager
    @ObservedObject private var settings = AppSettings.shared
    @State private var selection: AppSection = .focus

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            #if os(macOS)
            macBody
            #else
            iosBody
            #endif

            // Floating quick-log control: stays available on every section,
            // including Focus, while a session is running. Hideable via its own
            // handle. Hidden on Appearance where it would cover the theme grid.
            if sessionManager.isRunning && selection != .appearance && settings.floatingControlEnabled {
                FloatingSessionControl()
                    .padding(.trailing, 16)
                    .padding(.bottom, floatingControlBottomPadding)
            }
        }
        .animation(.spring(response: 0.35), value: sessionManager.isRunning)
        .onChange(of: sessionManager.isRunning) { _, running in
            ScreenAwake.setEnabled(running && settings.keepScreenAwake)
        }
    }

    /// The iOS control sits above the tab bar; on Mac there isn't one.
    private var floatingControlBottomPadding: CGFloat {
        #if os(macOS)
        24
        #else
        90
        #endif
    }

    #if os(macOS)
    /// A Mac window gets a real sidebar rather than a tab strip, so all four
    /// destinations stay visible at once on a large display.
    private var macBody: some View {
        NavigationSplitView {
            List(AppSection.allCases, selection: $selection) { section in
                NavigationLink(value: section) {
                    Label(section.title, systemImage: section.systemImage)
                }
            }
            .navigationSplitViewColumnWidth(min: 180, ideal: 210, max: 280)
            .listStyle(.sidebar)
        } detail: {
            selection.destination
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .tint(theme.accentColor)
    }
    #else
    private var iosBody: some View {
        TabView(selection: $selection) {
            ForEach(AppSection.allCases) { section in
                section.destination
                    .tabItem { Label(section.title, systemImage: section.systemImage) }
                    .tag(section)
            }
        }
        .accentColor(theme.accentColor)
    }
    #endif
}
