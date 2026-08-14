import SwiftUI
import SwiftData

@main
@MainActor
struct CafadeApp: App {
    @State private var services = AppServices()
    @StateObject private var entitlements = EntitlementService()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(services)
                .environmentObject(entitlements)
                .preferredColorScheme(.light)
        }
        .modelContainer(for: [IntakeEvent.self, UserSettings.self])
    }
}

enum AppTab: Hashable {
    case today
    case history
    case settings
}

struct AppRootView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var entitlements: EntitlementService
    @State private var selectedTab: AppTab = .today

    var body: some View {
        TabView(selection: $selectedTab) {
            TodayView {
                selectedTab = .settings
            }
                .tabItem { Label("Today", systemImage: "sun.max") }
                .tag(AppTab.today)

            HistoryView()
                .tabItem { Label("History", systemImage: "chart.xyaxis.line") }
                .tag(AppTab.history)

            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(AppTab.settings)
        }
        .tint(CafadePalette.saffron)
        .task {
            _ = AppServices.ensureSettings(in: modelContext)
            await entitlements.loadOfferings()
        }
    }
}
