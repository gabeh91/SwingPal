import SwiftUI

/// Tee and full shots: the phone's landing dial, with club and lie written at
/// the top of the page. Nothing is sent until the stamp is pressed.
struct WatchShotLoggerView: View {
    let model: WatchRoundPresentation
    let onLog: (RoundCompanionShotEntry) -> Void
    var onSwitchToPutt: (() -> Void)? = nil

    @State private var draft: WatchShotDraft
    @State private var isPickingClub = false
    @State private var isPickingLie = false

    init(model: WatchRoundPresentation, onLog: @escaping (RoundCompanionShotEntry) -> Void, onSwitchToPutt: (() -> Void)? = nil) {
        self.model = model
        self.onLog = onLog
        self.onSwitchToPutt = onSwitchToPutt
        let suggested = model.snapshot?.suggestedSurface ?? .fairway
        _draft = State(initialValue: WatchShotDraft(
            clubName: model.snapshot?.selectedClubName ?? "7i",
            surface: suggested == .green ? .fairway : suggested
        ))
    }

    private var context: RoundCompanionShotContext {
        draft.surface == .tee || model.snapshot?.strokeNumber == 1 ? .tee : .shot
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.strokeText).font(WatchBook.Typeface.heading)
                    Spacer(minLength: 4)
                    Text(model.hasYardage ? "\(model.centreText) \(model.unitSuffix)" : "—")
                        .font(WatchBook.Typeface.smallFigure)
                        .foregroundStyle(WatchBook.pencil)
                }

                VStack(spacing: 0) {
                    pageLine(title: "Club", value: draft.clubName, symbol: "figure.golf") { isPickingClub = true }
                    WatchBookHairline().padding(.leading, 30)
                    pageLine(title: "Lie", value: WatchBookLabels.surface(draft.surface), symbol: WatchBookLabels.surfaceSymbol(draft.surface)) { isPickingLie = true }
                }
                .watchLeaf()

                WatchOutcomeDial(selection: $draft.outcome, isCentreSelected: $draft.isCentre, showsCentre: true)
                    .frame(height: 150)
                    .frame(maxWidth: .infinity)

                Text(draft.summary)
                    .font(.footnote.weight(draft.isComplete ? .semibold : .regular))
                    .foregroundStyle(draft.isComplete ? WatchBook.ink : WatchBook.pencil)
                    .frame(maxWidth: .infinity)

                if draft.outcome?.hasLateralMiss == true {
                    HStack(spacing: 6) {
                        intensityChoice("Normal", isSelected: !draft.isFar) { draft.isFar = false }
                        intensityChoice("Far", isSelected: draft.isFar) { draft.isFar = true }
                    }
                }

                if context == .tee {
                    Toggle("Provisional ball", isOn: $draft.isProvisional)
                        .font(.footnote)
                        .tint(WatchBook.stamp)
                }

                Button {
                    if let entry = draft.entry { onLog(entry) }
                } label: {
                    Text(WatchBookLabels.shotConfirmTitle(context: context, puttHoled: nil))
                }
                .buttonStyle(WatchStampButtonStyle())
                .disabled(!draft.isComplete)
                .sensoryFeedback(.selection, trigger: draft.summary)

                if let onSwitchToPutt {
                    Button("On the green? Log a putt", action: onSwitchToPutt)
                        .font(.caption2)
                        .foregroundStyle(WatchBook.pencil)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
        }
        .navigationTitle("Log shot")
        .watchPaper()
        .sheet(isPresented: $isPickingClub) {
            WatchClubPickerView(model: model, selectedName: draft.clubName) { name in
                draft.clubName = name
                isPickingClub = false
            }
        }
        .sheet(isPresented: $isPickingLie) {
            WatchLiePickerView(selection: draft.surface) { surface in
                draft.surface = surface
                isPickingLie = false
            }
        }
    }

    private func pageLine(title: String, value: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: symbol).font(.caption).foregroundStyle(WatchBook.pencil).frame(width: 18)
                VStack(alignment: .leading, spacing: 0) {
                    Text(title).font(.caption2).foregroundStyle(WatchBook.pencil)
                    Text(value).font(.footnote.weight(.semibold)).lineLimit(1)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption2).foregroundStyle(WatchBook.pencil)
            }
            .padding(.horizontal, 8)
            .frame(minHeight: 44)
        }
        .buttonStyle(WatchRowButtonStyle())
        .accessibilityLabel("\(title), \(value)")
    }

    private func intensityChoice(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.footnote.weight(.semibold)).frame(maxWidth: .infinity, minHeight: 36)
                .watchChoice(isSelected: isSelected, cornerRadius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Putts: holed or missed is the one required choice, as on the phone.
struct WatchPuttLoggerView: View {
    let model: WatchRoundPresentation
    let onLog: (RoundCompanionPuttEntry) -> Void
    var onSwitchToShot: (() -> Void)? = nil

    @State private var draft = WatchPuttDraft()
    @State private var isCentre = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline) {
                    Text(model.strokeText).font(WatchBook.Typeface.heading)
                    Spacer(minLength: 4)
                    WatchBookNote("On the green")
                }

                HStack(spacing: 6) {
                    puttChoice("Holed", symbol: "flag.fill", isSelected: draft.holed == true) {
                        draft.holed = true
                        draft.miss = nil
                    }
                    puttChoice("Missed", symbol: "xmark", isSelected: draft.holed == false) {
                        draft.holed = false
                    }
                }

                if draft.holed == false {
                    WatchBookNote("Where it finished · optional")
                    WatchOutcomeDial(selection: $draft.miss, isCentreSelected: $isCentre, showsCentre: false)
                        .frame(height: 130)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    if let entry = draft.entry { onLog(entry) }
                } label: {
                    Text(WatchBookLabels.shotConfirmTitle(context: .putt, puttHoled: draft.holed))
                }
                .buttonStyle(WatchStampButtonStyle())
                .disabled(draft.holed == nil)

                if let onSwitchToShot {
                    Button("Not on the green? Log a shot", action: onSwitchToShot)
                        .font(.caption2)
                        .foregroundStyle(WatchBook.pencil)
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, minHeight: 36)
                }
            }
        }
        .navigationTitle("Putt")
        .watchPaper()
    }

    private func puttChoice(_ title: String, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.footnote.weight(.semibold))
                Text(title).font(.system(.headline, weight: .bold).width(.condensed))
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .watchChoice(isSelected: isSelected, cornerRadius: 12)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }
}

// MARK: - Landing dial

/// Eight sectors clockwise from long, with an optional centre "Hit". Tapping
/// the selected sector again clears it.
struct WatchOutcomeDial: View {
    @Binding var selection: WatchShotOutcome?
    @Binding var isCentreSelected: Bool
    let showsCentre: Bool

    private let innerRatio: CGFloat = 0.42

    var body: some View {
        GeometryReader { proxy in
            let diameter = min(proxy.size.width, proxy.size.height)
            let radius = diameter / 2
            ZStack {
                ForEach(WatchShotOutcome.allCases) { node in
                    let isSelected = selection == node
                    WatchAnnularSector(startDegrees: node.midAngleDegrees - 22.5, endDegrees: node.midAngleDegrees + 22.5, innerRatio: innerRatio)
                        .fill(isSelected ? WatchBook.stamp : WatchBook.leaf)
                    WatchAnnularSector(startDegrees: node.midAngleDegrees - 22.5, endDegrees: node.midAngleDegrees + 22.5, innerRatio: innerRatio)
                        .stroke(WatchBook.rule, lineWidth: 1)
                    Text(node.label)
                        .font(.system(size: 10, weight: .semibold).width(.condensed))
                        .foregroundStyle(isSelected ? WatchBook.onStamp : WatchBook.ink)
                        .position(labelPosition(for: node, radius: radius))
                }
                if showsCentre {
                    Circle()
                        .fill(isCentreSelected ? WatchBook.stamp : WatchBook.wash)
                        .frame(width: diameter * innerRatio - 8, height: diameter * innerRatio - 8)
                    Text("Hit")
                        .font(.system(.headline, weight: .bold).width(.condensed))
                        .foregroundStyle(isCentreSelected ? WatchBook.onStamp : WatchBook.ink)
                } else {
                    Image(systemName: "flag.fill").font(.footnote).foregroundStyle(WatchBook.flag)
                }
            }
            .frame(width: diameter, height: diameter)
            .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
            .contentShape(Circle())
            .gesture(
                SpatialTapGesture().onEnded { value in
                    let origin = CGPoint(x: proxy.size.width / 2, y: proxy.size.height / 2)
                    tap(at: value.location, origin: origin, radius: radius)
                }
            )
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Where it finished")
        .accessibilityValue(isCentreSelected ? "Centre" : selection?.spokenLabel ?? "Not chosen")
        .accessibilityAdjustableAction { direction in
            let options: [WatchShotOutcome?] = (showsCentre ? [nil] : []) + WatchShotOutcome.allCases.map { $0 }
            let current = isCentreSelected ? 0 : options.firstIndex(where: { $0 == selection && $0 != nil }) ?? -1
            let next: Int
            switch direction {
            case .increment: next = min(current + 1, options.count - 1)
            case .decrement: next = max(current - 1, 0)
            @unknown default: return
            }
            choose(options[next], centre: showsCentre && next == 0)
        }
    }

    private func tap(at location: CGPoint, origin: CGPoint, radius: CGFloat) {
        let dx = location.x - origin.x
        let dy = location.y - origin.y
        let distance = (dx * dx + dy * dy).squareRoot()
        guard distance <= radius else { return }
        if distance < radius * innerRatio {
            guard showsCentre else { return }
            choose(nil, centre: !isCentreSelected)
            return
        }
        // Clockwise from north.
        let degrees = atan2(Double(dx), Double(-dy)) * 180 / .pi
        let node = WatchShotOutcome.sector(atDegrees: degrees)
        choose(selection == node ? nil : node, centre: false)
    }

    private func choose(_ node: WatchShotOutcome?, centre: Bool) {
        selection = node
        isCentreSelected = centre
    }

    private func labelPosition(for node: WatchShotOutcome, radius: CGFloat) -> CGPoint {
        let labelRadius = radius * (innerRatio + (1 - innerRatio) * 0.58)
        let radians = node.midAngleDegrees * .pi / 180
        return CGPoint(x: radius + labelRadius * CGFloat(sin(radians)), y: radius - labelRadius * CGFloat(cos(radians)))
    }
}

struct WatchAnnularSector: Shape {
    let startDegrees: Double
    let endDegrees: Double
    let innerRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outer = min(rect.width, rect.height) / 2
        let inner = outer * innerRatio
        // SwiftUI angles run clockwise from east; the dial runs clockwise from north.
        let start = Angle.degrees(startDegrees - 90)
        let end = Angle.degrees(endDegrees - 90)
        var path = Path()
        path.addArc(center: center, radius: outer, startAngle: start, endAngle: end, clockwise: false)
        path.addArc(center: center, radius: inner, startAngle: end, endAngle: start, clockwise: true)
        path.closeSubpath()
        return path
    }
}

// MARK: - Pickers

struct WatchLiePickerView: View {
    let selection: RoundCompanionSurface
    let onPick: (RoundCompanionSurface) -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ForEach([RoundCompanionSurface.tee, .fairway, .rough, .bunker], id: \.self) { surface in
                    Button { onPick(surface) } label: {
                        Label(WatchBookLabels.surface(surface), systemImage: WatchBookLabels.surfaceSymbol(surface))
                            .font(.footnote.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .padding(.horizontal, 10)
                            .watchChoice(isSelected: surface == selection)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(surface == selection ? .isSelected : [])
                }
            }
        }
        .navigationTitle("Lie")
        .watchPaper()
    }
}

struct WatchPenaltyPickerView: View {
    let onPick: (RoundCompanionPenalty) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(RoundCompanionPenalty.allCases.enumerated()), id: \.element) { index, penalty in
                    let label = WatchBookLabels.penalty(penalty)
                    if index > 0 { WatchBookHairline().padding(.leading, 34) }
                    Button { onPick(penalty) } label: {
                        HStack(spacing: 10) {
                            Image(systemName: label.symbol).font(.footnote).frame(width: 20)
                            VStack(alignment: .leading, spacing: 0) {
                                Text(label.title).font(.footnote.weight(.semibold))
                                Text(label.detail).font(.caption2).foregroundStyle(WatchBook.pencil)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .frame(minHeight: 48)
                    }
                    .buttonStyle(WatchRowButtonStyle())
                }
            }
            .watchLeaf()
            WatchBookNote("Adds one penalty stroke")
                .padding(.top, 6)
        }
        .navigationTitle("Penalty")
        .watchPaper()
    }
}
