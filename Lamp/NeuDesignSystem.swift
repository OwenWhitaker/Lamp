import SwiftUI

// MARK: - Neumorphism Design System
// Based on https://hackingwithswift.com/articles/213/how-to-build-neumorphic-designs-with-swiftui
// Elements are the SAME color as the background. Depth comes only from shadows.
// Light source: top-left. Dark shadow cast further than light highlight (asymmetric).

extension Color {
    static let neuBg = Color(UIColor { tc in
        tc.userInterfaceStyle == .dark
            ? UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1)
            : UIColor(red: 225/255, green: 225/255, blue: 235/255, alpha: 1)
    })
}

/// Top-leading → bottom-trailing gradient (used by NeuInset mask).
private let neuGradientDark = LinearGradient(gradient: Gradient(colors: [.black, .clear]), startPoint: .topLeading, endPoint: .bottomTrailing)
private let neuGradientLight = LinearGradient(gradient: Gradient(colors: [.clear, .black]), startPoint: .topLeading, endPoint: .bottomTrailing)

let neuCorner: CGFloat = 22

// MARK: - Neumorphic Primitives

/// Raised surface -- extruded from the background with flat fill.
struct NeuRaised<S: Shape>: View {
    @Environment(\.colorScheme) private var colorScheme
    var shape: S
    var radius: CGFloat = 10
    var distance: CGFloat = 10

    var body: some View {
        shape
            .fill(Color.neuBg)
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.3), radius: radius, x: distance, y: distance)
            .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.04 : 1.0), radius: radius, x: -distance * 0.5, y: -distance * 0.5)
    }
}

/// Inset surface -- pressed into the background (blur + gradient-mask inner shadow).
struct NeuInset<S: Shape>: View {
    @Environment(\.colorScheme) private var colorScheme
    var shape: S

    var body: some View {
        ZStack {
            shape.fill(Color.neuBg)
            shape
                .stroke(Color(white: colorScheme == .dark ? 0 : 0.5).opacity(colorScheme == .dark ? 0.5 : 0.5), lineWidth: 4)
                .blur(radius: 4)
                .offset(x: 2, y: 2)
                .mask(shape.fill(neuGradientDark))
            shape
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.12 : 0.5), lineWidth: 6)
                .blur(radius: 4)
                .offset(x: -2, y: -2)
                .mask(shape.fill(neuGradientLight))
        }
    }
}

// MARK: - Neumorphic Circle Button

struct NeuCircleButton: View {
    @Environment(\.colorScheme) private var colorScheme
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
                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.5) : Color.black.opacity(0.45))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Neumorphic Progress Ring

struct NeuProgressRing: View {
    @Environment(\.colorScheme) private var colorScheme
    let progress: Double
    var size: CGFloat = 36

    private var ringColor: Color {
        if progress >= 0.75 {
            return Color(red: 0.55, green: 0.78, blue: 0.95)
        }
        let t = max(0, progress / 0.75)
        let r = 0.9 + (0.95 - 0.9) * t
        let g = 0.3 + (0.8 - 0.3) * t
        let b = 0.25 + (0.3 - 0.25) * t
        return Color(red: r, green: g, blue: b)
    }

    private var grooveWidth: CGFloat { size > 24 ? 4 : 3 }
    private var grooveRadius: CGFloat { (size - grooveWidth) / 2 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.neuBg)
                .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: 3, x: 2, y: 2)
                .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: 3, x: -1, y: -1)

            Circle()
                .strokeBorder(Color.black.opacity(0.07), lineWidth: 0.5)
                .frame(width: max(0, size - 1), height: max(0, size - 1))

            Circle()
                .stroke(Color.black.opacity(0.04), lineWidth: grooveWidth)

            Circle()
                .stroke(Color.black.opacity(0.12), lineWidth: grooveWidth)
                .blur(radius: 0.5)
                .offset(x: -0.5, y: -0.5)
                .mask(Circle().stroke(lineWidth: grooveWidth + 1))

            Circle()
                .stroke(Color.white.opacity(colorScheme == .dark ? 0.1 : 0.7), lineWidth: grooveWidth)
                .blur(radius: 0.5)
                .offset(x: 0.5, y: 0.5)
                .mask(Circle().stroke(lineWidth: grooveWidth + 1))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor.opacity(0.4),
                    style: StrokeStyle(lineWidth: grooveWidth + 2, lineCap: .round)
                )
                .blur(radius: 2)
                .rotationEffect(.degrees(-90))

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    ringColor,
                    style: StrokeStyle(lineWidth: grooveWidth - 0.5, lineCap: .round)
                )
                .shadow(color: Color.black.opacity(0.2), radius: 0.5, x: 0.5, y: 0.5)
                .shadow(color: Color.white.opacity(0.4), radius: 0.5, x: -0.3, y: -0.3)
                .rotationEffect(.degrees(-90))

            if size >= 36 {
                Text("\(Int(progress * 100))")
                    .font(.system(size: size * 0.26, weight: .bold))
                    .foregroundStyle(ringColor)
            }
        }
        .frame(width: size, height: size)
    }
}
