import SwiftUI

struct ReportSheetView: View {
    let targetType: String // "post", "comment", "user", or "ad"
    let targetId: Int
    /// W158: machine-readable ad slot context ("placement=feed slot=0").
    /// Prepended to the submitted details so an ad report identifies the
    /// slot even when the user types nothing. Defaulted so the existing
    /// post/comment/user call sites are unaffected.
    var adContext: String? = nil
    @Environment(\.dismiss) private var dismiss

    @State private var reason = "spam"
    @State private var details = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    /// First element is the API value (sent to the server, never localized);
    /// second is the display label, a LocalizedStringKey so the menu shows the
    /// translated reason while the wire value stays stable.
    private let reasons: [(String, LocalizedStringKey)] = [
        ("spam", "Spam"),
        ("off_topic", "Off Topic"),
        ("harassment", "Harassment"),
        ("inappropriate", "Inappropriate"),
        ("other", "Other"),
    ]

    /// Discrete keys per target type rather than interpolating the capitalized
    /// English word into the title (which would not translate).
    private var navigationTitleText: LocalizedStringKey {
        switch targetType {
        case "comment": "Report Comment"
        case "user": "Report User"
        case "ad": "Report Ad"
        default: "Report Post"
        }
    }

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
            .navigationTitle(navigationTitleText)
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
            // W158: ad reports carry the slot context ahead of whatever
            // the user typed, so the slot is identifiable server-side.
            var submittedDetails = details
            if let adContext {
                submittedDetails = adContext + "\n" + details
            }
            // Server enforces validate_length(:details, max: 1000); the ad
            // context prefix must never push a valid comment over the cap.
            submittedDetails = String(submittedDetails.prefix(1000))
            let body = ReportRequest(targetType: targetType, targetId: targetId, reason: reason, details: submittedDetails)
            let _: MessageResponse = try await APIClient.shared.post(path: "/reports", body: body)
            submitted = true
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            errorMessage = String(localized: "Failed to submit report. Please try again.")
        }

        isSubmitting = false
    }
}
