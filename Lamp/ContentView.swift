import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var showAddPack = false

    var body: some View {
        TabView {
            NavigationStack(path: $path) {
                PacksView(path: $path, showAddPack: $showAddPack)
                    .navigationTitle("My Packs")
                    .navigationDestination(for: Pack.self) { pack in
                        PackDetailView(pack: pack, path: $path)
                            .navigationDestination(for: Verse.self) { verse in
                                VerseView(verse: verse)
                            }
                    }
                    .sheet(isPresented: $showAddPack) {
                        AddPackView(isPresented: $showAddPack)
                    }
            }
            .tabItem {
                Label("My Packs", systemImage: "folder.fill")
            }

            NavigationStack {
                PlaceholderTabView(title: "Search")
            }
            .tabItem {
                Label("Search", systemImage: "magnifyingglass")
            }

            NavigationStack {
                PlaceholderTabView(title: "Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gearshape")
            }
        }
    }
}

struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        Text("Coming soon")
            .font(.title2)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .navigationTitle(title)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
