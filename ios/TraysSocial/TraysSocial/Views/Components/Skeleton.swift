import SwiftUI

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

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // W239: one big lift block for the photo, pulsing as a unit.
            Theme.lift
                .skeletonPulse()

            VStack(alignment: .leading, spacing: 4) {
                SkeletonShape(height: 11, cornerRadius: 3, fill: Theme.surface.opacity(0.7))
                SkeletonShape(width: 80, height: 11, cornerRadius: 3, fill: Theme.surface.opacity(0.7))
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
    /// Mirror `SectionHeader.Style`. `.compact` is the 20pt rounded
    /// heading; `.editorial` is the 22pt centered label MyTray uses, so
    /// the skeleton header reads at the same scale as the loaded one.
    enum Style { case compact, editorial }
    var style: Style = .compact

    /// Editorial header is a 22pt .system font that scales with Dynamic
    /// Type, so the placeholder height tracks it.
    @ScaledMetric(relativeTo: .title2) private var editorialHeight: CGFloat = 22
    /// W239: the compact header is a 20pt rounded heading, so its bar is 16.
    @ScaledMetric(relativeTo: .title3) private var compactHeight: CGFloat = 16

    var body: some View {
        switch style {
        case .compact:
            HStack {
                SkeletonShape(width: 120, height: compactHeight, cornerRadius: 6)
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
