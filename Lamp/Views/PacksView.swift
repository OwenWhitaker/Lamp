import SwiftUI
import SwiftData

// MARK: - Neumorphism Design System
// Based on https://hackingwithswift.com/articles/213/how-to-build-neumorphic-designs-with-swiftui
// Key: elements are the SAME color as the background. Depth comes only from shadows.
// Light source: top-left. Dark shadow is cast further than light highlight (asymmetric).

private extension Color {
    static let neuBg = Color(red: 225 / 255, green: 225 / 255, blue: 235 / 255)
}

private extension LinearGradient {
    init(_ colors: Color...) {
        self.init(gradient: Gradient(colors: colors), startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

private let neuCorner: CGFloat = 22

// MARK: - Neumorphic Shapes

/// A raised neumorphic surface -- looks like it's extruded from the background.
private struct NeuRaisedShape<S: Shape>: View {
    var shape: S
    var body: some View {
        shape
            .fill(Color.neuBg)
            .shadow(color: Color.black.opacity(0.2), radius: 10, x: 10, y: 10)
            .shadow(color: Color.white.opacity(0.7), radius: 10, x: -5, y: -5)
    }
}

/// An inset/pressed neumorphic surface -- looks like it's pushed into the background.
/// Uses the blur+gradient-mask technique for realistic inner shadows.
private struct NeuInsetShape<S: Shape>: View {
    var shape: S
    var body: some View {
        ZStack {
            shape.fill(Color.neuBg)
            // Dark inner shadow (bottom-right)
            shape
                .stroke(Color.gray.opacity(0.5), lineWidth: 4)
                .blur(radius: 4)
                .offset(x: 2, y: 2)
                .mask(shape.fill(LinearGradient(Color.black, Color.clear)))
            // Light inner shadow (top-left)
            shape
                .stroke(Color.white, lineWidth: 6)
                .blur(radius: 4)
                .offset(x: -2, y: -2)
                .mask(shape.fill(LinearGradient(Color.clear, Color.black)))
        }
    }
}

// MARK: - PacksView

struct PacksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Pack.createdAt, order: .reverse) private var packs: [Pack]
    @Binding var path: NavigationPath
    @Binding var showAddPack: Bool

    @State private var packForAction: Pack?
    @State private var showActionDialog = false
    @State private var showRenameSheet = false
    @State private var renameText = ""

    private let columns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20)
    ]

    private var useThirdsLayout: Bool { packs.count <= 2 }

    var body: some View {
        Group {
            if useThirdsLayout {
                thirdsLayout
            } else {
                gridLayout
            }
        }
        .background(Color.neuBg.ignoresSafeArea())
        .confirmationDialog("Pack", isPresented: $showActionDialog, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                if let pack = packForAction {
                    modelContext.delete(pack)
                    try? modelContext.save()
                }
                packForAction = nil
            }
            Button("Rename") {
                renameText = packForAction?.title ?? ""
                showRenameSheet = true
            }
            Button("Cancel", role: .cancel) { packForAction = nil }
        } message: {
            Text(packForAction.map { "\"\($0.title)\"" } ?? "")
        }
        .sheet(isPresented: $showRenameSheet, onDismiss: { packForAction = nil }) {
            renameSheet
        }
    }

    // MARK: Layouts

    private var thirdsLayout: some View {
        GeometryReader { geo in
            let vPad: CGFloat = 16
            let hPad: CGFloat = 24
            let spacing: CGFloat = 28
            let count: CGFloat = packs.isEmpty ? 1 : CGFloat(packs.count + 1)
            let gaps = max(0, count - 1) * spacing
            let avH = geo.size.height - 2 * vPad - gaps
            let avW = geo.size.width - 2 * hPad
            let hByV = avH / count
            let hByW = avW * 2 / 3
            let cardH = min(hByV, hByW)
            let cardW = cardH * 3 / 2
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: spacing) {
                    if packs.isEmpty {
                        NeuAddCard { showAddPack = true }
                            .frame(width: cardW, height: cardH)
                            .frame(maxWidth: .infinity)
                    } else {
                        ForEach(packs) { pack in
                            NeuPackCard(pack: pack, action: { path.append(pack) }, onLongPress: {
                                packForAction = pack
                                showActionDialog = true
                            })
                            .frame(width: cardW, height: cardH)
                            .frame(maxWidth: .infinity)
                        }
                        NeuAddCard { showAddPack = true }
                            .frame(width: cardW, height: cardH)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.vertical, vPad)
                .padding(.horizontal, hPad)
            }
        }
        .background(Color.neuBg)
    }

    private var gridLayout: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(packs) { pack in
                    NeuPackCard(pack: pack, action: { path.append(pack) }, onLongPress: {
                        packForAction = pack
                        showActionDialog = true
                    })
                }
                NeuAddCard { showAddPack = true }
            }
            .padding(20)
        }
        .background(Color.neuBg)
    }

    // MARK: Rename Sheet

    private var renameSheet: some View {
        NavigationStack {
            Form {
                TextField("Pack name", text: $renameText)
            }
            .navigationTitle("Rename Pack")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { showRenameSheet = false }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if let pack = packForAction, !renameText.trimmingCharacters(in: .whitespaces).isEmpty {
                            pack.title = renameText.trimmingCharacters(in: .whitespaces)
                            try? modelContext.save()
                        }
                        showRenameSheet = false
                    }
                    .disabled(renameText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}

// MARK: - Neumorphic Pack Card

private struct NeuPackCard: View {
    let pack: Pack
    let action: () -> Void
    var onLongPress: (() -> Void)? = nil

    private let shape = RoundedRectangle(cornerRadius: neuCorner, style: .continuous)
    private let insetShape = RoundedRectangle(cornerRadius: 14, style: .continuous)

    var body: some View {
        cardBody
            .aspectRatio(3/2, contentMode: .fit)
            .contentShape(.rect)
            .onTapGesture { action() }
            .onLongPressGesture(minimumDuration: 0.5) { onLongPress?() }
    }

    private var cardBody: some View {
        ZStack {
            // Raised card surface
            NeuRaisedShape(shape: shape)

            VStack(spacing: 14) {
                Spacer()

                // Title in an inset well
                Text(pack.title)
                    .font(.system(.title3, design: .rounded).weight(.semibold))
                    .foregroundStyle(Color.black.opacity(0.6))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(NeuInsetShape(shape: insetShape))
                    .clipShape(insetShape)

                // Verse count in a small inset pill
                Text("\(pack.verses.count) verse\(pack.verses.count == 1 ? "" : "s")")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.35))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .background(NeuInsetShape(shape: Capsule()))
                    .clipShape(Capsule())

                Spacer()
            }
            .padding(18)
        }
    }
}

// MARK: - Neumorphic Add Card

private struct NeuAddCard: View {
    let action: () -> Void

    private let shape = RoundedRectangle(cornerRadius: neuCorner, style: .continuous)

    var body: some View {
        Button(action: action) {
            cardBody
                .aspectRatio(3/2, contentMode: .fit)
        }
        .buttonStyle(.plain)
    }

    private var cardBody: some View {
        ZStack {
            // Raised card surface
            NeuRaisedShape(shape: shape)

            VStack(spacing: 12) {
                // Raised circular plus button
                ZStack {
                    NeuRaisedShape(shape: Circle())
                        .frame(width: 52, height: 52)

                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.35))
                }

                Text("New Pack")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(Color.black.opacity(0.35))
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        PacksView(path: .constant(NavigationPath()), showAddPack: .constant(false))
            .navigationTitle("My Packs")
    }
    .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
