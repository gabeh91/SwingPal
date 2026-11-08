import SwiftUI

private enum WatchLivePage: Hashable {
    case hole
    case actions
}

struct WatchLiveRoundPages: View {
    let model: WatchRoundPresentation
    @ObservedObject var store: WatchRoundCompanionStore
    @Binding var path: [WatchRoundRoute]
    @State private var page: WatchLivePage = .hole

    var body: some View {
        TabView(selection: $page) {
            WatchHolePage(model: model, store: store, path: $path)
                .tag(WatchLivePage.hole)
                .containerBackground(WatchBook.paper.gradient, for: .tabView)
            WatchShotActionsPage(model: model, store: store, path: $path)
                .tag(WatchLivePage.actions)
                .containerBackground(WatchBook.paper.gradient, for: .tabView)
        }
        .tabViewStyle(.verticalPage)
        .foregroundStyle(WatchBook.ink)
        .tint(WatchBook.stamp)
    }
}
