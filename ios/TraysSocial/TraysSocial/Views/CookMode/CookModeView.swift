import SwiftUI

/// Cook mode: one step at a time, full screen, with the screen kept awake.
///
/// W247: restyled to the Recipe artboard — progress segments, the step on a
/// scrollable page, Back and an amber Next. The stepping rules live in
/// `CookProgress`. W141 removed the per-step timer and D16 keeps it out, so
/// the unused timer code is gone.
struct CookModeView: View {
    let steps: [CookingStep]
    let title: String
    /// The recipe's servings, for the "Title · serves N" line; nil hides it.
    var servings: Int?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// W158: last-step "Done" lands on a completion screen (with an
    /// optional sponsored card) instead of dismissing immediately.
    @State private var progress: CookProgress

    init(steps: [CookingStep], title: String, servings: Int? = nil, progress: CookProgress? = nil) {
        self.steps = steps
        self.title = title
        self.servings = servings
        _progress = State(initialValue: progress ?? CookProgress(stepCount: steps.count))
    }

    var body: some View {
        VStack(spacing: 18) {
            CookModeHeader(
                progressLabel: String(localized: "Step \(progress.stepNumber) of \(progress.stepCount)"),
                onClose: { dismiss() }
            )
            .padding(.horizontal, 22)

            CookProgressSegments(segments: progress.segments, reduceMotion: reduceMotion)
                .padding(.horizontal, 22)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(Text("Step \(progress.stepNumber) of \(progress.stepCount)"))

            if progress.isComplete {
                // W158: completion screen — replaces step content and the
                // nav buttons once the last step's Done is tapped.
                Spacer()
                CookCompletionContent()
                Spacer()
                Button { dismiss() } label: {
                    Text("Done")
                }
                .buttonStyle(PrimaryButtonStyle(fillsWidth: true))
                .padding(.horizontal, 22)
                .padding(.bottom, 34)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Food-safety disclaimer — shown only on step 1 so it
                        // greets the user when they begin cooking but does not
                        // clutter later steps. Wording matches Terms of
                        // Service §10 verbatim.
                        if progress.isFirstStep {
                            FoodSafetyNote()
                        }
                        if progress.current < steps.count {
                            CookStepContent(
                                recipeLine: CookModeCopy.recipeLine(title: title, servings: servings),
                                instruction: steps[progress.current].instruction
                            )
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.vertical, 4)
                    .containerRelativeFrame(.horizontal, alignment: .leading)
                }

                CookModeNavButtons(
                    canGoBack: progress.canGoBack,
                    isLastStep: progress.isLastStep,
                    onBack: { step { $0.goBack() } },
                    onNext: { step { $0.advance() } }
                )
                .padding(.horizontal, 22)
                .padding(.bottom, 34)
            }
        }
        .padding(.top, 16)
        .background(Theme.cookBackground)
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false
        }
        .gesture(
            DragGesture(minimumDistance: 50)
                .onEnded { value in
                    // W158: step swiping is disabled on the completion screen
                    // (CookProgress ignores both moves once complete).
                    if value.translation.width < -50 {
                        step { $0.swipeForward() }
                    } else if value.translation.width > 50 {
                        step { $0.goBack() }
                    }
                }
        )
    }

    /// Applies a step change, animated unless Reduce Motion is on.
    private func step(_ change: (inout CookProgress) -> Void) {
        if reduceMotion {
            change(&progress)
        } else {
            withAnimation(.easeInOut(duration: 0.25)) { change(&progress) }
        }
    }
}
