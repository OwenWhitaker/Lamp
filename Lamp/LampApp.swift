import SwiftUI
import SwiftData

@main
struct LampApp: App {
    @AppStorage("appearanceMode") private var appearanceMode: Int = 0  // 0=system, 1=light, 2=dark

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Pack.self, Verse.self, Reminder.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    private var colorSchemeOverride: ColorScheme? {
        switch appearanceMode {
        case 1: return .light
        case 2: return .dark
        default: return nil
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(colorSchemeOverride)
        }
        .modelContainer(sharedModelContainer)
    }
}
