import SwiftUI

struct BottomBar: View {
    var onCreateTap: () -> Void
    var onProfileTap: () -> Void
    var profilePhotoURL: String?

    var body: some View {
        HStack {
            Spacer()

            // Create button
            Button(action: onCreateTap) {
                Image(systemName: "plus")
                    .font(.title2.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(Theme.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Theme.primary.opacity(0.25), radius: 8, y: 4)
            }

            Spacer()

            // Profile button
            Button(action: onProfileTap) {
                Circle()
                    .fill(Color(.systemGray4))
                    .frame(width: 28, height: 28)
                    .overlay {
                        if let url = profilePhotoURL, let imageURL = url.asBackendURL {
                            AsyncImage(url: imageURL) { image in
                                image.resizable().scaledToFill()
                            } placeholder: {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.gray)
                            }
                            .frame(width: 28, height: 28)
                            .clipShape(Circle())
                        } else {
                            Image(systemName: "person.fill")
                                .foregroundStyle(.gray)
                        }
                    }
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.surface)
                .frame(height: 1)
        }
    }
}
