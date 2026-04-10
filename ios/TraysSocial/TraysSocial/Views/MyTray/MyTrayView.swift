import SwiftUI

struct MyTrayView: View {
    @State private var viewModel = MyTrayViewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("\(viewModel.posts.count) recipes saved")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Spacer()

                // Grid/List toggle
                HStack(spacing: 4) {
                    Button { viewModel.showGrid = false } label: {
                        Image(systemName: "list.bullet")
                            .foregroundStyle(viewModel.showGrid ? .gray : .orange)
                            .padding(6)
                            .background(Color.white.opacity(viewModel.showGrid ? 0.04 : 0.08))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    Button { viewModel.showGrid = true } label: {
                        Image(systemName: "square.grid.2x2")
                            .foregroundStyle(viewModel.showGrid ? .orange : .gray)
                            .padding(6)
                            .background(Color.white.opacity(viewModel.showGrid ? 0.08 : 0.04))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if viewModel.showGrid {
                gridView
            } else {
                listView
            }
        }
        .overlay {
            if viewModel.isLoading && viewModel.posts.isEmpty {
                ProgressView().tint(Theme.accent)
            } else if viewModel.posts.isEmpty && !viewModel.isLoading {
                VStack(spacing: 8) {
                    Text("Your tray is empty")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Save recipes from the feed to find them here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .task {
            if viewModel.posts.isEmpty {
                await viewModel.load()
            }
        }
    }

    // MARK: - List View

    private var listView: some View {
        List {
            ForEach(Array(viewModel.posts.enumerated()), id: \.element.id) { index, post in
                HStack(spacing: 12) {
                    // Thumbnail
                    if let url = post.thumbURL {
                        AsyncImage(url: fullURL(url)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                        .frame(width: 80, height: 80)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    } else {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(Color(.systemGray5))
                            .frame(width: 80, height: 80)
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(post.caption ?? "Recipe")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)

                        HStack(spacing: 6) {
                            if let time = post.cookingTimeMinutes {
                                Text("\(time) min")
                                    .font(.caption)
                                    .foregroundStyle(Theme.accent)
                            }
                            if let servings = post.servings {
                                Text("|\(servings) servings")
                                    .font(.caption)
                                    .foregroundStyle(.gray)
                            }
                        }

                        Text("by \(post.user.username)")
                            .font(.caption)
                            .foregroundStyle(Color(.systemGray2))
                    }

                    Spacer()
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        viewModel.removeBookmark(at: index)
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                }
            }
        }
        .listStyle(.plain)
        .refreshable { await viewModel.refresh() }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 4) {
                ForEach(viewModel.posts) { post in
                    if let url = post.primaryPhotoURL {
                        AsyncImage(url: fullURL(url)) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                        .frame(height: 160)
                        .clipped()
                    } else {
                        Rectangle()
                            .fill(Color(.systemGray5))
                            .frame(height: 160)
                    }
                }
            }
            .padding(.horizontal, 2)
        }
        .refreshable { await viewModel.refresh() }
    }

    private func fullURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: Configuration.apiBaseURL + path)
    }
}
