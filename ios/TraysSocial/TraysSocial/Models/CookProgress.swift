import Foundation

/// W247: where Cook mode is in a recipe's steps. Pure, so the stepping rules
/// (clamping at both ends, Done on the last step, the segment fills) are
/// tested without a view.
struct CookProgress: Equatable {
    enum Segment: Equatable {
        case done
        case current
        case upcoming
    }

    let stepCount: Int
    private(set) var current: Int
    private(set) var isComplete: Bool

    init(stepCount: Int, current: Int = 0, isComplete: Bool = false) {
        self.stepCount = max(0, stepCount)
        self.current = min(max(0, current), max(0, stepCount - 1))
        self.isComplete = isComplete
    }

    var isFirstStep: Bool {
        current == 0
    }

    var isLastStep: Bool {
        current >= stepCount - 1
    }

    var canGoBack: Bool {
        !isComplete && current > 0
    }

    /// One-based step number for "Step N" and "N of M".
    var stepNumber: Int {
        stepCount == 0 ? 0 : current + 1
    }

    var segments: [Segment] {
        (0 ..< stepCount).map { index in
            if isComplete || index < current {
                return .done
            }
            return index == current ? .current : .upcoming
        }
    }

    /// Next on any step but the last; Done on the last finishes the recipe.
    mutating func advance() {
        guard !isComplete, stepCount > 0 else { return }
        if isLastStep {
            isComplete = true
        } else {
            current += 1
        }
    }

    /// A forward swipe moves to the next step but never finishes the recipe.
    mutating func swipeForward() {
        guard !isComplete, !isLastStep else { return }
        current += 1
    }

    mutating func goBack() {
        guard canGoBack else { return }
        current -= 1
    }
}
