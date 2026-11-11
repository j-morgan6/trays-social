import SwiftUI

/// W239: a recipe photo slot. Shows the cream (light) or lift (dark)
/// placeholder until the image loads, so a missing photo still reads as a
/// deliberate block. Callers set the frame or aspect ratio and pass a URL
/// already resolved with `.asBackendURL`.
struct PhotoSlot: View {
    let url: URL?
    var cornerRadius: CGFloat = 15

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        Theme.creamOrLift
            .overlay {
                if let url {
                    CachedAsyncImage(url: url) { image in
                        Color.clear.overlay {
                            image.resizable().scaledToFill()
                        }
                        .clipped()
                    } placeholder: {
                        Color.clear
                    }
                    .id(url)
                }
            }
            .clipShape(shape)
            .accessibilityHidden(true)
    }
}

/// W239: a round avatar slot with the same placeholder rule as `PhotoSlot`.
struct AvatarSlot: View {
    let url: URL?
    var size: CGFloat = 22

    var body: some View {
        Theme.creamOrLift
            .overlay {
                if let url {
                    CachedAsyncImage(url: url) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Color.clear
                    }
                    .id(url)
                }
            }
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
            .accessibilityHidden(true)
    }
}

#Preview("ImageSlots · light") {
    HStack(spacing: 16) {
        PhotoSlot(url: nil).frame(width: 120, height: 90)
        AvatarSlot(url: nil, size: 44)
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.light)
}

#Preview("ImageSlots · dark") {
    HStack(spacing: 16) {
        PhotoSlot(url: nil).frame(width: 120, height: 90)
        AvatarSlot(url: nil, size: 44)
    }
    .padding()
    .background(Theme.background)
    .preferredColorScheme(.dark)
}

#Preview("ImageSlots · largest text") {
    HStack(spacing: 16) {
        PhotoSlot(url: nil).frame(width: 120, height: 90)
        AvatarSlot(url: nil, size: 44)
    }
    .padding()
    .background(Theme.background)
    .dynamicTypeSize(.accessibility5)
}
