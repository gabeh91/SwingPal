import SwiftUI
import MapKit

/// Bundles the four tray-action presentations (quick-penalty sheet,
/// undo confirmation alert, re-tee confirmation alert, undo toast
/// auto-dismiss timer) into a single view modifier so the live-round
/// screen body stays under Swift's type-checker complexity limit.
private struct FreshLiveRoundTrayActionsModifier<PickerContent: View>: ViewModifier {
    @ObservedObject var state: LiveRoundState
    let onUndoneToastSchedule: () -> Void
    let quickPenaltyPicker: () -> PickerContent
    let modalCanvas: Color
    let surfaceLabel: (ShotEvent.Surface) -> String
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { state.isShowingQuickPenaltyPicker },
                set: { if !$0 { state.dismissQuickPenaltyPicker() } }
            )) {
                quickPenaltyPicker()
                    .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
                    .presentationBackground(modalCanvas)
            }
            .alert(
                "Undo last shot?",
                isPresented: Binding(
                    get: { state.pendingUndoPreview != nil },
                    set: { if !$0 { state.dismissUndoConfirmation() } }
                ),
                presenting: state.pendingUndoPreview
            ) { _ in
                Button("Cancel", role: .cancel) { }
                Button("Undo", role: .destructive) {
                    state.confirmUndoLastShot()
                }
            } message: { preview in
                Text("Remove \(preview.clubName) from \(surfaceLabel(preview.surface))? You can re-log it any time.")
            }
            .alert(
                "Re-tee from tee box?",
                isPresented: Binding(
                    get: { state.isShowingReteeConfirmation },
                    set: { if !$0 { state.dismissReteeConfirmation() } }
                )
            ) {
                Button("Cancel", role: .cancel) { }
                Button("Re-tee · +1 penalty", role: .destructive) {
                    state.confirmRetee()
                }
            } message: {
                Text("Adds a +1 penalty stroke and re-aims the next shot at the tee box. Use for OB, lost ball, or stroke-and-distance penalties.")
            }
            .onChange(of: state.lastUndoneShotPreview != nil, initial: false) { _, isVisible in
                guard isVisible else { return }
                onUndoneToastSchedule()
            }
    }
}

struct FreshLiveRoundScreen: View {
    @ObservedObject var state: LiveRoundState
    let onFinishHole: () -> Void
    let onSaveAndExitRound: () -> Void
    let onDiscardRound: () -> Void
    let onReviewRound: () -> Void

    init(
        state: LiveRoundState,
        onFinishHole: @escaping () -> Void,
        onSaveAndExitRound: @escaping () -> Void,
        onDiscardRound: @escaping () -> Void,
        onReviewRound: @escaping () -> Void = {}
    ) {
        self.state = state
        self.onFinishHole = onFinishHole
        self.onSaveAndExitRound = onSaveAndExitRound
        self.onDiscardRound = onDiscardRound
        self.onReviewRound = onReviewRound

        // Seed the camera at the tee-biased framing so the very first frame is already
        // looking up the hole from the tee, instead of MapKit's default empty/automatic state
        // (which can flash a green placeholder while satellite tiles load in).
        let initialRegion = state.isInspectingHole
            ? state.displayedHoleRegion
            : state.nextHoleTeeFramingRegion
        _cameraPosition = State(initialValue: .region(initialRegion))
    }

    @State private var cameraPosition: MapCameraPosition
    @AppStorage("liveMapStyle") private var liveMapStyleRaw = "aerial"
    /// The drag-to-plan hint shows until the ring has been moved once.
    @AppStorage("liveAimHintSeen") private var hasSeenAimHint = false
    @State private var playingPreviewClub: String?
    @ScaledMetric(relativeTo: .largeTitle) private var playingDistanceSize: CGFloat = 30
    @State private var isShowingShotLoggedToast = false
    @State private var shotLoggedToastTask: Task<Void, Never>?
    /// Auto-dismiss timer for the post-undo "Undid 7-iron" toast.
    @State private var undoneToastTask: Task<Void, Never>?
    /// True while a finger holds the target ring (map gestures pause).
    @State private var isAimDragging = false
    /// Camera frames for the aim overlay. Plain `@State`, not `@StateObject`:
    /// a state object would subscribe this whole screen to every camera frame.
    @State private var aimTicker = AimCameraTicker()
    /// Page outline and hazard figures, kept between renders.
    @State private var drawingCache = LiveMapDrawingCache()
    @State private var hasSeededInitialCamera = false
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @State private var isShowingHoleInspector = false
    @State private var isShowingShotHistory = false
    @State private var isShowingConditions = false
    @State private var isShowingCurrentHoleEditor = false
    @State private var isShowingEndRoundFlow = false
    @State private var isShowingRoundActions = false
    @State private var pendingRoundAction: (() -> Void)?
    @State private var pendingEndRoundChoice: FreshLiveRoundEndRoundChoice?
    @State private var isShowingNativeClubPicker = false
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityVoiceOverEnabled) private var voiceOverEnabled

    var body: some View {
        GeometryReader { proxy in
            if dynamicTypeSize.isAccessibilitySize || voiceOverEnabled {
                ScrollView {
                    VStack(spacing: 0) {
                        courseRoundHeader
                        courseDistanceInstrument
                        courseMapStage.frame(height: 260)
                        courseShotActions(availableWidth: proxy.size.width)
                    }
                }
                .background(CourseStyle.ground)
            } else {
                immersiveRoundContent(in: proxy)
            }
        }
        .onChange(of: dynamicTypeSize) { _, _ in state.dismissClubWheel(); playingPreviewClub = nil }
        .onChange(of: voiceOverEnabled) { _, enabled in
            if enabled { state.dismissClubWheel(); playingPreviewClub = nil }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Land on the 3D tee perspective the first time the screen mounts so the player
            // sees the hole from behind the tee box looking toward the green. After that, the
            // various onChange handlers below take over.
            if !hasSeededInitialCamera {
                hasSeededInitialCamera = true
                syncCameraToHoleFraming()
                aimAtClubCarry()
            }
        }
        .onChange(of: state.selectedClubName) { _, _ in aimAtClubCarry() }
        .onChange(of: state.hole.number) { _, _ in aimAtClubCarry() }
        .onChange(of: isAimDragging) { _, active in if active { hasSeenAimHint = true } }
        .onChange(of: state.locationStatus, initial: false) { _, _ in
            // Once GPS comes online we don't snap the camera (would yank the user away from
            // wherever they're looking). The first GPS-ready frame is handled by the initial
            // tee framing on appear; subsequent recenters are explicit via the recenter button.
        }
        .onChange(of: state.displayedHoleNumber, initial: false) { _, _ in
            syncCameraToHoleFraming(animated: true)
        }
        .onChange(of: state.isInspectingHole, initial: false) { _, _ in
            syncCameraToHoleFraming(animated: true)
        }
        .onChange(of: state.shotLogConfirmationCount, initial: false) { _, newValue in
            guard newValue > 0 else { return }
            aimAtClubCarry()
            shotLoggedToastTask?.cancel()
            withAnimation(.spring(response: 0.28, dampingFraction: 0.92)) {
                isShowingShotLoggedToast = true
            }
            shotLoggedToastTask = Task { @MainActor in
                try? await Task.sleep(for: .seconds(1.6))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    isShowingShotLoggedToast = false
                }
            }
        }
        .task {
            await state.refreshWeather()
        }
        .onDisappear {
            shotLoggedToastTask?.cancel()
            undoneToastTask?.cancel()
        }
        .sheet(isPresented: Binding(
            get: { state.isShowingShotLogger },
            set: { if !$0 { state.dismissShotLogger() } }
        )) {
            FreshLiveRoundShotLoggerSheet(state: state)
        }
        .sheet(isPresented: Binding(
            get: { state.isShowingHoleConfirmation },
            set: { if !$0 { state.dismissHoleConfirmation() } }
        )) {
            FreshLiveRoundHoleConfirmationSheet(
                state: state,
                onRoundFinished: onFinishHole
            )
        }
        .sheet(isPresented: $isShowingHoleInspector) {
            FreshLiveRoundHoleInspectorSheet(state: state)
        }
        .sheet(isPresented: $isShowingShotHistory) {
            FreshLiveRoundShotHistorySheet(state: state)
        }
        .sheet(isPresented: $isShowingConditions) {
            FreshLiveRoundConditionsSheet(state: state)
        }
        .sheet(isPresented: $isShowingCurrentHoleEditor) {
            FreshLiveRoundCurrentHoleEditorSheet(state: state)
        }
        .sheet(isPresented: $isShowingEndRoundFlow, onDismiss: {
            // Act once the sheet has gone, so the card can present in its place.
            let choice = pendingEndRoundChoice
            pendingEndRoundChoice = nil
            switch choice {
            case .signCard?, .reviewCard?: onReviewRound()
            case .finishLater?: onSaveAndExitRound()
            case .discard?: onDiscardRound()
            case nil: break
            }
        }) {
            FreshLiveRoundEndRoundSheet(state: state) { choice in
                pendingEndRoundChoice = choice
                isShowingEndRoundFlow = false
            }
        }
        .sheet(isPresented: $isShowingRoundActions, onDismiss: {
            let action = pendingRoundAction
            pendingRoundAction = nil
            action?()
        }) {
            courseRoundActionsSheet
        }
        .sheet(isPresented: $isShowingNativeClubPicker) {
            courseClubPicker
        }
        .transaction { transaction in
            if reduceMotion { transaction.animation = nil }
        }
        .modifier(trayActionPresentations)
    }

    // The course is the planning surface. Controls enter only at its edges;
    // yardage belongs to the green and equipment range belongs to the shot origin.
    private var plannerGround: Color { Book.paper }
    private var plannerInk: Color { Book.ink }

    /// Aerial imagery is the default; the drawn page is the yardage book's own
    /// rendering of the same geometry on a quiet base map.
    private var isDrawnMap: Bool { liveMapStyleRaw == "drawn" }
    /// Marker ink that reads on either the aerial photo or the drawn page.
    private var mapMarkInk: Color { isDrawnMap ? Book.ink : .white }

    private func immersiveRoundContent(in proxy: GeometryProxy) -> some View {
        Group {
            if proxy.size.height < 420 || dynamicTypeSize >= .xxLarge {
                ScrollView {
                    VStack(spacing: 0) {
                        playingHeader
                        courseDistanceInstrument
                        liveMap.frame(height: 320)
                        playingLowerControls(in: proxy)
                    }
                }
                .background(plannerGround)
            } else {
                ZStack {
                    liveMap.ignoresSafeArea()
                        .overlay(alignment: .top) {
                            plannerGround.frame(height: proxy.safeAreaInsets.top)
                                .offset(y: -proxy.safeAreaInsets.top).allowsHitTesting(false)
                        }
                    VStack(spacing: 0) {
                        playingHeader
                            .background(alignment: .top) {
                                // Solid paper behind every line of the header (and up
                                // under the status bar), then a short fade onto the map
                                // that starts only below the last line of text.
                                VStack(spacing: 0) {
                                    plannerGround
                                    if !reduceTransparency {
                                        LinearGradient(colors: [plannerGround, plannerGround.opacity(0)], startPoint: .top, endPoint: .bottom)
                                            .frame(height: 22)
                                    }
                                }
                                .padding(.top, -proxy.safeAreaInsets.top)
                                .padding(.bottom, reduceTransparency ? 0 : -22)
                                .allowsHitTesting(false)
                            }
                        Spacer(minLength: 0)
                        playingLowerControls(in: proxy)
                    }
                }
            }
        }
        .overlay { topBannerStack(safeAreaInsetTop: 0) }
        .foregroundStyle(plannerInk)
        .animation(reduceMotion ? nil : .snappy(duration: 0.3), value: state.isShowingClubWheel)
        .onChange(of: state.isShowingClubWheel) { _, shown in
            playingPreviewClub = shown ? state.selectedClubName : nil
            // Cancel puts the plan back on the club in hand; Use moves it via the club change.
            if !shown { aimAtClubCarry() }
        }
        .onChange(of: playingPreviewClub) { _, name in
            // Previewing a club shows what it leaves: the ring moves to its carry.
            guard let name, let entry = state.clubWheelEntries.first(where: { $0.clubName == name }) else { return }
            state.placePlanningTarget(atCarryMeters: entry.displayCarryMeters)
        }
    }

    /// The page header: the hole's folio numeral, par and course, with page
    /// turns at the right edge. Tapping the folio opens the hole index.
    private var playingHeader: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 0) {
                Button { isShowingHoleInspector = true } label: {
                    // Lockup: the course line shares the numeral's baseline and
                    // the par sits above it, so both stay within the numeral's height.
                    HStack(alignment: .lastTextBaseline, spacing: 10) {
                        Text(String(format: "%02d", state.displayedHoleNumber))
                            .font(.system(size: 46, weight: .bold).width(.condensed))
                            .monospacedDigit()
                            .contentTransition(.numericText(value: Double(state.displayedHoleNumber)))
                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 6) {
                                Text("Par \(state.displayedHoleSession.par)")
                                    .font(Book.Typeface.subheading)
                                if !state.isDisplayedHoleLive {
                                    BookNote("Inspecting", color: Book.flag)
                                }
                            }
                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                Text(state.courseName)
                                    .lineLimit(1)
                                if let wind = windReading {
                                    HStack(spacing: 3) {
                                        Image(systemName: "location.north.fill")
                                            .font(.system(size: 9, weight: .bold))
                                            .rotationEffect(.degrees(wind.motion))
                                        Text("\(wind.speed) km/h").monospacedDigit()
                                    }
                                    .foregroundStyle(Book.ink)
                                    .fixedSize()
                                }
                            }
                            .font(.caption)
                            .foregroundStyle(Book.pencil)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .accessibilityLabel("\(state.courseName). Hole \(state.displayedHoleNumber), par \(state.displayedHoleSession.par).\(windReading.map { " Wind \($0.speed) kilometres per hour, \(state.windRelativeCategory.label.lowercased())." } ?? "") Inspect holes")
                playingIcon("chevron.left", label: "Previous hole", enabled: state.canInspectPreviousHole) { state.inspectPreviousHole() }
                playingIcon("chevron.right", label: "Next hole", enabled: state.canInspectNextHole) { state.inspectNextHole() }
                playingIcon("ellipsis", label: "Round actions and review") { isShowingRoundActions = true }
            }
            if !hasLiveDistance {
                Button { isShowingConditions = true } label: {
                    Label(!hasGreenReference ? "No green geometry · score this hole by hand" : state.isDisplayedHoleLive ? "GPS unavailable · reference distances from the tee" : "Inspecting · distances from the tee", systemImage: "location.slash")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Book.pencil)
                        .frame(minHeight: 32)
                }
            }
        }
        .padding(.horizontal, 18).padding(.top, 2).padding(.bottom, 10)
        // The header is paper, not map: touches anywhere on it stay here.
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }

    /// Wind as it bears on the line of play: the arrow points where the air
    /// is going, with up being toward the target.
    private var windReading: (motion: Double, speed: Int)? {
        guard state.hasUsableWindReading,
              let motion = state.windRelativeMotionDegrees,
              let snapshot = state.weatherSnapshot
        else { return nil }
        return (motion, snapshot.windSpeedKilometersPerHour)
    }

    private func playingLowerControls(in proxy: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                if state.canMarkBallOnDisplayedHole {
                    Button { state.markBall() } label: {
                        Label(state.atBallActionTitle, systemImage: state.ballMarkStatus == .marked ? "checkmark" : "scope")
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 14).frame(minHeight: 44)
                            .background(Book.leaf, in: Capsule())
                            .overlay(Capsule().strokeBorder(Book.rule))
                    }
                    .confirmationDialog(
                        "The ball's already marked a few steps from here",
                        isPresented: $state.isAskingAboutRemark,
                        titleVisibility: .visible
                    ) {
                        Button("I've hit again: mark the new spot") { state.markBall(as: .newShot) }
                        Button("Same ball: move the mark here") { state.markBall(as: .correction) }
                        Button("Cancel", role: .cancel) {}
                    }
                }
                Spacer()
                Button {
                    liveMapStyleRaw = isDrawnMap ? "aerial" : "drawn"
                } label: {
                    Label(isDrawnMap ? "Aerial" : "Drawn", systemImage: isDrawnMap ? "globe.americas" : "pencil.and.outline")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 14).frame(minHeight: 44)
                        .background(Book.leaf, in: Capsule())
                        .overlay(Capsule().strokeBorder(Book.rule))
                }
                .accessibilityLabel(isDrawnMap ? "Show aerial photo" : "Show drawn yardage page")
                Button { syncCameraToHoleFraming(animated: true) } label: {
                    Image(systemName: "location.north.line").font(.body.weight(.medium)).frame(width: 44, height: 44)
                        .background(Book.leaf, in: Circle())
                        .overlay(Circle().strokeBorder(Book.rule))
                }.accessibilityLabel("Frame current hole")
            }
            .padding(.horizontal, 16)

            VStack(spacing: 6) {
                HStack(alignment: .firstTextBaseline) {
                    BookNote(state.isShowingClubWheel ? "\(playingEntry.carrySource == .logged ? "Bag carry" : "Estimated carry")\(hasLiveDistance ? " · arc on the map" : "")" : state.isDisplayedHoleLive ? state.topBarScoreSubtitle : "Inspecting hole \(state.displayedHoleNumber)")
                    Spacer()
                    Button {
                        if state.isDisplayedHoleLive { state.presentHoleConfirmation() } else { onReviewRound() }
                    } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            BookNote("Card", color: Book.ink)
                            Text(state.roundScoreToParDisplay)
                                .font(Book.Typeface.smallFigure)
                            Image(systemName: "chevron.right").font(.caption2.weight(.bold))
                        }.frame(minHeight: 44).contentShape(Rectangle())
                    }.accessibilityLabel("\(state.isDisplayedHoleLive ? "Hole score" : "Review scores"), round score \(state.roundScoreToParDisplay)")
                }
                BookHairline()
                if state.isShowingClubWheel {
                    plannerClubSequence
                } else {
                    playingDock
                }
                HStack(spacing: 6) {
                    if state.isShowingClubWheel {
                        Button { state.dismissClubWheel() } label: { Text("Cancel").font(.subheadline).frame(minWidth: 44, minHeight: 44).contentShape(Rectangle()) }
                        Spacer()
                        Button {
                            state.dismissClubWheel()
                            isShowingNativeClubPicker = true
                        } label: {
                            Label("All clubs", systemImage: "list.bullet").font(.subheadline).frame(minHeight: 44).contentShape(Rectangle())
                        }
                        Spacer()
                        Button("Use \(PlayingInstrumentStyle.clubLabel(playingEntry.clubName))") {
                            state.selectClubFromWheel(named: playingEntry.clubName)
                        }
                        .font(.subheadline.weight(.bold))
                        .padding(.horizontal, 16).frame(minHeight: 40)
                        .foregroundStyle(Book.onStamp)
                        .background(Book.stamp, in: Capsule())
                    } else if !hasGreenReference {
                        Image(systemName: "pencil").font(.caption)
                        Text("No green on this hole's map · log shots and score by hand")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    } else if !hasSeenAimHint && state.isDisplayedHoleLive {
                        Image(systemName: "hand.point.up.left").font(.caption)
                        Text("The ring is where your club lands · hold it to move it")
                            .font(.caption).fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }
                }
                .foregroundStyle(state.isShowingClubWheel ? Book.ink : Book.pencil)
            }
            .padding(.horizontal, 20).padding(.top, 10).padding(.bottom, 10)
            .contentShape(Rectangle())
            .background {
                plannerGround
                    .padding(.top, -24)
                    .ignoresSafeArea(edges: .bottom)
                    .mask {
                        if reduceTransparency { Rectangle() }
                        else { LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .white, location: 0.14)], startPoint: .top, endPoint: .bottom) }
                    }
                    .allowsHitTesting(false)
            }
        }
        .buttonStyle(.plain)
    }

    private var playingEntry: LiveRoundState.ClubWheelEntry {
        state.clubWheelEntries.first { $0.clubName == playingPreviewClub } ?? state.selectedClubWheelEntry
    }

    /// Clubs as a ruled sequence, longest to shortest: the one being previewed
    /// stands on the rule at full size and its carry draws on the map.
    private var plannerClubSequence: some View {
        ScrollViewReader { reader in
            ScrollView(.horizontal) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(state.clubWheelEntries) { entry in
                        let selected = entry.clubName == playingEntry.clubName
                        Button { playingPreviewClub = entry.clubName } label: {
                            VStack(spacing: 3) {
                                Text(PlayingInstrumentStyle.clubLabel(entry.clubName))
                                    .font(.system(size: selected ? 40 : 24, weight: selected ? .bold : .medium).width(.condensed))
                                    .lineLimit(1).minimumScaleFactor(0.4)
                                    .frame(height: 46, alignment: .bottom)
                                Text(state.shortDistanceLabel(forMeters: entry.displayCarryMeters))
                                    .font(.caption.weight(selected ? .semibold : .regular)).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8)
                                Rectangle().fill(selected ? Book.flag : Book.rule).frame(width: selected ? 26 : 14, height: selected ? 3 : 1)
                            }
                            .foregroundStyle(selected ? Book.ink : Book.pencil)
                            .frame(width: 62, height: 78)
                            .contentShape(Rectangle())
                        }
                        .id(entry.clubName)
                        .accessibilityLabel("Preview \(entry.clubName), \(state.shortDistanceLabel(forMeters: entry.displayCarryMeters)), \(entry.carrySource == .logged ? "stored bag carry" : "estimated carry")")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
            .onAppear { reader.scrollTo(playingEntry.clubName, anchor: .center) }
            .onChange(of: playingPreviewClub) { _, name in
                guard let name else { return }
                withAnimation(reduceMotion ? nil : .snappy(duration: 0.25)) { reader.scrollTo(name, anchor: .center) }
            }
        }
        .animation(reduceMotion ? nil : .snappy(duration: 0.18), value: playingPreviewClub)
        .sensoryFeedback(.selection, trigger: playingPreviewClub)
    }

    /// The equipment line: the club in hand as a large condensed code, its
    /// carry and where that carry comes from, and the stamp that logs a shot.
    private var playingDock: some View {
        HStack(spacing: 14) {
            Button {
                if state.isDisplayedHoleLive { state.presentClubWheel() } else { state.returnToActiveHole() }
            } label: {
                HStack(alignment: .center, spacing: 12) {
                    if state.isDisplayedHoleLive {
                        Text(PlayingInstrumentStyle.clubLabel(playingEntry.clubName))
                            .font(.system(size: 50, weight: .bold).width(.condensed))
                            .lineLimit(1).minimumScaleFactor(0.5)
                            .frame(minWidth: 58, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(alignment: .firstTextBaseline, spacing: 3) {
                                Text("\(state.distanceUnit.scalarValue(fromMeters: playingEntry.displayCarryMeters))")
                                    .font(Book.Typeface.heading).monospacedDigit()
                                Text("\(state.distanceUnit.shortSuffix) carry").font(.caption).foregroundStyle(Book.pencil)
                            }
                            HStack(spacing: 4) {
                                Text(playingEntry.carrySource == .logged ? "From your bag" : "Estimated")
                                Image(systemName: "chevron.up.chevron.down").font(.caption2)
                            }
                            .font(.caption.weight(.medium))
                            .foregroundStyle(Book.pencil)
                        }
                    } else {
                        Label("Return to hole \(state.hole.number)", systemImage: "arrow.uturn.backward").font(.headline)
                    }
                }.frame(maxWidth: .infinity, minHeight: 70, alignment: .leading)
                .contentShape(Rectangle())
            }
            .accessibilityLabel(state.isDisplayedHoleLive ? "Choose club. \(playingEntry.clubName), \(state.shortDistanceLabel(forMeters: playingEntry.displayCarryMeters)), \(playingEntry.carrySource == .logged ? "stored bag carry" : "estimated carry")" : "Return to active hole")
            Button { state.presentShotLogger() } label: {
                VStack(spacing: 4) {
                    Image(systemName: "figure.golf").font(.system(size: 22, weight: .semibold))
                    Text("Log shot").font(.caption.weight(.bold))
                }
                .foregroundStyle(Book.onStamp)
                .frame(width: 78, height: 70)
                .background(Book.stamp, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .disabled(!state.canPresentShotLogger).opacity(state.canPresentShotLogger ? 1 : 0.35)
        }
    }

    private func playingIcon(_ symbol: String, label: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.body.weight(.semibold)).frame(width: 44, height: 44)
                // Plain buttons hit-test only their drawn pixels; without this the
                // 44 pt target was just the glyph and taps fell through to the map.
                .contentShape(Rectangle())
        }.buttonStyle(.plain).disabled(!enabled).opacity(enabled ? 1 : 0.25).accessibilityLabel(label)
    }

    /// Green readings written beside the green, joined by a fine leader.
    @ViewBuilder
    private var plannerGreenMarker: some View {
        if dynamicTypeSize >= .xxLarge || voiceOverEnabled {
            Image(systemName: "flag.fill").font(.title2).foregroundStyle(Book.flag)
                .shadow(color: .black.opacity(0.4), radius: 2)
                .accessibilityLabel(state.targetLabel)
        } else {
        HStack(spacing: 0) {
            Circle().fill(mapMarkInk).frame(width: 6, height: 6)
                .shadow(color: .black.opacity(isDrawnMap ? 0 : 0.5), radius: 1)
            Rectangle().fill(mapMarkInk.opacity(0.9)).frame(width: 14, height: 1.5)
                .shadow(color: .black.opacity(isDrawnMap ? 0 : 0.5), radius: 1)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(showsReferenceDistance ? "\(state.distanceUnit.scalarValue(fromMeters: state.displayedPinDistanceMeters))" : "—")
                        .font(.system(size: playingDistanceSize * 1.25, weight: .bold).width(.condensed)).monospacedDigit()
                    Text(state.distanceUnit.shortSuffix).font(.caption.weight(.semibold)).foregroundStyle(Book.pencil)
                }
                Text(state.targetLabel.uppercased()).font(Book.Typeface.noteSmall).tracking(0.5).foregroundStyle(Book.pencil)
                if showsReferenceDistance {
                    HStack(spacing: 8) {
                        Text("F \(state.distanceUnit.scalarValue(fromMeters: state.displayedFrontDistanceMeters))")
                        Text("B \(state.distanceUnit.scalarValue(fromMeters: state.displayedBackDistanceMeters))")
                    }
                    .font(.system(.caption, weight: .semibold).width(.condensed)).monospacedDigit().padding(.top, 3)
                    if state.isDisplayedHoleLive && state.hasMeaningfulPlaysLikeDelta {
                        Text("Plays \(state.distanceUnit.scalarValue(fromMeters: state.displayedPlaysLikeDistanceMeters))")
                            .font(.system(.caption, weight: .bold).width(.condensed)).monospacedDigit()
                            .foregroundStyle(Book.flag)
                    }
                }
            }
            .foregroundStyle(Book.ink)
            .padding(.horizontal, 10).padding(.vertical, 7)
            .background(Book.leaf, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).strokeBorder(Book.rule, lineWidth: 0.5))
            .shadow(color: .black.opacity(isDrawnMap ? 0.06 : 0.3), radius: isDrawnMap ? 2 : 6, y: 2)
        }
        .foregroundStyle(mapMarkInk)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(state.targetLabel), \(showsReferenceDistance ? state.shortDistanceLabel(forMeters: state.displayedPinDistanceMeters) : "unavailable"). Front \(showsReferenceDistance ? state.shortDistanceLabel(forMeters: state.displayedFrontDistanceMeters) : "unavailable"), back \(showsReferenceDistance ? state.shortDistanceLabel(forMeters: state.displayedBackDistanceMeters) : "unavailable"). \(state.isDisplayedHoleLive && state.hasMeaningfulPlaysLikeDelta ? " Plays \(state.shortDistanceLabel(forMeters: state.displayedPlaysLikeDistanceMeters))." : "") \(distanceSourceText)")
        }
    }

    // A working distance instrument gives the map its own uninterrupted stage.
    // At larger text sizes the entire composition scrolls; the map never pins
    // essential controls outside the reading order.
    private var courseRoundHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.courseName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(CourseStyle.muted)
                    Text("Hole \(state.displayedHoleNumber) · Par \(state.displayedHoleSession.par)")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(CourseStyle.ink)
                }
                Spacer(minLength: 0)
                Button { isShowingRoundActions = true } label: {
                    Image(systemName: "ellipsis")
                        .font(.headline)
                        .frame(width: 44, height: 44)
                        .background(CourseStyle.wash, in: Circle())
                }
                .accessibilityLabel("Round actions")
            }
            if state.isInspectingHole {
                Button { state.returnToActiveHole() } label: {
                    Label("Inspecting · Return to hole \(state.hole.number)", systemImage: "arrow.uturn.backward")
                        .font(.subheadline.weight(.semibold))
                        .frame(minHeight: 44)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .tint(CourseStyle.action)
    }

    private var hasGreenReference: Bool {
        state.currentHoleFeatures.contains { $0.kind == .green && !$0.coordinates.isEmpty }
    }

    private var hasLiveDistance: Bool {
        state.isDisplayedHoleLive && hasGreenReference && state.locationStatus == .ready && state.playerLocation != nil
    }

    private var showsReferenceDistance: Bool {
        hasGreenReference && (!state.isDisplayedHoleLive || hasLiveDistance)
    }

    private var courseDistanceInstrument: some View {
        VStack(alignment: .leading, spacing: 8) {
            let layout = dynamicTypeSize >= .xxLarge
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 14))
                : AnyLayout(HStackLayout(alignment: .center, spacing: 18))
            layout {
                courseDistanceValue("Front", meters: state.displayedFrontDistanceMeters, prominent: false)
                courseDistanceValue(state.targetLabel, meters: state.displayedPinDistanceMeters, prominent: true)
                courseDistanceValue("Back", meters: state.displayedBackDistanceMeters, prominent: false)
            }
            Button { isShowingConditions = true } label: {
                Label(distanceSourceText, systemImage: hasLiveDistance ? "location.fill" : "location.slash")
                    .font(.caption)
                    .multilineTextAlignment(.leading)
                    .foregroundStyle(CourseStyle.muted)
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Open weather and location details")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(CourseStyle.ground)
    }

    private var distanceSourceText: String {
        if !hasGreenReference { return "Green geometry unavailable · manual scoring available" }
        if !state.isDisplayedHoleLive { return "From tee · green centre is inferred from course geometry" }
        if !hasLiveDistance { return "\(state.playerLocationStatusText) · live distances unavailable" }
        return "\(state.playerLocationStatusText) · green centre, not surveyed pin"
    }

    private func courseDistanceValue(_ title: String, meters: Int, prominent: Bool) -> some View {
        VStack(alignment: dynamicTypeSize >= .xxLarge ? .leading : .center, spacing: 2) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundStyle(CourseStyle.muted)
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(showsReferenceDistance ? "\(state.distanceUnit.scalarValue(fromMeters: meters))" : "—")
                    .font(prominent ? .largeTitle.weight(.bold) : .title2.weight(.semibold))
                    .monospacedDigit()
                    .foregroundStyle(CourseStyle.ink)
                Text(state.distanceUnit.shortSuffix)
                    .font(.caption)
                    .foregroundStyle(CourseStyle.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: dynamicTypeSize >= .xxLarge ? .leading : .center)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title), \(showsReferenceDistance ? state.shortDistanceLabel(forMeters: meters) : "unavailable")")
    }

    private var courseMapStage: some View {
        liveMap
            .overlay(alignment: .topLeading) {
                if hasGreenReference && !hasLiveDistance {
                    Text(state.isDisplayedHoleLive ? "GPS unavailable · reference map" : "Inspecting · distances from tee")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(CourseStyle.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(CourseStyle.surface, in: Capsule())
                        .padding(12)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                Button { syncCameraToHoleFraming(animated: true) } label: {
                    Label("Recenter", systemImage: "location.north.line")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 14)
                        .frame(minHeight: 44)
                        .background(CourseStyle.surface, in: Capsule())
                }
                .tint(CourseStyle.action)
                .padding(12)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 12)
    }

    private var selectedCarrySource: String {
        let entry = state.selectedClubWheelEntry
        let distance = state.shortDistanceLabel(forMeters: entry.displayCarryMeters)
        return entry.carrySource == .logged ? "\(distance) · stored bag carry" : "\(distance) · estimated baseline"
    }

    private func courseShotActions(availableWidth: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if state.isDisplayedHoleLive {
                Button { isShowingNativeClubPicker = true } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(state.selectedClubName).font(.headline)
                            Text(selectedCarrySource).font(.caption).foregroundStyle(CourseStyle.muted)
                        }
                        Spacer(minLength: 0)
                        Label("Club", systemImage: "chevron.up.chevron.down").font(.subheadline)
                    }
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                let layout = dynamicTypeSize >= .xLarge || availableWidth < 390
                    ? AnyLayout(VStackLayout(spacing: 10))
                    : AnyLayout(HStackLayout(spacing: 10))
                layout {
                    Button { state.presentShotLogger() } label: {
                        Label("Log shot", systemImage: "plus")
                    }
                    .buttonStyle(BookStampButtonStyle())
                    .disabled(!state.canPresentShotLogger)
                    Button { state.presentHoleConfirmation() } label: {
                        Label("Hole score", systemImage: "square.and.pencil")
                            .font(.headline)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(CourseStyle.wash, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Button(action: onReviewRound) {
                    Label("Review hole \(state.displayedHoleNumber)", systemImage: "square.and.pencil")
                }
                .buttonStyle(BookStampButtonStyle())
                Button("Back to round review", action: onReviewRound)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
        .padding(.bottom, 20)
        .background(CourseStyle.ground)
        .foregroundStyle(CourseStyle.ink)
        .tint(CourseStyle.action)
    }

    /// Every club in the bag with its carry, whatever the wheel is showing,
    /// so a suggestion never hides a club.
    private var courseClubPicker: some View {
        let recommended = state.recommendedClubName.map { $0.lowercased() }
        let selected = state.selectedClubName.lowercased()
        return NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 6) {
                        Toggle("Suggest a club for each shot", isOn: Binding(
                            get: { state.isClubAutoRecommendationEnabled },
                            set: state.setClubAutoRecommendationEnabled
                        ))
                        .tint(Book.stamp)
                        .padding(.horizontal, 14)
                        .frame(minHeight: 52)
                        .background(Book.leaf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Book.rule, lineWidth: 0.5))
                        Text(state.isClubAutoRecommendationEnabled
                             ? "The suggestion matches your carries to the distance left. Choose any club to override it."
                             : "No suggestions: the full catalog and your own clubs are listed.")
                            .font(.caption)
                            .foregroundStyle(Book.pencil)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    BookGroup(state.isClubAutoRecommendationEnabled ? "Your bag" : "All clubs") {
                        ForEach(state.allChoosableClubNames, id: \.self) { club in
                            Button {
                                if state.isClubAutoRecommendationEnabled {
                                    state.selectClub(named: club)
                                } else {
                                    state.selectClubFromWheel(named: club)
                                }
                                isShowingNativeClubPicker = false
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(Book.stamp)
                                        .opacity(club.lowercased() == selected ? 1 : 0)
                                        .frame(width: 18)
                                    Text(club).font(.body.weight(club.lowercased() == selected ? .semibold : .regular))
                                    if club.lowercased() == recommended {
                                        Text("SUGGESTED").font(Book.Typeface.noteSmall).foregroundStyle(Book.stamp)
                                    }
                                    Spacer(minLength: 8)
                                    Text(state.shortDistanceLabel(forMeters: state.carryMeters(forClub: club)))
                                        .font(Book.Typeface.smallFigure)
                                        .foregroundStyle(Book.pencil)
                                }
                                .padding(.horizontal, 14)
                                .frame(minHeight: 50)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(BookRowButtonStyle())
                            .accessibilityAddTraits(club.lowercased() == selected ? .isSelected : [])
                            .accessibilityHint(club.lowercased() == recommended ? "Suggested for this shot" : "")
                        }
                    }

                    Text("Choosing a club doesn't log a shot.")
                        .font(.caption)
                        .foregroundStyle(Book.pencil)
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .bookSheetChrome()
            .navigationTitle("Choose club")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingNativeClubPicker = false }
                }
            }
        }
        .presentationBackground(Book.paper)
    }

    private func finishRoundAction(_ action: @escaping () -> Void) {
        pendingRoundAction = action
        isShowingRoundActions = false
    }

    private var courseRoundActionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(String(format: "%02d", state.hole.number))
                            .font(.system(size: 34, weight: .bold).width(.condensed)).monospacedDigit()
                        VStack(alignment: .leading, spacing: 1) {
                            Text(state.courseName).font(Book.Typeface.subheading).lineLimit(1)
                            Text("\(state.roundScoreToParDisplay) · \(state.topBarScoreSubtitle)")
                                .font(.caption).foregroundStyle(Book.pencil)
                        }
                    }

                    roundActionGroup("The round") {
                        roundActionRow("Scorecard", detail: "Review and correct every hole", symbol: "tablecells") { finishRoundAction(onReviewRound) }
                        roundActionRow("Hole index", detail: "Look ahead or back at any hole", symbol: "book.pages") { finishRoundAction { isShowingHoleInspector = true } }
                        roundActionRow("Shot history", detail: "Every shot logged this round", symbol: "clock.arrow.circlepath") { finishRoundAction { isShowingShotHistory = true } }
                        if state.isDisplayedHoleLive {
                            roundActionRow("Edit hole \(state.hole.number)", detail: "Strokes, putts and penalties", symbol: "pencil") { finishRoundAction { isShowingCurrentHoleEditor = true } }
                        }
                    }

                    if state.isDisplayedHoleLive {
                        roundActionGroup("This shot") {
                            roundActionRow("Undo last shot", symbol: "arrow.uturn.backward", enabled: state.canUndoLastShot) { finishRoundAction { state.presentUndoConfirmation() } }
                            roundActionRow("Penalty", detail: "Lost, out of bounds, unplayable, water", symbol: "exclamationmark.triangle") { finishRoundAction { state.presentQuickPenaltyPicker() } }
                            roundActionRow("Re-tee", detail: "Play again from the tee", symbol: "arrow.counterclockwise") { finishRoundAction { state.presentReteeConfirmation() } }
                            roundActionRow(state.atBallActionTitle, detail: "Measure the next shot from here", symbol: "scope", enabled: state.canMarkBallOnDisplayedHole) {
                                // After the sheet has gone, so the "new shot or correction?" question has somewhere to appear.
                                finishRoundAction { state.markBall() }
                            }
                        }
                    }

                    roundActionGroup("The map") {
                        roundActionRow("Read the green", detail: "Close up, turned to your line", symbol: "flag", enabled: state.canInspectGreen) { finishRoundAction { syncCameraToGreenInspection(animated: true) } }
                        roundActionRow(isDrawnMap ? "Aerial photo" : "Drawn page", detail: isDrawnMap ? "Satellite imagery under the plan" : "The hole drawn as a yardage book page", symbol: isDrawnMap ? "globe.americas" : "pencil.and.outline") {
                            liveMapStyleRaw = isDrawnMap ? "aerial" : "drawn"
                            isShowingRoundActions = false
                        }
                        roundActionRow("Conditions and GPS", detail: state.weatherSnapshot.map { "\($0.conditionDescription) · \($0.temperatureCelsius)°C" } ?? "Location, wind and plays-like", symbol: "wind") { finishRoundAction { isShowingConditions = true } }
                    }

                    BookNote("On the map")
                    Text("The arc across the line is your club's carry from the ball; the ring is your aim, placed at that carry until you drag it. Pairs of figures by bunkers and water are the distances to reach and to carry them.")
                        .font(.footnote).foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, -14)

                    VStack(spacing: 10) {
                        Button { finishRoundAction(onSaveAndExitRound) } label: {
                            Text("Save and leave the course")
                                .font(.headline).frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(BookStampButtonStyle(prominent: true))
                        Button { finishRoundAction { isShowingEndRoundFlow = true } } label: {
                            Text("End round…")
                                .font(.subheadline.weight(.semibold)).foregroundStyle(Book.warning)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20).padding(.top, 4).padding(.bottom, 24)
            }
            .background(Book.paper)
            .navigationTitle("Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { isShowingRoundActions = false }
                }
            }
            .foregroundStyle(Book.ink)
            .tint(Book.ink)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Book.paper)
    }

    private func roundActionGroup<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            BookNote(title)
            VStack(spacing: 0) {
                Group(subviews: content()) { rows in
                    ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                        if index > 0 { BookHairline().padding(.leading, 48) }
                        row
                    }
                }
            }
            .background(Book.leaf, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Book.rule, lineWidth: 0.5))
        }
    }

    private func roundActionRow(_ title: String, detail: String? = nil, symbol: String, enabled: Bool = true, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: symbol)
                    .font(.body.weight(.medium))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.body)
                    if let detail {
                        Text(detail).font(.caption).foregroundStyle(Book.pencil)
                    }
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Book.pencil)
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(BookRowButtonStyle())
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.4)
    }

    private var trayActionPresentations: some ViewModifier {
        FreshLiveRoundTrayActionsModifier(
            state: state,
            onUndoneToastSchedule: {
                undoneToastTask?.cancel()
                undoneToastTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2.4))
                    guard !Task.isCancelled else { return }
                    withAnimation(.easeOut(duration: 0.2)) {
                        state.acknowledgeUndoneShotPreview()
                    }
                }
            },
            quickPenaltyPicker: { quickPenaltyPicker },
            modalCanvas: Book.paper,
            surfaceLabel: surfaceLabel(for:)
        )
    }

    /// Single composite that owns the three top-of-map transient
    /// banners (shot-logged toast, holed-putt confirm pill, undo
    /// toast). Splitting them out of the main `ZStack` keeps Swift's
    /// type checker from blowing up on the body expression.
    @ViewBuilder
    private func topBannerStack(safeAreaInsetTop: CGFloat) -> some View {
        VStack {
            if isShowingShotLoggedToast {
                shotLoggedToast
                    .padding(.top, safeAreaInsetTop + 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if state.isShowingHoleConfirmationPill {
                holeConfirmationPill
                    .padding(.top, safeAreaInsetTop + 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let undonePreview = state.lastUndoneShotPreview {
                undoneShotToast(undonePreview)
                    .padding(.top, safeAreaInsetTop + 12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isShowingShotLoggedToast)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: state.isShowingHoleConfirmationPill)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: state.lastUndoneShotPreview)
    }

    /// A slip of paper laid on the course for a moment.
    private func mapNote(symbol: String, text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Book.stamp)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Book.ink)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .bookLeaf(cornerRadius: 12)
        .accessibilityElement(children: .combine)
    }

    private var shotLoggedToast: some View {
        mapNote(symbol: "checkmark", text: "Shot saved")
    }

    /// Banner that surfaces at the top of the map after a holed putt
    /// is logged. One tap commits the hole + advances; the inline
    /// "Edit" affordance opens the editor sheet for fine-grained
    /// adjustments first; the "x" dismisses the pill if the player
    /// wants to keep playing the same hole.
    private var holeConfirmationPill: some View {
        let strokeCount = state.pendingHoleScore ?? state.hole.strokeCount
        return HStack(spacing: 12) {
            Image(systemName: "flag.fill")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 0) {
                Text("Hole \(state.displayedHoleNumber) · \(strokeCount) strokes")
                    .font(.system(.headline, weight: .bold).width(.condensed))
                    .monospacedDigit()
                Text("Tap to write it on the card")
                    .font(.caption)
                    .opacity(0.8)
            }

            Spacer(minLength: 8)

            Button {
                state.dismissHoleConfirmationPill()
                isShowingCurrentHoleEditor = true
            } label: {
                Text("Edit")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Book.onStamp.opacity(0.55), lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                state.dismissHoleConfirmationPill()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Keep playing this hole")
        }
        .foregroundStyle(Book.onStamp)
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 10)
        .background(Book.stamp, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Book.ink.opacity(0.18), radius: 10, y: 4)
        .onTapGesture {
            let previousHoleNumber = state.hole.number
            guard state.confirmCurrentHoleFromDerivedValues() else { return }
            if state.hole.number == previousHoleNumber {
                onFinishHole()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to confirm this hole and advance")
    }

    private func undoneShotToast(_ preview: LiveRoundState.LoggedShotPreview) -> some View {
        mapNote(symbol: "arrow.uturn.backward", text: "Undid \(preview.clubName) · \(surfaceLabel(for: preview.surface))")
    }

    private var quickPenaltyPicker: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Adds a one-stroke penalty. Your next shot is the replay.")
                        .font(.subheadline)
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)

                    BookGroup(ruleInset: 50) {
                        ForEach(LiveRoundState.QuickPenaltyType.allCases) { type in
                            quickPenaltyOptionButton(type)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 24)
            }
            .scrollBounceBehavior(.basedOnSize)
            .bookSheetChrome()
            .navigationTitle("Penalty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        state.dismissQuickPenaltyPicker()
                    }
                }
            }
        }
        .sensoryFeedback(.warning, trigger: state.isShowingQuickPenaltyPicker)
    }

    private func quickPenaltyOptionButton(_ type: LiveRoundState.QuickPenaltyType) -> some View {
        Button {
            state.logQuickPenalty(type)
        } label: {
            HStack(spacing: 14) {
                Image(systemName: type.iconName)
                    .font(.body.weight(.medium))
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 1) {
                    Text(type.label).font(.body)
                    Text(type.subtitle)
                        .font(.caption)
                        .foregroundStyle(Book.pencil)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                Text("+1")
                    .font(.system(.subheadline, weight: .bold).width(.condensed))
                    .foregroundStyle(Book.warning)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(BookRowButtonStyle())
    }

    private func surfaceLabel(for surface: ShotEvent.Surface) -> String {
        switch surface {
        case .tee: return "tee"
        case .fairway: return "fairway"
        case .rough: return "rough"
        case .bunker: return "sand"
        case .green: return "green"
        }
    }

    private var liveMap: some View {
        MapReader { proxy in
            Map(
                position: $cameraPosition,
                bounds: mapBounds,
                interactionModes: aimMapInteractionModes
            ) {
                // The drawn page is one hole on paper: everything beyond a
                // margin around the hole's geometry is covered, as in a book.
                if isDrawnMap, let page = pageMask {
                    MapPolygon(page.sheet)
                        .foregroundStyle(Book.paper)
                        .mapOverlayLevel(level: .aboveLabels)
                    MapPolygon(coordinates: page.edge)
                        .foregroundStyle(Book.rough)
                        .stroke(Book.rule, lineWidth: 1)
                        .mapOverlayLevel(level: .aboveLabels)
                }

                ForEach(state.currentHoleFeatures) { feature in
                    overlay(for: feature)
                }

                ForEach(hazardYardages) { hazard in
                    Annotation(hazard.kind == .water ? "Water" : "Bunker", coordinate: hazard.labelCoordinate, anchor: hazard.isRightOfLine ? .leading : .trailing) {
                        hazardTag(hazard)
                    }
                    .annotationTitles(.hidden)
                }

                if state.currentHoleFeatures.contains(where: { $0.kind == .tee && !$0.coordinates.isEmpty }) && !isStandingOnTee {
                    Annotation("Tee", coordinate: state.teeCoordinate, anchor: .center) {
                        teeMarker
                    }
                    .annotationTitles(.hidden)
                }
                if hasGreenReference {
                    Annotation(state.targetLabel, coordinate: state.targetCoordinate, anchor: .leading) {
                        plannerGreenMarker
                    }
                    .annotationTitles(.hidden)
                }

                if isDrawnMap && hasGreenReference {
                    // Distances to the green centre, written at the edge of play
                    // with a short tick pointing at the line, as in a yardage book.
                    ForEach(yardageRings, id: \.label) { ring in
                        Annotation(ring.label, coordinate: ring.labelCoordinate, anchor: .trailing) {
                            HStack(spacing: 3) {
                                Text(ring.label)
                                    .font(.system(size: 10, weight: .bold).width(.condensed))
                                    .monospacedDigit()
                                Rectangle().frame(width: 8, height: 1)
                            }
                            .foregroundStyle(Book.pencil)
                        }
                        .annotationTitles(.hidden)
                    }
                }

                if state.playerLocation != nil && state.locationStatus == .ready {
                    Annotation("You", coordinate: state.playerCoordinate, anchor: .center) {
                        youMarker
                    }
                    .annotationTitles(.hidden)
                }
            }
            .mapStyle(isDrawnMap
                ? .standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false)
                : .imagery(elevation: .flat))
            // Hide MapKit's default control overlays (compass, scale, pitch toggle, user
            // location button). The screen has its own custom recenter button and tee/pin/you
            // markers, so the built-in floating widgets just clutter the imagery.
            .mapControls { }
            // Every camera frame reprojects the aim overlay only; this view's body
            // never reads the ticker, so panning doesn't redraw the screen.
            .onMapCameraChange(frequency: .continuous) { _ in
                aimTicker.advance()
            }
            .overlay {
                if state.isDisplayedHoleLive && hasGreenReference {
                    AimPlanOverlay(
                        proxy: proxy,
                        ticker: aimTicker,
                        origin: state.shotOriginCoordinate,
                        pin: state.targetCoordinate,
                        committedAim: state.planningTargetCoordinate.clCoordinate,
                        carryMetres: hasLiveDistance ? Double(playingEntry.displayCarryMeters) : 0,
                        isDrawnMap: isDrawnMap,
                        distanceLabel: { state.shortDistanceLabel(forMeters: $0) },
                        clubForDistance: { state.suggestedClubName(forMeters: $0).map(PlayingInstrumentStyle.clubLabel) },
                        clampToHole: { state.clampedPlanningTarget(for: $0) },
                        onDraggingChange: { isAimDragging = $0 },
                        onCommit: { state.movePlanningTarget(to: $0) }
                    )
                }
            }
        }
    }

    /// Map gestures need to be disabled while the user is actively dragging the aim crosshair,
    /// otherwise MapKit's pan recogniser fights the SwiftUI drag and the map slides under the
    /// finger. The overlay reports release and cancellation alike, so the map
    /// always gets its gestures back. We allow pitch and rotate alongside pan/zoom so power users can re-orient
    /// the perspective camera if they want a different look at the hole.
    private var aimMapInteractionModes: MapInteractionModes {
        isAimDragging ? [] : [.pan, .zoom, .pitch, .rotate]
    }

    /// Bounds the camera to the whole course so the user can zoom from a tight green
    /// view all the way out to the full layout (with a bit of context around the
    /// edges). Previously this was scoped to the displayed hole, which capped the
    /// zoom-out at about one-hole-diagonal and made the experience feel claustrophobic.
    private var courseMapCameraBounds: MapCameraBounds {
        let bounds = state.courseBounds
        let southWest = MKMapPoint(
            CLLocationCoordinate2D(latitude: bounds.minLatitude, longitude: bounds.minLongitude)
        )
        let northEast = MKMapPoint(
            CLLocationCoordinate2D(latitude: bounds.maxLatitude, longitude: bounds.maxLongitude)
        )
        let origin = MKMapPoint(
            x: min(southWest.x, northEast.x),
            y: min(southWest.y, northEast.y)
        )
        let size = MKMapSize(
            width: max(abs(northEast.x - southWest.x), 1),
            height: max(abs(northEast.y - southWest.y), 1)
        )

        // 110m floor lets the user zoom in tight on a green; the course-diagonal-based
        // ceiling means the user can always pull back to see the whole layout, plus a
        // bit of surrounding terrain. The 2.5km absolute floor on `maximumDistance`
        // covers small/synthetic test courses where the diagonal is under-reported.
        let courseDiagonalMeters = state.courseDiagonalMeters
        return MapCameraBounds(
            centerCoordinateBounds: MKMapRect(origin: origin, size: size),
            minimumDistance: 110,
            maximumDistance: max(courseDiagonalMeters * 1.4, 2_500)
        )
    }

    /// The whole course is always reachable: framing a green or a hole
    /// moves the camera but never fences it in.
    private var mapBounds: MapCameraBounds {
        courseMapCameraBounds
    }

    /// The tee block, as the mark draws it.
    private var teeMarker: some View {
        RoundedRectangle(cornerRadius: 2.5, style: .continuous)
            .fill(Book.stamp)
            .frame(width: 16, height: 9)
            .overlay(RoundedRectangle(cornerRadius: 2.5, style: .continuous).strokeBorder(Book.leaf, lineWidth: 1.5))
            .shadow(color: .black.opacity(isDrawnMap ? 0.15 : 0.45), radius: 2, y: 1)
            .accessibilityLabel("Tee")
    }

    /// The ball: the one flag-red mark that is the player.
    private var youMarker: some View {
        ZStack {
            Circle().fill(Book.flag.opacity(0.18)).frame(width: 30, height: 30)
            Circle().fill(Book.leaf).frame(width: 16, height: 16)
            Circle().fill(Book.flag).frame(width: 9, height: 9)
        }
        .shadow(color: .black.opacity(isDrawnMap ? 0.15 : 0.4), radius: 2, y: 1)
        .accessibilityLabel(isStandingOnTee ? "You, on the tee" : "You")
    }

    private func overlay(for feature: SwingPalCourse.Hole.Feature) -> some MapContent {
        featureShape(for: feature)
            .mapOverlayLevel(level: isDrawnMap ? .aboveLabels : .aboveRoads)
    }

    @MapContentBuilder
    private func featureShape(for feature: SwingPalCourse.Hole.Feature) -> some MapContent {
        let coordinates = feature.coordinates.map(\.clCoordinate)
        let drawn = isDrawnMap

        switch feature.kind {
        case .fairway:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(drawn ? Book.fairway : Color(red: 0.34, green: 0.58, blue: 0.31).opacity(0.28))
                .stroke(drawn ? Book.fairwayEdge : Color.white.opacity(0.18), lineWidth: 1)
        case .green:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(drawn ? Book.green : Color(red: 0.63, green: 0.84, blue: 0.55).opacity(0.42))
                .stroke(drawn ? Book.greenContour : Color.white.opacity(0.22), lineWidth: 1)
        case .bunker:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(drawn ? Book.sand : Color(red: 0.90, green: 0.81, blue: 0.58).opacity(0.50))
                .stroke(drawn ? Book.sandDot : Color.white.opacity(0.22), lineWidth: 1)
        case .water:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(drawn ? Book.water : Color(red: 0.30, green: 0.62, blue: 0.92).opacity(0.45))
                .stroke(drawn ? Book.waterLine : Color.white.opacity(0.20), lineWidth: 1)
        case .tee:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(drawn ? Book.ink.opacity(0.75) : Color.white.opacity(0.18))
                .stroke(drawn ? Book.ink : Color.white.opacity(0.18), lineWidth: 1)
        case .layup:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(drawn ? Color.clear : Color.black.opacity(0.12))
                .stroke(drawn ? Book.pencil : Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    // MARK: Yardage-book annotations

    /// The ball's position for measuring: the shot origin on the live hole,
    /// the tee when looking ahead at another hole.
    private var measuringOrigin: CLLocationCoordinate2D {
        state.isDisplayedHoleLive ? state.shotOriginCoordinate : state.teeCoordinate
    }

    private var hazardYardages: [HoleMapGeometry.HazardYardage] {
        guard hasGreenReference, dynamicTypeSize < .xxLarge else { return [] }
        let origin = measuringOrigin
        let pin = state.targetCoordinate
        let key = String(format: "%d|%.5f,%.5f|%.5f,%.5f", state.displayedHoleNumber, origin.latitude, origin.longitude, pin.latitude, pin.longitude)
        return drawingCache.hazards(for: key) {
            HoleMapGeometry.hazardYardages(features: state.currentHoleFeatures, origin: origin, pin: pin)
        }
    }

    /// Reach and carry, written beside the hazard: the near edge in pencil,
    /// the far edge in ink.
    private func hazardTag(_ hazard: HoleMapGeometry.HazardYardage) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Circle()
                .fill(hazard.kind == .water ? Book.waterLine : Book.sandDot)
                .frame(width: 6, height: 6)
                .alignmentGuide(.firstTextBaseline) { $0[.bottom] - 1 }
            Text("\(state.distanceUnit.scalarValue(fromMeters: hazard.reachMetres))")
                .foregroundStyle(Book.pencil)
            Text("\(state.distanceUnit.scalarValue(fromMeters: hazard.carryMetres))")
                .fontWeight(.bold)
        }
        .font(.system(size: 12, weight: .semibold).width(.condensed))
        .monospacedDigit()
        .foregroundStyle(Book.ink)
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Book.leaf.opacity(reduceTransparency ? 1 : 0.94), in: Capsule())
        .overlay(Capsule().strokeBorder(Book.rule, lineWidth: 0.5))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(hazard.kind == .water ? "Water" : "Bunker"): reach \(state.shortDistanceLabel(forMeters: hazard.reachMetres)), carry \(state.shortDistanceLabel(forMeters: hazard.carryMetres))")
    }

    /// When the ball is on the tee the tee marker would sit under the
    /// player's own mark, so only one is drawn.
    private var isStandingOnTee: Bool {
        hasLiveDistance && HoleMapGeometry.distance(state.playerCoordinate, state.teeCoordinate) < 25
    }

    private var pageMask: (sheet: MKPolygon, edge: [CLLocationCoordinate2D])? {
        drawingCache.page(for: state.displayedHoleNumber) {
            let points = state.currentHoleFeatures.flatMap { $0.coordinates.map(\.clCoordinate) }
            guard let edge = HoleMapGeometry.pageOutline(around: points, bufferMetres: 45),
                  let centre = HoleMapGeometry.centroid(of: points)
            else { return nil }
            let window = MKPolygon(coordinates: edge, count: edge.count)
            let paper = HoleMapGeometry.sheet(around: centre, halfSizeMetres: 8_000)
            return (MKPolygon(coordinates: paper, count: paper.count, interiorPolygons: [window]), edge)
        }
    }

    /// Keeps the aim where the club in hand lands whenever the club, the
    /// hole or the ball changes. Dragging the ring still overrides it.
    private func aimAtClubCarry() {
        guard state.isDisplayedHoleLive, hasGreenReference else { return }
        state.placePlanningTarget(atCarryMeters: state.selectedClubWheelEntry.displayCarryMeters)
    }

    private struct YardageRing {
        let label: String
        let metres: CLLocationDistance
        let labelCoordinate: CLLocationCoordinate2D
    }

    /// Distances to the green centre every 50, out to the length of the
    /// hole, placed at the edge of play on the tee side. Drawn mode only.
    private var yardageRings: [YardageRing] {
        let green = state.targetCoordinate
        let tee = state.teeCoordinate
        let holeLength = CLLocation(latitude: green.latitude, longitude: green.longitude)
            .distance(from: CLLocation(latitude: tee.latitude, longitude: tee.longitude))
        guard holeLength > 60 else { return [] }
        let unitMetres = state.distanceUnit == .yards ? 0.9144 : 1.0
        let cosLat = cos(green.latitude * .pi / 180)
        let east = (tee.longitude - green.longitude) * 111_320 * cosLat
        let north = (tee.latitude - green.latitude) * 110_540
        let axis = atan2(north, east)
        func offset(_ metres: Double, _ angle: Double) -> CLLocationCoordinate2D {
            CLLocationCoordinate2D(
                latitude: green.latitude + metres * sin(angle) / 110_540,
                longitude: green.longitude + metres * cos(angle) / (111_320 * cosLat)
            )
        }
        return stride(from: 50, through: 350, by: 50).compactMap { step in
            let metres = Double(step) * unitMetres
            guard metres < holeLength - 15 else { return nil }
            let spread = min(0.5, 70 / metres)
            // Written on the side away from the green tag, which reads to the right.
            let coordinate = offset(metres, axis - min(spread, 45 / metres))
            return YardageRing(label: "\(step)", metres: metres, labelCoordinate: coordinate)
        }
    }

    private func syncCamera(to region: MKCoordinateRegion, animated: Bool = false) {
        if animated && !reduceMotion {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.92)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func syncCamera(to camera: MapCamera, animated: Bool = false) {
        if animated && !reduceMotion {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.92)) {
                cameraPosition = .camera(camera)
            }
        } else {
            cameraPosition = .camera(camera)
        }
    }

    /// Centralised hole-framing logic shared by the initial appear, hole-change,
    /// inspect-toggle, and recenter-button paths. The flat playing map leaves
    /// space above the green for yardages and below the tee for the open fan.
    private func syncCameraToHoleFraming(animated: Bool = false) {
        let spec = state.teePerspectiveCameraSpec
        let camera = MapCamera(
            centerCoordinate: CLLocationCoordinate2D(
                latitude: state.teeCoordinate.latitude + (state.targetCoordinate.latitude - state.teeCoordinate.latitude) * 0.30,
                longitude: state.teeCoordinate.longitude + (state.targetCoordinate.longitude - state.teeCoordinate.longitude) * 0.30
            ),
            distance: spec.distance * (hasLiveDistance ? 2.2 : 2.5),
            heading: spec.heading,
            pitch: 0
        )
        syncCamera(to: camera, animated: animated)
    }

    /// Drops the camera onto the current hole's green for an approach
    /// read. Falls back silently if no green polygon exists for the
    /// displayed hole — the launcher tile is also disabled in that case
    /// (`state.canInspectGreen`), but we no-op here too so callers (e.g.
    /// future shortcuts, watch hand-off) don't have to gate themselves.
    private func syncCameraToGreenInspection(animated: Bool = true) {
        guard let spec = state.greenInspectionCameraSpec else { return }
        let camera = MapCamera(
            centerCoordinate: spec.center,
            distance: spec.distance,
            heading: spec.heading,
            pitch: spec.pitch
        )
        syncCamera(to: camera, animated: animated)
    }
}

private extension SwingPalCourse.Coordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

private extension LiveRoundState.MapCoordinate {
    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// Local floating materials preserve the course as the primary surface.
/// Reduce Transparency substitutes an opaque surface with the same boundary.
private enum PlayingInstrumentStyle {
    static let surface = Color(red: 0.055, green: 0.105, blue: 0.095)
    static let text = Color(red: 0.96, green: 0.98, blue: 0.95)
    static let secondary = Color(red: 0.72, green: 0.79, blue: 0.75)
    static let accent = Color(red: 0.83, green: 0.94, blue: 0.64)
    static let actionFill = Color(red: 0.95, green: 0.97, blue: 0.91)
    static let edge = Color(red: 0.30, green: 0.39, blue: 0.35)

    static func clubLabel(_ name: String) -> String {
        switch name.lowercased() {
        case "driver": return "Dr"
        case "putter": return "Pt"
        case "pitching wedge": return "PW"
        case "gap wedge", "approach wedge": return "GW"
        case "sand wedge": return "SW"
        case "lob wedge": return "LW"
        default:
            return name.replacingOccurrences(of: "-iron", with: "i", options: .caseInsensitive)
                .replacingOccurrences(of: " Iron", with: "i", options: .caseInsensitive)
                .replacingOccurrences(of: "-wood", with: "w", options: .caseInsensitive)
                .replacingOccurrences(of: "-hybrid", with: "h", options: .caseInsensitive)
        }
    }
}
