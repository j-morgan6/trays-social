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

/// Loading placeholder mirroring `PostCardView`'s layout: avatar + username,
/// image, caption lines, action row. Approximate proportions, not
/// pixel-identical — robust to PostCardView changes.
struct SkeletonPostCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                SkeletonCircle(size: 32)
                SkeletonShape(width: 140, height: 12, cornerRadius: 4)
                Spacer()
            }
            SkeletonShape(height: 220, cornerRadius: 12)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape(height: 12, cornerRadius: 4)
                SkeletonShape(width: 220, height: 12, cornerRadius: 4)
            }
            HStack(spacing: 14) {
                SkeletonShape(width: 56, height: 16, cornerRadius: 4)
                SkeletonShape(width: 56, height: 16, cornerRadius: 4)
                Spacer()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
    }
}

/// Loading placeholder for a 2-column explore/find grid tile.
struct SkeletonGridTile: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            SkeletonShape(height: 120, cornerRadius: 10)
            SkeletonShape(height: 11, cornerRadius: 3)
            SkeletonShape(width: 60, height: 10, cornerRadius: 3)
        }
    }
}

/// Profile header skeleton — avatar, name, bio rows, stats row.
struct SkeletonProfileHeader: View {
    var body: some View {
        VStack(spacing: 20) {
            VStack(spacing: 10) {
                SkeletonCircle(size: 80)
                SkeletonShape(width: 140, height: 18, cornerRadius: 4)
                SkeletonShape(width: 220, height: 11, cornerRadius: 3)
            }
            HStack(spacing: 16) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    VStack(spacing: 6) {
                        SkeletonShape(width: 36, height: 18, cornerRadius: 4)
                        SkeletonShape(width: 52, height: 10, cornerRadius: 3)
                    }
                }
            }
        }
        .padding(.top, 20)
    }
}

/// MyTray-style skeleton: thumbnail + 3 text lines.
struct SkeletonListRow: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonShape(width: 80, height: 80, cornerRadius: 10)
            VStack(alignment: .leading, spacing: 6) {
                SkeletonShape(height: 14, cornerRadius: 4)
                SkeletonShape(width: 120, height: 10, cornerRadius: 3)
                SkeletonShape(width: 80, height: 10, cornerRadius: 3)
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

/// Loading placeholder for `PostDetailView` — composes existing
/// `SkeletonShape` / `SkeletonCircle` primitives to approximate the
/// recipe-hero photo, byline strip, meta row, body text block, and
/// ingredient list. Approximate proportions, not pixel-identical, so
/// PostDetailView visual edits don't have to drag this with them.
struct SkeletonPostDetail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            SkeletonShape(height: 320, cornerRadius: 0)

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    SkeletonCircle(size: 32)
                    SkeletonShape(width: 120, height: 12, cornerRadius: 4)
                    Spacer()
                }

                HStack(spacing: 14) {
                    SkeletonShape(width: 64, height: 12, cornerRadius: 4)
                    SkeletonShape(width: 64, height: 12, cornerRadius: 4)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 8) {
                    SkeletonShape(height: 13, cornerRadius: 4)
                    SkeletonShape(height: 13, cornerRadius: 4)
                    SkeletonShape(width: 220, height: 13, cornerRadius: 4)
                }
                .padding(.top, 6)

                VStack(alignment: .leading, spacing: 6) {
                    SkeletonShape(width: 80, height: 11, cornerRadius: 3)
                    ForEach(0 ..< 4, id: \.self) { _ in
                        SkeletonShape(height: 14, cornerRadius: 4)
                    }
                }
                .padding(.top, 10)
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
