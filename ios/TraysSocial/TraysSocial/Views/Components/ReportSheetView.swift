import SwiftUI

struct ReportSheetView: View {
    let targetType: String // "post", "comment", or "user"
    let targetId: Int
    @Environment(\.dismiss) private var dismiss

    @State private var reason = "spam"
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    private let reasons = [
        ("spam", "Spam"),
        ("off_topic", "Off Topic"),
        ("harassment", "Harassment"),
        ("inappropriate", "Inappropriate"),
        ("other", "Other"),
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("What's the issue?") {
                    Picker("Reason", selection: $reason) {
                        ForEach(reasons, id: \.0) { value, label in
                            Text(label).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Additional details (optional)") {
                    TextField("Tell us more...", text: $details, axis: .vertical)
                        .lineLimit(3 ... 6)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Report \(targetType.capitalized)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView().tint(Theme.accent)
                    } else {
                        Button("Submit") {
                            Task { await submitReport() }
                        }
                    }
                }
            }
            .overlay {
                if submitted {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.primary)
                        Text("Report Submitted")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                        Text("We'll review this and take action if needed.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
                }
            }
        }
    }

    // MARK: - Submit

    private struct ReportRequest: Encodable {
        let targetType: String
        let targetId: Int
        let reason: String
        let details: String
    }

    private func submitReport() async {
        isSubmitting = true
        errorMessage = nil

        do {
            let body = ReportRequest(targetType: targetType, targetId: targetId, reason: reason, details: details)
            let _: MessageResponse = try await APIClient.shared.post(path: "/reports", body: body)
            submitted = true
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            errorMessage = "Failed to submit report. Please try again."
        }

        isSubmitting = false
    }
}
