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

private let neuBg = Color(UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1)
        : UIColor(red: 225/255, green: 225/255, blue: 235/255, alpha: 1)
})

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
    @Environment(\.colorScheme) private var colorScheme
    @Binding var selected: Tab
    @State private var dragX: CGFloat? = nil   // nil = use selected tab's rest position
    @State private var isDragging = false
    @State private var holdTriggered = false    // true once a held-tap fires
    @State private var holdID = UUID()          // cancels stale hold timers
    @State private var touchLocation: CGFloat = 0

    // Threshold (pt) to distinguish a tap from a real drag
    private let dragThreshold: CGFloat = 8
    // How long a stationary press must be held before the pill slides over
    private let holdDelay: TimeInterval = 0.2

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let tabCount = CGFloat(Tab.allCases.count)
            let tabWidth = w / tabCount
            let inset: CGFloat = 8       // uniform gap between track and pill
            let selectorW = tabWidth - inset * 2
            let selectorH = h - inset * 2

            // Rest position = center of the selected tab
            let restX = tabWidth * CGFloat(selected.rawValue) + tabWidth / 2
            // During a real drag follow the finger; otherwise use the animated rest position
            let pillX = dragX ?? restX

            ZStack {
                // 1. Track with physical border
                trackBody

                // 2. Neumorphic pill – raised from the track floor
                Capsule()
                    .fill(neuBg)
                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.5 : 0.18), radius: 5, x: 4, y: 4)
                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.07 : 0.6), radius: 5, x: -3, y: -3)
                    .frame(width: selectorW, height: selectorH)
                    .position(x: pillX, y: h / 2)

                // 3. Tab labels (hit-testing disabled; gesture layer handles touches)
                HStack(spacing: 0) {
                    ForEach(Tab.allCases, id: \.self) { tab in
                        VStack(spacing: 3) {
                            Image(systemName: tab.icon)
                                .font(.system(size: 17, weight: .medium))
                            Text(tab.label)
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                        }
                        .foregroundStyle(
                            selected == tab
                                ? (colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                                : (colorScheme == .dark ? Color.white.opacity(0.3) : Color.black.opacity(0.28))
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                    }
                }
                .allowsHitTesting(false)

                // 4. Invisible gesture layer — taps animate, drags follow finger
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let moved = abs(value.translation.width)
                                touchLocation = value.location.x

                                if moved > dragThreshold {
                                    // Real drag — cancel any pending hold timer
                                    holdID = UUID()
                                    isDragging = true
                                    let clampedX = min(max(value.location.x, tabWidth / 2), w - tabWidth / 2)
                                    withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.82)) {
                                        dragX = clampedX
                                    }
                                    // Update selected tab in real-time
                                    let index = min(max(Int(value.location.x / tabWidth), 0), Tab.allCases.count - 1)
                                    let newTab = Tab.allCases[index]
                                    if newTab != selected { selected = newTab }
                                } else if !isDragging && !holdTriggered && value.translation == .zero {
                                    // First touch frame — schedule a hold timer
                                    let currentID = UUID()
                                    holdID = currentID
                                    let loc = value.location.x
                                    DispatchQueue.main.asyncAfter(deadline: .now() + holdDelay) {
                                        // Only fire if the gesture hasn't moved or ended
                                        guard holdID == currentID, !isDragging else { return }
                                        holdTriggered = true
                                        let index = min(max(Int(loc / tabWidth), 0), Tab.allCases.count - 1)
                                        let newTab = Tab.allCases[index]
                                        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                            selected = newTab
                                            dragX = nil
                                        }
                                    }
                                }
                            }
                            .onEnded { value in
                                // Cancel any pending hold timer
                                holdID = UUID()

                                let moved = abs(value.translation.width)
                                let index = min(max(Int(value.location.x / tabWidth), 0), Tab.allCases.count - 1)
                                let finalTab = Tab.allCases[index]

                                if holdTriggered {
                                    // Hold already moved the pill — just clean up
                                    holdTriggered = false
                                    isDragging = false
                                    dragX = nil
                                } else if moved <= dragThreshold {
                                    // Quick tap — animate pill to tapped tab
                                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                                        selected = finalTab
                                        dragX = nil
                                    }
                                } else {
                                    // Drag release — spring-settle to nearest tab center
                                    isDragging = false
                                    withAnimation(.spring(response: 0.42, dampingFraction: 0.75)) {
                                        selected = finalTab
                                        dragX = nil
                                    }
                                }
                            }
                    )
            }
        }
        .frame(height: 84)
    }

    // MARK: Track Background

    /// Neumorphic track – inset into the page surface.
    private var trackBody: some View {
        ZStack {
            // Base fill – same as background
            Capsule().fill(neuBg)

            // Inner shadow – dark along full top edge
            Capsule()
                .stroke(Color(white: colorScheme == .dark ? 0 : 0.5).opacity(colorScheme == .dark ? 0.6 : 0.7), lineWidth: 7)
                .blur(radius: 5)
                .offset(y: 4)
                .mask(Capsule().fill(
                    LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center)
                ))

            // Inner shadow – dark along full left edge
            Capsule()
                .stroke(Color(white: colorScheme == .dark ? 0 : 0.5).opacity(colorScheme == .dark ? 0.6 : 0.7), lineWidth: 7)
                .blur(radius: 5)
                .offset(x: 4)
                .mask(Capsule().fill(
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .center)
                ))

            // Inner shadow – light along full bottom edge
            Capsule()
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.9), lineWidth: 7)
                .blur(radius: 5)
                .offset(y: -3)
                .mask(Capsule().fill(
                    LinearGradient(colors: [.black, .clear], startPoint: .bottom, endPoint: .center)
                ))

            // Inner shadow – light along full right edge
            Capsule()
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.9), lineWidth: 7)
                .blur(radius: 5)
                .offset(x: -3)
                .mask(Capsule().fill(
                    LinearGradient(colors: [.black, .clear], startPoint: .trailing, endPoint: .center)
                ))
        }
    }
}

// MARK: - Placeholder

struct PlaceholderTabView: View {
    @Environment(\.colorScheme) private var colorScheme
    let title: String

    var body: some View {
        VStack(spacing: 16) {
            Text(title)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
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
