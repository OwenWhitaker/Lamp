# Neumorphic Design Guidelines — Lamp App

Reference: [Hacking with Swift — How to build neumorphic designs with SwiftUI](https://hackingwithswift.com/articles/213/how-to-build-neumorphic-designs-with-swiftui)

---

## Core Principles

1. **Everything is the same color as the background.** Depth comes *only* from shadows. There are no borders, strokes, or color fills that differ from `neuBg`. If you add a stroke or border, you're probably doing it wrong.

2. **Light source is top-left.** Every shadow in the system assumes light comes from the top-left corner. This means:
   - **Raised** surfaces cast a dark shadow to the bottom-right and a light highlight to the top-left.
   - **Inset** surfaces have a dark shadow along the top and left inner edges, and a light highlight along the bottom and right inner edges.

3. **Contrast is reduced.** Never use pure white (`#FFFFFF`) or pure black (`#000000`) as background colors. The background is an off-white with a slight cool tint.

---

## Background Color

`neuBg` is a dynamic `UIColor` that adapts to the system appearance:

| Mode | RGB | Description |
|------|-----|-------------|
| **Light** | `(225, 225, 235)` | Cool off-white — the original neumorphic palette |
| **Dark** | `(40, 40, 50)` | Deep charcoal with a slight cool tint |

```swift
private let neuBg = Color(UIColor { tc in
    tc.userInterfaceStyle == .dark
        ? UIColor(red: 40/255, green: 40/255, blue: 50/255, alpha: 1)
        : UIColor(red: 225/255, green: 225/255, blue: 235/255, alpha: 1)
})
```

---

## Raised Surfaces (Extruded from background)

Used for: cards, buttons, the tab bar pill selector.

### The Asymmetric Shadow Rule

**The dark shadow is cast FURTHER than the light highlight.** This is the single most important rule. The dark shadow offset should be roughly **2x** the light highlight offset. Both shadows use the **same blur radius**.

### Standard formula (NeuRaised)

```swift
@Environment(\.colorScheme) private var colorScheme

shape
    .fill(neuBg)
    .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.4 : 0.2), radius: R, x: D, y: D)
    .shadow(color: Color.white.opacity(colorScheme == .dark ? 0.08 : 0.7), radius: R, x: -D * 0.5, y: -D * 0.5)
```

Where:
- `R` = blur radius (same for both)
- `D` = dark shadow distance
- Light highlight distance = `D * 0.5`

### Recommended values by element size

| Element | R | D | Dark: black | Dark: white | Light: black | Light: white |
|---------|---|---|------------|------------|-------------|-------------|
| Large card (300pt) | 10 | 10 | 0.4 | 0.08 | 0.2 | 0.7 |
| Medium card (pack card) | 10 | 10 | 0.4 | 0.08 | 0.2 | 0.7 |
| Small element (pill in track) | 5 | 4 | 0.5 | 0.07 | 0.18 | 0.6 |
| Tiny element (circle button) | 6 | 5 | 0.4 | 0.08 | 0.2 | 0.7 |

### Key mistakes to avoid

- **Symmetric offsets** (e.g., `x: 6` dark, `x: -6` light) — looks flat and unnatural. Always use asymmetric (2:1 ratio).
- **Mismatched blur radii** (e.g., radius 10 dark, radius 14 light) — makes the highlight look like a glow rather than a lit edge.
- **Too strong for nested elements** — a pill sitting inside an inset track should have softer shadows than a card on the page, or it will look like it's floating above the page surface.

---

## Inset Surfaces (Pressed into background)

Used for: the tab bar track, progress ring tracks, text input fields.

### Technique: Blur + Gradient-Mask Inner Shadows

You cannot use SwiftUI's `.shadow()` modifier for inner shadows. Instead, use a stroked shape, blur it, offset it, and mask it with a gradient so only the desired edge is visible.

### Simple diagonal version (NeuInset — for small elements)

```swift
ZStack {
    shape.fill(neuBg)

    // Dark inner shadow (top-left crease)
    shape
        .stroke(Color.black.opacity(0.5), lineWidth: 4)
        .blur(radius: 4)
        .offset(x: 2, y: 2)
        .mask(shape.fill(
            LinearGradient(colors: [.black, .clear], startPoint: .topLeading, endPoint: .bottomTrailing)
        ))

    // Light inner shadow (bottom-right highlight)
    shape
        .stroke(Color.white.opacity(0.12), lineWidth: 6)
        .blur(radius: 4)
        .offset(x: -2, y: -2)
        .mask(shape.fill(
            LinearGradient(colors: [.clear, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
        ))
}
```

This works well for small, roughly square elements (circles, small rounded rects).

### Full-edge version (for wide/tall elements like the tab bar track)

For wide or tall shapes, a single diagonal gradient mask causes the shadow to fade out too early on the long edges. Instead, **split into four separate edge layers** — one per edge — each masked with a gradient perpendicular to that edge:

```swift
ZStack {
    shape.fill(neuBg)

    // Dark – full top edge
    shape.stroke(Color.black.opacity(0.6), lineWidth: 7)
        .blur(radius: 5).offset(y: 4)
        .mask(shape.fill(
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: .center)
        ))

    // Dark – full left edge
    shape.stroke(Color.black.opacity(0.6), lineWidth: 7)
        .blur(radius: 5).offset(x: 4)
        .mask(shape.fill(
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .center)
        ))

    // Light – full bottom edge
    shape.stroke(Color.white.opacity(0.1), lineWidth: 7)
        .blur(radius: 5).offset(y: -3)
        .mask(shape.fill(
            LinearGradient(colors: [.black, .clear], startPoint: .bottom, endPoint: .center)
        ))

    // Light – full right edge
    shape.stroke(Color.white.opacity(0.1), lineWidth: 7)
        .blur(radius: 5).offset(x: -3)
        .mask(shape.fill(
            LinearGradient(colors: [.black, .clear], startPoint: .trailing, endPoint: .center)
        ))
}
```

### Key parameters for inset depth

**Dark mode:**

| Depth feel | lineWidth | blur | offset | dark stroke | light stroke |
|-----------|-----------|------|--------|------------|-------------|
| Subtle | 4 | 4 | 2 | `black @ 0.5` | `white @ 0.12` |
| Medium | 5–6 | 4–5 | 3 | `black @ 0.55–0.6` | `white @ 0.1` |
| Deep | 7 | 5 | 4 | `black @ 0.6` | `white @ 0.1` |

**Light mode:**

| Depth feel | lineWidth | blur | offset | dark stroke | light stroke |
|-----------|-----------|------|--------|------------|-------------|
| Subtle | 4 | 4 | 2 | `gray @ 0.5` | `white @ 1.0` |
| Medium | 5–6 | 4–5 | 3 | `gray @ 0.55–0.6` | `white @ 0.9` |
| Deep | 7 | 5 | 4 | `gray @ 0.7` | `white @ 0.9` |

### Key mistakes to avoid

- **Adding outer raised shadows to an inset element** — an inset surface is below the page; it should NOT cast drop shadows outward.
- **Using a diagonal mask on a wide element** — the shadow will only appear in the corner and fade out along the long edges. Use the four-edge technique instead.
- **Light highlight visible on the top/left** — the gradient mask must confine the light shadow to only the bottom and right edges, consistent with the top-left light source.

---

## Nesting: Raised Inside Inset

When placing a raised element inside an inset channel (e.g., the pill inside the tab bar track):

1. The **inset** has NO outer shadows — it's a depression.
2. The **raised element** has softer shadows than a standalone raised surface, because it only needs to look lifted from the track floor, not from the page surface.
3. The gap between inset and raised element should be **uniform** on all sides for concentric corners.

### Concentric capsule formula

```swift
let inset: CGFloat = 8
let pillWidth = tabWidth - inset * 2
let pillHeight = trackHeight - inset * 2
// Capsule corner radius = height / 2
// Track radius: trackHeight / 2
// Pill radius:  pillHeight / 2
// Difference:   trackHeight/2 - pillHeight/2 = inset  ✓ Concentric
```

---

## Shadow Color Rules

| Shadow type | Dark mode | Light mode |
|------------|-----------|------------|
| Dark outer (raised) | `black @ 0.4` | `black @ 0.2` |
| Light outer (raised) | `white @ 0.07–0.08` | `white @ 0.7` |
| Dark inner (inset) | `black @ 0.5–0.6` | `gray @ 0.5–0.7` |
| Light inner (inset) | `white @ 0.1–0.12` | `white @ 0.9–1.0` |

**Never use colored shadows.** The neumorphic system is monochromatic — all shadows are grayscale.

## Text Color Rules

| Role | Dark mode | Light mode |
|------|-----------|------------|
| Primary text | `Color(white: 0.88)` | `Color(white: 0.18)` |
| Secondary text | `white @ 0.55` | `black @ 0.55` |
| Tertiary text | `white @ 0.35` | `black @ 0.35` |
| Icon color | `white @ 0.5` | `black @ 0.45` |
| Tab active | `white @ 0.7` | `black @ 0.6` |
| Tab inactive | `white @ 0.3` | `black @ 0.28` |

---

## Quick Checklist

- [ ] Fill color matches `neuBg` exactly
- [ ] No visible borders or strokes (depth from shadows only)
- [ ] Light source is top-left everywhere
- [ ] Raised: dark shadow offset ~2x the light highlight offset
- [ ] Raised: both shadows use the same blur radius
- [ ] Inset: no outer drop shadows
- [ ] Inset on wide elements: four-edge shadow layers, not diagonal
- [ ] Nested raised-in-inset: softer shadows on the inner element
- [ ] Concentric corners: uniform gap between parent and child shapes
