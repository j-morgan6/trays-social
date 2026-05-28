import SwiftUI

// MARK: - Primitives

/// A shimmering rounded rectangle used as a loading placeholder.
/// One animation per shape (a single LinearGradient that translates), so a
/// screen full of skeletons stays cheap. All skeleton shapes are
/// .accessibilityHidden so VoiceOver doesn't announce each rectangle —
/// wrap a group in `.skeletonGroup(label:)` to announce the load state once.
struct SkeletonShape: View {
    var width: CGFloat?
    var height: CGFloat
    var cornerRadius: CGFloat = 8

    @State private var phase: CGFloat = -1

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
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
            .frame(width: width, height: height)
            .clipped()
            .accessibilityHidden(true)
            .onAppear {
                withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

/// A circular skeleton placeholder, sized to match avatar dimensions.
struct SkeletonCircle: View {
    var size: CGFloat

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

            // Square photo block
            SkeletonShape(height: 240, cornerRadius: 0)

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
    var body: some View {
        VStack(spacing: 0) {
            SkeletonCircle(size: 84)
                .padding(.top, 14)
                .padding(.bottom, 14)

            // Name (24pt bold)
            SkeletonShape(width: 140, height: 22, cornerRadius: 4)

            // @handle
            SkeletonShape(width: 110, height: 11, cornerRadius: 3)
                .padding(.top, 8)

            // Bio bars (centered)
            VStack(spacing: 6) {
                SkeletonShape(width: 240, height: 11, cornerRadius: 3)
                SkeletonShape(width: 180, height: 11, cornerRadius: 3)
            }
            .padding(.top, 12)

            // Stats triplet
            HStack(spacing: 22) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    VStack(spacing: 6) {
                        SkeletonShape(width: 28, height: 18, cornerRadius: 4)
                        SkeletonShape(width: 52, height: 9, cornerRadius: 3)
                    }
                }
            }
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
    var body: some View {
        HStack(spacing: 12) {
            SkeletonCircle(size: 40)
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
    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            SkeletonShape(width: 80, height: 11, cornerRadius: 3)
            SkeletonShape(width: 18, height: 11, cornerRadius: 3)
            Spacer()
        }
        .padding(.horizontal, 20)
    }
}

/// D93: matches `RecipeHero` + the metadata strip + first sections
/// in `RecipeBodySection`. Used as the load surface for
/// `PostDetailView`.
struct SkeletonPostDetail: View {
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

                // Cook's-note pull quote
                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(height: 13, cornerRadius: 3)
                    SkeletonShape(height: 13, cornerRadius: 3)
                    SkeletonShape(width: 200, height: 13, cornerRadius: 3)
                }
                .padding(.top, 4)

                // Ingredients section header + rows
                SkeletonShape(width: 110, height: 16, cornerRadius: 4)
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
