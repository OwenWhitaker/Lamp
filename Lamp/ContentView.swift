import SwiftUI

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var showAddPack = false

    var body: some View {
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
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
