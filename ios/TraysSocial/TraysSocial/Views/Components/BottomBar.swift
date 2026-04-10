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
                    .frame(width: 48, height: 48)
                    .background(Theme.accent)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .shadow(color: Theme.accent.opacity(0.25), radius: 8, y: 4)
            }

            Spacer()

            // Profile button
            Button(action: onProfileTap) {
                VStack(spacing: 3) {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if let url = profilePhotoURL, let imageURL = URL(string: url) {
                                AsyncImage(url: imageURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    Image(systemName: "person.fill")
                                        .foregroundStyle(.gray)
                                }
                                .frame(width: 32, height: 32)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.gray)
                            }
                        }

                    Text("Profile")
                        .font(.system(size: 10))
                        .foregroundStyle(Color(.systemGray))
                }
            }

            Spacer()
        }
        .padding(.vertical, 10)
        .background(Theme.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }
}
