import Foundation

/// W247: which ingredients the cook has ticked on recipe detail. Ticks live
/// only while the screen is open, like the web recipe page's, and are keyed
/// by row index because `Ingredient.id` is "name-quantity" and repeats when a
/// recipe lists the same ingredient twice.
struct IngredientTicks: Equatable {
    private(set) var ticked: Set<Int> = []

    var count: Int {
        ticked.count
    }

    func isTicked(_ index: Int) -> Bool {
        ticked.contains(index)
    }

    mutating func toggle(_ index: Int) {
        if ticked.contains(index) {
            ticked.remove(index)
        } else {
            ticked.insert(index)
        }
    }
}
