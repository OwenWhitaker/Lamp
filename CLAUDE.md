# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Lamp is a native iOS scripture memorization app built with SwiftUI and SwiftData. It uses a neumorphic (soft UI) design system throughout. No third-party dependencies — only Apple frameworks.

- **Target:** iOS 17+
- **Language:** Swift 5.9+
- **Persistence:** SwiftData (`@Model`, `@Query`, `ModelContainer`)

## Build Commands

```bash
# Build
xcodebuild build -scheme Lamp -configuration Debug

# Build for simulator
xcodebuild build -scheme Lamp -destination 'platform=iOS Simulator,name=iPhone 16'
```

There are no tests or linting configured in this project currently. Development is done primarily through Xcode with SwiftUI previews.

## Architecture

**Pattern:** Direct SwiftUI state management (no separate ViewModel layer). Views use `@State`, `@Query`, `@Environment(\.modelContext)`, and `@Bindable` directly.

**Data models** (`Lamp/Models/`):
- `Pack` — a collection of verses (title, createdAt, verses relationship)
- `Verse` — a single scripture verse (reference, text, order, memoryHealth, lastReviewed)
- Relationship: Pack → Verses is one-to-many with cascade delete

**Entry point:** `LampApp.swift` initializes a SwiftData `ModelContainer` with both models and injects it into the view hierarchy.

**Navigation:** `ContentView.swift` implements a custom `NeuTabBar` with three tabs (My Packs, Search, Settings). Uses `NavigationStack` with `NavigationPath` for drill-down navigation.

**Views** (`Lamp/Views/`):
- `PacksView` — grid of pack cards on the home tab
- `PackDetailView` — verse list with swipe-to-delete/edit, floating header/footer
- `VerseView` — single verse detail with reveal animation
- `FlashcardView` / `MemorizationView` — study modes
- `AddPackView` / `AddVerseView` / `EditVerseView` — modal forms presented as sheets

## Neumorphic Design System

The app uses a custom neumorphic design system documented in `Lamp/NeuDesignGuide.md`. **Read this file before making any UI changes.** Key rules:

- **Background color:** `Color(red: 225/255, green: 225/255, blue: 235/255)` (neuBg) — everything fills this color
- **Depth from shadows only** — no borders, strokes, or color fills that differ from neuBg
- **Light source is top-left** — all shadows are consistent with this
- **Raised surfaces** (`NeuRaised<S: Shape>`): dark shadow offset is 2x the light highlight offset, same blur radius for both
- **Inset surfaces** (`NeuInset<S: Shape>`): use blurred strokes with gradient masks (four-edge technique for wide elements)
- **Shadows are monochromatic** — never use colored shadows

Reusable neumorphic components are defined inline in `ContentView.swift`: `NeuRaised`, `NeuInset`, `NeuTabBar`, `NeuCircleButton`, `NeuSwipeActionCircle`, `NeuVerseCard`, `NeuProgressRing`, `NeuPackCard`.

## Conventions

- Every view includes a `#Preview` block with an in-memory `ModelContainer` for Xcode canvas previews
- `// MARK:` comments are used extensively to organize sections within view files
- Generic shape parameters (`<S: Shape>`) are used for reusable neumorphic primitives
- Private extensions on `Color` and `LinearGradient` provide design system tokens
- Git branches: `feature/` for features, `ui/` for UI work, `experiment/` for experiments
