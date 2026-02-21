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

struct HomeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Query private var packs: [Pack]
    @Query private var verses: [Verse]
    @Binding var path: NavigationPath

    private var totalPacks: Int { packs.count }
    private var totalVerses: Int { verses.count }

    // MARK: Computed Properties

    private var overallHealth: Double {
        let healthValues = verses.compactMap(\.memoryHealth)
        guard !healthValues.isEmpty else { return 0 }
        return healthValues.reduce(0, +) / Double(healthValues.count)
    }

    private var reviewedDaySet: Set<Date> {
        Set(verses.compactMap(\.lastReviewed).map { Calendar.current.startOfDay(for: $0) })
    }

    private var reviewCountByDay: [Date: Int] {
        let cal = Calendar.current
        var counts: [Date: Int] = [:]
        for verse in verses {
            guard let reviewed = verse.lastReviewed else { continue }
            let day = cal.startOfDay(for: reviewed)
            counts[day, default: 0] += 1
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
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {

                // Title
                Text("Home")
                    .font(.system(size: 30, weight: .bold))
                    .foregroundStyle(Color(white: colorScheme == .dark ? 0.88 : 0.18))
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)

                // Stats row
                HStack(spacing: 12) {
                    statChip(value: "\(totalPacks)", label: "Packs")
                    statChip(value: "\(totalVerses)", label: "Verses")
                    statChip(value: "\(currentStreak) day", label: "Streak")
                }
                .padding(.horizontal, 20)

                // AMH ring + label
                VStack(spacing: 6) {
                    HomeAMHRing(progress: overallHealth)
                        .padding(.vertical, 16)

                    HStack(spacing: 4) {
                        Text("% Average memory health")
                            .font(.system(.subheadline, design: .rounded).weight(.medium))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                        Image(systemName: "info.circle")
                            .font(.system(size: 13))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)

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

                Spacer().frame(height: 100)
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
                AttentionDetailView(verses: weakestVerses)
            }
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

// MARK: - AMH Ring

private struct HomeAMHRing: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double

    private let ringDiameter: CGFloat = 190
    private let ringWidth: CGFloat = 24

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

    var body: some View {
        ZStack {
            // MARK: Raised ring (torus)
            Circle()
                .stroke(Color.neuBg, lineWidth: ringWidth)
                .frame(width: ringDiameter, height: ringDiameter)
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2),
                    radius: 5, x: 6, y: 6
                )
                .shadow(
                    color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7),
                    radius: 5, x: -3, y: -3
                )

            // MARK: Progress arc (painted on top of ring)
            // Outer glow
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor.opacity(0.35),
                    style: StrokeStyle(lineWidth: ringWidth + 6, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .blur(radius: 6)
                .rotationEffect(.degrees(-90))

            // Fillet layer — slightly wider and softened to blend into the ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor.opacity(0.5),
                    style: StrokeStyle(lineWidth: ringWidth + 2, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .blur(radius: 3)
                .rotationEffect(.degrees(-90))

            // Solid color arc with cylindrical shading
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    LinearGradient(
                        colors: [
                            ringColor.opacity(0.7),
                            ringColor,
                            ringColor.opacity(0.7)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    style: StrokeStyle(lineWidth: ringWidth - 4, lineCap: .round)
                )
                .frame(width: ringDiameter, height: ringDiameter)
                .shadow(color: Color.black.opacity(0.2), radius: 2, x: 1, y: 1)
                .shadow(color: Color.white.opacity(0.3), radius: 2, x: -0.5, y: -0.5)
                .rotationEffect(.degrees(-90))

            // MARK: Center text (NeuInset — simple diagonal, per NeuDesignGuide subtle)
            ZStack {
                // Base fill
                Text("\(Int(progress * 100))")
                    .font(.system(size: 88, weight: .heavy, design: .default))
                    .foregroundStyle(Color.neuBg)

                // Dark inner shadow (top-left crease)
                // Guide: gray @ 0.5 light / black @ 0.5 dark, lineWidth 4, blur 4, offset 2
                Text("\(Int(progress * 100))")
                    .font(.system(size: 88, weight: .heavy, design: .default))
                    .foregroundStyle(Color.clear)
                    .overlay(
                        Text("\(Int(progress * 100))")
                            .font(.system(size: 88, weight: .heavy, design: .default))
                            .foregroundStyle(Color(white: colorScheme == .dark ? 0 : 0.5).opacity(0.5))
                            .blur(radius: 4)
                            .offset(x: 2, y: 2)
                            .mask(
                                Text("\(Int(progress * 100))")
                                    .font(.system(size: 88, weight: .heavy, design: .default))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            )
                    )

                // Light inner highlight (bottom-right)
                // Guide: white @ 0.12 dark / white @ 1.0 light, lineWidth 6, blur 4, offset -2
                Text("\(Int(progress * 100))")
                    .font(.system(size: 88, weight: .heavy, design: .default))
                    .foregroundStyle(Color.clear)
                    .overlay(
                        Text("\(Int(progress * 100))")
                            .font(.system(size: 88, weight: .heavy, design: .default))
                            .foregroundStyle(Color.white.opacity(colorScheme == .dark ? 0.12 : 1.0))
                            .blur(radius: 4)
                            .offset(x: -2, y: -2)
                            .mask(
                                Text("\(Int(progress * 100))")
                                    .font(.system(size: 88, weight: .heavy, design: .default))
                                    .foregroundStyle(
                                        LinearGradient(colors: [.clear, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                                    )
                            )
                    )
            }
        }
        .frame(width: ringDiameter + ringWidth + 24, height: ringDiameter + ringWidth + 24)
    }
}

// MARK: - Heatmap Card

private struct HeatmapCard: View {
    @Environment(\.colorScheme) private var colorScheme
    let heatmapDays: [Date]
    let reviewCountByDay: [Date: Int]
    let totalVerses: Int
    let reviewsThisWeek: Int

    private let cols = 10
    private let rows = 3
    private let cellSize: CGFloat = 11
    private let cellSpacing: CGFloat = 3

    private let heatColor = Color(red: 0.35, green: 0.6, blue: 0.95)

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
                Text("Review")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.6) : Color.black.opacity(0.55))
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
    }

    // Grid: columns are weeks (oldest left, newest right).
    // Within each column, days fill bottom-to-top.
    // Index 0 = oldest day, index 29 = today (bottom-right).
    private var heatmapGrid: some View {
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
                                // Raised blue square (NeuRaised: R=2, D=2)
                                RoundedRectangle(cornerRadius: 2.5, style: .continuous)
                                    .fill(heatColor.opacity(level))
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 2, x: 2, y: 2)
                                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: 2, x: -1, y: -1)
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
            Text("Needs attention")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))

            VStack(spacing: 8) {
                ForEach(verses, id: \.id) { verse in
                    HStack(spacing: 6) {
                        Circle()
                            .fill(healthColor(for: verse.memoryHealth ?? 0))
                            .frame(width: 6, height: 6)
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

    private let heatColor = Color(red: 0.35, green: 0.6, blue: 0.95)

    private func intensity(for day: Date) -> Double {
        guard totalVerses > 0 else { return 0 }
        let count = reviewCountByDay[day, default: 0]
        guard count > 0 else { return 0 }
        return min(1.0, max(0.25, Double(count) / Double(totalVerses)))
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

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 5), count: 10), spacing: 5) {
                        ForEach(Array(heatmapDays.enumerated()), id: \.offset) { _, day in
                            let level = intensity(for: day)
                            if level > 0 {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(heatColor.opacity(level))
                                    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 3, x: 3, y: 3)
                                    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: 3, x: -1.5, y: -1.5)
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
                    .padding(16)
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
    @Environment(\.dismiss) private var dismiss
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
                    }
                    Spacer()
                }

                Text("Needs Attention")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.88) : Color(white: 0.18))

                if verses.isEmpty {
                    Text("All verses are in great shape!")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))
                } else {
                    Text("These verses could use some review.")
                        .font(.system(size: 15, weight: .medium, design: .rounded))
                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.5))

                    VStack(spacing: 14) {
                        ForEach(verses, id: \.id) { verse in
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(healthColor(for: verse.memoryHealth ?? 0))
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(verse.reference)
                                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                                        .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.7) : Color.black.opacity(0.65))
                                    if let pack = verse.pack {
                                        Text(pack.title)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.35))
                                    }
                                }
                                Spacer()
                                Text("\(Int((verse.memoryHealth ?? 0) * 100))%")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                    .foregroundStyle(healthColor(for: verse.memoryHealth ?? 0))
                            }
                        }
                    }
                }
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
