import SwiftUI

// MARK: - Tab Definition

private enum Tab: Int, CaseIterable, Hashable {
    case packs = 0, search, settings

    var label: String {
        switch self {
        case .packs: "My Packs"
        case .search: "Search"
        case .settings: "Settings"
        }
    }

    var icon: String {
        switch self {
        case .packs: "folder.fill"
        case .search: "magnifyingglass"
        case .settings: "gearshape"
        }
    }
}

// MARK: - Neumorphic Tab Bar Color

private let neuBg = Color(red: 225 / 255, green: 225 / 255, blue: 235 / 255)

// MARK: - ContentView

struct ContentView: View {
    @State private var path = NavigationPath()
    @State private var showAddPack = false
    @State private var selectedTab: Tab = .packs

    var body: some View {
        ZStack(alignment: .bottom) {
            // Tab content (full screen, scrolls behind the tab bar)
            ZStack {
                NavigationStack(path: $path) {
                    PacksView(path: $path, showAddPack: $showAddPack)
                        .navigationTitle("My Packs")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar(.hidden, for: .navigationBar)
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
                .opacity(selectedTab == .packs ? 1 : 0)

                NavigationStack {
                    PlaceholderTabView(title: "Search")
                }
                .opacity(selectedTab == .search ? 1 : 0)

                NavigationStack {
                    PlaceholderTabView(title: "Settings")
                }
                .opacity(selectedTab == .settings ? 1 : 0)
            }

            // Floating tab bar with gradient fade
            VStack(spacing: 0) {
                // Soft gradient fade from transparent to neuBg
                LinearGradient(
                    colors: [neuBg.opacity(0), neuBg.opacity(0.8), neuBg],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 28)

                // Tab bar on solid background
                NeuTabBar(selected: $selectedTab)
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 4)
                    .background(neuBg)
            }
            .ignoresSafeArea(edges: .bottom)
        }
    }
}

// MARK: - Neumorphic Tab Bar

private struct NeuTabBar: View {
    @Binding var selected: Tab

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let tabCount = CGFloat(Tab.allCases.count)
            let tabWidth = w / tabCount
            let selectorW = tabWidth - 10
            let selectorH = h - 10
            let selectorX = tabWidth * CGFloat(selected.rawValue) + tabWidth / 2

            ZStack {
                // 1. Track with clean physical border
                trackBody

                // 2. Sliding raised selector
                Capsule()
                    .fill(neuBg)
                    .shadow(color: .black.opacity(0.18), radius: 5, x: 4, y: 4)
                    .shadow(color: .white.opacity(0.7), radius: 5, x: -2, y: -2)
                    .frame(width: selectorW, height: selectorH)
                    .position(x: selectorX, y: h / 2)

                // 3. Tab items
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        Button {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.78)) {
                                selected = tab
                            }
                        } label: {
                            VStack(spacing: 3) {
                                Image(systemName: tab.icon)
                                    .font(.system(size: 17, weight: .medium))
                                Text(tab.label)
                                    .font(.system(size: 10, weight: .medium, design: .rounded))
                            }
                            .foregroundStyle(
                                selected == tab
                                    ? Color.black.opacity(0.6)
                                    : Color.black.opacity(0.28)
                            )
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .frame(height: 56)
    }

    // MARK: Track Background

    /// Inset track with pronounced physical raised border rim + inner shadows.
    private var trackBody: some View {
        ZStack {
            // Base fill
            Capsule().fill(neuBg)

            // Outer raised border rim (strong gradient stroke)
            Capsule()
                .strokeBorder(
                    LinearGradient(
                        gradient: Gradient(colors: [
                            Color.white.opacity(0.95),
                            Color.white.opacity(0.4),
                            Color.black.opacity(0.18)
                        ]),
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 6
                )

            // Inner shadow -- dark (bottom-right depression)
            Capsule()
                .stroke(Color.gray.opacity(0.5), lineWidth: 5)
                .blur(radius: 4)
                .offset(x: 3, y: 3)
                .mask(
                    Capsule().fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.black, Color.clear]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )

            // Inner shadow -- light (top-left highlight)
            Capsule()
                .stroke(Color.white, lineWidth: 6)
                .blur(radius: 4)
                .offset(x: -3, y: -3)
                .mask(
                    Capsule().fill(
                        LinearGradient(
                            gradient: Gradient(colors: [Color.clear, Color.black]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                )
        }
        // Outer shadows
        .shadow(color: .black.opacity(0.2), radius: 10, x: 7, y: 7)
        .shadow(color: .white.opacity(0.7), radius: 10, x: -4, y: -4)
    }
}

// MARK: - Placeholder

struct PlaceholderTabView: View {
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color(white: 0.18))
                .frame(maxWidth: .infinity)
                .padding(.top, 20)

            Spacer()

            Text("Coming soon")
                .font(.title2)
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(neuBg)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .modelContainer(for: [Pack.self, Verse.self], inMemory: true)
}
