import SwiftUI

/// Recipes / What I have segmented switch shared by Find (today) and the
/// recipe-first Search tab.
struct SearchModeSwitch: View {
    @Binding var mode: SearchMode

    var body: some View {
        Picker("Search mode", selection: $mode) {
            Text("Recipes").tag(SearchMode.recipes)
            Text("What I have").tag(SearchMode.whatIHave)
        }
        .pickerStyle(.segmented)
    }
}
