import SwiftUI

enum FreshLiveRoundShotLoggerPresentationPolicy {
    static let usesSystemSheetBackground = true
}

private struct FreshLiveRoundShotLoggerPresentationBackgroundModifier: ViewModifier {
    func body(content: Content) -> some View {
        if FreshLiveRoundShotLoggerPresentationPolicy.usesSystemSheetBackground {
            content
        } else {
            content.presentationBackground(.clear)
        }
    }
}

struct FreshLiveRoundShotLoggerSheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State var shotOutcomeIntensity: FreshLiveRoundShotOutcomeIntensity = .normal
    @State private var isLiePickerExpanded: Bool = false

    private let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    contextHeader

                    if prefersStandardControls {
                        Picker("Lie", selection: Binding(get: { state.pendingShotSurface }, set: state.selectShotSurface)) {
                            ForEach(state.availableShotSurfaces, id: \.self) { surface in
                                Text(surfaceLabel(for: surface)).tag(surface)
                            }
                        }
                    }

                    Group {
                        switch state.currentShotLoggerContext {
                        case .tee:
                            teeContextSection
                        case .shot:
                            shotContextSection
                        case .putt:
                            puttContextSection
                        }
                    }

                    addDetailDisclosure

                    primaryCTA
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .bookSheetChrome()
            .navigationTitle("Log shot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        state.dismissShotLogger()
                    }
                }
            }
        }
        .modifier(FreshLiveRoundShotLoggerPresentationBackgroundModifier())
        .presentationDetents(prefersStandardControls ? [.large] : [.medium, .large])
        .transaction { if reduceMotion { $0.animation = nil } }
        .presentationBackground(Book.paper)
        .onAppear {
            shotOutcomeIntensity = (state.pendingShotDirection == .farLeft || state.pendingShotDirection == .farRight) ? .far : .normal
        }
    }

    private var prefersStandardControls: Bool { dynamicTypeSize.isAccessibilitySize || voiceOverEnabled }

    private var standardShotOutcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Direction", selection: Binding(get: { state.pendingShotDirection }, set: { if let value = $0 { state.selectShotDirection(value) } })) {
                Text("Choose direction").tag(ShotEvent.DirectionResult?.none)
                ForEach(ShotEvent.DirectionResult.allCases, id: \.self) { value in
                    Text(directionLabel(for: value)).tag(Optional(value))
                }
            }
            Picker("Distance outcome", selection: Binding(get: { state.pendingShotDistance }, set: { if let value = $0 { state.selectShotDistance(value) } })) {
                Text("Choose outcome").tag(ShotEvent.DistanceResult?.none)
                ForEach(ShotEvent.DistanceResult.allCases, id: \.self) { value in
                    Text(distanceLabel(for: value)).tag(Optional(value))
                }
            }
        }
        .pickerStyle(.menu)
    }

    private var standardPuttMissOutcome: some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Miss direction", selection: Binding(get: { state.pendingShotPuttMissDirection }, set: state.setPendingShotPuttMissDirection)) {
                Text("Not recorded").tag(ShotEvent.DirectionResult?.none)
                ForEach(ShotEvent.DirectionResult.allCases, id: \.self) { value in
                    Text(directionLabel(for: value)).tag(Optional(value))
                }
            }
            Picker("Miss distance outcome", selection: Binding(get: { state.pendingShotPuttMissDistance }, set: state.setPendingShotPuttMissDistance)) {
                Text("Not recorded").tag(ShotEvent.DistanceResult?.none)
                ForEach(ShotEvent.DistanceResult.allCases, id: \.self) { value in
                    Text(distanceLabel(for: value)).tag(Optional(value))
                }
            }
        }
        .pickerStyle(.menu)
    }

    // MARK: - Top of the page

    /// The shot in one line, as the book would write it: club, from and to,
    /// and the distance it had to go.
    private var contextHeader: some View {
        let layout = prefersStandardControls
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 10))
            : AnyLayout(HStackLayout(alignment: .lastTextBaseline, spacing: 10))
        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text("Stroke \(state.pendingShotStrokeNumber)")
                    .font(Book.Typeface.heading)
                Text("\(state.pendingShotOriginLabel.lowercased(with: .current)) → \(state.pendingShotTargetLabel.lowercased(with: .current))")
                    .font(.caption)
                    .foregroundStyle(Book.pencil)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 0) {
                Text(state.targetLabel == "Target unavailable" ? "—" : state.pendingShotDistanceLabel)
                    .font(Book.Typeface.figure)
                Text(state.targetLabel.uppercased())
                    .font(Book.Typeface.noteSmall)
                    .foregroundStyle(Book.pencil)
            }
        }
        .accessibilityElement(children: .combine)
    }

    /// The club and the lie, ruled like the top lines of a page. The lie is
    /// inferred from where the ball is; tap it to correct.
    private func clubAndLie(showsClub: Bool = true) -> some View {
        VStack(spacing: 8) {
            BookGroup(ruleInset: 50) {
                if showsClub {
                Menu {
                    ForEach(state.availableClubNames, id: \.self) { clubName in
                        Button(clubName) {
                            state.overridePendingShotClubName(clubName)
                        }
                    }
                } label: {
                    pageLine(symbol: "figure.golf", title: "Club", value: state.pendingShotClubName, trailingSymbol: "chevron.up.chevron.down", rotation: 0)
                }
                .buttonStyle(BookRowButtonStyle())
                }

                if !prefersStandardControls {
                    Button {
                        withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                            isLiePickerExpanded.toggle()
                        }
                    } label: {
                        pageLine(
                            symbol: surfaceIconName(for: state.pendingShotSurface),
                            title: state.pendingShotLieBannerSubtitle,
                            value: state.pendingShotLieBannerTitle,
                            trailingSymbol: "chevron.down",
                            rotation: isLiePickerExpanded ? -180 : 0
                        )
                    }
                    .buttonStyle(BookRowButtonStyle())
                }
            }

            if isLiePickerExpanded && !prefersStandardControls {
                liePickerStrip
            }
        }
    }

    private func pageLine(symbol: String, title: String, value: String, trailingSymbol: String, rotation: Double) -> some View {
        HStack(spacing: 14) {
            Image(systemName: symbol)
                .font(.body.weight(.medium))
                .foregroundStyle(Book.pencil)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(Book.pencil)
                    .lineLimit(1)
                Text(value).font(.body.weight(.semibold))
            }
            Spacer(minLength: 8)
            Image(systemName: trailingSymbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(Book.pencil)
                .rotationEffect(.degrees(rotation))
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 54)
        .contentShape(Rectangle())
    }

    private var liePickerStrip: some View {
        HStack(spacing: 8) {
            ForEach(state.availableShotSurfaces, id: \.self) { surface in
                let isSelected = state.pendingShotSurface == surface
                Button {
                    state.selectShotSurface(surface)
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                        isLiePickerExpanded = false
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: surfaceIconName(for: surface))
                            .font(.subheadline.weight(.semibold))
                        Text(surfaceLabel(for: surface))
                            .font(.caption.weight(.semibold))
                    }
                    .frame(maxWidth: .infinity, minHeight: 54)
                    .bookChoice(isSelected: isSelected)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func surfaceIconName(for surface: ShotEvent.Surface) -> String {
        switch surface {
        case .tee: return "flag.fill"
        case .fairway: return "leaf.fill"
        case .rough: return "leaf"
        case .bunker: return "circle.dotted"
        case .green: return "circle.circle.fill"
        }
    }

    // MARK: - Context sections

    private var teeContextSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            clubAndLie()

            if prefersStandardControls { standardShotOutcome } else { shotOutcomeSection }

            if state.availableShotTypes.contains(.provisionalBall) {
                provisionalChip
            }
        }
    }

    private var shotContextSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            clubAndLie()
            if prefersStandardControls { standardShotOutcome } else { shotOutcomeSection }
        }
    }

    private var puttContextSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !prefersStandardControls {
                clubAndLie(showsClub: false)
            }
            puttHoledMissedRow
            if state.pendingShotPuttHoled == false {
                puttMissPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: state.pendingShotPuttHoled)
    }

    private var puttHoledMissedRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(title: "How did the putt finish?")
            HStack(spacing: 10) {
                puttOutcomeChoice(title: "Holed", icon: "flag.fill", isSelected: state.pendingShotPuttHoled == true) {
                    state.setPendingShotPuttHoled(true)
                }
                puttOutcomeChoice(title: "Missed", icon: "xmark", isSelected: state.pendingShotPuttHoled == false) {
                    state.setPendingShotPuttHoled(false)
                }
            }
        }
    }

    private func puttOutcomeChoice(
        title: String,
        icon: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.system(.title3, weight: .bold).width(.condensed))
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .bookChoice(isSelected: isSelected, cornerRadius: 14)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var puttMissPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionHeading(
                title: "Where did it finish?",
                subtitle: "Tap where the ball stopped. Optional."
            )

            if prefersStandardControls { standardPuttMissOutcome } else { puttMissOutcomeDial }

            optionalCounter(
                title: "Miss distance",
                value: state.pendingShotPuttMissDistanceMeters,
                unsetLabel: "Add how far it finished",
                suffix: "m",
                range: 0...30,
                setValue: { state.setPendingShotPuttMissDistanceMeters($0) }
            )
        }
    }

    private var puttMissOutcomeDial: some View {
        let layout = FreshLiveRoundShotOutcomeLayout.puttMiss

        return VStack(alignment: .leading, spacing: 10) {
            ZStack {
                Circle()
                    .fill(Book.leaf)
                    .frame(width: layout.ringDiameter, height: layout.ringDiameter)
                    .overlay { Circle().strokeBorder(Book.rule, lineWidth: 1) }

                ForEach(FreshLiveRoundShotOutcomeNode.allCases, id: \.self) { node in
                    puttMissOutcomeSegmentButton(node: node, layout: layout)
                }

                puttMissOutcomeCenter(size: layout.centerButtonSize)
            }
            .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .center)
            .frame(maxWidth: .infinity)

            selectionLine(text: puttMissChipLabel, isEmpty: state.pendingShotPuttMissDirection == nil && state.pendingShotPuttMissDistance == nil)
        }
        .sensoryFeedback(.selection, trigger: puttMissSelectionToken)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.pendingShotPuttMissDirection)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.pendingShotPuttMissDistance)
    }

    /// Maps an 8-sector outcome node to the (direction, distance) pair we
    /// persist on the shot event for a putt miss. Diagonals encode both
    /// axes; cardinals leave the unused axis as the neutral value (`.hit`
    /// for direction, `.onNumber` for distance) so existing analytics
    /// continue to slice cleanly.
    private func puttMissOutcome(
        for node: FreshLiveRoundShotOutcomeNode
    ) -> (direction: ShotEvent.DirectionResult, distance: ShotEvent.DistanceResult) {
        switch node {
        case .long:       return (.hit, .long)
        case .longRight:  return (.right, .long)
        case .right:      return (.right, .onNumber)
        case .shortRight: return (.right, .short)
        case .short:      return (.hit, .short)
        case .shortLeft:  return (.left, .short)
        case .left:       return (.left, .onNumber)
        case .longLeft:   return (.left, .long)
        }
    }

    private func isPuttMissOutcomeNodeSelected(_ node: FreshLiveRoundShotOutcomeNode) -> Bool {
        let outcome = puttMissOutcome(for: node)
        return state.pendingShotPuttMissDirection == outcome.direction
            && state.pendingShotPuttMissDistance == outcome.distance
    }

    private func selectPuttMissOutcomeNode(_ node: FreshLiveRoundShotOutcomeNode) {
        let outcome = puttMissOutcome(for: node)
        if isPuttMissOutcomeNodeSelected(node) {
            state.setPendingShotPuttMissOutcome(direction: nil, distance: nil)
        } else {
            state.setPendingShotPuttMissOutcome(
                direction: outcome.direction,
                distance: outcome.distance
            )
        }
    }

    private func puttMissOutcomeSegmentButton(
        node: FreshLiveRoundShotOutcomeNode,
        layout: FreshLiveRoundShotOutcomeLayout
    ) -> some View {
        let isSelected = isPuttMissOutcomeNodeSelected(node)
        return ringSegment(node: node, layout: layout, isSelected: isSelected) {
            segmentLabel(icon: outcomeSegmentIcon(for: node), text: puttMissSegmentLabelText(for: node), width: 60)
        } action: {
            selectPuttMissOutcomeNode(node)
        }
    }

    private func puttMissSegmentLabelText(for node: FreshLiveRoundShotOutcomeNode) -> String {
        switch node {
        case .long:       return "Long"
        case .longRight:  return "Long\nright"
        case .right:      return "Right"
        case .shortRight: return "Short\nright"
        case .short:      return "Short"
        case .shortLeft:  return "Short\nleft"
        case .left:       return "Left"
        case .longLeft:   return "Long\nleft"
        }
    }

    private func puttMissOutcomeCenter(size: CGSize) -> some View {
        VStack(spacing: 2) {
            Circle().fill(Book.ink).frame(width: 8, height: 8)
            Text("CUP")
                .font(Book.Typeface.noteSmall)
                .foregroundStyle(Book.pencil)
        }
        .frame(width: size.width, height: size.height)
        .background(Circle().fill(Book.paper))
        .overlay { Circle().strokeBorder(Book.rule, lineWidth: 1) }
        .accessibilityHidden(true)
    }

    private var puttMissChipLabel: String {
        let direction = state.pendingShotPuttMissDirection
        let distance = state.pendingShotPuttMissDistance

        if direction == nil && distance == nil {
            return "Tap where it finished"
        }

        let directionPart: String? = (direction != nil && direction != .hit) ? direction.map(puttMissDirectionLabel(for:)) : nil
        let distancePart: String? = (distance != nil && distance != .onNumber) ? distance.map(distanceLabel(for:)) : nil

        switch (distancePart, directionPart) {
        case let (dist?, dir?):
            return "\(dist) · \(dir)"
        case let (dist?, nil):
            return dist
        case let (nil, dir?):
            return dir
        case (nil, nil):
            return "Right at the cup"
        }
    }

    private var puttMissSelectionToken: String {
        let dir = state.pendingShotPuttMissDirection.map(\.rawValue) ?? "nil"
        let dist = state.pendingShotPuttMissDistance.map(\.rawValue) ?? "nil"
        return "\(dir)|\(dist)"
    }

    private func puttMissDirectionLabel(for direction: ShotEvent.DirectionResult) -> String {
        switch direction {
        case .hit: return "Centre"
        case .left, .farLeft: return "Left"
        case .right, .farRight: return "Right"
        }
    }

    private var provisionalChip: some View {
        let isSelected = state.pendingShotType == .provisionalBall
        return Button {
            state.setPendingShotType(isSelected ? nil : .provisionalBall)
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(.body.weight(.medium))
                Text("Hit a provisional ball")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 48)
            .bookChoice(isSelected: isSelected)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - More detail

    private var addDetailDisclosure: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    state.toggleShotLoggerAddDetailVisibility()
                }
            } label: {
                HStack(spacing: 8) {
                    BookNote(state.isShowingShotLoggerAddDetail ? "Less detail" : "More detail")
                    Rectangle().fill(Book.rule).frame(height: 1)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(Book.pencil)
                        .rotationEffect(.degrees(state.isShowingShotLoggerAddDetail ? -180 : 0))
                }
                .frame(minHeight: 36)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if state.isShowingShotLoggerAddDetail {
                addDetailContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    @ViewBuilder
    private var addDetailContent: some View {
        switch state.currentShotLoggerContext {
        case .tee, .shot:
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 0) {
                    BookCounter(title: "Penalties", value: state.pendingShotPenaltyCount, range: 0...10, onChange: state.setPendingShotPenaltyCount)
                    BookHairline()
                    BookCounter(title: "Drops", value: state.pendingShotDropCount, range: 0...10, onChange: state.setPendingShotDropCount)
                    BookHairline()
                    BookCounter(title: "Stroke number", value: state.pendingShotStrokeNumber, range: 1...20, onChange: state.setPendingShotStrokeNumber)
                    BookHairline()
                }

                optionSection(
                    title: "Strike",
                    subtitle: "Tap again to clear.",
                    options: ShotEvent.StrikeResult.allCases,
                    selection: state.pendingShotStrike,
                    label: strikeLabel(for:),
                    action: { option in
                        state.setPendingShotStrike(state.pendingShotStrike == option ? nil : option)
                    }
                )

                noteField
            }

        case .putt:
            VStack(alignment: .leading, spacing: 20) {
                VStack(spacing: 0) {
                    optionalCounter(
                        title: "Putts",
                        value: state.pendingShotPuttCount,
                        unsetLabel: "Counted for you (\(max(1, state.currentPlayerTotalPutts + 1)))",
                        range: 1...4,
                        setValue: { state.setPendingShotPuttCount($0) }
                    )
                    BookHairline()
                    optionalCounter(
                        title: "First putt",
                        value: state.pendingShotFirstPuttDistanceMeters,
                        unsetLabel: "Add how long it was",
                        suffix: "m",
                        range: 0...60,
                        setValue: { state.setPendingShotFirstPuttDistanceMeters($0) }
                    )
                    BookHairline()
                    BookCounter(title: "Penalties", value: state.pendingShotPenaltyCount, range: 0...10, onChange: state.setPendingShotPenaltyCount)
                    BookHairline()
                }

                noteField
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookNote("Note")
            TextField(
                "Anything worth remembering",
                text: Binding(
                    get: { state.pendingShotNote ?? "" },
                    set: { state.setPendingShotNote($0) }
                ),
                axis: .vertical
            )
            .lineLimit(1...4)
            .bookRuledField()
        }
    }

    // MARK: - Save

    private var primaryCTA: some View {
        Button {
            state.confirmPendingShot()
        } label: {
            HStack {
                Text(state.pendingShotConfirmCTAText)
                Spacer(minLength: 12)
                Image(systemName: "checkmark")
            }
        }
        .buttonStyle(BookStampButtonStyle())
        .disabled(!state.canConfirmPendingShot)
        .padding(.top, 4)
    }

    private func sectionHeading(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(Book.Typeface.subheading)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(Book.pencil)
            }
        }
    }

    private func optionSection<Option: Hashable>(
        title: String,
        subtitle: String? = nil,
        options: [Option],
        selection: Option?,
        label: @escaping (Option) -> String,
        action: @escaping (Option) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeading(title: title, subtitle: subtitle)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection == option
                    Button {
                        action(option)
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 46)
                            .bookChoice(isSelected: isSelected)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
        }
    }

    // MARK: - Where it landed

    private var shotOutcomeSection: some View {
        let layout = FreshLiveRoundShotOutcomeLayout.standard
        let intensity = shotOutcomeIntensity
        let isEmpty = state.pendingShotDirection == nil && state.pendingShotDistance == nil

        return VStack(alignment: .leading, spacing: 12) {
            sectionHeading(
                title: "Where did it finish?",
                subtitle: "The corners log distance and direction in one tap."
            )

            ZStack {
                Circle()
                    .fill(Book.leaf)
                    .frame(width: layout.ringDiameter, height: layout.ringDiameter)
                    .overlay { Circle().strokeBorder(Book.rule, lineWidth: 1) }

                ForEach(FreshLiveRoundShotOutcomeNode.allCases, id: \.self) { node in
                    outcomeRingSegmentButton(node: node, layout: layout, intensity: intensity)
                }

                outcomeCenterHitButton(size: layout.centerButtonSize)
            }
            .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .center)
            .frame(maxWidth: .infinity)

            selectionLine(text: shotOutcomeChipLabel, isEmpty: isEmpty)

            outcomeIntensitySelector
        }
        .sensoryFeedback(.selection, trigger: shotOutcomeSelectionToken)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.pendingShotDirection)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.pendingShotDistance)
        .animation(.easeInOut(duration: 0.18), value: shotOutcomeIntensity)
    }

    /// What's been picked, written under the dial in pencil until there's
    /// something to record, then in ink.
    private func selectionLine(text: String, isEmpty: Bool) -> some View {
        Text(text)
            .font(.system(.headline, weight: .semibold).width(.condensed))
            .foregroundStyle(isEmpty ? Book.pencil : Book.ink)
            .contentTransition(.interpolate)
            .frame(maxWidth: .infinity)
    }

    private func isShotOutcomeNodeSelected(_ node: FreshLiveRoundShotOutcomeNode) -> Bool {
        state.pendingShotDirection == node.resolvedDirection(intensity: shotOutcomeIntensity)
            && state.pendingShotDistance == node.distance
    }

    private func selectShotOutcomeNode(_ node: FreshLiveRoundShotOutcomeNode) {
        state.selectShotDirection(node.resolvedDirection(intensity: shotOutcomeIntensity))
        state.selectShotDistance(node.distance)
    }

    private func setShotOutcomeIntensity(_ newValue: FreshLiveRoundShotOutcomeIntensity) {
        guard newValue != shotOutcomeIntensity else { return }
        shotOutcomeIntensity = newValue

        // If a directional miss is currently selected, immediately swap it to match the new intensity.
        switch state.pendingShotDirection {
        case .left where newValue == .far:
            state.selectShotDirection(.farLeft)
        case .right where newValue == .far:
            state.selectShotDirection(.farRight)
        case .farLeft where newValue == .normal:
            state.selectShotDirection(.left)
        case .farRight where newValue == .normal:
            state.selectShotDirection(.right)
        default:
            break
        }
    }

    private var outcomeIntensitySelector: some View {
        HStack(spacing: 10) {
            Text("How far offline")
                .font(.footnote)
                .foregroundStyle(Book.pencil)

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                ForEach(FreshLiveRoundShotOutcomeIntensity.allCases, id: \.self) { option in
                    let isActive = shotOutcomeIntensity == option
                    Button {
                        setShotOutcomeIntensity(option)
                    } label: {
                        Text(option.label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(isActive ? Book.onStamp : Book.ink)
                            .frame(minWidth: 64, minHeight: 32)
                            .background(isActive ? Book.stamp : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(isActive ? .isSelected : [])
                }
            }
            .padding(3)
            .background(Book.leaf, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Book.rule, lineWidth: 1))
        }
        .frame(maxWidth: .infinity)
    }

    private func outcomeCenterHitButton(size: CGSize) -> some View {
        let isCleanStrike = state.pendingShotDirection == .hit && state.pendingShotDistance == .onNumber

        return Button {
            state.selectShotDirection(.hit)
            state.selectShotDistance(.onNumber)
        } label: {
            VStack(spacing: 1) {
                Image(systemName: "scope")
                    .font(.title3.weight(.semibold))
                Text("On line")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(isCleanStrike ? Book.onStamp : Book.ink)
            .frame(width: size.width, height: size.height)
            .background(Circle().fill(isCleanStrike ? Book.stamp : Book.paper))
            .overlay {
                Circle().strokeBorder(isCleanStrike ? Color.clear : Book.rule, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .accessibilityLabel("On line and on the number")
        .accessibilityAddTraits(isCleanStrike ? .isSelected : [])
    }

    private var shotOutcomeChipLabel: String {
        let direction = state.pendingShotDirection
        let distance = state.pendingShotDistance

        if direction == nil && distance == nil {
            return "Tap where it finished"
        }
        if direction == .hit && distance == .onNumber {
            return "On line, on the number"
        }

        let directionPart: String? = (direction != nil && direction != .hit) ? direction.map(directionLabel(for:)) : nil
        let distancePart: String? = (distance != nil && distance != .onNumber) ? distance.map(distanceLabel(for:)) : nil

        switch (distancePart, directionPart) {
        case let (dist?, dir?):
            return "\(dist) · \(dir)"
        case let (dist?, nil):
            return dist
        case let (nil, dir?):
            return dir
        case (nil, nil):
            return "On line, on the number"
        }
    }

    private var shotOutcomeSelectionToken: String {
        let dir = state.pendingShotDirection.map(\.rawValue) ?? "nil"
        let dist = state.pendingShotDistance.map(\.rawValue) ?? "nil"
        return "\(dir)|\(dist)"
    }

    private func outcomeRingSegmentButton(
        node: FreshLiveRoundShotOutcomeNode,
        layout: FreshLiveRoundShotOutcomeLayout,
        intensity: FreshLiveRoundShotOutcomeIntensity
    ) -> some View {
        let isFar = intensity == .far && node.lateralLean != .none
        return ringSegment(node: node, layout: layout, isSelected: isShotOutcomeNodeSelected(node)) {
            segmentLabel(icon: outcomeSegmentIcon(for: node), text: outcomeSegmentLabelText(for: node, isFar: isFar), width: 64)
        } action: {
            selectShotOutcomeNode(node)
        }
    }

    /// One sector of the dial: paper, or stamped when chosen.
    private func ringSegment<Label: View>(
        node: FreshLiveRoundShotOutcomeNode,
        layout: FreshLiveRoundShotOutcomeLayout,
        isSelected: Bool,
        @ViewBuilder label: () -> Label,
        action: @escaping () -> Void
    ) -> some View {
        let segmentShape = FreshLiveRoundAnnularSegmentShape(
            startAngleDegrees: layout.startAngleDegrees(for: node),
            endAngleDegrees: layout.endAngleDegrees(for: node),
            innerRadiusRatio: layout.ringInnerRadiusRatio
        )
        let ringDiameter = layout.ringDiameter
        let labelPosition = layout.labelPosition(for: node)

        return Button(action: action) {
            ZStack {
                segmentShape
                    .fill(isSelected ? Book.stamp : Book.leaf)
                    .frame(width: ringDiameter, height: ringDiameter)
                    .overlay {
                        segmentShape
                            .stroke(Book.rule, lineWidth: 1)
                            .frame(width: ringDiameter, height: ringDiameter)
                    }

                label()
                    .foregroundStyle(isSelected ? Book.onStamp : Book.ink)
                    .position(labelPosition)
            }
            .frame(width: ringDiameter, height: ringDiameter)
        }
        .buttonStyle(.plain)
        .contentShape(segmentShape)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func segmentLabel(icon: String, text: String, width: CGFloat) -> some View {
        VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(width: width)
    }

    private func outcomeSegmentIcon(for node: FreshLiveRoundShotOutcomeNode) -> String {
        switch node {
        case .long:       return "arrow.up"
        case .longRight:  return "arrow.up.right"
        case .right:      return "arrow.right"
        case .shortRight: return "arrow.down.right"
        case .short:      return "arrow.down"
        case .shortLeft:  return "arrow.down.left"
        case .left:       return "arrow.left"
        case .longLeft:   return "arrow.up.left"
        }
    }

    private func outcomeSegmentLabelText(for node: FreshLiveRoundShotOutcomeNode, isFar: Bool) -> String {
        let farPrefix = isFar ? "Far " : ""
        switch node {
        case .long:       return "Long"
        case .longRight:  return "Long\n\(farPrefix)Right"
        case .right:      return "\(farPrefix)Right"
        case .shortRight: return "Short\n\(farPrefix)Right"
        case .short:      return "Short"
        case .shortLeft:  return "Short\n\(farPrefix)Left"
        case .left:       return "\(farPrefix)Left"
        case .longLeft:   return "Long\n\(farPrefix)Left"
        }
    }

    /// A tally that can be left blank: "Add…" until a value is set, then a
    /// counter with a way to clear it.
    @ViewBuilder
    private func optionalCounter(
        title: String,
        value: Int?,
        unsetLabel: String,
        suffix: String = "",
        range: ClosedRange<Int>,
        setValue: @escaping (Int?) -> Void
    ) -> some View {
        if let value {
            VStack(alignment: .trailing, spacing: 0) {
                BookCounter(title: title, value: value, range: range, suffix: suffix) { setValue($0) }
                Button("Clear") { setValue(nil) }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Book.pencil)
                    .padding(.bottom, 6)
            }
        } else {
            Button {
                setValue(range.lowerBound)
            } label: {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(title).font(.body)
                        Text(unsetLabel).font(.caption).foregroundStyle(Book.pencil)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .frame(width: 44, height: 44)
                        .background(Circle().strokeBorder(Book.ink.opacity(0.6), lineWidth: 1))
                }
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func directionLabel(for result: ShotEvent.DirectionResult) -> String {
        switch result {
        case .hit: return "Hit"
        case .left: return "Left"
        case .farLeft: return "Far Left"
        case .right: return "Right"
        case .farRight: return "Far Right"
        }
    }

    private func distanceLabel(for result: ShotEvent.DistanceResult) -> String {
        switch result {
        case .onNumber: return "On Number"
        case .long: return "Long"
        case .short: return "Short"
        }
    }

    private func strikeLabel(for result: ShotEvent.StrikeResult) -> String {
        switch result {
        case .pure: return "Pure"
        case .thin: return "Thin"
        case .chunk: return "Chunk"
        case .top: return "Top"
        case .slice: return "Slice"
        case .hook: return "Hook"
        }
    }

    private func surfaceLabel(for surface: ShotEvent.Surface) -> String {
        switch surface {
        case .tee: return "Tee"
        case .fairway: return "Fairway"
        case .rough: return "Rough"
        case .bunker: return "Bunker"
        case .green: return "Green"
        }
    }

}
