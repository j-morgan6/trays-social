import SwiftUI

@MainActor
@Observable
final class ShellViewModel {
    private(set) var pillsHidden: Bool = false

    func hidePills() {
        pillsHidden = true
    }

    func showPills() {
        pillsHidden = false
    }
}
