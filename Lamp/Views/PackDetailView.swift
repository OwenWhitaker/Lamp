import SwiftUI
import SwiftData

// MARK: - Neumorphism Design System

private extension Color {
    static let neuBg = Color(red: 225 / 255, green: 225 / 255, blue: 235 / 255)
}

private extension LinearGradient {
    init(_ colors: Color...) {
        self.init(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

/// Raised surface -- extruded from the background with flat fill.
private struct NeuRaised<S: Shape>: View {
    var shape: S
    var radius: CGFloat = 10
    var distance: CGFloat = 10

    var body: some View {
        shape
            .fill(Color.neuBg)
            .shadow(color: Color.black.opacity(0.2), radius: radius, x: distance, y: distance)
            .shadow(color: Color.white.opacity(0.7), radius: radius, x: -distance * 0.5, y: -distance * 0.5)
    }
}

/// Inset surface -- pressed into the background (blur + gradient-mask inner shadow).
private struct NeuInset<S: Shape>: View {
    var shape: S

    var body: some View {
        ZStack {
            shape.fill(Color.neuBg)
            shape
                .stroke(Color.gray.opacity(0.5), lineWidth: 4)
                .blur(radius: 4)
                .offset(x: 2, y: 2)
                .mask(shape.fill(LinearGradient(Color.black, Color.clear)))
            shape
                .stroke(Color.white, lineWidth: 6)
                .blur(radius: 4)
                .offset(x: -2, y: -2)
                .mask(shape.fill(LinearGradient(Color.clear, Color.black)))
        }
    }
}

// MARK: - Shared Layout

/// Shared card dimensions for verse cards. Used by PackDetailView and FlashcardView.
enum VerseCardLayout {
    static let cardHeight: CGFloat = 160
    static let horizontalPadding: CGFloat = 12
}

// MARK: - Pack Detail View

struct PackDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Bindable var pack: Pack
    @Binding var path: NavigationPath

    @State private var showDeleteConfirmation = false
    @State private var showMemorization = false
    @State private var showAddVerse = false

    private var sortedVerses: [Verse] {
        pack.verses.sorted { $0.order < $1.order }
    }

    private var averageMemoryHealth: Double {
        let withHealth = pack.verses.compactMap(\.memoryHealth)
        guard !withHealth.isEmpty else { return 0 }
        return withHealth.reduce(0, +) / Double(withHealth.count)
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .bottom) {
            // Full-screen neuBg
            Color.neuBg.ignoresSafeArea()

            // Main content: scroll view fills screen, header floats on top
            verseList

            // Floating header with gradient fade
            VStack(spacing: 0) {
                neuHeader
                    .background(Color.neuBg)

                // Soft gradient fade so cards blend under the header
                LinearGradient(
                    colors: [Color.neuBg, Color.neuBg.opacity(0.85), Color.neuBg.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 24)
                .allowsHitTesting(false)

                Spacer()
            }

            // Floating footer
            neuFooter
        }
        .navigationTitle("My Packs")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
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
            FlashcardView(pack: pack, verses: pack.verses.sorted { $0.order < $1.order })
        }
    }

    // MARK: - Neumorphic Header

    private var neuHeader: some View {
        HStack(spacing: 16) {
            // Back button
            NeuCircleButton(icon: "chevron.left") {
                dismiss()
            }

            Spacer()

            // Pack title
            Text(pack.title)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(Color(white: 0.18))
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Spacer()

            // Add verse button
            NeuCircleButton(icon: "plus") {
                showAddVerse = true
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Verse List

    private var verseList: some View {
        ScrollView(.vertical, showsIndicators: false) {
            if sortedVerses.isEmpty {
                emptyState
            } else {
                LazyVStack(spacing: 16) {
                    ForEach(sortedVerses) { verse in
                        NeuVerseCard(verse: verse) {
                            path.append(verse)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 80) // clear the floating header
                .padding(.bottom, 200) // clear the floating footer + tab bar
            }
        }
    }

    // MARK: Empty / No Results

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer().frame(height: 120) // clear the floating header

            // Neumorphic inset circle icon
            ZStack {
                NeuInset(shape: Circle())
                    .frame(width: 80, height: 80)
                Image(systemName: "book.closed")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.25))
            }

            Text("No verses yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(Color.black.opacity(0.5))

            Text("Tap + to add your first verse")
                .font(.system(size: 15))
                .foregroundStyle(Color.black.opacity(0.3))

            // Add verse raised button
            Button {
                showAddVerse = true
            } label: {
                ZStack {
                    NeuRaised(shape: RoundedRectangle(cornerRadius: 16, style: .continuous), radius: 8, distance: 6)
                        .frame(height: 50)
                    HStack(spacing: 8) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Add Verse")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundStyle(Color.black.opacity(0.5))
                }
            }
            .buttonStyle(.plain)
            .frame(width: 180)
            .padding(.top, 8)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 140)
    }

    // MARK: - Floating Neumorphic Footer

    private var neuFooter: some View {
        VStack(spacing: 0) {
            // Gradient fade
            LinearGradient(
                colors: [Color.neuBg.opacity(0), Color.neuBg.opacity(0.85), Color.neuBg],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 32)
            .allowsHitTesting(false)

            // Footer content
            HStack(spacing: 16) {
                // Stats
                VStack(alignment: .leading, spacing: 3) {
                    Text("\(pack.verses.count) verse\(pack.verses.count == 1 ? "" : "s")")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color(white: 0.18))

                    if !pack.verses.isEmpty {
                        HStack(spacing: 6) {
                            NeuProgressRing(progress: averageMemoryHealth, size: 18)
                            Text("\(Int(averageMemoryHealth * 100))% memorized")
                                .font(.system(size: 12))
                                .foregroundStyle(Color.black.opacity(0.35))
                        }
                    }
                }

                Spacer()

                // Delete button
                NeuCircleButton(icon: "trash", size: 38) {
                    showDeleteConfirmation = true
                }

                // Review button
                Button {
                    showMemorization = true
                } label: {
                    ZStack {
                        NeuRaised(
                            shape: RoundedRectangle(cornerRadius: 16, style: .continuous),
                            radius: 8,
                            distance: 6
                        )
                        Text("Review")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Color.black.opacity(0.55))
                            .padding(.horizontal, 28)
                            .padding(.vertical, 14)
                    }
                    .fixedSize()
                }
                .buttonStyle(.plain)
                .disabled(pack.verses.isEmpty)
                .opacity(pack.verses.isEmpty ? 0.45 : 1)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .padding(.bottom, 100) // clear the tab bar
            .background(Color.neuBg)
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Neumorphic Circle Button

private struct NeuCircleButton: View {
    let icon: String
    var size: CGFloat = 44
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                NeuRaised(shape: Circle(), radius: 6, distance: 5)
                    .frame(width: size, height: size)
                Image(systemName: icon)
                    .font(.system(size: size * 0.36, weight: .semibold))
                    .foregroundStyle(Color.black.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Neumorphic Verse Card

private struct NeuVerseCard: View {
    let verse: Verse
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                // Left: reference + text preview
                VStack(alignment: .leading, spacing: 6) {
                    Text(verse.reference)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color(white: 0.18))

                    Text(verse.text)
                        .font(.system(size: 14))
                        .foregroundStyle(Color.black.opacity(0.4))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                // Right: memory health ring
                if let health = verse.memoryHealth {
                    NeuProgressRing(progress: health, size: 36)
                } else {
                    // Empty neumorphic inset circle
                    NeuInset(shape: Circle())
                        .frame(width: 36, height: 36)
                }
            }
            .padding(18)
            .background(
                NeuRaised(shape: RoundedRectangle(cornerRadius: 18, style: .continuous))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Neumorphic Progress Ring

private struct NeuProgressRing: View {
    let progress: Double
    var size: CGFloat = 36

    var body: some View {
        ZStack {
            // Inset track
            Circle()
                .fill(Color.neuBg)
                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 2, y: 2)
                .shadow(color: Color.white.opacity(0.8), radius: 2, x: -1, y: -1)

            // Track
            Circle()
                .stroke(Color.black.opacity(0.06), lineWidth: size > 24 ? 3.5 : 2.5)

            // Progress arc
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    Color.black.opacity(0.32),
                    style: StrokeStyle(lineWidth: size > 24 ? 3.5 : 2.5, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            // Percentage label (only on larger rings)
            if size >= 36 {
                Text("\(Int(progress * 100))")
                    .font(.system(size: size * 0.28, weight: .bold))
                    .foregroundStyle(Color.black.opacity(0.4))
            }
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Legacy Types (used by FlashcardView)

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.black.opacity(0.1), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.black.opacity(0.35), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PackDetailView(
            pack: Pack(title: "Romans 8"),
            path: .constant(NavigationPath())
        )
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
