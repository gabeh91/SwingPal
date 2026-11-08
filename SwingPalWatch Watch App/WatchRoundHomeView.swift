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

// MARK: - Live pages

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

/// Page one: the hole, the green readings beside it, and the club in hand
/// over the stamp that logs a shot.
struct WatchHolePage: View {
    let model: WatchRoundPresentation
    @ObservedObject var store: WatchRoundCompanionStore
    @Binding var path: [WatchRoundRoute]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            HStack(alignment: .top, spacing: 4) {
                greenReadings
                    .frame(maxWidth: .infinity, alignment: .leading)
                if let sketch = model.snapshot?.sketch {
                    WatchHoleSketchView(sketch: sketch)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
            .frame(maxHeight: .infinity)
            if let status = model.statusLine {
                Text(status)
                    .font(.caption2)
                    .foregroundStyle(model.isStale ? WatchBook.warning : WatchBook.pencil)
                    .lineLimit(2)
                    .padding(.bottom, 2)
            }
            WatchBookHairline()
            dock
        }
        .padding(.horizontal, 4)
    }

    /// The folio: hole number, par and the round so far.
    private var header: some View {
        HStack(alignment: .lastTextBaseline, spacing: 6) {
            Text(model.folioText)
                .font(WatchBook.Typeface.folio)
            VStack(alignment: .leading, spacing: 0) {
                Text(model.parText).font(WatchBook.Typeface.heading)
                Text("\(model.roundToParText) · \(model.strokeText)")
                    .font(.caption2)
                    .foregroundStyle(WatchBook.pencil)
                    .lineLimit(1)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Hole \(model.snapshot?.holeNumber ?? 0), \(model.parText). Round \(model.roundToParText). \(model.strokeText)")
    }

    /// Centre, front and back, written beside the drawing as the book does.
    private var greenReadings: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(model.centreText)
                    .font(WatchBook.Typeface.figure)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundStyle(model.isStale ? WatchBook.pencil : WatchBook.ink)
                if model.hasYardage {
                    Text(model.unitSuffix)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(WatchBook.pencil)
                }
            }
            WatchBookNote(model.yardageNote)
            if model.hasYardage {
                HStack(spacing: 8) {
                    Text("F \(model.frontText)")
                    Text("B \(model.backText)")
                }
                .font(WatchBook.Typeface.smallFigure)
                .padding(.top, 2)
                if let playsLike = model.playsLikeText {
                    Text(playsLike)
                        .font(.system(.footnote, weight: .bold).width(.condensed))
                        .foregroundStyle(WatchBook.flag)
                }
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.yardageAccessibilityLabel)
    }

    /// The equipment line: the club code and its carry, then the stamp.
    private var dock: some View {
        HStack(spacing: 6) {
            Button { path.append(.club) } label: {
                HStack(alignment: .center, spacing: 5) {
                    Text(model.clubCode)
                        .font(WatchBook.Typeface.clubCode)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    VStack(alignment: .leading, spacing: 0) {
                        if let carry = model.carryText {
                            Text(carry).font(.caption2.weight(.semibold)).monospacedDigit()
                        }
                        if let source = model.carrySourceText {
                            Text(source).font(.caption2).foregroundStyle(WatchBook.pencil)
                        }
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                }
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(model.isInspectingOnPhone)
            .accessibilityLabel("Choose club. \(model.snapshot?.selectedClubName ?? ""), \(model.carryText ?? ""), \(model.carrySourceText ?? "")")

            if model.isInspectingOnPhone {
                Button {
                    store.send(.returnToLiveHole)
                } label: {
                    Label("Hole \(model.snapshot?.holeNumber ?? 0)", systemImage: "arrow.uturn.backward")
                        .font(.footnote.weight(.bold))
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(WatchStampButtonStyle())
                .frame(width: 82)
                .accessibilityLabel("Back to the live hole")
            } else {
                Button {
                    path.append(model.snapshot?.shotContext == .putt ? .putt : .shot)
                } label: {
                    VStack(spacing: 1) {
                        Image(systemName: "figure.golf").font(.system(size: 16, weight: .semibold))
                        Text("Log").font(.caption2.weight(.bold))
                    }
                }
                .buttonStyle(WatchStampButtonStyle())
                .frame(width: 62)
                .disabled(!model.canRecordShots)
                .accessibilityLabel(model.logShotTitle)
            }
        }
        .padding(.top, 4)
        .padding(.bottom, 6)
    }
}

/// Page two: everything else the phone's round actions offer for this shot
/// and hole, with the card for this hole at the top.
struct WatchShotActionsPage: View {
    let model: WatchRoundPresentation
    @ObservedObject var store: WatchRoundCompanionStore
    @Binding var path: [WatchRoundRoute]
    @State private var isConfirmingUndo = false
    @State private var isConfirmingRetee = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                card
                if let reason = model.recordBlockedReason {
                    Label(reason, systemImage: "iphone")
                        .font(.caption2)
                        .foregroundStyle(WatchBook.pencil)
                }
                VStack(alignment: .leading, spacing: 4) {
                    WatchBookNote("This shot")
                    VStack(spacing: 0) {
                        if model.snapshot?.ballMark != .hidden {
                            row(model.ballMarkTitle, detail: "Measure from here", symbol: model.snapshot?.ballMark == .marked ? "checkmark" : "scope") {
                                store.send(.markBall)
                            }
                            WatchBookHairline().padding(.leading, 34)
                        }
                        row(model.undoTitle, detail: model.undoDetail, symbol: "arrow.uturn.backward", enabled: model.snapshot?.canUndoLastShot == true) {
                            isConfirmingUndo = true
                        }
                        WatchBookHairline().padding(.leading, 34)
                        row("Penalty", detail: "Lost, OB, unplayable, water", symbol: "exclamationmark.triangle") {
                            path.append(.penalty)
                        }
                        WatchBookHairline().padding(.leading, 34)
                        row("Re-tee", detail: "+1 · play again from the tee", symbol: "arrow.counterclockwise") {
                            isConfirmingRetee = true
                        }
                    }
                    .watchLeaf()
                    .disabled(!model.canRecordShots)
                    .opacity(model.canRecordShots ? 1 : 0.5)
                }
                if let status = model.statusLine {
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(model.isStale ? WatchBook.warning : WatchBook.pencil)
                }
            }
            .padding(.horizontal, 2)
        }
        .confirmationDialog("Undo last shot?", isPresented: $isConfirmingUndo, titleVisibility: .visible) {
            Button("Undo", role: .destructive) { store.send(.undoLastShot) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text([model.undoTitle.replacingOccurrences(of: "Undo ", with: ""), model.undoDetail].compactMap { $0 }.joined(separator: " · "))
        }
        .confirmationDialog("Re-tee from the tee?", isPresented: $isConfirmingRetee, titleVisibility: .visible) {
            Button("Re-tee · +1 penalty", role: .destructive) { store.send(.retee) }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Adds a penalty stroke. Log the replayed shot as normal.")
        }
    }

    /// The hole so far, and the stamp that writes it on the card.
    private var card: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(model.folioText).font(WatchBook.Typeface.heading).monospacedDigit()
                Text(model.holeTallyText)
                    .font(.footnote)
                    .foregroundStyle(WatchBook.pencil)
                    .lineLimit(2)
            }
            Button { path.append(.score) } label: {
                HStack {
                    Text("Hole score")
                    Spacer(minLength: 2)
                    Image(systemName: "arrow.right")
                }
            }
            .buttonStyle(WatchStampButtonStyle())
            .disabled(!model.canRecordShots)
        }
    }

    private func row(_ title: String, detail: String? = nil, symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: symbol)
                    .font(.footnote.weight(.medium))
                    .frame(width: 20)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.footnote.weight(.semibold))
                    if let detail {
                        Text(detail).font(.caption2).foregroundStyle(WatchBook.pencil).lineLimit(2)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
        }
        .buttonStyle(WatchRowButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }
}

// MARK: - Covers

struct WatchNoRoundView: View {
    let link: WatchCompanionLink

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("––").font(WatchBook.Typeface.folio).foregroundStyle(WatchBook.pencil)
            Text("No round in progress").font(WatchBook.Typeface.heading)
            Text("Start a round on your iPhone. The hole, the green and your club appear here.")
                .font(.footnote)
                .foregroundStyle(WatchBook.pencil)
                .fixedSize(horizontal: false, vertical: true)
            if link == .unavailable {
                WatchBookNote("iPhone not connected", color: WatchBook.warning)
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(WatchBook.ink)
        .containerBackground(WatchBook.paper.gradient, for: .navigation)
    }
}

struct WatchIncompatibleView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: "arrow.triangle.2.circlepath").font(.title3)
            Text("Update SwingPal").font(WatchBook.Typeface.heading)
            Text("The Watch and iPhone apps are different versions. Update both from the App Store.")
                .font(.footnote)
                .foregroundStyle(WatchBook.pencil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(WatchBook.ink)
        .containerBackground(WatchBook.paper.gradient, for: .navigation)
    }
}

struct WatchRoundCompleteView: View {
    let model: WatchRoundPresentation

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            WatchBookNote("Card complete")
            Text(model.roundToParText).font(WatchBook.Typeface.figure)
            Text(model.courseText).font(WatchBook.Typeface.heading).lineLimit(2)
            Text("Review and save the round on your iPhone.")
                .font(.footnote)
                .foregroundStyle(WatchBook.pencil)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(WatchBook.ink)
        .containerBackground(WatchBook.paper.gradient, for: .navigation)
    }
}

struct WatchFeedbackToast: View {
    let feedback: WatchActionFeedback

    private var symbol: String {
        switch feedback.tone {
        case .saved: return "checkmark"
        case .finished: return "flag.fill"
        case .queued: return "clock"
        case .refused: return "exclamationmark"
        }
    }

    var body: some View {
        Label(feedback.message, systemImage: symbol)
            .font(.caption.weight(.semibold))
            .lineLimit(2)
            .foregroundStyle(feedback.tone == .refused ? WatchBook.warning : WatchBook.ink)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(WatchBook.leaf, in: Capsule())
            .overlay(Capsule().strokeBorder(WatchBook.rule, lineWidth: 0.5))
            .padding(.top, 2)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityAddTraits(.isStaticText)
    }
}
