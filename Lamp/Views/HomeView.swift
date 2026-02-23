import SwiftUI
import SwiftData

// MARK: - Enable edge-swipe back when nav bar is hidden

private extension View {
    func enableSwipeBack() -> some View {
        self.background(SwipeBackHelper())
    }
}

private struct SwipeBackHelper: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> UIViewController {
        let vc = UIViewController()
        DispatchQueue.main.async {
            vc.navigationController?.interactivePopGestureRecognizer?.isEnabled = true
            vc.navigationController?.interactivePopGestureRecognizer?.delegate = nil
        }
        return vc
    }
    func updateUIViewController(_ uiViewController: UIViewController, context: Context) {}
}

// MARK: - HomeView

enum HomeDestination: Hashable {
    case heatmap
    case attention
}

private struct PackFocusRoute: Hashable {
    let pack: Pack
    let verseID: UUID
}

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var packs: [Pack]
    @Query private var verses: [Verse]
    @Binding var path: NavigationPath
    @State private var showMemoryHealthInfo = false

    private var totalPacks: Int { packs.count }
    private var totalVerses: Int { verses.count }

    // MARK: Computed Properties

    private var overallHealth: Double {
        let healthValues = verses.compactMap(\.memoryHealth)
        guard !healthValues.isEmpty else { return 0 }
        return healthValues.reduce(0, +) / Double(healthValues.count)
    }

    private var reviewedDaySet: Set<Date> {
        Set(verses.flatMap { verse in
            verse.reviewDays().map { Calendar.current.startOfDay(for: $0) }
        })
    }

    private var reviewCountByDay: [Date: Int] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for verse in verses {
            for day in verse.reviewDays(calendar: cal) {
                counts[day, default: 0] += 1
            }
        }
        return counts
    }

    private var currentStreak: Int {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        guard !reviewedDaySet.isEmpty else { return 0 }
        var anchor = today
        if !reviewedDaySet.contains(today) {
            guard let yesterday = cal.date(byAdding: .day, value: -1, to: today),
                  reviewedDaySet.contains(yesterday) else { return 0 }
            anchor = yesterday
        }
        var streak = 0
        var cursor = anchor
        while reviewedDaySet.contains(cursor) {
            streak += 1
            guard let prev = cal.date(byAdding: .day, value: -1, to: cursor) else { break }
            cursor = prev
        }
        return streak
    }

    private var heatmapDays: [Date] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        return (0..<30).compactMap { cal.date(byAdding: .day, value: -(29 - $0), to: today) }
    }

    private var reviewsThisWeek: Int {
        let cal = Calendar.current
        let weekStart = cal.date(from: cal.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date()))!
        let weekEnd = cal.date(byAdding: .day, value: 7, to: weekStart)!
        return reviewedDaySet.filter { $0 >= weekStart && $0 < weekEnd }.count
    }

    private var weakestVerses: [Verse] {
        verses
            .filter { $0.memoryHealth != nil }
            .sorted { ($0.memoryHealth ?? 1) < ($1.memoryHealth ?? 1) }
            .prefix(3)
            .map { $0 }
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
            let bottomClearance = max(170, geo.safeAreaInsets.bottom + 130)
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 0) {

                    // Title
                    Text("Home")
                        .font(.system(size: 30, weight: .bold))
                        .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    Spacer(minLength: max(10, geo.size.height * 0.02))

                    // Stats row
                    HStack(spacing: 12) {
                        statChip(value: "\(totalPacks)", label: "Packs")
                        statChip(value: "\(totalVerses)", label: "Verses")
                        statChip(value: "\(currentStreak) day", label: "Streak")
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: max(18, geo.size.height * 0.045))

                    // AMH ring + label
                    VStack(spacing: 6) {
                        HomeAMHRing(progress: overallHealth)
                            .padding(.vertical, 16)

                        HStack(spacing: 4) {
                            Text("% Average memory health")
                                .font(.system(.subheadline, design: .rounded).weight(.medium))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                            Button {
                                showMemoryHealthInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 13))
                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)

                    Spacer(minLength: max(18, geo.size.height * 0.055))

                    // Bottom cards row
                    HStack(alignment: .top, spacing: 14) {
                        Button { path.append(HomeDestination.heatmap) } label: {
                            HeatmapCard(
                                heatmapDays: heatmapDays,
                                reviewCountByDay: reviewCountByDay,
                                totalVerses: verses.count,
                                reviewsThisWeek: reviewsThisWeek
                            )
                        }
                        .buttonStyle(.plain)

                        Button { path.append(HomeDestination.attention) } label: {
                            NeedsAttentionCard(verses: weakestVerses)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 20)

                    Spacer(minLength: bottomClearance)
                }
                .frame(minHeight: geo.size.height, alignment: .top)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.neuBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .navigationDestination(for: HomeDestination.self) { dest in
            switch dest {
            case .heatmap:
                HeatmapDetailView(
                    heatmapDays: heatmapDays,
                    reviewCountByDay: reviewCountByDay,
                    totalVerses: verses.count,
                    reviewsThisWeek: reviewsThisWeek
                )
            case .attention:
                AttentionDetailView(path: $path, verses: weakestVerses)
            }
        }
        .navigationDestination(for: PackFocusRoute.self) { route in
            PackDetailView(pack: route.pack, path: $path, initialVerseID: route.verseID)
        }
        .sheet(isPresented: $showMemoryHealthInfo) {
            MemoryHealthInfoSheet()
        }
    }

    // MARK: Stat Chip

    private func statChip(value: String, label: String) -> some View {
        ZStack {
            NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))
            VStack(spacing: 2) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.6))
                Text(label)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
            }
            .padding(.horizontal, 6)
        }
        .frame(height: 68)
    }
}

private struct MemoryHealthInfoSheet: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color.neuBg.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Average Memory Health")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                        Spacer()

                        NeuCircleButton(icon: "xmark", size: 36) { dismiss() }
                    }

                    ZStack(alignment: .topLeading) {
                        NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))

                        VStack(alignment: .leading, spacing: 12) {
                            Text("How it's calculated")
                                .font(.system(size: 16, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                            Text("1. Include every verse where memory health has a value.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.58))

                            Text("2. Add those values and divide by the number of included verses.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.58))

                            Text("3. Display as a percent: average × 100.")
                                .font(.system(size: 14, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.58))

                            ZStack(alignment: .leading) {
                                NeuInset(shape: RoundedRectangle(cornerRadius: 14, style: .continuous))

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Formula")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.42) : Color.black.opacity(0.38))

                                    Text("average = sum(memoryHealth values) / count(values)")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.58) : Color.black.opacity(0.54))
                                    Text("displayed percent = Int(average * 100)")
                                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.58) : Color.black.opacity(0.54))
                                }
                                .padding(12)
                            }
                            .frame(minHeight: 86)

                            Text("If no verses have memory health yet, the displayed average is 0%.")
                                .font(.system(size: 13, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.42) : Color.black.opacity(0.42))
                                .padding(.top, 4)
                        }
                        .padding(16)
                    }
                }
                .padding(20)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}

// MARK: - AMH Ring

private struct HomeAMHRing: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double

    private let ringDiameter: CGFloat = 190
    private let ringWidth: CGFloat = 26
    private let scoreFontSize: CGFloat = 88

    private var ringColor: Color {
        if progress >= 0.75 {
            return Color(red: 0.55, green: 0.78, blue: 0.95)
        }
        let t = max(0, progress / 0.75)
        return Color(
            red: 0.9 + 0.05 * t,
            green: 0.3 + 0.5 * t,
            blue: 0.25 + 0.05 * t
        )
    }

    private var scoreText: String {
        "\(Int(progress * 100))"
    }

    private var scoreDisplayFontSize: CGFloat {
        scoreText.count >= 3 ? scoreFontSize * 0.8 : scoreFontSize
    }

    var body: some View {
        let clampedProgress = min(1, max(0, progress))
        let baseMedallionDiameter = ringDiameter + 8
        let ringBodyDiameter = ringDiameter - 14
        let ringPathDiameter = ringBodyDiameter
        let trackWidth = max(14, ringWidth - 8)
        let progressWidth = max(13, trackWidth - 1)
        let centerDiskDiameter = ringBodyDiameter - trackWidth - 26
        let tintMaskColors: [Color] = colorScheme == .dark
            ? [.black, .clear]
            : [.clear, .black]

        ZStack {
            // Base medallion rising from the page.
            Circle()
                .fill(Color.neuBg)
                .frame(width: baseMedallionDiameter, height: baseMedallionDiameter)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.45 : 0.18), radius: 13, x: 9, y: 9)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.74), radius: 11, x: -6, y: -6)

            // Ring body raised on top of the medallion.
            Circle()
                .stroke(Color.neuBg, lineWidth: ringWidth)
                .frame(width: ringBodyDiameter, height: ringBodyDiameter)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.36 : 0.16), radius: 8, x: 6, y: 6)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.1 : 0.58), radius: 8, x: -4, y: -4)

            // Broad neutral track under the progress segment.
            Circle()
                .stroke(Color.neuBg.opacity(colorScheme == .dark ? 0.93 : 0.98), lineWidth: trackWidth)
                .frame(width: ringPathDiameter, height: ringPathDiameter)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), radius: 1.6, x: 1.1, y: 1.1)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.45), radius: 1.2, x: -0.8, y: -0.8)

            // Progress segment: solid raised element.
            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(ringColor.opacity(colorScheme == .dark ? 0.28 : 0.2), style: StrokeStyle(lineWidth: progressWidth + 6, lineCap: .round))
                .frame(width: ringPathDiameter, height: ringPathDiameter)
                .blur(radius: colorScheme == .dark ? 2.2 : 1.6)
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0, to: clampedProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: progressWidth, lineCap: .round))
                .frame(width: ringPathDiameter, height: ringPathDiameter)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.24 : 0.16), radius: 1.9, x: 1.2, y: 1.2)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.12 : 0.34), radius: 1.9, x: -1.2, y: -1.2)
                .rotationEffect(.degrees(-90))

            // Inner medallion raised in the center of the ring.
            Circle()
                .fill(Color.neuBg)
                .frame(width: centerDiskDiameter, height: centerDiskDiameter)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.32 : 0.15), radius: 7, x: 4, y: 4)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.72), radius: 6, x: -3, y: -3)

            // MARK: Center text (Embossed)
            ZStack {
                // Dark rim on top-left.
                Text(scoreText)
                    .font(.system(size: scoreDisplayFontSize, weight: .heavy, design: .default))
                    .foregroundStyle(Color.black.opacity(colorScheme == .dark ? 0.6 : 0.32))
                    .offset(x: -1.6, y: -1.6)
                    .blur(radius: 0.9)

                // Light rim on bottom-right.
                Text(scoreText)
                    .font(.system(size: scoreDisplayFontSize, weight: .heavy, design: .default))
                    .foregroundStyle(Color.white.opacity(colorScheme == .dark ? 0.26 : 0.95))
                    .offset(x: 1.2, y: 1.2)

                // Base glyph.
                Text(scoreText)
                    .font(.system(size: scoreDisplayFontSize, weight: .heavy, design: .default))
                    .foregroundStyle(Color.neuBg)

                // Bottom tint matches ring color.
                Text(scoreText)
                    .font(.system(size: scoreDisplayFontSize, weight: .heavy, design: .default))
                    .foregroundStyle(ringColor.opacity(colorScheme == .dark ? 0.68 : 0.58))
                    .mask(
                        Text(scoreText)
                            .font(.system(size: scoreDisplayFontSize, weight: .heavy, design: .default))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: tintMaskColors,
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    )
            }
        }
        .frame(width: ringDiameter + ringWidth + 24, height: ringDiameter + ringWidth + 24)
    }
}

// MARK: - Heatmap Card

private struct CandyHeatSquare: View {
    @Environment(\.colorScheme) private var colorScheme
    let baseColor: Color
    let level: Double
    let cornerRadius: CGFloat

    var body: some View {
        let t = min(1, max(0, level))
        let innerCorner = max(0, cornerRadius - 0.6)

        ZStack {
            // Subtle emissive halo.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(baseColor.opacity(colorScheme == .dark ? 0.2 : 0.12))
                .blur(radius: 2.6)
                .scaleEffect(1.08)

            // Extruded body.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            baseColor.opacity(0.78 + 0.14 * t),
                            baseColor.opacity(0.92 + 0.08 * t)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            // Top-left face light.
            RoundedRectangle(cornerRadius: innerCorner, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(colorScheme == .dark ? 0.2 : 0.34),
                            .clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .padding(1)

            // Crisp rim.
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.08 : 0.24), lineWidth: 0.6)
        }
        .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.2), radius: 2.1, x: 1.5, y: 1.5)
        .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.58), radius: 1.8, x: -1.0, y: -1.0)
    }
}

private struct HeatmapCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let heatmapDays: [Date]
    let reviewCountByDay: [Date: Int]
    let totalVerses: Int
    let reviewsThisWeek: Int
    @State private var cachedGridImage: Image?
    @State private var cachedGridKey: String = ""

    private let cols = 10
    private let rows = 3
    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3

    private let heatColor = Color(red: 0.35, green: 0.6, blue: 0.95)

    private var gridWidth: CGFloat {
        CGFloat(cols) * cellSize + CGFloat(cols - 1) * cellSpacing
    }

    private var gridHeight: CGFloat {
        CGFloat(rows) * cellSize + CGFloat(rows - 1) * cellSpacing
    }

    private func intensity(for day: Date) -> Double {
        guard totalVerses > 0 else { return 0 }
        let count = reviewCountByDay[day, default: 0]
        guard count > 0 else { return 0 }
        // Normalize: 1 verse = 0.25, all verses = 1.0
        return min(1.0, max(0.25, Double(count) / Double(totalVerses)))
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Review")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.55))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3))
                }
                Text("Last 30 days")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))

                heatmapGrid
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)

                Text("\(reviewsThisWeek)/7 this week")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
            }
            .padding(14)
        }
        .frame(maxWidth: .infinity, minHeight: 130)
        .task(id: gridCacheKey) {
            updateGridSnapshotIfNeeded()
        }
    }

    // Grid: columns are weeks (oldest left, newest right).
    // Within each column, days fill bottom-to-top.
    // Index 0 = oldest day, index 29 = today (bottom-right).
    private var heatmapGrid: some View {
        Group {
            if let cachedGridImage, cachedGridKey == gridCacheKey {
                cachedGridImage
                    .resizable()
                    .interpolation(.none)
            } else {
                liveHeatmapGrid
            }
        }
        .frame(width: gridWidth, height: gridHeight)
    }

    private var liveHeatmapGrid: some View {
        HStack(spacing: cellSpacing) {
            ForEach(0..<cols, id: \.self) { col in
                VStack(spacing: cellSpacing) {
                    ForEach(0..<rows, id: \.self) { row in
                        // Top row = highest row index in the column, bottom = 0
                        let dayIndex = col * rows + (rows - 1 - row)
                        if dayIndex < heatmapDays.count {
                            let day = heatmapDays[dayIndex]
                            let level = intensity(for: day)
                            if level > 0 {
                                CandyHeatSquare(baseColor: heatColor, level: level, cornerRadius: 2.5)
                                    .frame(width: cellSize, height: cellSize)
                            } else {
                                // Inset empty pit (NeuInset: subtle)
                                ZStack {
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .fill(Color.neuBg)
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .stroke(Color(white: colorScheme == .dark ? 0 : 0.5).opacity(colorScheme == .dark ? 0.5 : 0.5), lineWidth: 3)
                                        .blur(radius: 2)
                                        .offset(x: 1.5, y: 1.5)
                                        .mask(RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(
                                            LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        ))
                                    RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                        .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.9), lineWidth: 3)
                                        .blur(radius: 2)
                                        .offset(x: -1.5, y: -1.5)
                                        .mask(RoundedRectangle(cornerRadius: 2.5, style: .continuous).fill(
                                            LinearGradient(colors: [.clear, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                                        ))
                                }
                                .frame(width: cellSize, height: cellSize)
                            }
                        } else {
                            Color.clear.frame(width: cellSize, height: cellSize)
                        }
                    }
                }
            }
        }
    }

    private var gridCacheKey: String {
        let schemeKey = colorScheme == .dark ? "dark" : "light"
        let levelsKey = (0..<(cols * rows))
            .map { dayIndex -> String in
                guard dayIndex < heatmapDays.count else { return "x" }
                let level = intensity(for: heatmapDays[dayIndex])
                return String(Int((level * 1000).rounded()))
            }
            .joined(separator: ",")
        return "\(schemeKey)|\(levelsKey)"
    }

    @MainActor
    private func updateGridSnapshotIfNeeded() {
        guard cachedGridKey != gridCacheKey else { return }

        let renderer = ImageRenderer(
            content: liveHeatmapGrid.frame(width: gridWidth, height: gridHeight)
        )
        renderer.proposedSize = ProposedViewSize(width: gridWidth, height: gridHeight)
        renderer.scale = UIScreen.main.scale

        if let uiImage = renderer.uiImage {
            cachedGridImage = Image(uiImage: uiImage)
            cachedGridKey = gridCacheKey
        } else {
            cachedGridImage = nil
            cachedGridKey = ""
        }
    }
}

// MARK: - Needs Attention Card

private struct NeedsAttentionCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let verses: [Verse]

    var body: some View {
        ZStack(alignment: .topLeading) {
            NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))

            if verses.isEmpty {
                emptyState
            } else {
                verseList
            }
        }
        .frame(maxWidth: .infinity, minHeight: 130)
    }

    private var verseList: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text("Needs attention")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.55))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3))
                }
                Text("Lowest memory health")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
            }

            ZStack {
                NeuInset(shape: RoundedRectangle(cornerRadius: 12, style: .continuous))

                VStack(spacing: 7) {
                    ForEach(verses, id: \.id) { verse in
                        HStack(spacing: 6) {
                            ZStack {
                                Circle()
                                    .fill(Color.neuBg)
                                    .frame(width: 9, height: 9)
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.35 : 0.16), radius: 1.2, x: 1.0, y: 1.0)
                                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.6), radius: 1.2, x: -0.5, y: -0.5)
                                Circle()
                                    .fill(healthColor(for: verse.memoryHealth ?? 0))
                                    .frame(width: 5.5, height: 5.5)
                            }
                            Text(verse.reference)
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.6))
                                .lineLimit(1)
                            Spacer()
                            Text("\(Int((verse.memoryHealth ?? 0) * 100))%")
                                .font(.system(size: 10, weight: .medium, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
            }
        }
        .padding(14)
    }

    private var emptyState: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 22))
                .foregroundStyle(Color(red: 0.55, green: 0.78, blue: 0.95).opacity(0.7))
            Text("All verses\nin great shape")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.4))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(14)
    }

    private func healthColor(for health: Double) -> Color {
        if health >= 0.75 { return Color(red: 0.55, green: 0.78, blue: 0.95) }
        let t = max(0, health / 0.75)
        return Color(
            red: 0.9 + 0.05 * t,
            green: 0.3 + 0.5 * t,
            blue: 0.25 + 0.05 * t
        )
    }
}

// MARK: - Heatmap Detail View

private struct HeatmapDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dismiss) private var dismiss
    let heatmapDays: [Date]
    let reviewCountByDay: [Date: Int]
    let totalVerses: Int
    let reviewsThisWeek: Int
    @State private var cachedDetailGridImage: Image?
    @State private var cachedDetailGridKey: String = ""
    @State private var detailGridWidth: CGFloat = 0

    private let heatColor = Color(red: 0.35, green: 0.6, blue: 0.95)
    private let detailGridColumns = 10
    private let detailGridSpacing: CGFloat = 5

    private func intensity(for day: Date) -> Double {
        guard totalVerses > 0 else { return 0 }
        let count = reviewCountByDay[day, default: 0]
        guard count > 0 else { return 0 }
        return min(1.0, max(0.25, Double(count) / Double(totalVerses)))
    }

    private var detailGridDataKey: String {
        let schemeKey = colorScheme == .dark ? "dark" : "light"
        let levelsKey = heatmapDays
            .map { day in
                let level = intensity(for: day)
                return String(Int((level * 1000).rounded()))
            }
            .joined(separator: ",")
        return "\(schemeKey)|\(levelsKey)"
    }

    private var liveDetailHeatmapGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: detailGridSpacing), count: detailGridColumns),
            spacing: detailGridSpacing
        ) {
            ForEach(Array(heatmapDays.enumerated()), id: \.offset) { _, day in
                let level = intensity(for: day)
                if level > 0 {
                    CandyHeatSquare(baseColor: heatColor, level: level, cornerRadius: 3)
                        .aspectRatio(1, contentMode: .fit)
                } else {
                    ZStack {
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(Color.neuBg)
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color(white: colorScheme == .dark ? 0 : 0.5).opacity(colorScheme == .dark ? 0.5 : 0.5), lineWidth: 4)
                            .blur(radius: 3)
                            .offset(x: 2, y: 2)
                            .mask(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(
                                LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                            ))
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.9), lineWidth: 4)
                            .blur(radius: 3)
                            .offset(x: -2, y: -2)
                            .mask(RoundedRectangle(cornerRadius: 3, style: .continuous).fill(
                                LinearGradient(colors: [.clear, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                            ))
                    }
                    .aspectRatio(1, contentMode: .fit)
                }
            }
        }
    }

    private func detailGridCacheKey(for width: CGFloat) -> String {
        "\(detailGridDataKey)|w\(Int((width * 10).rounded()))"
    }

    @MainActor
    private func updateDetailGridSnapshotIfNeeded(width: CGFloat) {
        guard width > 0 else { return }
        let cacheKey = detailGridCacheKey(for: width)
        guard cachedDetailGridKey != cacheKey else { return }

        let renderer = ImageRenderer(
            content: liveDetailHeatmapGrid.frame(width: width)
        )
        renderer.proposedSize = ProposedViewSize(width: width, height: nil)
        renderer.scale = UIScreen.main.scale

        if let uiImage = renderer.uiImage {
            cachedDetailGridImage = Image(uiImage: uiImage)
            cachedDetailGridKey = cacheKey
        } else {
            cachedDetailGridImage = nil
            cachedDetailGridKey = ""
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                // Back button
                NeuCircleButton(icon: "chevron.left", size: 40) { dismiss() }

                // Title
                Text("Review Activity")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                Text("\(reviewsThisWeek)/7 days this week")
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))

                // Heatmap in raised card
                ZStack(alignment: .topLeading) {
                    NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))

                    Group {
                        let activeCacheKey = detailGridWidth > 0 ? detailGridCacheKey(for: detailGridWidth) : ""
                        if let cachedDetailGridImage, cachedDetailGridKey == activeCacheKey {
                            cachedDetailGridImage
                                .resizable()
                                .interpolation(.none)
                                .aspectRatio(contentMode: .fit)
                        } else {
                            liveDetailHeatmapGrid
                        }
                    }
                    .padding(16)
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .task(id: Int((proxy.size.width * 10).rounded())) {
                                    let measuredWidth = proxy.size.width
                                    guard measuredWidth > 0 else { return }
                                    detailGridWidth = measuredWidth
                                    updateDetailGridSnapshotIfNeeded(width: measuredWidth)
                                }
                        }
                    )
                    .task(id: detailGridDataKey) {
                        guard detailGridWidth > 0 else { return }
                        updateDetailGridSnapshotIfNeeded(width: detailGridWidth)
                    }
                }

                // Recent days in raised card
                ZStack(alignment: .topLeading) {
                    NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))

                    VStack(alignment: .leading, spacing: 14) {
                        Text("Recent days")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.55) : Color.black.opacity(0.5))

                        ForEach(heatmapDays.suffix(7).reversed(), id: \.self) { day in
                            let count = reviewCountByDay[day, default: 0]
                            HStack {
                                Text(day, format: .dateTime.weekday(.wide).month(.abbreviated).day())
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.65) : Color.black.opacity(0.6))
                                Spacer()
                                Text("\(count) verse\(count == 1 ? "" : "s")")
                                    .font(.system(size: 14, weight: .bold, design: .rounded))
                                    .foregroundStyle(count > 0 ? heatColor : (colorScheme == .dark ? Color.white.opacity(0.25) : Color.black.opacity(0.25)))
                            }
                        }
                    }
                    .padding(16)
                }

                Spacer().frame(height: 40)
            }
            .padding(20)
        }
        .background(Color.neuBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
    }
}

// MARK: - Attention Detail View

private struct AttentionDetailView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var path: NavigationPath
    @Query private var packs: [Pack]
    let verses: [Verse]

    private func healthColor(for health: Double) -> Color {
        if health >= 0.75 { return Color(red: 0.55, green: 0.78, blue: 0.95) }
        let t = max(0, health / 0.75)
        return Color(
            red: 0.9 + 0.05 * t,
            green: 0.3 + 0.5 * t,
            blue: 0.25 + 0.05 * t
        )
    }

    private func mostRecentlyAccessedPack(for verse: Verse) -> Pack? {
        let matching = packs.filter { pack in
            pack.verses.contains(where: { $0.id == verse.id })
        }
        return matching.max { lhs, rhs in
            let l = lhs.lastAccessedAt ?? lhs.createdAt
            let r = rhs.lastAccessedAt ?? rhs.createdAt
            return l < r
        }
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 24) {
                NeuCircleButton(icon: "chevron.left", size: 40) {
                    if !path.isEmpty { path.removeLast() }
                }

                Text("Needs Attention")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))

                ZStack(alignment: .topLeading) {
                    NeuRaised(shape: RoundedRectangle(cornerRadius: neuCorner, style: .continuous))

                    VStack(alignment: .leading, spacing: 16) {
                        Text(verses.isEmpty ? "All verses are in great shape." : "These verses could use review.")
                            .font(.system(size: 15, weight: .medium, design: .rounded))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))

                        if verses.isEmpty {
                            HStack(spacing: 10) {
                                Image(systemName: "checkmark.circle")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(Color(red: 0.55, green: 0.78, blue: 0.95).opacity(0.75))
                                Text("No low-health verses right now.")
                                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.58))
                            }
                        } else {
                            Text("\(verses.count) verse\(verses.count == 1 ? "" : "s") below ideal memory health")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.4) : Color.black.opacity(0.38))
                        }
                    }
                    .padding(16)
                }

                if !verses.isEmpty {
                    VStack(spacing: 14) {
                        ForEach(verses, id: \.id) { verse in
                            Button {
                                guard let pack = mostRecentlyAccessedPack(for: verse) ?? verse.pack else { return }
                                path.append(PackFocusRoute(pack: pack, verseID: verse.id))
                            } label: {
                                ZStack {
                                    NeuRaised(shape: RoundedRectangle(cornerRadius: 16, style: .continuous), radius: 8, distance: 8)

                                    HStack(spacing: 12) {
                                        ZStack {
                                            NeuInset(shape: Circle())
                                            Circle()
                                                .fill(healthColor(for: verse.memoryHealth ?? 0))
                                                .frame(width: 8, height: 8)
                                        }
                                        .frame(width: 20, height: 20)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(verse.reference)
                                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                                                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.72) : Color.black.opacity(0.66))
                                            if let pack = verse.pack {
                                                Text(pack.title)
                                                    .font(.system(size: 12, weight: .medium, design: .rounded))
                                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.36) : Color.black.opacity(0.36))
                                            }
                                        }

                                        Spacer()

                                        Text("\(Int((verse.memoryHealth ?? 0) * 100))%")
                                            .font(.system(size: 15, weight: .bold, design: .rounded))
                                            .foregroundStyle(healthColor(for: verse.memoryHealth ?? 0))
                                    }
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 12)
                                }
                            }
                            .buttonStyle(.plain)
                            .disabled(verse.pack == nil)
                        }
                    }
                }

                Spacer().frame(height: 40)
            }
            .padding(20)
        }
        .background(Color.neuBg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .enableSwipeBack()
    }
}

// MARK: - Preview

@MainActor
private func makePreviewContainer() -> ModelContainer {
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Pack.self, Verse.self, configurations: config)

    let pack = Pack(title: "Psalms")
    container.mainContext.insert(pack)

    let cal = Calendar.current
    let today = Date()

    let sampleVerses: [(String, String, Double, Int)] = [
        ("Psalm 23:1",  "The Lord is my shepherd; I shall not want.",      0.88, 0),
        ("John 3:16",   "For God so loved the world...",                   0.42, 1),
        ("Romans 8:28", "And we know that in all things God works for good", 0.31, 2),
        ("Phil 4:13",   "I can do all things through Christ who strengthens me", 0.65, 3),
        ("Prov 3:5",    "Trust in the Lord with all your heart...",        0.19, 4),
    ]

    for (i, (ref, text, health, order)) in sampleVerses.enumerated() {
        let daysAgo = [0, 1, 2, 4, 6][i]
        let reviewed = cal.date(byAdding: .day, value: -daysAgo, to: today)
        let verse = Verse(reference: ref, text: text, order: order, lastReviewed: reviewed, memoryHealth: health)
        verse.pack = pack
        container.mainContext.insert(verse)
    }

    for d in [3, 5, 7, 9, 11, 13, 16, 19, 22, 25, 28] {
        let v = Verse(
            reference: "Gen 1:\(d)",
            text: "Sample verse text.",
            order: 10 + d,
            lastReviewed: cal.date(byAdding: .day, value: -d, to: today),
            memoryHealth: nil
        )
        v.pack = pack
        container.mainContext.insert(v)
    }

    return container
}

#Preview {
    @Previewable @State var path = NavigationPath()
    NavigationStack(path: $path) {
        HomeView(path: $path)
    }
    .modelContainer(makePreviewContainer())
}
