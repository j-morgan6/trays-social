import SwiftUI

// MARK: - Primitives

/// A shimmering rounded rectangle used as a loading placeholder.
/// One animation per shape (a single LinearGradient that translates), so a
/// screen full of skeletons stays cheap. All skeleton shapes are
/// .accessibilityHidden so VoiceOver doesn't announce each rectangle —
/// wrap a group in `.skeletonGroup(label:)` to announce the load state once.
struct SkeletonShape: View {
    var width: CGFloat?
    var height: CGFloat = 0
    var cornerRadius: CGFloat = 8
    /// When set, the shape sizes to this width:height aspect ratio and
    /// `height` is ignored — used for full-width photo blocks that must
    /// match an aspect-ratio'd real image (e.g. the 1:1 feed photo).
    var aspectRatio: CGFloat?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Theme.surface)
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(RoundedRectangle(cornerRadius: cornerRadius))
                .offset(x: phase * (width ?? 600))
            )

        Group {
            if let aspectRatio {
                shape.aspectRatio(aspectRatio, contentMode: .fit)
            } else {
                shape.frame(width: width, height: height)
            }
        }
        .clipped()
        .accessibilityHidden(true)
        .onAppear {
            // Reduce Motion: keep the placeholder static (no translating
            // highlight), per the app-flow Reduce Motion table.
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

/// A circular skeleton placeholder, sized to match avatar dimensions.
struct SkeletonCircle: View {
    var size: CGFloat

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        Circle()
            .fill(Theme.surface)
            .overlay(
                LinearGradient(
                    colors: [.clear, Color.white.opacity(0.18), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .mask(Circle())
                .offset(x: phase * size)
            )
            .frame(width: size, height: size)
            .accessibilityHidden(true)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Content-shaped composites

/// D93: matches the Pass 1 `FeedCardView` (W136): rounded 18pt card
/// chrome with a 30pt avi + handle row, square photo block, and a
/// short content row. Approximate proportions, not pixel-identical —
/// robust to FeedCardView tweaks.
struct SkeletonPostCard: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header: 30pt avi + handle + time
            HStack(spacing: 10) {
                SkeletonCircle(size: 30)
                SkeletonShape(width: 110, height: 11, cornerRadius: 3)
                Spacer(minLength: 8)
                SkeletonShape(width: 36, height: 10, cornerRadius: 3)
            }
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 10)

            // Square photo block — match FeedCardView's real photo,
            // which is aspectRatio(1, .fit) (a full-width 1:1 square),
            // so the card height doesn't snap when content loads.
            SkeletonShape(cornerRadius: 0, aspectRatio: 1)

            // Title + counts row
            VStack(alignment: .leading, spacing: 8) {
                SkeletonShape(height: 13, cornerRadius: 3)
                SkeletonShape(width: 160, height: 13, cornerRadius: 3)
                HStack(spacing: 14) {
                    SkeletonShape(width: 50, height: 11, cornerRadius: 3)
                    SkeletonShape(width: 50, height: 11, cornerRadius: 3)
                }
                .padding(.top, 4)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 18)
    }
}

/// D93: matches the Pass 1 `GridCard` (W134): 1:1.1 aspect, 14pt
/// corner radius, photo-shaped placeholder with a title bar at the
/// bottom under the scrim position. Pairs naturally with
/// `SkeletonSectionHeader` above for grid-led screens (MyTray,
/// Profile, Find).
struct SkeletonGridTile: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Fill the tile with the surface color + a translating
            // shimmer so it reads as one big photo placeholder.
            Theme.surface
            LinearGradient(
                colors: [.clear, Color.white.opacity(0.18), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .offset(x: phase * 200)

            VStack(alignment: .leading, spacing: 4) {
                SkeletonShape(height: 11, cornerRadius: 3)
                SkeletonShape(width: 80, height: 11, cornerRadius: 3)
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 12)
        }
        .aspectRatio(1.0 / 1.1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 0.5)
        )
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                phase = 1
            }
        }
    }
}

/// D93: matches the Pass 1 `ProfileBody` (W138 / D88): centered 84pt
/// avatar with border ring, 24pt bold name, amber @handle, centered
/// bio bars, and a 3-stat row. Replaces the pre-W127 header that put
/// stats inline with the name.
struct SkeletonProfileHeader: View {
    // Heights track Dynamic Type the way the real .system(size:) fonts
    // do, so the placeholder doesn't fall short of the content at large
    // text sizes (and reflow on swap).
    @ScaledMetric(relativeTo: .title) private var nameHeight: CGFloat = 24
    @ScaledMetric(relativeTo: .subheadline) private var handleHeight: CGFloat = 13
    @ScaledMetric(relativeTo: .title2) private var statNumberHeight: CGFloat = 22
    @ScaledMetric(relativeTo: .caption) private var statLabelHeight: CGFloat = 11

    var body: some View {
        VStack(spacing: 0) {
            SkeletonCircle(size: 84)
                .padding(.top, 14)
                .padding(.bottom, 14)

            // Name (24pt bold)
            SkeletonShape(width: 140, height: nameHeight, cornerRadius: 4)

            // @handle (13pt medium)
            SkeletonShape(width: 110, height: handleHeight, cornerRadius: 3)
                .padding(.top, 8)

            // Bio bars (centered)
            VStack(spacing: 6) {
                SkeletonShape(width: 240, height: 11, cornerRadius: 3)
                SkeletonShape(width: 180, height: 11, cornerRadius: 3)
            }
            .padding(.top, 12)

            // Stats triplet (22pt number / 11pt label)
            HStack(spacing: 22) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    VStack(spacing: 6) {
                        SkeletonShape(width: 28, height: statNumberHeight, cornerRadius: 4)
                        SkeletonShape(width: 52, height: statLabelHeight, cornerRadius: 3)
                    }
                }
            }
            .padding(.top, 18)

            // Action button (Follow / Edit) — full-width 44pt control
            // present on both own and other-user profiles, so the
            // header height matches once content loads.
            SkeletonShape(height: 44, cornerRadius: 14)
                .padding(.top, 18)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }
}

/// D93: shared row skeleton for actual list-shaped screens —
/// FollowListView (user rows) and BlockedUsersView (blocked-user
/// rows). NOT used for MyTray anymore (MyTray is now a grid; use
/// `SkeletonGridTile` + `SkeletonSectionHeader` there).
struct SkeletonListRow: View {
    /// Avatar diameter — defaults to FollowListView's 40pt. Pass the
    /// real row's avatar size so the placeholder matches (CommentRow is
    /// 28pt, BlockedUsersView is 36pt).
    var avatarSize: CGFloat = 40

    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: avatarSize)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape(width: 130, height: 12, cornerRadius: 3)
                SkeletonShape(width: 90, height: 10, cornerRadius: 3)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
}

/// D93 NEW: matches `SectionHeader` (an 11pt semibold uppercase
/// label with optional count chip). Use above grid skeletons on
/// screens that have `SectionHeader`-led sections (MyTray, Profile).
struct SkeletonSectionHeader: View {
    /// Mirror `SectionHeader.Style`. `.compact` is the 11pt uppercase
    /// label; `.editorial` is the 22pt centered label MyTray uses, so
    /// the skeleton header reads at the same scale as the loaded one.
    enum Style { case compact, editorial }
    var style: Style = .compact

    /// Editorial header is a 22pt .system font that scales with Dynamic
    /// Type, so the placeholder height tracks it.
    @ScaledMetric(relativeTo: .title2) private var editorialHeight: CGFloat = 22

    var body: some View {
        switch style {
        case .compact:
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                SkeletonShape(width: 80, height: 11, cornerRadius: 3)
                SkeletonShape(width: 18, height: 11, cornerRadius: 3)
                Spacer()
            }
            .padding(.horizontal, 20)
        case .editorial:
            SkeletonShape(width: 120, height: editorialHeight, cornerRadius: 4)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.horizontal, 20)
        }
    }
}

/// D93: matches `RecipeHero` + the metadata strip + first sections
/// in `RecipeBodySection`. Used as the load surface for
/// `PostDetailView`.
struct SkeletonPostDetail: View {
    // Track Dynamic Type so the placeholder keeps matching the real
    // (scaling) cook's-note and section-header type at large sizes.
    @ScaledMetric(relativeTo: .body) private var noteLineHeight: CGFloat = 17
    @ScaledMetric(relativeTo: .title2) private var ingredientsHeaderHeight: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero photo block — full-width, 360pt to match RecipeHero
            SkeletonShape(height: 360, cornerRadius: 0)

            VStack(alignment: .leading, spacing: 12) {
                // Byline: 36pt avatar + handle + time
                HStack(spacing: 10) {
                    SkeletonCircle(size: 36)
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonShape(width: 100, height: 12, cornerRadius: 3)
                        SkeletonShape(width: 60, height: 10, cornerRadius: 3)
                    }
                    Spacer()
                }

                // Metadata strip (Time / Serves / Ingredients)
                HStack(alignment: .top, spacing: 24) {
                    ForEach(0 ..< 3, id: \.self) { _ in
                        VStack(alignment: .leading, spacing: 4) {
                            SkeletonShape(width: 36, height: 9, cornerRadius: 3)
                            SkeletonShape(width: 52, height: 16, cornerRadius: 4)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.vertical, 6)

                // Cook's-note pull quote (17pt italic)
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(height: noteLineHeight, cornerRadius: 3)
                    SkeletonShape(height: noteLineHeight, cornerRadius: 3)
                    SkeletonShape(width: 200, height: noteLineHeight, cornerRadius: 3)
                }
                .padding(.top, 4)

                // Ingredients section header (22pt bold) + rows
                SkeletonShape(width: 110, height: ingredientsHeaderHeight, cornerRadius: 4)
                    .padding(.top, 10)
                ForEach(0 ..< 4, id: \.self) { _ in
                    SkeletonShape(height: 12, cornerRadius: 3)
                }
            }
            .padding(.horizontal, 20)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Presentation wrapper

/// Wraps a skeleton cluster at a loading->content swap site so the load
/// state (a) fades in/out instead of snapping, and (b) does not flash a
/// single frame on instant (cached) loads — it only becomes visible
/// after a short delay, so a sub-180ms fetch shows no skeleton at all.
///
/// Removal is animated by the parent: put
/// `.animation(.easeInOut(duration: 0.18), value: <loadingFlag>)` on the
/// container that owns the `if <loadingFlag> { SkeletonFade { … } }`
/// branch so the `.transition(.opacity)` here fires on the way out.
///
/// Honors Reduce Motion: the fade-in is skipped (instant show) while the
/// shimmer itself is already disabled in the primitives.
struct SkeletonFade<Content: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ViewBuilder var content: () -> Content
    @State private var shown = false

    var body: some View {
        content()
            .opacity(shown ? 1 : 0)
            // Asymmetric so the two opacity drivers don't fight: insertion
            // is handled solely by the debounced `shown` fade below
            // (identity here), removal by the parent's
            // `.animation(value:)` driving this opacity transition.
            .transition(.asymmetric(insertion: .identity, removal: .opacity))
            .task {
                // Debounce: a fast-cached load finishes inside this window
                // and the branch is removed before `shown` ever flips, so
                // no skeleton frame is shown.
                try? await Task.sleep(for: .milliseconds(180))
                guard !Task.isCancelled else { return }
                if reduceMotion {
                    shown = true
                } else {
                    withAnimation(.easeInOut(duration: 0.18)) { shown = true }
                }
            }
    }
}

// MARK: - Group helpers

extension View {
    /// Wrap a cluster of skeletons so VoiceOver announces "Loading <thing>"
    /// once instead of stepping through each invisible rectangle.
    func skeletonGroup(label: String) -> some View {
        accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityAddTraits(.updatesFrequently)
    }
}
