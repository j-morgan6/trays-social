import SwiftUI

struct MutedKeywordsView: View {
    @State private var keywords: [String] = []
    @State private var newKeyword = ""
    @State private var isLoading = true

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("Add keyword", text: $newKeyword)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()

                    Button("Add") {
                        let trimmed = newKeyword.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmed.isEmpty, !keywords.contains(trimmed.lowercased()) else { return }
                        keywords.append(trimmed.lowercased())
                        newKeyword = ""
                        Task { await saveKeywords() }
                    }
                    .disabled(newKeyword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            Section("Active Keywords") {
                ForEach(keywords, id: \.self) { keyword in
                    HStack {
                        Text(keyword)
                            .foregroundStyle(Theme.text)
                        Spacer()
                        Button {
                            keywords.removeAll { $0 == keyword }
                            Task { await saveKeywords() }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .navigationTitle("Muted Keywords")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView().tint(Theme.accent)
            }
        }
        .task { await loadKeywords() }
    }

    private func loadKeywords() async {
        do {
            let response: DataResponse<MutedKeywordsResponse> = try await APIClient.shared.get(path: "/muted-keywords")
            keywords = response.data.mutedKeywords
        } catch {}
        isLoading = false
    }

    private func saveKeywords() async {
        struct KeywordsRequest: Encodable {
            let keywords: [String]
        }
        do {
            let _: DataResponse<MutedKeywordsResponse> = try await APIClient.shared.put(
                path: "/muted-keywords",
                body: KeywordsRequest(keywords: keywords)
            )
        } catch {}
    }
}

struct MutedKeywordsResponse: Codable {
    let mutedKeywords: [String]
}
