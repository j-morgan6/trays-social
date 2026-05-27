@testable import TraysSocial
import XCTest

@MainActor
final class ShellViewModelTests: XCTestCase {
    func test_pillsHiddenDefaultsToFalse() {
        let vm = ShellViewModel()
        XCTAssertFalse(vm.pillsHidden)
    }

    func test_hidePillsSetsTrue() {
        let vm = ShellViewModel()
        vm.hidePills()
        XCTAssertTrue(vm.pillsHidden)
    }

    func test_showPillsSetsFalse() {
        let vm = ShellViewModel()
        vm.hidePills()
        vm.showPills()
        XCTAssertFalse(vm.pillsHidden)
    }
}
