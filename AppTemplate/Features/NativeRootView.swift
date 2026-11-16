import SwiftUI

struct NativeRootView: View {
    @State private var store = CasinoStore()
    var body: some View {
        ContentView().environment(store)
            .environment(\.locale, Locale(identifier: store.state.preferences.language))
            .tint(ClubStyle.gold)
    }
}
