import SwiftUI

/// In-app feedback form (W125 / G27). Opened as a sheet from the
/// Settings list, visible to every authenticated user (NOT gated on
/// is_admin). Subject + body fields; submit POSTs to
/// `/api/v1/feedback` with the user's app/OS/device metadata.
///
/// Mirrors `ReportSheetView`'s confirmation pattern: success shows a
/// 1.5s checkmark overlay then dismisses; failure keeps the sheet
/// open with an inline error message and preserves what the user
/// typed (per the W125 pitfall).
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var subject = ""
    @State private var feedbackBody = ""
    @State private var isSubmitting = false
    @State private var submitted = false
    @State private var errorMessage: String?

    private let bodyCharLimit = 5000
    private let subjectCharLimit = 200

    private var trimmedBody: String {
        feedbackBody.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmit: Bool {
        !trimmedBody.isEmpty &&
            feedbackBody.count <= bodyCharLimit &&
            subject.count <= subjectCharLimit &&
            !isSubmitting
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Subject (optional)") {
                    TextField("Short subject", text: $subject)
                        .textInputAutocapitalization(.sentences)
                }

                Section("What's working or not working?") {
                    TextField(
                        "Tell us anything — bugs, ideas, things you like or don't.",
                        text: $feedbackBody,
                        axis: .vertical
                    )
                    .lineLimit(6 ... 14)
                    .textInputAutocapitalization(.sentences)

                    Text("\(feedbackBody.count) / \(bodyCharLimit)")
                        .font(.caption2)
                        .foregroundStyle(feedbackBody.count > bodyCharLimit ? .red : .secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                if let errorMessage {
                    Section {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Send Feedback")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSubmitting)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSubmitting {
                        ProgressView().tint(Theme.accent)
                    } else {
                        Button("Submit") {
                            Task { await submit() }
                        }
                        .disabled(!canSubmit)
                    }
                }
            }
            .overlay {
                if submitted {
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(Theme.primary)
                        Text("Thanks — we'll read it")
                            .font(.headline)
                            .foregroundStyle(Theme.text)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.background)
                }
            }
        }
    }

    private func submit() async {
        isSubmitting = true
        errorMessage = nil

        do {
            try await APIClient.shared.submitFeedback(
                subject: subject.isEmpty ? nil : subject,
                body: trimmedBody
            )
            submitted = true
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        } catch {
            // Preserve subject/body so the user can retry without
            // re-typing — the W125 pitfall is explicit about this.
            errorMessage = ErrorReporter.userMessage(for: error, fallback: "Couldn't send your feedback. Please try again.")
        }

        isSubmitting = false
    }
}
