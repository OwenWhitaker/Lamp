import SwiftUI
import SwiftData

@main
struct LampApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Pack.self, Verse.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        return try! ModelContainer(for: schema, configurations: [config])
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
