import SwiftUI

enum WatchRoundRoute: Hashable {
    case club
    case shot
    case putt
    case penalty
    case score
}

/// The Watch app's root: a no-round cover, or the live hole as two vertical
/// pages (read the hole, then act on it), turned with the Digital Crown.
struct WatchRoundRootView: View {
    @ObservedObject var store: WatchRoundCompanionStore
    @State private var path: [WatchRoundRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                let model = store.presentation(at: timeline.date)
                Group {
                    switch model.phase {
                    case .live:
                        WatchLiveRoundPages(model: model, store: store, path: $path)
                    case .roundComplete:
                        WatchRoundCompleteView(model: model)
                    case .noRound:
                        WatchNoRoundView(link: model.link)
                    case .incompatible:
                        WatchIncompatibleView()
                    }
                }
                .navigationDestination(for: WatchRoundRoute.self) { route in
                    destination(for: route, model: model)
                }
            }
        }
        .overlay(alignment: .top) {
            if let feedback = store.feedback {
                WatchFeedbackToast(feedback: feedback)
                    .task(id: feedback.id) {
                        try? await Task.sleep(for: .seconds(2.2))
                        store.clearFeedback(feedback.id)
                    }
            }
        }
        .onChange(of: store.snapshot == nil) { _, hasNoRound in
            if hasNoRound { path.removeAll() }
        }
    }

    @ViewBuilder
    private func destination(for route: WatchRoundRoute, model: WatchRoundPresentation) -> some View {
        switch route {
        case .club:
            WatchClubPickerView(model: model, selectedName: model.snapshot?.selectedClubName) { name in
                store.send(.selectClub(name: name))
                path.removeAll()
            }
        case .shot:
            WatchShotLoggerView(
                model: model,
                onLog: { entry in
                    store.send(.logShot(entry))
                    path.removeAll()
                },
                onSwitchToPutt: { path = [.putt] }
            )
        case .putt:
            WatchPuttLoggerView(
                model: model,
                onLog: { entry in
                    store.send(.logPutt(entry))
                    // A holed putt finishes the hole: go straight to the card.
                    path = entry.holed ? [.score] : []
                },
                onSwitchToShot: { path = [.shot] }
            )
        case .penalty:
            WatchPenaltyPickerView { penalty in
                store.send(.quickPenalty(penalty))
                path.removeAll()
            }
        case .score:
            WatchHoleScoreView(model: model) { score, putts in
                store.send(.finishHole(score: score, putts: putts))
                path.removeAll()
            }
        }
    }
}
