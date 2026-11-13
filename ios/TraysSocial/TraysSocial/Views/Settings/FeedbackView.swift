import SwiftUI

/// In-app feedback form (W125 / G27), restyled for the redesign in W263.
/// Opened as a sheet from Settings and from the verify-email gate; visible
/// to every signed-in user, confirmed or not (NOT gated on is_admin).
///
/// A Bug / Feedback choice, an optional subject and the message, then an
/// amber Send button. `FeedbackForm` builds the request: the kind, the app
/// version, build, OS and device model, and the screen the sheet was opened
/// from. Success shows a checkmark for 1.5s and dismisses; a failure keeps
/// the sheet open with an inline message and keeps everything typed (the
/// W125 pitfall). Never a toast: this is the write path's own inline error.
struct FeedbackView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var form: FeedbackForm

    private enum Field: Hashable {
        case subject
        case body
    }

    @FocusState private var focusedField: Field?

    init(entryPoint: FeedbackEntryPoint) {
        _form = State(initialValue: FeedbackForm(entryPoint: entryPoint))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("We include your app version, build, iOS version and device model with your message.")
                        .scaledFont(14.5, relativeTo: .subheadline)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    kindPicker
                    subjectField
                    bodyField

                    if let message = form.errorMessage {
                        AuthCallout(message: message)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) { sendBar }
            .navigationTitle(form.kind == .bug ? String(localized: "Report a bug") : String(localized: "Send feedback"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(form.isSending)
                }
            }
            .overlay {
                if form.isSent {
                    sentConfirmation
                }
            }
        }
        .interactiveDismissDisabled(form.isSending)
        // Editing after a failure clears the message; the text stays.
        .onChange(of: form.subject) { form.clearError() }
        .onChange(of: form.body) { form.clearError() }
        .onChange(of: form.kind) { form.clearError() }
    }

    private var kindPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(text: String(localized: "Type"))
            SegmentedPills(
                options: [
                    .init(value: FeedbackKind.bug, title: String(localized: "Bug")),
                    .init(value: FeedbackKind.feedback, title: String(localized: "Feedback")),
                ],
                selection: $form.kind
            )
            .disabled(form.isSending)
        }
    }

    private var subjectField: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(text: String(localized: "Subject"), isOptional: true)
            TextField("Subject", text: $form.subject, prompt: Text("Short subject").foregroundStyle(Theme.muted))
                .scaledFont(16, relativeTo: .body)
                .textInputAutocapitalization(.sentences)
                .submitLabel(.next)
                .focused($focusedField, equals: .subject)
                .onSubmit { focusedField = .body }
                .trayField(isFocused: focusedField == .subject, needsAttention: form.subjectIsOverLimit)
                .disabled(form.isSending)
            if form.subjectIsOverLimit {
                EditorAttentionNote(message: String(localized: "Keep the subject to 200 characters."))
            }
        }
    }

    private var bodyField: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(text: form.kind == .bug
                ? String(localized: "What happened?")
                : String(localized: "What's on your mind?"))
            TextField(
                form.kind == .bug ? String(localized: "What happened?") : String(localized: "What's on your mind?"),
                text: $form.body,
                prompt: Text("Tell us anything — bugs, ideas, things you like or don't.").foregroundStyle(Theme.muted),
                axis: .vertical
            )
            .scaledFont(16, relativeTo: .body)
            .lineLimit(6 ... 14)
            .textInputAutocapitalization(.sentences)
            .focused($focusedField, equals: .body)
            .padding(.vertical, 12)
            .trayField(
                isFocused: focusedField == .body,
                needsAttention: form.bodyIsOverLimit,
                alignment: .topLeading
            )
            .disabled(form.isSending)

            Text("\(form.bodyCount) / \(FeedbackForm.bodyLimit)")
                .scaledFont(13, relativeTo: .footnote)
                .monospacedDigit()
                .foregroundStyle(form.bodyIsOverLimit ? Theme.text : Theme.muted)
                .frame(maxWidth: .infinity, alignment: .trailing)

            if form.bodyIsOverLimit {
                EditorAttentionNote(message: String(localized: "Keep it to 5,000 characters."))
            }
        }
    }

    /// Pinned under the scroll view so Send stays visible above the keyboard
    /// and at the largest text sizes.
    private var sendBar: some View {
        Button {
            focusedField = nil
            Task { await send() }
        } label: {
            HStack(spacing: 10) {
                if form.isSending {
                    ProgressView().tint(Theme.inkOnAccent)
                }
                Text(form.isSending ? String(localized: "Sending...") : String(localized: "Send"))
            }
        }
        .buttonStyle(AccentButtonStyle(fillsWidth: true, dimsWhenDisabled: !form.isSending))
        .disabled(!form.canSubmit)
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Theme.background)
    }

    private var sentConfirmation: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundStyle(Theme.primary)
                .accessibilityHidden(true)
            Text("Thanks — we'll read it")
                .roundedFont(17, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Theme.text)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private func send() async {
        await form.submit()
        if form.isSent {
            try? await Task.sleep(for: .seconds(1.5))
            dismiss()
        }
    }
}

#Preview("Feedback · light") {
    FeedbackView(entryPoint: .settings)
        .preferredColorScheme(.light)
}

#Preview("Feedback · dark") {
    FeedbackView(entryPoint: .verifyEmail)
        .preferredColorScheme(.dark)
}

#Preview("Feedback · largest text") {
    FeedbackView(entryPoint: .settings)
        .dynamicTypeSize(.accessibility5)
}
