import SwiftUI
import SwiftData

struct PackDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var pack: Pack
    @Binding var path: NavigationPath
    @State private var searchText = ""
    @State private var showDeleteConfirmation = false
    @State private var showMemorization = false
    @State private var showAddVerse = false

    private var filteredVerses: [Verse] {
        let list = pack.verses.sorted { $0.order < $1.order }
        guard !searchText.trimmingCharacters(in: .whitespaces).isEmpty else { return list }
        let q = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return list.filter {
            $0.reference.lowercased().contains(q) || $0.text.lowercased().contains(q)
        }
    }

    private var averageMemoryHealth: Double {
        let withHealth = pack.verses.compactMap(\.memoryHealth)
        guard !withHealth.isEmpty else { return 0 }
        return withHealth.reduce(0, +) / Double(withHealth.count)
    }

    var body: some View {
        VStack(spacing: 0) {
            TextField("Search this Pack:", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 8)

            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(filteredVerses) { verse in
                        VerseRowView(verse: verse) {
                            path.append(verse)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 120)
            }

            VStack(spacing: 12) {
                Text("\(pack.verses.count) verses | \(Int(averageMemoryHealth * 100))% avg memory health")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Button("Review") {
                    showMemorization = true
                }
                .buttonStyle(.glass)
                .frame(maxWidth: .infinity)
                .disabled(pack.verses.isEmpty)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .navigationTitle(pack.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showAddVerse = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }
            ToolbarItem(placement: .secondaryAction) {
                Menu {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Delete Pack", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showAddVerse) {
            AddVerseView(pack: pack, isPresented: $showAddVerse)
        }
        .confirmationDialog("Delete Pack", isPresented: $showDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                modelContext.delete(pack)
                try? modelContext.save()
                path = NavigationPath()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \"\(pack.title)\"? All verses will be removed.")
        }
        .fullScreenCover(isPresented: $showMemorization) {
            MemorizationView(verses: pack.verses.sorted { $0.order < $1.order }, pack: pack)
        }
    }
}

struct VerseRowView: View {
    let verse: Verse
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verse.reference)
                        .font(.subheadline.weight(.semibold))
                    Text(verse.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer()
                if let health = verse.memoryHealth {
                    CircularProgressView(progress: health)
                        .frame(width: 28, height: 28)
                }
            }
            .padding()
        }
        .buttonStyle(.plain)
        .glassEffect()
    }
}

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

#Preview {
    NavigationStack {
        PackDetailView(
            pack: Pack(title: "Preview Pack"),
            path: .constant(NavigationPath())
        )
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
