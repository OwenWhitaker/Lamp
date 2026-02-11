import SwiftUI
import SwiftData

struct PacksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pack.createdAt, order: .reverse) private var packs: [Pack]
    @Binding var path: NavigationPath
    @Binding var showAddPack: Bool
    @Namespace private var glassNamespace

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        ScrollView {
            GlassEffectContainer(spacing: 16) {
                LazyVGrid(columns: columns, spacing: 16) {
                    ForEach(packs) { pack in
                        PackCardView(pack: pack, namespace: glassNamespace) {
                            path.append(pack)
                        }
                    }
                    AddPackCardView {
                        showAddPack = true
                    }
                }
                .padding()
            }
        }
    }
}

struct PackCardView: View {
    let pack: Pack
    let namespace: Namespace.ID
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(pack.title)
                .font(.headline)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 100)
                .padding()
        }
        .buttonStyle(.plain)
        .glassEffect()
        .glassEffectID(pack.id.uuidString, in: namespace)
    }
}

struct AddPackCardView: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.largeTitle)
                .frame(maxWidth: .infinity, minHeight: 100)
        }
        .buttonStyle(.plain)
        .glassEffect()
    }
}

#Preview {
    NavigationStack {
        PacksView(path: .constant(NavigationPath()), showAddPack: .constant(false))
            .navigationTitle("My Packs")
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
