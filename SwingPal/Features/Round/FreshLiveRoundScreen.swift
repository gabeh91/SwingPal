import SwiftUI
import MapKit

enum FreshLiveRoundClubWheelGeometry {
    /// Default angular stickiness margin (as a fraction of one
    /// `angleStep`). At 0.20 the touch must move past the midpoint plus
    /// 20 % of a sector before the hover flips to an adjacent spoke,
    /// which is enough to absorb small accidental drifts (e.g. drifting
    /// upward toward the centre while resting on a side spoke) without
    /// feeling sluggish for deliberate angular sweeps.
    static let defaultAngularStickinessFraction: Double = 0.20

    /// Finds the club whose spoke is nearest to the given screen
    /// `location`, accounting for the wheel's rotation around the
    /// currently selected entry.
    ///
    /// `FreshLiveRoundClubWheelLayout.entryPosition` rotates the layout
    /// so the *selected* entry sits at the top (`-π/2`), with the rest
    /// fanning out clockwise. The hover-hit math has to apply the same
    /// rotation, otherwise the angle the player's finger points to maps
    /// onto an unrotated index and the wheel "selects in reverse" the
    /// further the user has rotated the wheel from its initial position.
    ///
    /// `previousHoveredClubName` enables angular hysteresis: once a
    /// spoke has been engaged during a drag, small drifts past the
    /// boundary into the adjacent sector won't flip the hover. The
    /// player has to deliberately move *past* the midpoint plus a
    /// stickiness margin before the wheel re-targets. This is what
    /// makes the wheel feel "anchored" rather than springy when the
    /// player drifts their finger toward the chrome's centre.
    static func hoveredClubName(
        for location: CGPoint,
        center: CGPoint,
        clubNames: [String],
        segmentDistance: CGFloat,
        entrySize: CGSize,
        innerSelectionRadius: CGFloat,
        selectedIndex: Int = 0,
        previousHoveredClubName: String? = nil,
        angularStickinessFraction: Double = FreshLiveRoundClubWheelGeometry.defaultAngularStickinessFraction
    ) -> String? {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt((dx * dx) + (dy * dy))
        let outerSelectionRadius = segmentDistance + hypot(entrySize.width / 2, entrySize.height / 2)
        guard distance >= innerSelectionRadius, distance <= outerSelectionRadius else {
            return nil
        }

        let count = max(clubNames.count, 1)
        var angle = Double(atan2(Double(dy), Double(dx))) + (.pi / 2)
        if angle < 0 {
            angle += (2 * .pi)
        }
        let angleStep = (2 * Double.pi) / Double(count)
        let rawIndex = Int(round(angle / angleStep)) % count
        // Re-apply the wheel's rotation: relativeIndex 0 always sits at
        // the top, and that slot belongs to `selectedIndex`. Adding the
        // selected offset in (mod count) lands us back on the entry
        // visually under the player's finger.
        let adjustedIndex = ((rawIndex + selectedIndex) % count + count) % count

        // Fast path when there's no previous hover or the candidate is
        // the same: just return the natural pick.
        guard let previousName = previousHoveredClubName,
              let previousAdjustedIndex = clubNames.firstIndex(of: previousName),
              previousAdjustedIndex != adjustedIndex
        else {
            return clubNames[adjustedIndex]
        }

        // Hysteresis: compute the angular distance from the touch to
        // the *previous* spoke's centre (in the rotated frame) and only
        // flip to the new candidate when we're far enough past the
        // midpoint (`angleStep / 2`).
        let previousRelativeIndex = previousAdjustedIndex - selectedIndex
        let normalizedPrevious = Self.wrapAngle(Double(previousRelativeIndex) * angleStep)
        var deltaAngle = angle - normalizedPrevious
        if deltaAngle > .pi { deltaAngle -= 2 * .pi }
        if deltaAngle < -.pi { deltaAngle += 2 * .pi }
        let stickinessThreshold = (angleStep / 2) + (angleStep * angularStickinessFraction)
        if abs(deltaAngle) < stickinessThreshold {
            return clubNames[previousAdjustedIndex]
        }
        return clubNames[adjustedIndex]
    }

    /// Wraps an angle into `[0, 2π)` so we can safely diff it against a
    /// touch's `angle` value (which is already wrapped).
    private static func wrapAngle(_ angle: Double) -> Double {
        let twoPi = 2 * Double.pi
        let modulo = angle.truncatingRemainder(dividingBy: twoPi)
        return modulo < 0 ? modulo + twoPi : modulo
    }
}

enum FreshLiveRoundTextContrast: Equatable {
    case darkInk
    case lightInk
}

struct FreshLiveRoundChromeMetrics {
    let launcherHorizontalInset: CGFloat
    let launcherContentPadding: CGFloat
    let topPanelHorizontalPadding: CGFloat
    let topPanelVerticalPadding: CGFloat

    static let standard = FreshLiveRoundChromeMetrics(
        launcherHorizontalInset: 0,
        launcherContentPadding: 20,
        topPanelHorizontalPadding: 12,
        topPanelVerticalPadding: 12
    )
}

enum FreshLiveRoundTopPanelDensity {
    case compact
    case regular
}

struct FreshLiveRoundTopPanelLayout {
    let density: FreshLiveRoundTopPanelDensity
    let panelMinHeight: CGFloat
    let rowSpacing: CGFloat
    let distanceCardSpacing: CGFloat
    let distanceCardMinHeight: CGFloat
    /// Font size used for the small "satellite" distance numbers
    /// (Front / Back, recommended-club tile). The hero number uses
    /// `heroValueFontSize` for a much larger weight.
    let distanceValueFontSize: CGFloat
    /// Font size for the centred hero distance number in the top
    /// panel's second row. Sized intentionally larger than the
    /// satellite numbers so the eye lands on the pin distance
    /// (or putt distance on the green) before anything else.
    let heroValueFontSize: CGFloat
    let edgeMetricWidth: CGFloat
    let navButtonSize: CGFloat
    let centerHorizontalPadding: CGFloat
    let prefersCondensedHoleTitle: Bool

    static func resolve(containerSize: CGSize) -> FreshLiveRoundTopPanelLayout {
        let compact = containerSize.width < 390 || containerSize.height < 760
        let prefersCondensedHoleTitle = containerSize.width < 410

        if compact {
            return FreshLiveRoundTopPanelLayout(
                density: .compact,
                panelMinHeight: 142,
                rowSpacing: 8,
                distanceCardSpacing: 8,
                distanceCardMinHeight: 78,
                distanceValueFontSize: 18,
                heroValueFontSize: 40,
                edgeMetricWidth: 72,
                navButtonSize: 32,
                centerHorizontalPadding: 8,
                prefersCondensedHoleTitle: true
            )
        }

        return FreshLiveRoundTopPanelLayout(
            density: .regular,
            panelMinHeight: 168,
            rowSpacing: 10,
            distanceCardSpacing: 10,
            distanceCardMinHeight: 90,
            distanceValueFontSize: 20,
            heroValueFontSize: 48,
            edgeMetricWidth: 80,
            navButtonSize: 36,
            centerHorizontalPadding: 10,
            prefersCondensedHoleTitle: prefersCondensedHoleTitle
        )
    }

    static func compactHoleTitle(for holeNumber: Int) -> String {
        "H\(holeNumber)"
    }

    func holeTitle(for holeNumber: Int) -> String {
        if density == .compact || prefersCondensedHoleTitle {
            return Self.compactHoleTitle(for: holeNumber)
        }
        return "Hole \(holeNumber)"
    }
}

struct FreshLiveRoundPalette {
    let primaryTextContrast: FreshLiveRoundTextContrast
    let secondaryTextContrast: FreshLiveRoundTextContrast
    let unselectedChipUsesProminentFill: Bool
    let loggerOptionUsesTintedFill: Bool
    let chromeTintOpacity: Double
    let panelFillOpacity: Double
    let secondaryFillOpacity: Double
    let tertiaryFillOpacity: Double
    let wheelEntryFillOpacity: Double
    let wheelCenterFillOpacity: Double
    let chromeTint: Color
    let panelFill: Color
    let secondaryFill: Color
    let tertiaryFill: Color
    let border: Color
    let primaryTextColor: Color
    let secondaryTextColor: Color
    let tertiaryTextColor: Color
    let accent: Color
    let accentForeground: Color
    let quietIcon: Color
    let scrim: Color
    let loggerOptionFill: Color
    let mapLabelFill: Color
    let wheelRingStroke: Color
    let wheelEntryFill: Color
    let wheelCenterFill: Color
    /// Soft radial halo painted *behind* the club wheel so it lifts off
    /// the scrim and reads as the focal element. Used as the inner
    /// stop of a `RadialGradient(... .clear)` — the outer stop is
    /// always `.clear` so the backdrop blends seamlessly into the scrim.
    let wheelBackdrop: Color
    let modalCanvas: Color
    let glassHighlight: Color
    let glassGlow: Color
    let shadowColor: Color

    static func forColorScheme(_ colorScheme: ColorScheme) -> FreshLiveRoundPalette {
        switch colorScheme {
        case .dark:
            return FreshLiveRoundPalette(
                primaryTextContrast: .lightInk,
                secondaryTextContrast: .lightInk,
                unselectedChipUsesProminentFill: false,
                loggerOptionUsesTintedFill: true,
                chromeTintOpacity: 0.26,
                panelFillOpacity: 0.16,
                secondaryFillOpacity: 0.22,
                tertiaryFillOpacity: 0.14,
                wheelEntryFillOpacity: 0.16,
                wheelCenterFillOpacity: 0.30,
                chromeTint: Color(red: 0.05, green: 0.08, blue: 0.07).opacity(0.26),
                panelFill: Color(red: 0.11, green: 0.14, blue: 0.13).opacity(0.68),
                secondaryFill: Color(red: 0.13, green: 0.16, blue: 0.15).opacity(0.78),
                tertiaryFill: Color(red: 0.16, green: 0.19, blue: 0.18).opacity(0.84),
                border: Color.white.opacity(0.36),
                primaryTextColor: Color.white.opacity(0.96),
                secondaryTextColor: Color.white.opacity(0.86),
                tertiaryTextColor: Color.white.opacity(0.68),
                accent: ShellTokens.ColorRole.pine500,
                accentForeground: .white,
                quietIcon: Color.white.opacity(0.90),
                scrim: Color.black.opacity(0.28),
                loggerOptionFill: Color(red: 0.15, green: 0.17, blue: 0.16).opacity(0.92),
                mapLabelFill: Color.black.opacity(0.58),
                wheelRingStroke: Color.white.opacity(0.24),
                wheelEntryFill: Color(red: 0.16, green: 0.19, blue: 0.18).opacity(0.86),
                wheelCenterFill: Color(red: 0.10, green: 0.13, blue: 0.12).opacity(0.92),
                wheelBackdrop: Color.black.opacity(0.52),
                modalCanvas: Color(red: 0.06, green: 0.08, blue: 0.07),
                glassHighlight: Color.white.opacity(0.22),
                glassGlow: Color.white.opacity(0.06),
                shadowColor: Color.black.opacity(0.28)
            )
        default:
            return FreshLiveRoundPalette(
                primaryTextContrast: .darkInk,
                secondaryTextContrast: .darkInk,
                unselectedChipUsesProminentFill: false,
                loggerOptionUsesTintedFill: true,
                chromeTintOpacity: 0.08,
                panelFillOpacity: 0.055,
                secondaryFillOpacity: 0.055,
                tertiaryFillOpacity: 0.032,
                wheelEntryFillOpacity: 0.12,
                wheelCenterFillOpacity: 0.18,
                chromeTint: Color(red: 0.93, green: 0.95, blue: 0.89).opacity(0.08),
                panelFill: Color.white.opacity(0.055),
                secondaryFill: Color.white.opacity(0.055),
                tertiaryFill: Color.white.opacity(0.032),
                border: Color.white.opacity(0.34),
                primaryTextColor: ShellTokens.ColorRole.textPrimary,
                secondaryTextColor: ShellTokens.ColorRole.textSecondary,
                tertiaryTextColor: ShellTokens.ColorRole.textTertiary,
                accent: ShellTokens.ColorRole.pine700,
                accentForeground: .white,
                quietIcon: ShellTokens.ColorRole.textPrimary,
                scrim: Color.black.opacity(0.08),
                loggerOptionFill: Color.white.opacity(0.14),
                mapLabelFill: Color.black.opacity(0.32),
                wheelRingStroke: Color.white.opacity(0.24),
                wheelEntryFill: Color.white.opacity(0.12),
                wheelCenterFill: Color.white.opacity(0.18),
                wheelBackdrop: Color.black.opacity(0.32),
                modalCanvas: Color(red: 0.95, green: 0.96, blue: 0.92),
                glassHighlight: Color.white.opacity(0.42),
                glassGlow: Color.white.opacity(0.14),
                shadowColor: Color.black.opacity(0.08)
            )
        }
    }
}

enum FreshLiveRoundGlassCapabilities {
    static var supportsNativeGlass: Bool {
        if #available(iOS 26.0, *) {
            return true
        }
        return false
    }
}

enum FreshLiveRoundNativeGlassKind: Equatable {
    case regular
    case clear
}

enum FreshLiveRoundNativeGlassPolicy {
    static let primaryChrome: FreshLiveRoundNativeGlassKind = .regular
    static let embeddedChrome: FreshLiveRoundNativeGlassKind = .regular
}

enum FreshLiveRoundHUDInteractionPolicy {
    static let usesDedicatedTopPanelGestureShield = true
    static let topPanelGestureShieldUsesBackgroundSizing = true
}

enum FreshLiveRoundLauncherLayoutPolicy {
    static let liveActionsBaseHeight: CGFloat = 360
    static let liveExpandedBaseHeight: CGFloat = 620
    static let inspectionActionsBaseHeight: CGFloat = 360
    static let inspectionExpandedBaseHeight: CGFloat = 620
    static let maxExpandedHeightRatio: CGFloat = 0.78
}

struct FreshLiveRoundLauncherDetentHeights {
    let collapsed: CGFloat
    let actions: CGFloat
    let expanded: CGFloat
}

enum FreshLiveRoundLauncherSnapPolicy {
    private static let minimumThreshold: CGFloat = 36
    private static let maximumThreshold: CGFloat = 84
    private static let thresholdRatio: CGFloat = 0.24
    private static let momentumLimit: CGFloat = 44

    static func targetDetent(
        from currentDetent: LiveRoundState.LauncherDetent,
        translation: CGFloat,
        predictedEndTranslation: CGFloat,
        heights: FreshLiveRoundLauncherDetentHeights
    ) -> LiveRoundState.LauncherDetent {
        let effectiveTranslation = translation + clampedMomentumDelta(
            predictedEndTranslation - translation
        )

        switch currentDetent {
        case .collapsed:
            let upwardThreshold = threshold(
                from: heights.collapsed,
                to: heights.actions
            )
            return effectiveTranslation <= -upwardThreshold ? .actions : .collapsed
        case .actions:
            let upwardThreshold = threshold(
                from: heights.actions,
                to: heights.expanded
            )
            let downwardThreshold = threshold(
                from: heights.actions,
                to: heights.collapsed
            )

            if effectiveTranslation <= -upwardThreshold {
                return .expanded
            }
            if effectiveTranslation >= downwardThreshold {
                return .collapsed
            }
            return .actions
        case .expanded:
            let downwardThreshold = threshold(
                from: heights.expanded,
                to: heights.actions
            )
            return effectiveTranslation >= downwardThreshold ? .actions : .expanded
        }
    }

    private static func threshold(from origin: CGFloat, to target: CGFloat) -> CGFloat {
        let distance = abs(target - origin)
        return min(max(distance * thresholdRatio, minimumThreshold), maximumThreshold)
    }

    private static func clampedMomentumDelta(_ delta: CGFloat) -> CGFloat {
        min(max(delta, -momentumLimit), momentumLimit)
    }
}

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

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: Binding(
                get: { state.isShowingQuickPenaltyPicker },
                set: { if !$0 { state.dismissQuickPenaltyPicker() } }
            )) {
                quickPenaltyPicker()
                    .presentationDetents([.medium])
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

private struct FreshLiveRoundGlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let palette: FreshLiveRoundPalette
    let tint: Color
    let material: Material
    let nativeGlass: FreshLiveRoundNativeGlassKind

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .glassEffect(nativeGlass == .clear ? .clear : .regular, in: shape)
                .overlay {
                    shape
                        .stroke(palette.border.opacity(0.72), lineWidth: 1)
                }
        } else {
            content
                .background(material, in: shape)
                .background(tint, in: shape)
                .overlay {
                    shape
                        .fill(
                            LinearGradient(
                                colors: [
                                    palette.glassHighlight,
                                    palette.glassGlow,
                                    .clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .blendMode(.screen)
                        .allowsHitTesting(false)
                }
                .overlay {
                    shape
                        .stroke(palette.border, lineWidth: 1)
                }
        }
    }
}

private extension View {
    func freshGlass<S: Shape>(
        _ shape: S,
        palette: FreshLiveRoundPalette,
        tint: Color,
        material: Material = .thinMaterial,
        nativeGlass: FreshLiveRoundNativeGlassKind = .regular
    ) -> some View {
        modifier(FreshLiveRoundGlassSurface(shape: shape, palette: palette, tint: tint, material: material, nativeGlass: nativeGlass))
    }

    func freshRoundSheetCanvas(palette: FreshLiveRoundPalette) -> some View {
        background(palette.modalCanvas.ignoresSafeArea())
            .tint(palette.accent)
    }

    func freshRoundInputFieldStyle(palette: FreshLiveRoundPalette) -> some View {
        font(.subheadline)
            .foregroundStyle(palette.primaryTextColor)
            .tint(palette.accent)
            .padding(.horizontal, ShellTokens.Spacing.x14)
            .padding(.vertical, ShellTokens.Spacing.x14)
            .background(palette.secondaryFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
    }

    func freshRoundListChrome(palette: FreshLiveRoundPalette) -> some View {
        scrollContentBackground(.hidden)
            .background(palette.modalCanvas)
            .tint(palette.accent)
    }
}

struct FreshLiveRoundClubWheelLayout {
    let center: CGPoint
    let outerRadius: CGFloat
    let chromeDiameter: CGFloat
    let segmentDistance: CGFloat
    let entrySize: CGSize
    let innerSelectionRadius: CGFloat
    let orbitRingDiameter: CGFloat

    static func resolve(
        anchorFrame: CGRect,
        safeAreaInsets: EdgeInsets,
        containerSize: CGSize,
        entryCount: Int
    ) -> FreshLiveRoundClubWheelLayout {
        let outerRadius = min(156, max(144, containerSize.width * 0.39))
        let chromeDiameter = outerRadius * 2
        let entrySize = CGSize(width: min(96, max(88, containerSize.width * 0.23)), height: 74)
        let segmentDistance = outerRadius - 20
        let innerSelectionRadius = max(54, outerRadius * 0.45)
        let orbitRingDiameter = segmentDistance * 2
        let usableMinY = safeAreaInsets.top + outerRadius + 16
        // Reserve room *below* the chrome for the Auto/Manual toggle pill
        // (52pt gap + ~44pt pill height + 16pt breathing room).
        let usableMaxY = containerSize.height - safeAreaInsets.bottom - outerRadius - 112
        let centeredY = min(max(containerSize.height / 2, usableMinY), usableMaxY)
        let preferredCenter = CGPoint(
            x: containerSize.width / 2,
            y: centeredY
        )

        return FreshLiveRoundClubWheelLayout(
            center: preferredCenter,
            outerRadius: outerRadius,
            chromeDiameter: chromeDiameter,
            segmentDistance: segmentDistance,
            entrySize: entrySize,
            innerSelectionRadius: innerSelectionRadius,
            orbitRingDiameter: orbitRingDiameter
        )
    }

    func entryPosition(
        for index: Int,
        count: Int,
        selectedIndex: Int,
        anchorFrame: CGRect
    ) -> CGPoint {
        let angleStep = (2 * Double.pi) / Double(max(count, 1))
        let relativeIndex = index - selectedIndex
        let angle = (-Double.pi / 2) + (angleStep * Double(relativeIndex))

        return CGPoint(
            x: center.x + (CGFloat(cos(angle)) * segmentDistance),
            y: center.y + (CGFloat(sin(angle)) * segmentDistance)
        )
    }
}

/// Eight equal sectors of a compass-style shot outcome ring, plus a
/// resolved (direction, distance) pair.
///
/// Indexing is clockwise starting from the top (`long` = north, 0°).
enum FreshLiveRoundShotOutcomeNode: Int, CaseIterable {
    case long = 0       // N
    case longRight = 1  // NE
    case right = 2      // E
    case shortRight = 3 // SE
    case short = 4      // S
    case shortLeft = 5  // SW
    case left = 6       // W
    case longLeft = 7   // NW

    /// 0 = up (N), increases clockwise.
    var midAngleDegrees: Double {
        Double(rawValue) * 45
    }

    var distance: ShotEvent.DistanceResult {
        switch self {
        case .long, .longRight, .longLeft: return .long
        case .short, .shortRight, .shortLeft: return .short
        case .right, .left: return .onNumber
        }
    }

    /// Whether this sector has a left/right component that intensity can modify.
    enum LateralLean { case left, none, right }

    var lateralLean: LateralLean {
        switch self {
        case .longRight, .right, .shortRight: return .right
        case .longLeft, .left, .shortLeft: return .left
        case .long, .short: return .none
        }
    }

    func resolvedDirection(intensity: FreshLiveRoundShotOutcomeIntensity) -> ShotEvent.DirectionResult {
        switch lateralLean {
        case .left:
            return intensity == .far ? .farLeft : .left
        case .right:
            return intensity == .far ? .farRight : .right
        case .none:
            return .hit
        }
    }
}

enum FreshLiveRoundShotOutcomeIntensity: CaseIterable {
    case normal
    case far

    var label: String {
        switch self {
        case .normal: return "Normal"
        case .far: return "Far"
        }
    }
}

struct FreshLiveRoundShotOutcomeLayout {
    let canvasSize: CGSize
    let ringDiameter: CGFloat
    let ringInnerRadiusRatio: CGFloat
    let centerButtonSize: CGSize
    /// 0 = label sits on inner edge, 1 = on outer edge. 0.62 keeps it visually centered in the band.
    let labelRadialBias: CGFloat

    static let standard = FreshLiveRoundShotOutcomeLayout(
        canvasSize: CGSize(width: 280, height: 280),
        ringDiameter: 240,
        ringInnerRadiusRatio: 0.42,
        centerButtonSize: CGSize(width: 96, height: 96),
        labelRadialBias: 0.6
    )

    /// Compact variant used by the putt-miss outcome dial. There's no
    /// interactive centre button (the player has already declared the
    /// putt missed), so we let the inner cut-out be slightly larger to
    /// keep the eight sector labels comfortable.
    static let puttMiss = FreshLiveRoundShotOutcomeLayout(
        canvasSize: CGSize(width: 240, height: 240),
        ringDiameter: 220,
        ringInnerRadiusRatio: 0.46,
        centerButtonSize: CGSize(width: 80, height: 80),
        labelRadialBias: 0.62
    )

    var center: CGPoint {
        CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
    }

    var sectorAngleSpanDegrees: Double { 360.0 / 8.0 }

    func startAngleDegrees(for node: FreshLiveRoundShotOutcomeNode) -> Double {
        node.midAngleDegrees - sectorAngleSpanDegrees / 2
    }

    func endAngleDegrees(for node: FreshLiveRoundShotOutcomeNode) -> Double {
        node.midAngleDegrees + sectorAngleSpanDegrees / 2
    }

    /// Label position in the segment view's local coordinate space (origin at top-left of `ringDiameter` square).
    func labelPosition(for node: FreshLiveRoundShotOutcomeNode) -> CGPoint {
        let outerRadius = ringDiameter / 2
        let innerRadius = outerRadius * ringInnerRadiusRatio
        let labelRadius = innerRadius + ((outerRadius - innerRadius) * labelRadialBias)
        let radians = node.midAngleDegrees * .pi / 180
        return CGPoint(
            x: outerRadius + labelRadius * CGFloat(sin(radians)),
            y: outerRadius - labelRadius * CGFloat(cos(radians))
        )
    }
}

struct FreshLiveRoundAnnularSegmentShape: Shape {
    let startAngleDegrees: Double
    let endAngleDegrees: Double
    let innerRadiusRatio: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let outerRadius = min(rect.width, rect.height) / 2
        let innerRadius = outerRadius * innerRadiusRatio
        let outerPoints = sampledPoints(
            center: center,
            radius: outerRadius,
            startAngleDegrees: startAngleDegrees,
            endAngleDegrees: endAngleDegrees
        )
        let innerPoints = sampledPoints(
            center: center,
            radius: innerRadius,
            startAngleDegrees: endAngleDegrees,
            endAngleDegrees: startAngleDegrees
        )

        var path = Path()
        guard let firstOuterPoint = outerPoints.first else { return path }
        path.move(to: firstOuterPoint)
        outerPoints.dropFirst().forEach { path.addLine(to: $0) }
        innerPoints.forEach { path.addLine(to: $0) }
        path.closeSubpath()
        return path
    }

    private func sampledPoints(
        center: CGPoint,
        radius: CGFloat,
        startAngleDegrees: Double,
        endAngleDegrees: Double
    ) -> [CGPoint] {
        let angleSpan = endAngleDegrees - startAngleDegrees
        let segments = max(Int(abs(angleSpan) / 8), 6)

        return (0...segments).map { index in
            let progress = Double(index) / Double(segments)
            let angle = startAngleDegrees + (angleSpan * progress)
            let radians = angle * .pi / 180
            return CGPoint(
                x: center.x + (radius * CGFloat(sin(radians))),
                y: center.y - (radius * CGFloat(cos(radians)))
            )
        }
    }
}

/// One concentric distance ring centred on the **pin** of the active hole. Rings are tighter on
/// approach (25 m increments inside 150 m, where club selection precision matters most) and wider
/// further out (50 m increments beyond 150 m). Colours are grouped into "club zones" so a glance
/// tells you which class of shot you're looking at rather than just a raw number:
///
///   red    – chip / pitch zone (≤ 50 m)
///   orange – wedge zone (50–100 m)
///   white  – mid iron zone (100–150 m)
///   blue   – long iron / wood zone (150 m+)
struct FreshLiveRoundCarryRing: Identifiable, Hashable {
    let id: Int
    let radiusMeters: Int
    let color: Color

    private static let chip = Color(red: 0.94, green: 0.32, blue: 0.32)
    private static let wedge = Color(red: 0.99, green: 0.69, blue: 0.21)
    private static let midIron = Color.white.opacity(0.92)
    private static let longIron = Color(red: 0.27, green: 0.62, blue: 0.96)

    static let standardSet: [FreshLiveRoundCarryRing] = [
        .init(id: 0, radiusMeters: 25,  color: chip),
        .init(id: 1, radiusMeters: 50,  color: chip),
        .init(id: 2, radiusMeters: 75,  color: wedge),
        .init(id: 3, radiusMeters: 100, color: wedge),
        .init(id: 4, radiusMeters: 125, color: midIron),
        .init(id: 5, radiusMeters: 150, color: midIron),
        .init(id: 6, radiusMeters: 200, color: longIron),
        .init(id: 7, radiusMeters: 250, color: longIron),
    ]

    /// Compact legend rows: one entry per club-zone, showing both rings in that zone.
    /// Used by `carryRingLegend` to keep the bottom strip readable now that we have 8
    /// rings instead of 4.
    struct LegendZone: Identifiable, Hashable {
        let id: Int
        let label: String
        let color: Color
    }

    static let legendZones: [LegendZone] = [
        .init(id: 0, label: "25 / 50",   color: chip),
        .init(id: 1, label: "75 / 100",  color: wedge),
        .init(id: 2, label: "125 / 150", color: midIron),
        .init(id: 3, label: "200 / 250", color: longIron),
    ]
}

struct FreshLiveRoundClubWheelMotion {
    let entryBaseScale: CGFloat
    let selectedScale: CGFloat
    /// Per-entry delay used when the wheel breathes in. Kept small so the 12
    /// entries feel like one cohesive motion rather than a 220ms cascade.
    let entryDelayStep: Double
    /// Extra scale bump applied when the entry is *both* selected and
    /// recommended, so the user can pick out the "correct" club at a glance.
    let recommendedScale: CGFloat

    static let standard = FreshLiveRoundClubWheelMotion(
        entryBaseScale: 0.84,
        selectedScale: 1.06,
        entryDelayStep: 0.006,
        recommendedScale: 1.10
    )
}

struct FreshLiveRoundScreen: View {
    private static let clubWheelCoordinateSpace = "FreshLiveRoundScreenSpace"
    @ObservedObject var state: LiveRoundState
    let onFinishHole: () -> Void
    let onSaveAndExitRound: () -> Void
    let onDiscardRound: () -> Void

    init(
        state: LiveRoundState,
        onFinishHole: @escaping () -> Void,
        onSaveAndExitRound: @escaping () -> Void,
        onDiscardRound: @escaping () -> Void
    ) {
        self.state = state
        self.onFinishHole = onFinishHole
        self.onSaveAndExitRound = onSaveAndExitRound
        self.onDiscardRound = onDiscardRound

        // Seed the camera at the tee-biased framing so the very first frame is already
        // looking up the hole from the tee, instead of MapKit's default empty/automatic state
        // (which can flash a green placeholder while satellite tiles load in).
        let initialRegion = state.isInspectingHole
            ? state.displayedHoleRegion
            : state.nextHoleTeeFramingRegion
        _cameraPosition = State(initialValue: .region(initialRegion))
    }

    @State private var cameraPosition: MapCameraPosition
    @State private var clubLauncherFrame: CGRect = .zero
    @State private var isShowingShotLoggedToast = false
    @State private var shotLoggedToastTask: Task<Void, Never>?
    /// Auto-dismiss timer for the post-undo "Undid 7-iron" toast.
    @State private var undoneToastTask: Task<Void, Never>?
    // The launcher sheet's drag translation is owned by `FreshLiveRoundLauncherOffsetWrapper`
    // (a private view declared further down). Confining the @State to that wrapper means
    // changes during drag invalidate ONLY the wrapper's body, not the parent screen's body.
    // That's the difference between "smooth drag" and "the entire MapContent diff fires
    // 60 times a second" - the parent still owns the full Map (with all its polygons,
    // distance pills, carry rings, annotations) and we don't want it to be re-evaluated
    // while the user is just dragging the sheet.
    /// Driven by the sequenced long-press + drag on the aim crosshair. Backed by `@GestureState`
    /// so the value automatically resets to `false` the instant the gesture ends, cancels, or is
    /// interrupted - we can't end up in a state where the map stays locked because the drag was
    /// torn down without firing `onEnded`.
    @GestureState private var isAimDragActive: Bool = false
    /// Bumped on every map camera change so views that read screen coords from
    /// `MapProxy.convert(_:to:)` get re-evaluated as the user pans/zooms. Without
    /// this the gesture catcher would stay parked at its initial screen position
    /// even while the in-Map crosshair Annotation correctly follows the map.
    @State private var mapCameraVersion: Int = 0
    @State private var hasSeededInitialCamera = false
    /// While true (after **View green**), the map only allows pan/zoom within
    /// `LiveRoundState.greenInspectionPanLimits`. Reset when the camera is
    /// re-framed to the hole (recenter, hole change, inspect toggle).
    @State private var isGreenInspectionPanClampActive = false
    @Environment(\.colorScheme) private var colorScheme
    @State private var isShowingHoleInspector = false
    @State private var isShowingShotHistory = false
    @State private var isShowingConditions = false
    @State private var isShowingCurrentHoleEditor = false
    @State private var isShowingEndRoundFlow = false

    private let chromeMetrics = FreshLiveRoundChromeMetrics.standard

    private var palette: FreshLiveRoundPalette {
        FreshLiveRoundPalette.forColorScheme(colorScheme)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                liveMap

                VStack(spacing: 0) {
                    topPanel(in: proxy)
                        .padding(.top, proxy.safeAreaInsets.top + ShellTokens.Spacing.x12)
                        .padding(.horizontal, ShellTokens.Spacing.x16)

                    Spacer(minLength: 0)
                }

                // Sheet stack (carry-ring legend + launcher sheet) wrapped in
                // a dedicated subview that owns the drag `@State`. Because the
                // drag translation lives inside the wrapper, finger movement
                // during a sheet drag invalidates ONLY the wrapper's body. The
                // parent body (and the entire `liveMap` MapContent tree) stays
                // untouched - that's the difference between smooth drag and
                // 60 Hz MapContent diffs.
                FreshLiveRoundLauncherOffsetWrapper(
                    collapsedHeight: launcherCollapsedHeight(in: proxy),
                    actionsHeight: launcherActionsHeight(in: proxy),
                    expandedHeight: launcherExpandedHeight(in: proxy),
                    restingHeight: launcherRestingHeight(in: proxy),
                    currentDetent: state.launcherDetent
                ) { dragTranslation in
                    bottomSheetStack(in: proxy, dragTranslation: dragTranslation)
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        recenterButton
                    }
                    .padding(.horizontal, ShellTokens.Spacing.x16)
                    // Anchor to the resting detent height (not the live drag-
                    // tracking height) so the recenter button stays put during
                    // drag instead of bouncing along with the sheet. Reading
                    // `launcherCurrentHeight` here would invalidate this
                    // subtree's layout on every drag tick.
                    .padding(.bottom, max(proxy.safeAreaInsets.bottom, ShellTokens.Spacing.x12) + launcherRestingHeight(in: proxy) + ShellTokens.Spacing.x16)
                    .animation(.spring(response: 0.34, dampingFraction: 0.86), value: state.launcherDetent)
                }

                if state.isShowingClubWheel {
                    clubWheelOverlay(in: proxy)
                }

                topBannerStack(safeAreaInsetTop: proxy.safeAreaInsets.top)
            }
            .background(ShellTokens.ColorRole.bgApp)
            .ignoresSafeArea()
        }
        .coordinateSpace(name: Self.clubWheelCoordinateSpace)
        .onPreferenceChange(FreshLiveRoundClubLauncherFramePreferenceKey.self) { frame in
            guard frame != .zero else { return }
            clubLauncherFrame = frame
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Land on the 3D tee perspective the first time the screen mounts so the player
            // sees the hole from behind the tee box looking toward the green. After that, the
            // various onChange handlers below take over.
            if !hasSeededInitialCamera {
                hasSeededInitialCamera = true
                syncCameraToHoleFraming()
            }
        }
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
        .sheet(isPresented: $isShowingEndRoundFlow) {
            FreshLiveRoundEndRoundSheet(
                onSaveAndExit: onSaveAndExitRound,
                onDiscardRound: onDiscardRound
            )
        }
        .modifier(trayActionPresentations)
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
            modalCanvas: palette.modalCanvas,
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
                    .padding(.top, safeAreaInsetTop + ShellTokens.Spacing.x12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if state.isShowingHoleConfirmationPill {
                holeConfirmationPill
                    .padding(.top, safeAreaInsetTop + ShellTokens.Spacing.x12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else if let undonePreview = state.lastUndoneShotPreview {
                undoneShotToast(undonePreview)
                    .padding(.top, safeAreaInsetTop + ShellTokens.Spacing.x12)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, ShellTokens.Spacing.x16)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: isShowingShotLoggedToast)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: state.isShowingHoleConfirmationPill)
        .animation(.spring(response: 0.32, dampingFraction: 0.86), value: state.lastUndoneShotPreview)
    }

    private var shotLoggedToast: some View {
        HStack(spacing: ShellTokens.Spacing.x10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(palette.accent)
            Text("Shot saved")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)
        }
        .padding(.horizontal, ShellTokens.Spacing.x16)
        .padding(.vertical, ShellTokens.Spacing.x12)
        .freshGlass(Capsule(), palette: palette, tint: palette.panelFill)
        .shadow(color: palette.shadowColor, radius: 12, y: 6)
    }

    /// Banner that surfaces at the top of the map after a holed putt
    /// is logged. One tap commits the hole + advances; the inline
    /// "Edit" affordance opens the editor sheet for fine-grained
    /// adjustments first; the "x" dismisses the pill if the player
    /// wants to keep playing the same hole.
    private var holeConfirmationPill: some View {
        let strokeCount = state.pendingHoleScore ?? state.hole.strokeCount
        return HStack(spacing: ShellTokens.Spacing.x10) {
            Image(systemName: "flag.checkered")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accentForeground)

            VStack(alignment: .leading, spacing: 0) {
                Text("Hole \(state.displayedHoleNumber) · \(strokeCount) strokes")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.accentForeground)
                Text("Tap to finish hole")
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(palette.accentForeground.opacity(0.85))
            }

            Spacer(minLength: ShellTokens.Spacing.x8)

            Button {
                state.dismissHoleConfirmationPill()
                isShowingCurrentHoleEditor = true
            } label: {
                Text("Edit")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accentForeground)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(palette.accentForeground.opacity(0.18), in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                state.dismissHoleConfirmationPill()
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accentForeground.opacity(0.85))
                    .padding(6)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ShellTokens.Spacing.x14)
        .padding(.vertical, ShellTokens.Spacing.x12)
        .background(palette.accent, in: Capsule())
        .shadow(color: palette.shadowColor.opacity(0.7), radius: 14, y: 7)
        .onTapGesture {
            state.confirmCurrentHoleFromDerivedValues()
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Double tap to confirm this hole and advance")
    }

    private func undoneShotToast(_ preview: LiveRoundState.LoggedShotPreview) -> some View {
        HStack(spacing: ShellTokens.Spacing.x10) {
            Image(systemName: "arrow.uturn.backward.circle.fill")
                .foregroundStyle(palette.accent)
            Text("Undid \(preview.clubName) · \(surfaceLabel(for: preview.surface))")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)
        }
        .padding(.horizontal, ShellTokens.Spacing.x16)
        .padding(.vertical, ShellTokens.Spacing.x12)
        .freshGlass(Capsule(), palette: palette, tint: palette.panelFill)
        .shadow(color: palette.shadowColor, radius: 12, y: 6)
    }

    private var quickPenaltyPicker: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: ShellTokens.Spacing.x12) {
                    Text("Pick the relief option that matches what happened. We'll log a +1 penalty stroke; your next shot is the replay.")
                        .font(.system(.subheadline, design: .rounded))
                        .foregroundStyle(palette.secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, ShellTokens.Spacing.x4)

                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: ShellTokens.Spacing.x10),
                            GridItem(.flexible(), spacing: ShellTokens.Spacing.x10)
                        ],
                        spacing: ShellTokens.Spacing.x10
                    ) {
                        ForEach(LiveRoundState.QuickPenaltyType.allCases) { type in
                            quickPenaltyOptionButton(type)
                        }
                    }
                }
                .padding(.horizontal, ShellTokens.Spacing.x16)
                .padding(.vertical, ShellTokens.Spacing.x12)
            }
            .scrollBounceBehavior(.basedOnSize)
            .navigationTitle("Quick penalty")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        state.dismissQuickPenaltyPicker()
                    }
                }
            }
        }
    }

    private func quickPenaltyOptionButton(_ type: LiveRoundState.QuickPenaltyType) -> some View {
        Button {
            state.logQuickPenalty(type)
        } label: {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                Image(systemName: type.iconName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(palette.accent)
                Text(type.label)
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryTextColor)
                Text(type.subtitle)
                    .font(.system(.caption, design: .rounded).weight(.medium))
                    .foregroundStyle(palette.secondaryTextColor)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, minHeight: 122, alignment: .topLeading)
            .padding(ShellTokens.Spacing.x14)
            .freshGlass(
                RoundedRectangle(cornerRadius: 22, style: .continuous),
                palette: palette,
                tint: palette.tertiaryFill
            )
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.warning, trigger: state.isShowingQuickPenaltyPicker)
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

    private var topPanelGestureShield: some View {
        RoundedRectangle(cornerRadius: 28, style: .continuous)
            .fill(Color.clear)
            .contentShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .highPriorityGesture(SpatialTapGesture().onEnded { _ in })
            .highPriorityGesture(DragGesture(minimumDistance: 0).onChanged { _ in })
            .highPriorityGesture(MagnifyGesture().onChanged { _ in })
            .allowsHitTesting(FreshLiveRoundHUDInteractionPolicy.usesDedicatedTopPanelGestureShield)
            .accessibilityHidden(true)
    }

    /// Top HUD panel. Composed of two rows:
    ///
    /// 1. **Identity strip** — score-to-par chip, hole nav cluster, and
    ///    the always-on shot-relative wind chip. Tells the player who
    ///    they are on the round and which hole they're on.
    ///
    /// 2. **Phase-aware hero** — a big centred pin / putt distance
    ///    flanked by the most useful satellite for the current
    ///    `LiveRoundState.TopBarPhase`:
    ///    - `.tee`: Front · HERO · Recommended club (tee shots care
    ///      about reaching the fairway and what's in your hand)
    ///    - `.approach` / `.scoring`: Front · HERO · Back (classic
    ///      green-light wedge logic)
    ///    - `.greenSide`: hero only, no satellites — wind / plays-like
    ///      doesn't matter on a putt and the chrome stays clean
    ///
    /// Replaces the previous flat 4-card distance row (Front / Pin /
    /// Plays / Back) which gave every metric equal visual weight and
    /// kept the player from finding the pin distance at a glance.
    private func topPanel(in proxy: GeometryProxy) -> some View {
        let layout = FreshLiveRoundTopPanelLayout.resolve(containerSize: proxy.size)

        return VStack(spacing: layout.rowSpacing) {
            topPanelIdentityStrip(layout: layout)
            topPanelPhaseHero(layout: layout)
        }
        .padding(.horizontal, chromeMetrics.topPanelHorizontalPadding)
        .padding(.vertical, chromeMetrics.topPanelVerticalPadding)
        .frame(
            maxWidth: .infinity,
            minHeight: layout.panelMinHeight,
            alignment: .top
        )
        .freshGlass(
            RoundedRectangle(cornerRadius: 28, style: .continuous),
            palette: palette,
            tint: palette.panelFill,
            nativeGlass: FreshLiveRoundNativeGlassPolicy.primaryChrome
        )
        .background {
            if FreshLiveRoundHUDInteractionPolicy.topPanelGestureShieldUsesBackgroundSizing {
                topPanelGestureShield
            }
        }
        .shadow(color: palette.shadowColor, radius: 18, y: 8)
        .animation(.easeInOut(duration: 0.25), value: state.topBarPhase)
    }

    private func topPanelIdentityStrip(layout: FreshLiveRoundTopPanelLayout) -> some View {
        HStack(alignment: .center, spacing: ShellTokens.Spacing.x10) {
            scoreStrokeChip(width: layout.edgeMetricWidth)

            holeNavigationCluster(layout: layout)
                .frame(maxWidth: .infinity)

            windHUDChip(width: layout.edgeMetricWidth)
        }
    }

    @ViewBuilder
    private func topPanelPhaseHero(layout: FreshLiveRoundTopPanelLayout) -> some View {
        HStack(alignment: .center, spacing: layout.distanceCardSpacing) {
            leadingPhaseSatellite(layout: layout)
            heroDistanceCard(layout: layout)
                .frame(maxWidth: .infinity)
            trailingPhaseSatellite(layout: layout)
        }
        .frame(minHeight: layout.distanceCardMinHeight)
    }

    @ViewBuilder
    private func leadingPhaseSatellite(layout: FreshLiveRoundTopPanelLayout) -> some View {
        switch state.topBarPhase {
        case .tee, .approach, .scoring:
            satelliteDistanceChip(
                title: "Front",
                value: "\(state.distanceUnit.scalarValue(fromMeters: state.displayedFrontDistanceMeters))",
                unit: state.distanceUnit.shortSuffix,
                layout: layout
            )
        case .greenSide:
            // Empty placeholder so the hero stays optically centred and
            // the panel doesn't reflow when the player crosses the green
            // edge.
            Color.clear
                .frame(width: layout.edgeMetricWidth, height: 1)
        }
    }

    @ViewBuilder
    private func trailingPhaseSatellite(layout: FreshLiveRoundTopPanelLayout) -> some View {
        switch state.topBarPhase {
        case .tee:
            // On the tee, "back of green" is rarely actionable — the
            // recommended driver / 3-wood is what the player wants in
            // hand. Fall back to Back distance if the bag hasn't loaded
            // a recommendation yet so the slot never goes blank.
            if let club = state.recommendedClubName {
                satelliteTextChip(
                    title: "Club",
                    value: club,
                    layout: layout
                )
            } else {
                satelliteDistanceChip(
                    title: "Back",
                    value: "\(state.distanceUnit.scalarValue(fromMeters: state.displayedBackDistanceMeters))",
                    unit: state.distanceUnit.shortSuffix,
                    layout: layout
                )
            }
        case .approach, .scoring:
            satelliteDistanceChip(
                title: "Back",
                value: "\(state.distanceUnit.scalarValue(fromMeters: state.displayedBackDistanceMeters))",
                unit: state.distanceUnit.shortSuffix,
                layout: layout
            )
        case .greenSide:
            Color.clear
                .frame(width: layout.edgeMetricWidth, height: 1)
        }
    }

    private func heroDistanceCard(layout: FreshLiveRoundTopPanelLayout) -> some View {
        let isPutt = state.topBarPhase == .greenSide

        return VStack(spacing: 2) {
            Text(isPutt ? "PUTT" : "PIN")
                .font(.caption2.weight(.heavy))
                .tracking(2)
                .foregroundStyle(palette.secondaryTextColor)

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text("\(state.topBarHeroDistanceMeters)")
                    .font(.system(size: layout.heroValueFontSize, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryTextColor)
                Text("m")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
            }

            if let subtitle = state.topBarHeroSubtitle {
                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(.horizontal, ShellTokens.Spacing.x12)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity)
        .frame(minHeight: layout.distanceCardMinHeight)
        .freshGlass(
            RoundedRectangle(cornerRadius: 20, style: .continuous),
            palette: palette,
            tint: palette.accent.opacity(0.16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(palette.accent.opacity(0.32), lineWidth: 1)
        }
        // Animate the hero number when the player walks across the
        // course — the shift between "152" and "138" has more visual
        // impact than a static label flick.
        .contentTransition(.numericText())
        .animation(.easeOut(duration: 0.25), value: state.topBarHeroDistanceMeters)
    }

    private func satelliteDistanceChip(
        title: String,
        value: String,
        unit: String?,
        layout: FreshLiveRoundTopPanelLayout
    ) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(value)
                    .font(.system(size: layout.distanceValueFontSize, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryTextColor)
                if let unit {
                    Text(unit)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.secondaryTextColor)
                }
            }
        }
        .frame(width: layout.edgeMetricWidth)
        .frame(minHeight: layout.distanceCardMinHeight)
        .freshGlass(
            RoundedRectangle(cornerRadius: 18, style: .continuous),
            palette: palette,
            tint: palette.secondaryFill
        )
    }

    private func satelliteTextChip(
        title: String,
        value: String,
        layout: FreshLiveRoundTopPanelLayout
    ) -> some View {
        VStack(spacing: 2) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(palette.primaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: layout.edgeMetricWidth)
        .frame(minHeight: layout.distanceCardMinHeight)
        .freshGlass(
            RoundedRectangle(cornerRadius: 18, style: .continuous),
            palette: palette,
            tint: palette.secondaryFill
        )
    }

    /// Compact "score-to-par + stroke counter" chip for the identity
    /// strip. Replaces the old standalone strokes card. The headline
    /// uses `roundScoreToParDisplay` ("E" / "+1" / "-2") so the chip
    /// only ticks over on hole confirmation; the subtitle reads
    /// "Stk N" mid-hole or "Score N" on confirmed holes.
    private func scoreStrokeChip(width: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(state.topBarScoreHeadline)
                .font(.headline.weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(scoreChipHeadlineColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(state.topBarScoreSubtitle)
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(width: width, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    /// Tints the score headline so the chip carries a subtle "good /
    /// bad" cue without needing an icon: under par leans toward the
    /// course green accent, over par leans red, even-par stays neutral.
    private var scoreChipHeadlineColor: Color {
        let value = state.roundScoreToPar
        if value < 0 { return palette.accent }
        if value > 0 { return Color(red: 0.85, green: 0.30, blue: 0.30) }
        return palette.primaryTextColor
    }

    private var liveMap: some View {
        MapReader { proxy in
            Map(
                position: $cameraPosition,
                bounds: mapBounds,
                interactionModes: aimMapInteractionModes
            ) {
                ForEach(state.currentHoleFeatures) { feature in
                    overlay(for: feature)
                }

                if state.isDisplayedHoleLive {
                    // Distance rings centred on the pin. Filtered to just the rings
                    // that are useful at the player's current proximity-to-pin so the
                    // map isn't crowded with 8 concentric circles when you're 300 m
                    // out from a tee. See `visibleCarryRings` for the cull rule.
                    ForEach(visibleCarryRings) { ring in
                        MapCircle(
                            center: state.targetCoordinate,
                            radius: CLLocationDistance(ring.radiusMeters)
                        )
                        .foregroundStyle(.clear)
                        .stroke(ring.color.opacity(0.92), lineWidth: 1.6)
                    }

                    // Aim line + distance pills + crosshair render as MapContent when
                    // the user is NOT actively dragging the crosshair. MapKit handles
                    // the pan/zoom transform for free, so we get smooth map interaction
                    // with zero per-frame SwiftUI work. During an active drag the
                    // SwiftUI `aimVisualOverlay` below takes over for finger-perfect
                    // tracking (Map annotations interpolate slowly and looked jittery).
                    if !isAimDragActive {
                        let aimCoord = state.planningTargetCoordinate.clCoordinate
                        // `shotOriginCoordinate` is the player's GPS when
                        // they're sensibly on the hole, and the tee box
                        // when they're behind it / off-course. This keeps
                        // the aim line useful even when location is stale
                        // or set to a faraway sim coordinate.
                        let originCoord = state.shotOriginCoordinate
                        let carryMid = coordinateMidpoint(originCoord, aimCoord)
                        let remainingMid = coordinateMidpoint(aimCoord, state.targetCoordinate)

                        MapPolyline(
                            coordinates: [originCoord, aimCoord, state.targetCoordinate]
                        )
                        .stroke(.white.opacity(0.95), lineWidth: 2.6)

                        Annotation("Carry", coordinate: carryMid, anchor: .center) {
                            distancePill(value: state.planningCarryDistanceMeters)
                        }
                        .annotationTitles(.hidden)

                        Annotation("Remaining", coordinate: remainingMid, anchor: .center) {
                            distancePill(value: state.planningRemainingDistanceMeters)
                        }
                        .annotationTitles(.hidden)

                        Annotation("Aim", coordinate: aimCoord, anchor: .center) {
                            aimCrosshairMarker
                        }
                        .annotationTitles(.hidden)
                    }
                }

                Annotation("Tee", coordinate: state.teeCoordinate, anchor: .bottom) {
                    teeMarker
                }
                .annotationTitles(.hidden)

                Annotation("Pin", coordinate: state.targetCoordinate, anchor: .bottom) {
                    pinFlagMarker
                }
                .annotationTitles(.hidden)

                Annotation("You", coordinate: state.playerCoordinate, anchor: .center) {
                    youMarker
                }
                .annotationTitles(.hidden)
            }
            .mapStyle(.imagery(elevation: .realistic))
            // Hide MapKit's default control overlays (compass, scale, pitch toggle, user
            // location button). The screen has its own custom recenter button and tee/pin/you
            // markers, so the built-in floating widgets just clutter the imagery.
            .mapControls { }
            // `.onEnd` frequency (NOT `.continuous`) so we only re-anchor the SwiftUI
            // gesture catcher once the camera settles. `.continuous` fires at 60 Hz
            // during pan/zoom and used to bomb the entire view tree with state mutations,
            // making the map interaction visibly laggy. The catcher being briefly out of
            // sync during an in-flight pan is fine: the user is panning, not trying to
            // grab the crosshair, and as soon as the gesture finishes the catcher snaps
            // back onto the visible MapAnnotation crosshair.
            .onMapCameraChange(frequency: .onEnd) { _ in
                mapCameraVersion &+= 1
            }
            // The aim crosshair's long-press+drag gesture lives here, NOT inside the
            // `Annotation` view above. Annotation content is hosted inside `MKAnnotationView`
            // and `MKMapView` claims touches via its UIKit pan recogniser before SwiftUI
            // gestures can fire, which is why the interaction was completely dead before.
            // Keeping the gesture in the `.overlay { }` puts it above MapKit's UIKit gesture
            // stack so SwiftUI sees the touch first.
            .overlay {
                GeometryReader { geo in
                    if state.isDisplayedHoleLive {
                        ZStack {
                            // The transparent gesture catcher is always present so the
                            // user can long-press the crosshair anywhere it appears on
                            // screen. It re-anchors when the camera change settles
                            // (`mapCameraVersion` driven by `.onMapCameraChange(.onEnd)`).
                            aimGestureCatcher(
                                proxy: proxy,
                                mapGlobalFrame: geo.frame(in: .global),
                                cameraVersion: mapCameraVersion
                            )

                            // Smooth-tracking SwiftUI overlay (line + pills + crosshair)
                            // only mounts during an active drag. The rest of the time the
                            // exact same visuals come from MapPolyline + Annotation inside
                            // the Map block, which are essentially free for SwiftUI.
                            if isAimDragActive {
                                aimVisualOverlay(
                                    proxy: proxy,
                                    mapFrame: geo.frame(in: .local),
                                    mapGlobalFrame: geo.frame(in: .global)
                                )
                            }
                        }
                    }
                }
            }
        }
    }

    /// Map gestures need to be disabled while the user is actively dragging the aim crosshair,
    /// otherwise MapKit's pan recogniser fights the SwiftUI drag and the map slides under the
    /// finger. `isAimDragActive` is `@GestureState`, so it auto-resets to `false` on gesture
    /// end/cancel and the map regains its full interaction set without us having to manually
    /// clean up. We allow pitch and rotate alongside pan/zoom so power users can re-orient
    /// the perspective camera if they want a different look at the hole.
    private var aimMapInteractionModes: MapInteractionModes {
        isAimDragActive ? [] : [.pan, .zoom, .pitch, .rotate]
    }

    /// Wraps the carry-ring legend and the launcher sheet in a single offset-
    /// driven stack. The carry-ring legend rides along with the sheet so it
    /// always sits flush above the visible top edge, regardless of detent.
    @ViewBuilder
    private func bottomSheetStack(in proxy: GeometryProxy, dragTranslation: Binding<CGFloat>) -> some View {
        VStack(spacing: 0) {
            if state.isDisplayedHoleLive {
                carryRingLegend
                    .padding(.horizontal, ShellTokens.Spacing.x16)
                    .padding(.bottom, ShellTokens.Spacing.x10)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            launcherSheet(in: proxy, dragTranslation: dragTranslation)
        }
    }

    /// Always laid out at the expanded detent height. The visible portion is
    /// controlled by the parent's `.offset(y:)` so the sheet's frame is stable
    /// during drag - no per-tick layout invalidation in the parent VStack.
    private func launcherSheet(in proxy: GeometryProxy, dragTranslation: Binding<CGFloat>) -> some View {
        let sheetHeight = launcherExpandedHeight(in: proxy)
        let showsSupplementaryActions = state.launcherDetent != .collapsed
        let showsFullSupplementaryActions = state.launcherDetent == .expanded

        return VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            launcherHeader(in: proxy, dragTranslation: dragTranslation)

            if showsSupplementaryActions {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                        Divider()
                            .overlay(palette.border)

                        if state.isDisplayedHoleLive {
                            Text("Actions")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.secondaryTextColor)

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: ShellTokens.Spacing.x10),
                                    GridItem(.flexible(), spacing: ShellTokens.Spacing.x10)
                                ],
                                spacing: ShellTokens.Spacing.x10
                            ) {
                                launcherInvokerButton(
                                    title: "Undo last shot",
                                    subtitle: state.canUndoLastShot
                                        ? "Roll back the last log"
                                        : "Nothing to undo yet",
                                    systemImage: "arrow.uturn.backward.circle",
                                    isEnabled: state.canUndoLastShot
                                ) {
                                    state.presentUndoConfirmation()
                                }

                                launcherInvokerButton(
                                    title: "Quick penalty",
                                    subtitle: "Lost · OB · unplayable · water",
                                    systemImage: "exclamationmark.triangle"
                                ) {
                                    state.presentQuickPenaltyPicker()
                                }

                                launcherInvokerButton(
                                    title: "View green",
                                    subtitle: state.canInspectGreen
                                        ? "Zoom in for an approach read"
                                        : "No green geometry on this hole",
                                    systemImage: "binoculars.fill",
                                    isEnabled: state.canInspectGreen
                                ) {
                                    syncCameraToGreenInspection(animated: true)
                                }

                                launcherInvokerButton(
                                    title: "Quick finish hole",
                                    subtitle: "Picked up — log final totals",
                                    systemImage: "flag.checkered"
                                ) {
                                    state.presentHoleConfirmation()
                                }

                                if showsFullSupplementaryActions {
                                    launcherInvokerButton(
                                        title: "Inspect Holes",
                                        subtitle: "Jump and review scores",
                                        systemImage: "list.bullet.rectangle"
                                    ) {
                                        isShowingHoleInspector = true
                                    }

                                    launcherInvokerButton(
                                        title: "Re-tee",
                                        subtitle: "+1 penalty, replay from tee",
                                        systemImage: "arrow.counterclockwise"
                                    ) {
                                        state.presentReteeConfirmation()
                                    }

                                    launcherInvokerButton(
                                        title: "Shot History",
                                        subtitle: "Review this hole's shots",
                                        systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                                    ) {
                                        isShowingShotHistory = true
                                    }

                                    launcherInvokerButton(
                                        title: "Conditions",
                                        subtitle: "Wind, weather, and GPS",
                                        systemImage: "wind"
                                    ) {
                                        isShowingConditions = true
                                    }

                                    launcherInvokerButton(
                                        title: "Edit Current Hole",
                                        subtitle: "Fix score, putts, and notes",
                                        systemImage: "square.and.pencil"
                                    ) {
                                        isShowingCurrentHoleEditor = true
                                    }

                                    launcherInvokerButton(
                                        title: "End Round",
                                        subtitle: "Save, discard, or exit",
                                        systemImage: "xmark.circle"
                                    ) {
                                        isShowingEndRoundFlow = true
                                    }
                                }
                            }
                        } else {
                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(), spacing: ShellTokens.Spacing.x10),
                                    GridItem(.flexible(), spacing: ShellTokens.Spacing.x10)
                                ],
                                spacing: ShellTokens.Spacing.x10
                                ) {
                                launcherInvokerButton(
                                    title: "Inspect Holes",
                                    subtitle: "Jump and review scores",
                                    systemImage: "list.bullet.rectangle"
                                ) {
                                    isShowingHoleInspector = true
                                }

                                launcherInvokerButton(
                                    title: "Shot History",
                                    subtitle: "Review this hole's shots",
                                    systemImage: "clock.arrow.trianglehead.counterclockwise.rotate.90"
                                ) {
                                    isShowingShotHistory = true
                                }

                                if showsFullSupplementaryActions {
                                    launcherInvokerButton(
                                        title: "Conditions",
                                        subtitle: "Wind, weather, and GPS",
                                        systemImage: "wind"
                                    ) {
                                        isShowingConditions = true
                                    }

                                    launcherInvokerButton(
                                        title: "End Round",
                                        subtitle: "Save, discard, or exit",
                                        systemImage: "xmark.circle"
                                    ) {
                                        isShowingEndRoundFlow = true
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, ShellTokens.Spacing.x4)
                }
                .scrollBounceBehavior(.basedOnSize)
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(.horizontal, chromeMetrics.launcherContentPadding)
        .padding(.top, ShellTokens.Spacing.x12)
        .padding(.bottom, ShellTokens.Spacing.x14)
        .frame(maxWidth: .infinity, minHeight: sheetHeight, maxHeight: sheetHeight, alignment: .top)
        .freshGlass(
            RoundedRectangle(cornerRadius: 32, style: .continuous),
            palette: palette,
            tint: palette.panelFill,
            nativeGlass: FreshLiveRoundNativeGlassPolicy.primaryChrome
        )
        .contentShape(Rectangle())
        .shadow(color: palette.shadowColor, radius: 16, y: 8)
        // Drives the show/hide of the supplementary action grid in step with
        // the offset-wrapper's spring. Detent-driven animations only - the
        // continuous drag is owned by `FreshLiveRoundLauncherOffsetWrapper`
        // and we don't want a second spring layer re-interpolating the height
        // at 60 Hz during the drag.
        .animation(.spring(response: 0.34, dampingFraction: 0.86), value: state.launcherDetent)
    }

    private func launcherHeader(in proxy: GeometryProxy, dragTranslation: Binding<CGFloat>) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            // The grabber owns the drag gesture (see `launcherHandle`).
            // Keeping it scoped to the handle - rather than the whole header -
            // is what lets the Log Shot / club chip / At Ball buttons receive
            // their tap events: a header-wide `DragGesture(minimumDistance: 0)`
            // would otherwise eat every touch-down before SwiftUI's button
            // tap recognizer could fire.
            launcherHandle(in: proxy, dragTranslation: dragTranslation)

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                HStack(spacing: ShellTokens.Spacing.x10) {
                    currentClubLauncherButton

                    Spacer(minLength: 0)

                    statusChip(
                        title: state.isDisplayedHoleLive ? "Current hole" : "Inspection",
                        systemImage: state.isDisplayedHoleLive ? "location.fill" : "eye.fill"
                    )
                }

                HStack(spacing: ShellTokens.Spacing.x12) {
                    Button {
                        state.presentShotLogger()
                    } label: {
                        Label("Log Shot", systemImage: "plus.circle.fill")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .modifier(FreshLiveRoundPrimaryActionButtonModifier(palette: palette))
                    .disabled(!state.canPresentShotLogger)

                    if state.canMarkBallOnDisplayedHole {
                        Button {
                            state.markBall()
                        } label: {
                            Label(state.atBallActionTitle, systemImage: state.ballMarkStatus == .marked ? "checkmark.circle.fill" : "scope")
                                .font(.subheadline.weight(.semibold))
                        }
                        .modifier(FreshLiveRoundSecondaryActionButtonModifier(palette: palette))
                    }
                }

                if !state.isDisplayedHoleLive {
                    Text("Finish browsing to log shots on the current hole.")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(palette.secondaryTextColor)
                }
            }
        }
    }

    private func launcherHandle(
        in proxy: GeometryProxy,
        dragTranslation: Binding<CGFloat>
    ) -> some View {
        HStack(spacing: ShellTokens.Spacing.x12) {
            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 6) {
                Capsule()
                    .fill(palette.accent)
                    .frame(width: 44, height: 5)
            }

            Spacer(minLength: 0)
        }
        // Generous full-width / 32pt-tall hit area so the user can grab the
        // sheet anywhere across the top, even if their thumb misses the
        // 44x5 capsule. The drag gesture is intentionally restricted to this
        // handle (rather than the whole header) so the buttons below can
        // still receive taps without being eaten by `minimumDistance: 0`.
        .frame(maxWidth: .infinity)
        .frame(height: 32)
        .contentShape(Rectangle())
        .highPriorityGesture(launcherDragGesture(in: proxy, dragTranslation: dragTranslation))
    }

    private var currentClubLauncherButton: some View {
        Button {
            if state.isShowingClubWheel {
                state.dismissClubWheel()
            } else {
                state.presentClubWheel()
            }
        } label: {
            HStack(spacing: ShellTokens.Spacing.x8) {
                Image(systemName: "figure.golf")
                    .font(.subheadline.weight(.semibold))
                Text(state.currentClubLauncherTitle)
                    .font(.subheadline.weight(.semibold))
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(palette.primaryTextColor)
            .padding(.horizontal, ShellTokens.Spacing.x12)
            .padding(.vertical, ShellTokens.Spacing.x10)
            .freshGlass(Capsule(), palette: palette, tint: palette.secondaryFill)
            .background(
                GeometryReader { geometry in
                    Color.clear.preference(
                        key: FreshLiveRoundClubLauncherFramePreferenceKey.self,
                        value: geometry.frame(in: .named(Self.clubWheelCoordinateSpace))
                    )
                }
            )
        }
        .buttonStyle(.plain)
        .disabled(!state.isDisplayedHoleLive)
        .opacity(state.isDisplayedHoleLive ? 1 : 0.55)
        .contentShape(Capsule())
    }

    private func clubWheelOverlay(in proxy: GeometryProxy) -> some View {
        FreshLiveRoundClubWheelOverlay(
            state: state,
            anchorFrame: resolvedClubLauncherFrame(in: proxy),
            safeAreaInsets: proxy.safeAreaInsets,
            containerSize: proxy.size,
            palette: palette
        )
        .zIndex(10)
    }

    private func resolvedClubLauncherFrame(in proxy: GeometryProxy) -> CGRect {
        if clubLauncherFrame != .zero {
            return clubLauncherFrame
        }

        let fallbackWidth: CGFloat = 132
        let fallbackHeight: CGFloat = 44
        // Fallback path only fires before the preference key reports the real
        // anchor frame; using the resting (detent-only) height is fine here -
        // the user can't be dragging the sheet and opening the club wheel at
        // the same time, and avoiding `launcherCurrentHeight` keeps the parent
        // body free of the drag-translation dependency.
        let y = proxy.size.height - max(proxy.safeAreaInsets.bottom, ShellTokens.Spacing.x12) - launcherRestingHeight(in: proxy) + 54
        return CGRect(x: ShellTokens.Spacing.x24, y: y, width: fallbackWidth, height: fallbackHeight)
    }

    private func launcherInvokerButton(
        title: String,
        subtitle: String,
        systemImage: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isEnabled ? palette.accent : palette.secondaryTextColor.opacity(0.5))

                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isEnabled ? palette.primaryTextColor : palette.primaryTextColor.opacity(0.5))

                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.secondaryTextColor.opacity(isEnabled ? 1 : 0.6))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
            .padding(ShellTokens.Spacing.x14)
            .freshGlass(
                RoundedRectangle(cornerRadius: 22, style: .continuous),
                palette: palette,
                tint: palette.tertiaryFill
            )
            .opacity(isEnabled ? 1 : 0.7)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func statusChip(title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(palette.primaryTextColor)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .freshGlass(Capsule(), palette: palette, tint: palette.tertiaryFill)
    }

    private func launcherCollapsedHeight(in proxy: GeometryProxy) -> CGFloat {
        let baseHeight: CGFloat = state.canMarkBallOnDisplayedHole ? 176 : 152
        let inspectionAdjustment: CGFloat = state.isDisplayedHoleLive ? 0 : 12
        return min(baseHeight + inspectionAdjustment, proxy.size.height * 0.34)
    }

    private func launcherExpandedHeight(in proxy: GeometryProxy) -> CGFloat {
        let baseHeight = state.isDisplayedHoleLive
            ? FreshLiveRoundLauncherLayoutPolicy.liveExpandedBaseHeight
            : FreshLiveRoundLauncherLayoutPolicy.inspectionExpandedBaseHeight
        return min(baseHeight, proxy.size.height * FreshLiveRoundLauncherLayoutPolicy.maxExpandedHeightRatio)
    }

    private func launcherActionsHeight(in proxy: GeometryProxy) -> CGFloat {
        let baseHeight = state.isDisplayedHoleLive
            ? FreshLiveRoundLauncherLayoutPolicy.liveActionsBaseHeight
            : FreshLiveRoundLauncherLayoutPolicy.inspectionActionsBaseHeight
        return min(baseHeight, proxy.size.height * FreshLiveRoundLauncherLayoutPolicy.maxExpandedHeightRatio)
    }

    private func launcherHeight(for detent: LiveRoundState.LauncherDetent, in proxy: GeometryProxy) -> CGFloat {
        switch detent {
        case .collapsed:
            return launcherCollapsedHeight(in: proxy)
        case .actions:
            return launcherActionsHeight(in: proxy)
        case .expanded:
            return launcherExpandedHeight(in: proxy)
        }
    }

    private func launcherDetentHeights(in proxy: GeometryProxy) -> FreshLiveRoundLauncherDetentHeights {
        FreshLiveRoundLauncherDetentHeights(
            collapsed: launcherCollapsedHeight(in: proxy),
            actions: launcherActionsHeight(in: proxy),
            expanded: launcherExpandedHeight(in: proxy)
        )
    }

    private func nearestLauncherDetent(for height: CGFloat, in proxy: GeometryProxy) -> LiveRoundState.LauncherDetent {
        LiveRoundState.LauncherDetent.allCases.min { lhs, rhs in
            abs(launcherHeight(for: lhs, in: proxy) - height) < abs(launcherHeight(for: rhs, in: proxy) - height)
        } ?? .collapsed
    }

    private func launcherRestingHeight(in proxy: GeometryProxy) -> CGFloat {
        launcherHeight(for: state.launcherDetent, in: proxy)
    }

    private func launcherVisualStateIsExpanded(in proxy: GeometryProxy) -> Bool {
        state.launcherDetent != .collapsed
    }

    /// The drag gesture writes the live finger offset into `dragTranslation`
    /// (a `@State` owned by `FreshLiveRoundLauncherOffsetWrapper`). On release
    /// it both snaps the detent and zeroes the offset inside a single
    /// `withAnimation` so the spring covers the full path back to the resting
    /// detent height - even when the user releases mid-drag without crossing a
    /// snap threshold.
    private func launcherDragGesture(
        in proxy: GeometryProxy,
        dragTranslation: Binding<CGFloat>
    ) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                dragTranslation.wrappedValue = value.translation.height
            }
            .onEnded { value in
                let heights = launcherDetentHeights(in: proxy)
                let targetDetent = FreshLiveRoundLauncherSnapPolicy.targetDetent(
                    from: self.state.launcherDetent,
                    translation: value.translation.height,
                    predictedEndTranslation: value.predictedEndTranslation.height,
                    heights: heights
                )
                withAnimation(.spring(response: 0.34, dampingFraction: 0.86)) {
                    self.state.setLauncherDetent(targetDetent)
                    dragTranslation.wrappedValue = 0
                }
            }
    }

    /// "Frame the active hole" button. Peeking at another hole snaps back to
    /// the active hole first; then the camera animates to the tee perspective.
    /// Does not reset the aim crosshair — that stays where the user left it.
    private var recenterButton: some View {
        Button {
            if state.isInspectingHole {
                state.returnToActiveHole()
            }
            syncCameraToHoleFraming(animated: true)
        } label: {
            Image(systemName: "scope")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(palette.quietIcon)
                .frame(width: 52, height: 52)
        }
        .buttonStyle(.plain)
        .freshGlass(Circle(), palette: palette, tint: palette.panelFill)
        .contentShape(Circle())
        .shadow(color: palette.shadowColor, radius: 12, y: 6)
        .accessibilityLabel(
            state.isInspectingHole ? "Return to active hole" : "Frame current hole"
        )
    }

    /// Compact, always-on wind read in the top HUD. Replaces the old
    /// "12 NW" text card with a shot-relative arrow + speed + category
    /// (Tail / Head / Cross R / Cross L). Tapping the chip opens the
    /// Conditions sheet for the full breakdown — making the chip the
    /// discoverable entry into wind/weather details.
    private func windHUDChip(width: CGFloat) -> some View {
        Button {
            isShowingConditions = true
        } label: {
            HStack(alignment: .center, spacing: 6) {
                windDirectionArrow(diameter: 22, isCalm: !state.hasUsableWindReading)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(windHUDValueLabel)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(palette.primaryTextColor)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(windHUDCategoryLabel)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(palette.secondaryTextColor)
                        .lineLimit(1)
                }
            }
            .frame(width: width, alignment: .trailing)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(windHUDAccessibilityLabel))
        .accessibilityHint(Text("Open conditions"))
    }

    /// Small directional arrow for the HUD chip and the Conditions
    /// hero. Always points "with the wind" relative to the player's
    /// shot bearing — so a tail wind has the arrow pointing up the
    /// page, head pointing down, cross-right pointing right, etc.
    private func windDirectionArrow(diameter: CGFloat, isCalm: Bool) -> some View {
        let rotationDegrees: Double = state.windRelativeMotionDegrees ?? 0

        return ZStack {
            Circle()
                .fill(palette.secondaryFill)
                .overlay {
                    Circle().stroke(palette.border, lineWidth: 1)
                }

            if isCalm {
                Image(systemName: "circle.dotted")
                    .font(.system(size: diameter * 0.55, weight: .semibold))
                    .foregroundStyle(palette.secondaryTextColor)
            } else {
                // `arrow.up` points along the +Y axis; rotation is
                // clockwise. `windRelativeMotionDegrees` already
                // encodes "0° = with the shot", and SwiftUI's HUD frame
                // has shot direction up the screen, so the angle maps
                // 1:1 onto the rotation effect.
                Image(systemName: "arrow.up")
                    .font(.system(size: diameter * 0.6, weight: .heavy))
                    .foregroundStyle(palette.accent)
                    .rotationEffect(.degrees(rotationDegrees))
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeInOut(duration: 0.25), value: rotationDegrees)
    }

    private var windHUDValueLabel: String {
        guard let weather = state.weatherSnapshot else {
            return "--"
        }
        return "\(weather.windSpeedKilometersPerHour)"
    }

    private var windHUDCategoryLabel: String {
        guard state.weatherSnapshot != nil else { return "Wind" }
        if !state.hasUsableWindReading { return "Calm" }
        return state.windRelativeCategory.label
    }

    private var windHUDAccessibilityLabel: String {
        guard let weather = state.weatherSnapshot else {
            return "Wind unavailable"
        }
        let categoryWord = state.hasUsableWindReading
            ? state.windRelativeCategory.label
            : "calm"
        return "Wind \(weather.windSpeedKilometersPerHour) kilometres per hour, \(categoryWord)"
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

    private var mapBounds: MapCameraBounds {
        if isGreenInspectionPanClampActive,
           let limits = state.greenInspectionPanLimits {
            return MapCameraBounds(
                centerCoordinateBounds: limits.paddedGreenMapRect,
                minimumDistance: limits.minimumCameraDistance,
                maximumDistance: limits.maximumCameraDistance
            )
        }
        return courseMapCameraBounds
    }

    private func holeNavigationButton(
        systemImage: String,
        isEnabled: Bool,
        size: CGFloat,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isEnabled ? palette.primaryTextColor : palette.tertiaryTextColor)
                .frame(width: size, height: size)
        }
        .buttonStyle(.plain)
        .freshGlass(Circle(), palette: palette, tint: palette.secondaryFill)
        .overlay {
            Circle()
                .stroke(isEnabled ? palette.border : palette.tertiaryFill, lineWidth: 1)
        }
        .disabled(!isEnabled)
        .contentShape(Circle())
    }

    private func holeNavigationCluster(layout: FreshLiveRoundTopPanelLayout) -> some View {
        HStack(spacing: ShellTokens.Spacing.x8) {
            holeNavigationButton(systemImage: "chevron.left", isEnabled: state.canInspectPreviousHole, size: layout.navButtonSize) {
                state.inspectPreviousHole()
            }

            VStack(spacing: layout.density == .compact ? 1 : 2) {
                Text(layout.holeTitle(for: state.displayedHoleNumber))
                    .font(layout.density == .compact ? .headline.weight(.bold) : .title3.weight(.bold))
                    .foregroundStyle(palette.primaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .allowsTightening(true)

                Text(state.topPanelHoleSubtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .allowsTightening(true)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, layout.centerHorizontalPadding)

            holeNavigationButton(systemImage: "chevron.right", isEnabled: state.canInspectNextHole, size: layout.navButtonSize) {
                state.inspectNextHole()
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, layout.density == .compact ? 6 : 8)
        .freshGlass(
            RoundedRectangle(cornerRadius: 22, style: .continuous),
            palette: palette,
            tint: palette.secondaryFill
        )
    }

    private var aimCrosshairMarker: some View {
        let activeColor: Color = isAimDragActive ? Color(red: 1.0, green: 0.86, blue: 0.32) : .white

        return ZStack {
            Circle()
                .fill(.black.opacity(0.20))
                .frame(width: 56, height: 56)
                .blur(radius: 4)

            Circle()
                .stroke(activeColor.opacity(0.95), lineWidth: 2)
                .frame(width: 44, height: 44)

            Rectangle()
                .fill(activeColor.opacity(0.95))
                .frame(width: 2, height: 32)

            Rectangle()
                .fill(activeColor.opacity(0.95))
                .frame(width: 32, height: 2)

            Circle()
                .fill(activeColor)
                .frame(width: 6, height: 6)
        }
        .frame(width: 56, height: 56)
        .scaleEffect(isAimDragActive ? 1.1 : 1.0)
        .animation(.easeInOut(duration: 0.18), value: isAimDragActive)
        .sensoryFeedback(.selection, trigger: isAimDragActive)
        // The gesture is intentionally NOT attached to this view. SwiftUI Map hosts annotation
        // content inside `MKAnnotationView` whose touches are claimed by `MKMapView`'s own pan
        // recogniser before SwiftUI gestures get a chance to fire. The interactive hit-target
        // lives in `aimGestureCatcher` instead, which is added as a `.overlay { }` on the Map
        // and therefore sits above MapKit's UIKit gesture stack.
    }

    /// SwiftUI render of the aim group (line, distance pills, crosshair) used ONLY
    /// during an active crosshair drag. While dragging, MapKit's annotation
    /// interpolation produces visible jitter as the planning coordinate updates
    /// many times per second; rendering in SwiftUI screen-space sidesteps that and
    /// gives finger-perfect tracking.
    ///
    /// Outside of drag, the same visuals are rendered as MapPolyline + Annotation
    /// inside the Map block - those auto-follow pan/zoom for free, with no SwiftUI
    /// per-frame work.
    private func aimVisualOverlay(
        proxy: MapProxy,
        mapFrame: CGRect,
        mapGlobalFrame: CGRect
    ) -> some View {
        let aimPoint = screenPoint(
            for: state.planningTargetCoordinate.clCoordinate,
            proxy: proxy,
            mapGlobalFrame: mapGlobalFrame
        ) ?? CGPoint(x: mapFrame.midX, y: mapFrame.midY)
        // Mirror the MapPolyline branch: if the player has wandered
        // behind the teebox (or the location is way off-course) the
        // shot origin falls back to the tee so the line + carry pill
        // stay anchored to a sensible reference rather than chasing a
        // faraway GPS fix.
        let originPoint = screenPoint(
            for: state.shotOriginCoordinate,
            proxy: proxy,
            mapGlobalFrame: mapGlobalFrame
        )
        let pinPoint = screenPoint(
            for: state.targetCoordinate,
            proxy: proxy,
            mapGlobalFrame: mapGlobalFrame
        )

        return ZStack(alignment: .topLeading) {
            if let originPoint, let pinPoint {
                Path { path in
                    path.move(to: originPoint)
                    path.addLine(to: aimPoint)
                    path.addLine(to: pinPoint)
                }
                .stroke(
                    .white.opacity(0.95),
                    style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round)
                )
                .allowsHitTesting(false)

                distancePill(value: state.planningCarryDistanceMeters)
                    .position(midpoint(originPoint, aimPoint))
                    .allowsHitTesting(false)

                distancePill(value: state.planningRemainingDistanceMeters)
                    .position(midpoint(aimPoint, pinPoint))
                    .allowsHitTesting(false)
            }

            aimCrosshairMarker
                .position(aimPoint)
                .allowsHitTesting(false)
        }
    }

    /// Transparent always-on hit target that owns the long-press-then-drag gesture
    /// for the aim crosshair. Sits above MapKit's UIKit gesture stack (because it
    /// lives in a SwiftUI `.overlay`) so the long-press fires reliably; MapKit's
    /// own pan recogniser would otherwise claim the touch first.
    private func aimGestureCatcher(
        proxy: MapProxy,
        mapGlobalFrame: CGRect,
        cameraVersion: Int
    ) -> some View {
        // Reading `cameraVersion` here is what wires this view's identity to
        // `mapCameraVersion`, so SwiftUI re-evaluates the closure (and therefore
        // re-runs `proxy.convert`) when the camera change settles.
        _ = cameraVersion

        let aimPoint = screenPoint(
            for: state.planningTargetCoordinate.clCoordinate,
            proxy: proxy,
            mapGlobalFrame: mapGlobalFrame
        ) ?? CGPoint(x: -200, y: -200)

        return Color.clear
            .frame(width: 96, height: 96)
            .contentShape(Circle())
            .position(aimPoint)
            .highPriorityGesture(aimCrosshairGesture(proxy: proxy))
    }

    /// Convenience wrapper around `MapProxy.convert(_, to: .global)` that translates the
    /// returned screen-space point into the GeometryReader's local space (so SwiftUI's
    /// `.position(_:)` lands the view where we expect). Returns `nil` if the proxy
    /// hasn't laid out yet, which the caller can use to skip rendering optional elements
    /// (line, pills) until they have valid endpoints.
    private func screenPoint(
        for coordinate: CLLocationCoordinate2D,
        proxy: MapProxy,
        mapGlobalFrame: CGRect
    ) -> CGPoint? {
        guard let global = proxy.convert(coordinate, to: .global) else { return nil }
        return CGPoint(
            x: global.x - mapGlobalFrame.minX,
            y: global.y - mapGlobalFrame.minY
        )
    }

    private func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
        CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
    }

    /// Linear midpoint of two map coordinates. Lat/lon averaging is geometrically
    /// crude over long distances but perfectly fine inside a single golf hole
    /// (< 600 m), where the great-circle midpoint is indistinguishable from the
    /// equirectangular midpoint at this scale.
    private func coordinateMidpoint(
        _ a: CLLocationCoordinate2D,
        _ b: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        CLLocationCoordinate2D(
            latitude: (a.latitude + b.latitude) / 2,
            longitude: (a.longitude + b.longitude) / 2
        )
    }

    /// The subset of `FreshLiveRoundCarryRing.standardSet` worth drawing for the
    /// player's current proximity to the pin. Rules:
    ///
    ///   - Hide rings that sit > 50 m **inside** the player's distance (you've
    ///     already passed them - they're behind you).
    ///   - Hide rings that sit > 50 m **outside** the player's distance (irrelevant
    ///     for current shot planning).
    ///   - Hide the tight 25 m-spaced "approach" rings (radii < 150 m) unless the
    ///     player is actually on approach (within 175 m of the pin). From the tee
    ///     these would be a tiny bullseye around the pin and just add visual noise.
    ///   - Always anchor the outermost 250 m ring when the player is further out
    ///     than that, so a long-yardage reference is visible from the tee.
    private var visibleCarryRings: [FreshLiveRoundCarryRing] {
        let pinDistance = Double(state.displayedPinDistanceMeters)
        let onApproach = pinDistance <= 175

        return FreshLiveRoundCarryRing.standardSet.filter { ring in
            let r = Double(ring.radiusMeters)
            if pinDistance > 250 && ring.radiusMeters == 250 {
                return true
            }
            guard r >= pinDistance - 50, r <= pinDistance + 50 else { return false }
            if r < 150 && !onApproach { return false }
            return true
        }
    }


    /// A sequenced "long-press, then drag" recognizer attached to the aim crosshair.
    ///
    /// The user holds the crosshair to "pick it up", then drags their finger to slide the aim
    /// point across the satellite imagery. Drag movements are converted from on-screen points
    /// to map coordinates via the surrounding `MapReader`'s proxy, so the aim follows the
    /// finger faithfully even though the underlying `Annotation` view is also moving.
    ///
    /// `isAimDragActive` is a `@GestureState` so it self-resets the moment the gesture ends or
    /// is interrupted - we can't get stuck in a "drag locked" UI state.
    private func aimCrosshairGesture(proxy: MapProxy) -> some Gesture {
        let longPress = LongPressGesture(minimumDuration: 0.18, maximumDistance: .greatestFiniteMagnitude)
        // `.global` (screen coords) for the same reason `aimGestureCatcher` uses it for
        // positioning - it's the only coordinate space `MapProxy.convert` works with
        // reliably in this Xcode/iOS combo.
        let drag = DragGesture(minimumDistance: 0, coordinateSpace: .global)

        return longPress.sequenced(before: drag)
            .updating($isAimDragActive) { value, isActive, _ in
                switch value {
                case .first:
                    isActive = false
                case .second(let longPressFulfilled, _):
                    isActive = longPressFulfilled
                }
            }
            .onChanged { value in
                guard
                    case .second(let longPressFulfilled, let dragValue?) = value,
                    longPressFulfilled,
                    let coordinate = proxy.convert(dragValue.location, from: .global)
                else { return }
                state.movePlanningTarget(to: coordinate)
            }
    }

    private func distancePill(value: Int) -> some View {
        Text("\(value)")
            .font(.system(size: 13, weight: .bold, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(.black)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(.white.opacity(0.94), in: Capsule(style: .continuous))
            .overlay(
                Capsule(style: .continuous)
                    .stroke(.black.opacity(0.45), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.30), radius: 3, y: 1)
    }

    private var pinFlagMarker: some View {
        VStack(spacing: 0) {
            Image(systemName: "flag.fill")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(Color(red: 1.0, green: 0.83, blue: 0.20))
                .shadow(color: .black.opacity(0.55), radius: 2, y: 1)

            Capsule()
                .fill(.white.opacity(0.85))
                .frame(width: 2, height: 4)
        }
        .frame(width: 30, height: 30, alignment: .bottom)
    }

    private var teeMarker: some View {
        ZStack {
            Circle()
                .fill(.black.opacity(0.65))
                .frame(width: 10, height: 10)
            Circle()
                .stroke(.white, lineWidth: 2)
                .frame(width: 12, height: 12)
        }
        .shadow(color: .black.opacity(0.45), radius: 2, y: 1)
    }

    private var youMarker: some View {
        ZStack {
            Circle()
                .fill(.white)
                .frame(width: 16, height: 16)
            Circle()
                .fill(Color(red: 0.86, green: 0.16, blue: 0.16))
                .frame(width: 8, height: 8)
        }
        .shadow(color: .black.opacity(0.55), radius: 3, y: 1)
    }

    private var carryRingLegend: some View {
        // Group rings by club-zone colour so the legend stays compact even with 8
        // rings on the map. Each entry shows both ring radii in that zone (e.g.
        // "25 / 50" for the red chip zone).
        HStack(spacing: ShellTokens.Spacing.x10) {
            ForEach(FreshLiveRoundCarryRing.legendZones) { zone in
                HStack(spacing: 6) {
                    Circle()
                        .fill(zone.color)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle().stroke(.black.opacity(0.35), lineWidth: 0.5)
                        )

                    Text(zone.label)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, ShellTokens.Spacing.x12)
        .padding(.vertical, 8)
        .background(.black.opacity(0.55), in: Capsule(style: .continuous))
        .overlay(
            Capsule(style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.45), radius: 8, y: 4)
    }

    @MapContentBuilder
    private func overlay(for feature: SwingPalCourse.Hole.Feature) -> some MapContent {
        let coordinates = feature.coordinates.map(\.clCoordinate)

        switch feature.kind {
        case .fairway:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(Color(red: 0.34, green: 0.58, blue: 0.31).opacity(0.28))
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        case .green:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(Color(red: 0.63, green: 0.84, blue: 0.55).opacity(0.42))
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        case .bunker:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(Color(red: 0.90, green: 0.81, blue: 0.58).opacity(0.50))
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        case .water:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(Color(red: 0.30, green: 0.62, blue: 0.92).opacity(0.45))
                .stroke(Color.white.opacity(0.20), lineWidth: 1)
        case .tee:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(Color.white.opacity(0.18))
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        case .layup:
            MapPolygon(coordinates: coordinates)
                .foregroundStyle(Color.black.opacity(0.12))
                .stroke(Color.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
        }
    }

    private func syncCamera(to region: MKCoordinateRegion, animated: Bool = false) {
        if animated {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.92)) {
                cameraPosition = .region(region)
            }
        } else {
            cameraPosition = .region(region)
        }
    }

    private func syncCamera(to camera: MapCamera, animated: Bool = false) {
        if animated {
            withAnimation(.spring(response: 0.85, dampingFraction: 0.92)) {
                cameraPosition = .camera(camera)
            }
        } else {
            cameraPosition = .camera(camera)
        }
    }

    /// Centralised hole-framing logic shared by the initial appear, hole-change,
    /// inspect-toggle, and recenter-button code paths so they all converge on the
    /// same 3D tee-perspective view. Keeping this in one place means tweaks to
    /// pitch/distance/bias only need to happen in `LiveRoundState`.
    private func syncCameraToHoleFraming(animated: Bool = false) {
        isGreenInspectionPanClampActive = false
        let spec = state.teePerspectiveCameraSpec
        let camera = MapCamera(
            centerCoordinate: spec.center,
            distance: spec.distance,
            heading: spec.heading,
            pitch: spec.pitch
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
        isGreenInspectionPanClampActive = state.greenInspectionPanLimits != nil
        let camera = MapCamera(
            centerCoordinate: spec.center,
            distance: spec.distance,
            heading: spec.heading,
            pitch: spec.pitch
        )
        syncCamera(to: camera, animated: animated)
    }
}

/// Owns the launcher sheet's drag translation and applies the offset that
/// reveals/hides the sheet. This is intentionally split out from
/// `FreshLiveRoundScreen` so that finger movement during a sheet drag only
/// invalidates *this* view's body - the parent screen (which holds the
/// `Map` and its 18-hole feature tree, distance pills, carry rings, polylines
/// and annotations) stays untouched. With the drag `@State` on the parent
/// the body re-evaluated 60 times a second during drag, forcing MapKit to
/// re-diff every MapContent expression in `liveMap`, which is the actual
/// source of the long-running "jittery sheet" bug.
private struct FreshLiveRoundLauncherOffsetWrapper<Content: View>: View {
    let collapsedHeight: CGFloat
    let actionsHeight: CGFloat
    let expandedHeight: CGFloat
    let restingHeight: CGFloat
    let currentDetent: LiveRoundState.LauncherDetent
    @ViewBuilder let content: (Binding<CGFloat>) -> Content

    @State private var translation: CGFloat = 0

    var body: some View {
        content($translation)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .offset(y: expandedHeight - currentHeight)
            .animation(
                .spring(response: 0.34, dampingFraction: 0.86),
                value: currentDetent
            )
    }

    private var currentHeight: CGFloat {
        let proposed = restingHeight - translation
        return Self.rubberBandedHeight(
            proposed,
            lower: collapsedHeight,
            upper: expandedHeight
        )
    }

    /// Soft-clamps `raw` into `[lower, upper]`, allowing a small amount of
    /// over-travel beyond the detent boundaries. The 0.32 resistance factor
    /// mirrors UIKit's default rubber-band feel: pulling 100pt past a boundary
    /// reads ~32pt on screen, so the user gets tactile feedback that they're
    /// at the edge instead of hitting an invisible wall.
    private static func rubberBandedHeight(
        _ raw: CGFloat,
        lower: CGFloat,
        upper: CGFloat
    ) -> CGFloat {
        let resistance: CGFloat = 0.32
        if raw < lower {
            return lower - (lower - raw) * resistance
        }
        if raw > upper {
            return upper + (raw - upper) * resistance
        }
        return raw
    }
}

private struct FreshLiveRoundPrimaryActionButtonModifier: ViewModifier {
    let palette: FreshLiveRoundPalette

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glassProminent)
                .tint(palette.accent)
        } else {
            content
                .buttonStyle(.borderedProminent)
                .tint(palette.accent)
        }
    }
}

private struct FreshLiveRoundSecondaryActionButtonModifier: ViewModifier {
    let palette: FreshLiveRoundPalette

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content
                .buttonStyle(.glass)
                .tint(palette.accent)
        } else {
            content
                .buttonStyle(.bordered)
                .tint(palette.accent)
        }
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

private struct FreshLiveRoundClubLauncherFramePreferenceKey: PreferenceKey {
    static var defaultValue: CGRect = .zero

    static func reduce(value: inout CGRect, nextValue: () -> CGRect) {
        let next = nextValue()
        if next != .zero {
            value = next
        }
    }
}

private struct FreshLiveRoundClubWheelOverlay: View {
    @ObservedObject var state: LiveRoundState
    let anchorFrame: CGRect
    let safeAreaInsets: EdgeInsets
    let containerSize: CGSize
    let palette: FreshLiveRoundPalette

    @State private var previewClubName: String?
    @State private var hasAnimatedIn = false
    @State private var lastHoveredClubName: String?

    private let motion = FreshLiveRoundClubWheelMotion.standard
    private let hoverHaptics = UISelectionFeedbackGenerator()
    private let commitHaptics = UIImpactFeedbackGenerator(style: .medium)
    private let toggleHaptics = UIImpactFeedbackGenerator(style: .soft)

    var body: some View {
        let layout = FreshLiveRoundClubWheelLayout.resolve(
            anchorFrame: anchorFrame,
            safeAreaInsets: safeAreaInsets,
            containerSize: containerSize,
            entryCount: state.clubWheelEntries.count
        )
        let center = layout.center
        let activeEntry = resolvedEntry(named: previewClubName ?? state.selectedClubName)
        let selectedIndex = state.clubWheelEntries.firstIndex(where: { $0.clubName == state.selectedClubName }) ?? 0
        let isPreviewing = previewClubName != nil
        let isAutoEnabled = state.isClubAutoRecommendationEnabled

        ZStack {
            palette.scrim
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .opacity(hasAnimatedIn ? 1 : 0)
                .animation(.easeOut(duration: 0.18), value: hasAnimatedIn)
                .onTapGesture {
                    state.dismissClubWheel()
                }

            // Soft radial backdrop. Sits between the flat scrim and the
            // chrome circle so the wheel reads as a focal "puck" lifted
            // off the rest of the canvas instead of dissolving into the
            // dimmed map. The gradient stops are `wheelBackdrop ->
            // half-strength -> .clear`, so the dimming is concentrated
            // under the wheel and feathers seamlessly back into the
            // surrounding scrim. The chrome's ultraThinMaterial reads
            // through this darker patch to pick up extra contrast,
            // which is what gives the wheel its "lifted" feel.
            Circle()
                .fill(
                    RadialGradient(
                        gradient: Gradient(stops: [
                            .init(color: palette.wheelBackdrop, location: 0.0),
                            .init(color: palette.wheelBackdrop.opacity(0.6), location: 0.55),
                            .init(color: .clear, location: 1.0)
                        ]),
                        center: .center,
                        startRadius: 0,
                        endRadius: layout.outerRadius * 1.65
                    )
                )
                .frame(
                    width: layout.outerRadius * 3.3,
                    height: layout.outerRadius * 3.3
                )
                .position(center)
                .allowsHitTesting(false)
                .opacity(hasAnimatedIn ? 1 : 0)
                .scaleEffect(hasAnimatedIn ? 1 : 0.85)
                .animation(.easeOut(duration: 0.24), value: hasAnimatedIn)

            // Auto / Manual toggle. We render this *outside* the wheel's
            // drag-gesture container (below the chrome circle) so its tap
            // target isn't intercepted by the radial hover-select drag,
            // and so it visually reads as a global mode chip rather than a
            // 13th club spoke. Pinning it below the wheel keeps the top
            // spoke clear and gives the toggle a stable anchor that
            // doesn't compete with the entry tiles for vertical real
            // estate.
            FreshLiveRoundClubWheelAutoToggle(
                isEnabled: isAutoEnabled,
                palette: palette
            ) {
                toggleHaptics.impactOccurred(intensity: 0.65)
                state.toggleClubAutoRecommendation()
            }
            .position(
                x: center.x,
                y: min(
                    containerSize.height - safeAreaInsets.bottom - 32,
                    center.y + layout.outerRadius + 52
                )
            )
            .opacity(hasAnimatedIn ? 1 : 0)
            .scaleEffect(hasAnimatedIn ? 1 : 0.92)
            .animation(.spring(response: 0.3, dampingFraction: 0.86).delay(0.02), value: hasAnimatedIn)
            .zIndex(2)

            ZStack {
                ZStack {
                    // Single material disc with a tinted veil and a hairline
                    // edge. The previous design stacked a thick "plate" ring
                    // (24pt-wide stroke at the orbit diameter) on top of the
                    // chrome, which fought the entry tiles for visual
                    // weight. Letting the chrome read as a clean lens lets
                    // the spokes and the centre hub do the talking.
                    Circle()
                        .fill(.ultraThinMaterial)
                    Circle()
                        .fill(palette.chromeTint)
                    Circle()
                        .stroke(palette.wheelRingStroke, lineWidth: 1)
                    // A faint dashed orbit gives the wheel a sense of
                    // rotation without competing with the tiles.
                    Circle()
                        .stroke(
                            palette.wheelRingStroke.opacity(0.5),
                            style: StrokeStyle(lineWidth: 0.75, dash: [2, 5])
                        )
                        .frame(width: layout.orbitRingDiameter, height: layout.orbitRingDiameter)
                }
                .frame(width: layout.chromeDiameter, height: layout.chromeDiameter)
                .position(center)
                .scaleEffect(hasAnimatedIn ? 1 : 0.88)
                .opacity(hasAnimatedIn ? 1 : 0)
                .animation(.spring(response: 0.26, dampingFraction: 0.88), value: hasAnimatedIn)

                ForEach(Array(state.clubWheelEntries.enumerated()), id: \.element.id) { index, entry in
                    let isSelected = entry.clubName == activeEntry.clubName
                    let entryScale: CGFloat = {
                        if isSelected && entry.isRecommended { return motion.recommendedScale }
                        if isSelected { return motion.selectedScale }
                        if entry.isRecommended { return motion.recommendedScale * 0.94 }
                        return 1
                    }()
                    // Selected (and "REC") tiles must paint above their
                    // neighbours: their scale-up overlaps adjacent spokes
                    // and, without an explicit zIndex bump, MapKit's
                    // ForEach sibling order would let the next-clockwise
                    // tile clip the selected one's shadow / highlight.
                    let entryZIndex: Double = {
                        if isSelected { return 3 }
                        if entry.isRecommended { return 2 }
                        return 1
                    }()

                    FreshLiveRoundClubWheelEntryView(
                        entry: entry,
                        isSelected: isSelected,
                        isPutterMode: state.isClubWheelInPutterMode,
                        isAutoRecommendationEnabled: isAutoEnabled,
                        distanceUnit: state.distanceUnit,
                        palette: palette
                    )
                        .frame(width: layout.entrySize.width, height: layout.entrySize.height)
                        .position(
                            layout.entryPosition(
                                for: index,
                                count: state.clubWheelEntries.count,
                                selectedIndex: selectedIndex,
                                anchorFrame: anchorFrame
                            )
                        )
                        .opacity(hasAnimatedIn ? 1 : 0)
                        .scaleEffect(hasAnimatedIn ? entryScale : motion.entryBaseScale)
                        .zIndex(entryZIndex)
                        .animation(
                            .spring(response: 0.32, dampingFraction: 0.84)
                                .delay(Double(index) * motion.entryDelayStep),
                            value: hasAnimatedIn
                        )
                        .animation(.spring(response: 0.22, dampingFraction: 0.86), value: isSelected)
                        .onTapGesture {
                            commitHaptics.impactOccurred(intensity: 0.7)
                            state.selectClubFromWheel(named: entry.clubName)
                        }
                }

                FreshLiveRoundClubWheelCenterView(
                    entry: activeEntry,
                    targetDistanceMeters: state.displayedPinDistanceMeters,
                    playsLikeMeters: state.displayedPlaysLikeDistanceMeters,
                    recommendedClubName: state.recommendedClubName,
                    isPutterMode: state.isClubWheelInPutterMode,
                    isAutoRecommendationEnabled: isAutoEnabled,
                    isPreviewing: isPreviewing,
                    distanceUnit: state.distanceUnit,
                    palette: palette
                )
                    .frame(width: 132, height: 132)
                    .position(center)
                    .scaleEffect(hasAnimatedIn ? 1 : 0.9)
                    .opacity(hasAnimatedIn ? 1 : 0)
                    .animation(.spring(response: 0.28, dampingFraction: 0.88).delay(0.04), value: hasAnimatedIn)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0, coordinateSpace: .named("FreshLiveRoundScreenSpace"))
                    .onChanged { value in
                        // Hover-select only engages when the *touch started*
                        // inside the wheel's hit ring. Drags that originate
                        // on the scrim, the toggle pill, or any other
                        // off-wheel area must be ignored — otherwise
                        // sweeping a finger from the edge of the screen
                        // into the wheel would randomly commit a club on
                        // release.
                        guard isPointInsideWheel(value.startLocation, center: center, layout: layout) else {
                            return
                        }
                        // Pass the previously hovered club so the geometry
                        // helper can apply angular hysteresis. Without this
                        // an accidental drift past a sector boundary would
                        // immediately flip the selection to the adjacent
                        // spoke (often the previously-selected one at the
                        // top of the rotated wheel), which felt jittery.
                        let hovered = hoveredClubName(
                            for: value.location,
                            center: center,
                            layout: layout,
                            previousHoveredClubName: lastHoveredClubName
                        )
                        if hovered != lastHoveredClubName {
                            // Only fire selection haptic when crossing INTO a
                            // segment, not when sliding back into the dead zone.
                            if hovered != nil {
                                hoverHaptics.selectionChanged()
                                hoverHaptics.prepare()
                            }
                            lastHoveredClubName = hovered
                        }
                        previewClubName = hovered
                    }
                    .onEnded { value in
                        // Capture the final hovered club *before* clearing
                        // the gesture-tracking state so the hysteresis
                        // benefit applies on commit too — otherwise a drift
                        // past the boundary on release could pick a
                        // neighbour the player never visually engaged.
                        let finalHover: String? = {
                            guard isPointInsideWheel(value.startLocation, center: center, layout: layout) else {
                                return nil
                            }
                            return hoveredClubName(
                                for: value.location,
                                center: center,
                                layout: layout,
                                previousHoveredClubName: lastHoveredClubName
                            )
                        }()

                        previewClubName = nil
                        lastHoveredClubName = nil

                        // Off-wheel touches: if the player barely moved the
                        // finger we treat it as a "tap to dismiss" on the
                        // scrim. If they dragged any meaningful distance,
                        // we silently swallow the gesture — they were
                        // panning a finger into the wheel mid-drag, not
                        // selecting from it.
                        guard isPointInsideWheel(value.startLocation, center: center, layout: layout) else {
                            let translation = hypot(value.translation.width, value.translation.height)
                            if translation < FreshLiveRoundClubWheelOverlay.tapDismissTranslationThreshold {
                                state.dismissClubWheel()
                            }
                            return
                        }

                        if let finalHover {
                            commitHaptics.impactOccurred(intensity: 0.85)
                            state.selectClubFromWheel(named: finalHover)
                        } else {
                            state.dismissClubWheel()
                        }
                    }
            )
        }
        .onAppear {
            hoverHaptics.prepare()
            commitHaptics.prepare()
            toggleHaptics.prepare()
            hasAnimatedIn = true
        }
        .onDisappear {
            previewClubName = nil
            lastHoveredClubName = nil
            hasAnimatedIn = false
        }
    }

    private func hoveredClubName(
        for location: CGPoint,
        center: CGPoint,
        layout: FreshLiveRoundClubWheelLayout,
        previousHoveredClubName: String? = nil
    ) -> String? {
        let entries = state.clubWheelEntries
        let selectedIndex = entries.firstIndex(where: { $0.clubName == state.selectedClubName }) ?? 0
        return FreshLiveRoundClubWheelGeometry.hoveredClubName(
            for: location,
            center: center,
            clubNames: entries.map(\.clubName),
            segmentDistance: layout.segmentDistance,
            entrySize: layout.entrySize,
            innerSelectionRadius: layout.innerSelectionRadius,
            selectedIndex: selectedIndex,
            previousHoveredClubName: previousHoveredClubName
        )
    }

    /// Whether a touch lands inside the wheel's *visible* chrome. We
    /// deliberately clamp to `outerRadius` (the chrome's drawn edge)
    /// rather than the wider entry-corner envelope so drags that look
    /// like they started "outside the wheel" do nothing — the user's
    /// mental model is that the chrome circle is the wheel, even if the
    /// spoke tiles overhang it slightly. Direct taps on overhanging
    /// entry corners still work because each entry has its own
    /// `.onTapGesture`.
    private func isPointInsideWheel(_ location: CGPoint, center: CGPoint, layout: FreshLiveRoundClubWheelLayout) -> Bool {
        let dx = location.x - center.x
        let dy = location.y - center.y
        let distance = sqrt((dx * dx) + (dy * dy))
        return distance <= layout.outerRadius
    }

    /// Touches with translation under this threshold are treated as taps
    /// (so a tap on the scrim still dismisses the wheel). Anything beyond
    /// is considered a drag-from-outside which should do nothing.
    static let tapDismissTranslationThreshold: CGFloat = 8

    private func resolvedEntry(named clubName: String) -> LiveRoundState.ClubWheelEntry {
        state.clubWheelEntries.first(where: { $0.clubName == clubName }) ?? state.selectedClubWheelEntry
    }
}

private struct FreshLiveRoundClubWheelEntryView: View {
    let entry: LiveRoundState.ClubWheelEntry
    let isSelected: Bool
    let isPutterMode: Bool
    /// When `false` (manual mode) we never mute entries based on relevance;
    /// the wheel becomes a flat picker so the player can grab any club
    /// without the UI implying it's "wrong" for the shot.
    let isAutoRecommendationEnabled: Bool
    let distanceUnit: DistanceUnit
    let palette: FreshLiveRoundPalette

    private var isMutedRelevance: Bool {
        guard isAutoRecommendationEnabled else { return false }
        switch entry.relevance {
        case .tooLong, .tooShort, .mutedByPutterMode: return true
        case .viable: return false
        }
    }

    private var entryOpacity: Double {
        // Selected entries always read at full strength so the user can see
        // exactly what they're about to confirm. The recommended one is
        // visually loud through its ring + scale, so it's full opacity even
        // when relevance would otherwise mute it (which only happens when
        // there's literally no in-range option). Manual mode disables
        // muting outright via `isMutedRelevance`.
        if isSelected || entry.isRecommended { return 1 }
        return isMutedRelevance ? 0.55 : 1
    }

    private var fillForBackground: Color {
        if isSelected { return palette.accent }
        return palette.wheelEntryFill
    }

    private var primaryTextColor: Color {
        isSelected ? palette.accentForeground : palette.primaryTextColor
    }

    private var secondaryTextColor: Color {
        isSelected ? palette.accentForeground.opacity(0.86) : palette.secondaryTextColor
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 3) {
                Text(entry.clubName)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(primaryTextColor)
                    .minimumScaleFactor(0.75)
                    .lineLimit(1)

                gapOrCarryLabel
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)

            if entry.isRecommended {
                recommendedBadge
                    .padding(5)
            } else if !isSelected, entry.carrySource == .logged {
                // Only render the source dot for *logged* carries — the
                // baseline-vs-logged distinction is the whole point of the
                // chip, so an empty/outlined dot for baseline data
                // doubled as visual noise without conveying anything new.
                sourceDot
                    .padding(.trailing, 7)
                    .padding(.top, 7)
            }
        }
        .background(
            ZStack {
                // Selected: solid accent. Unselected: a quiet glass tile so
                // the chrome's material reads through. Removing the prior
                // screen-blend gradient drops a noisy highlight that
                // doubled up with the chrome's own glass shimmer.
                if isSelected {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.accent)
                } else {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(.ultraThinMaterial)
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.wheelEntryFill.opacity(0.55))
                }
            }
        )
        .overlay {
            // The recommendation halo lives outside the fill so a
            // simultaneously-selected-and-recommended tile reads as
            // "filled with a halo" — a single clear "yes" signal.
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(
                    entry.isRecommended ? palette.accent : (isSelected ? palette.accent.opacity(0.35) : palette.wheelRingStroke.opacity(0.85)),
                    lineWidth: entry.isRecommended ? 2 : 0.75
                )
        }
        .opacity(entryOpacity)
        .shadow(color: .black.opacity(isSelected ? 0.18 : 0.06), radius: isSelected ? 14 : 6, y: isSelected ? 8 : 4)
    }

    @ViewBuilder
    private var gapOrCarryLabel: some View {
        if isPutterMode && entry.clubName.caseInsensitiveCompare("Putter") != .orderedSame {
            // In auto putter mode the gap is meaningless; just keep the
            // non-putter entries visually quiet without trying to surface a
            // number. Manual mode never enters putter mode, so this branch
            // is only reachable when the assist is on.
            EmptyView()
        } else if isAutoRecommendationEnabled,
                  let gap = entry.gapToTargetMeters,
                  !isPutterMode {
            // Auto mode + gap data: show the signed delta to plays-like.
            HStack(spacing: 2) {
                Image(systemName: gapIconName(for: gap))
                    .font(.system(size: 9, weight: .bold))
                Text(formattedGap(gap))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .monospacedDigit()
            }
            .foregroundStyle(gapTextColor(for: gap))
        } else {
            // Manual mode (or no target distance available): show plain carry.
            // No "gap to target" framing because in manual mode the player
            // is making their own judgement about distance.
            Text(distanceUnit.shortLabel(forMeters: entry.displayCarryMeters))
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(secondaryTextColor)
        }
    }

    private var recommendedBadge: some View {
        Text("REC")
            .font(.system(size: 9, weight: .heavy, design: .rounded))
            .tracking(0.7)
            .foregroundStyle(palette.accentForeground)
            .padding(.horizontal, 6)
            .padding(.vertical, 2.5)
            .background(palette.accent, in: Capsule())
            .overlay(
                Capsule()
                    .stroke(palette.accentForeground.opacity(0.18), lineWidth: 0.5)
            )
    }

    /// A 5pt accent dot in the corner — appears only for logged carries
    /// to silently flag "this number came from your own shots".
    private var sourceDot: some View {
        Circle()
            .fill(palette.accent)
            .frame(width: 5, height: 5)
            .opacity(0.85)
            .accessibilityHidden(true)
    }

    private func gapIconName(for gap: Int) -> String {
        if abs(gap) <= 2 { return "checkmark" }
        return gap > 0 ? "arrow.up" : "arrow.down"
    }

    private func formattedGap(_ gapMeters: Int) -> String {
        if abs(gapMeters) <= 2 { return "On" }
        let absMeters = abs(gapMeters)
        let n = distanceUnit.scalarValue(fromMeters: absMeters)
        let suffix = distanceUnit.shortSuffix
        return gapMeters > 0 ? "+\(n)\(suffix)" : "-\(n)\(suffix)"
    }

    private func gapTextColor(for gap: Int) -> Color {
        if isSelected { return palette.accentForeground.opacity(0.92) }
        if abs(gap) <= 2 { return palette.accent }
        // We don't try to use semantic system colors here so the wheel reads
        // consistently against satellite imagery; we rely on the muted
        // opacity + arrow direction to convey "long" vs "short".
        return palette.secondaryTextColor
    }
}

private struct FreshLiveRoundClubWheelCenterView: View {
    let entry: LiveRoundState.ClubWheelEntry
    let targetDistanceMeters: Int
    let playsLikeMeters: Int
    let recommendedClubName: String?
    let isPutterMode: Bool
    /// When `false` we drop the REC chip and the auto putter-mode content
    /// in favour of a quiet "manual" hint, since both are recommendations
    /// and the user has explicitly opted out of being told what to hit.
    let isAutoRecommendationEnabled: Bool
    /// True while the user is dragging and previewing a different club. We
    /// dim the recommendation row slightly in that mode so the eye stays on
    /// the entry chip the finger is hovering over.
    let isPreviewing: Bool
    let distanceUnit: DistanceUnit
    let palette: FreshLiveRoundPalette

    private var hasPlaysLikeAdjustment: Bool {
        playsLikeMeters > 0 && playsLikeMeters != targetDistanceMeters
    }

    var body: some View {
        VStack(spacing: 4) {
            if isPutterMode {
                putterModeContent
            } else {
                liveContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 6)
        .freshGlass(Circle(), palette: palette, tint: palette.wheelCenterFill)
        .shadow(color: palette.shadowColor, radius: 14, y: 8)
    }

    @ViewBuilder
    private var liveContent: some View {
        Text("PIN")
            .font(.system(size: 10, weight: .heavy, design: .rounded))
            .tracking(0.8)
            .foregroundStyle(palette.secondaryTextColor)

        HStack(alignment: .lastTextBaseline, spacing: 2) {
            Text("\(distanceUnit.scalarValue(fromMeters: targetDistanceMeters))")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(palette.primaryTextColor)
            Text(distanceUnit.shortSuffix)
                .font(.caption.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
        }

        if hasPlaysLikeAdjustment {
            Text("Plays \(distanceUnit.shortLabel(forMeters: playsLikeMeters))")
                .font(.caption2.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(palette.tertiaryTextColor)
        }

        if isPreviewing {
            previewingChip
                .padding(.top, 2)
        } else if isAutoRecommendationEnabled, let recommendedClubName {
            recommendationChip(clubName: recommendedClubName)
                .padding(.top, 2)
        } else if !isAutoRecommendationEnabled {
            manualHintChip
                .padding(.top, 2)
        }
    }

    @ViewBuilder
    private var putterModeContent: some View {
        Image(systemName: "flag.checkered")
            .font(.system(size: 18, weight: .semibold))
            .foregroundStyle(palette.accent)

        Text("On the Green")
            .font(.subheadline.weight(.bold))
            .foregroundStyle(palette.primaryTextColor)

        Text("Putter recommended")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(palette.secondaryTextColor)
            .multilineTextAlignment(.center)
    }

    private func recommendationChip(clubName: String) -> some View {
        HStack(spacing: 4) {
            Text("REC")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(palette.accentForeground)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(palette.accent, in: Capsule())

            Text(clubName)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.primaryTextColor)
        }
    }

    /// Quiet "you're driving" indicator surfaced inside the hub when the
    /// user has manual mode on. Mirrors the `recommendationChip` slot so
    /// the layout doesn't bounce when the user toggles the assist.
    private var manualHintChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.tap.fill")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(palette.tertiaryTextColor)
            Text("Pick any club")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
        }
    }

    private var previewingChip: some View {
        HStack(spacing: 4) {
            Image(systemName: "hand.point.up.left.fill")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(palette.tertiaryTextColor)
            Text(entry.clubName)
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.primaryTextColor)
        }
    }
}

/// Top-of-wheel chip that flips between auto-recommendation and manual
/// modes. Lives outside the wheel's drag-gesture container so it can
/// receive its own taps without competing with the radial hover-select.
private struct FreshLiveRoundClubWheelAutoToggle: View {
    let isEnabled: Bool
    let palette: FreshLiveRoundPalette
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 8) {
                Image(systemName: isEnabled ? "sparkles" : "hand.tap.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isEnabled ? palette.accentForeground : palette.primaryTextColor)
                Text(isEnabled ? "Auto Club" : "Manual")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isEnabled ? palette.accentForeground : palette.primaryTextColor)
                    .tracking(0.3)
                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(isEnabled ? palette.accentForeground.opacity(0.92) : palette.tertiaryTextColor)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 11)
            .background(
                Group {
                    if isEnabled {
                        Capsule().fill(palette.accent)
                    } else {
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .overlay(Capsule().fill(palette.wheelEntryFill))
                    }
                }
            )
            .overlay(
                Capsule()
                    .stroke(isEnabled ? palette.accent.opacity(0.4) : palette.border, lineWidth: 1)
            )
            .shadow(color: palette.shadowColor, radius: 8, y: 5)
        }
        .buttonStyle(.plain)
        .contentShape(Capsule())
        .accessibilityLabel(isEnabled ? "Auto club selection on" : "Manual club selection")
        .accessibilityHint("Double tap to switch between auto-recommended and manual club selection.")
    }
}

private struct FreshLiveRoundHoleInspectorSheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.colorScheme) private var colorScheme

    private var palette: FreshLiveRoundPalette {
        FreshLiveRoundPalette.forColorScheme(colorScheme)
    }

    var body: some View {
        NavigationStack {
            List {
                if state.roundConfirmedHoleCount > 0 {
                    Section {
                        roundTotalsStrip
                            .listRowBackground(palette.secondaryFill)
                            .listRowSeparator(.hidden)
                    }
                }

                Section {
                    ForEach(state.holeInspectionEntries) { entry in
                        Button {
                            if let entryIndex = state.holeInspectionEntries.firstIndex(where: { $0.id == entry.id }) {
                                state.inspectHole(at: entryIndex)
                            }
                        } label: {
                            holeInspectionRow(for: entry)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(palette.secondaryFill)
                        .listRowSeparatorTint(palette.border)
                    }
                }
            }
            .freshRoundListChrome(palette: palette)
            .navigationTitle("Inspect Holes")
            .navigationBarTitleDisplayMode(.inline)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(palette.modalCanvas)
    }

    private var roundTotalsStrip: some View {
        let firs = state.roundFairwaysInRegulation
        let girs = state.roundGreensInRegulation
        return HStack(spacing: ShellTokens.Spacing.x12) {
            roundTotalsCell(label: "Score", value: state.roundScoreToParDisplay)
            roundTotalsDivider
            roundTotalsCell(
                label: "FIR",
                value: firs.applicable > 0 ? "\(firs.hit)/\(firs.applicable)" : "--"
            )
            roundTotalsDivider
            roundTotalsCell(
                label: "GIR",
                value: girs.applicable > 0 ? "\(girs.hit)/\(girs.applicable)" : "--"
            )
            roundTotalsDivider
            roundTotalsCell(label: "Putts", value: "\(state.roundTotalPutts)")
        }
        .padding(.vertical, ShellTokens.Spacing.x4)
    }

    private func roundTotalsCell(label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(palette.primaryTextColor)
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var roundTotalsDivider: some View {
        Rectangle()
            .fill(palette.border)
            .frame(width: 1, height: 28)
            .opacity(0.7)
    }

    private func holeInspectionRow(for entry: LiveRoundState.HoleInspectionEntry) -> some View {
        HStack(spacing: ShellTokens.Spacing.x12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Hole \(entry.number)")
                        .font(.headline.weight(.semibold))
                    Text("Par \(entry.par)")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(palette.secondaryTextColor)
                    if let scoreToPar = scoreToParBadge(for: entry) {
                        Text(scoreToPar.label)
                            .font(.caption.weight(.bold))
                            .monospacedDigit()
                            .foregroundStyle(scoreToPar.foreground)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(scoreToPar.background, in: Capsule(style: .continuous))
                    }
                }

                Text(scoreSubtitle(for: entry))
                    .font(.subheadline)
                    .foregroundStyle(palette.secondaryTextColor)

                if entry.score != nil || entry.putts != nil
                    || entry.fairwayHit != nil || entry.greenInRegulation != nil {
                    statRowChips(for: entry)
                }
            }

            Spacer()

            if entry.isDisplayed {
                Image(systemName: entry.isActive ? "location.fill" : "eye.fill")
                    .foregroundStyle(palette.accent)
            }
        }
        .padding(.vertical, 4)
    }

    private func statRowChips(for entry: LiveRoundState.HoleInspectionEntry) -> some View {
        HStack(spacing: 6) {
            if let fir = entry.fairwayHit {
                statChip(
                    title: "FIR",
                    systemImage: fir ? "checkmark" : "xmark",
                    isHit: fir
                )
            }
            if let gir = entry.greenInRegulation {
                statChip(
                    title: "GIR",
                    systemImage: gir ? "checkmark" : "xmark",
                    isHit: gir
                )
            }
            if let putts = entry.putts {
                statChip(
                    title: "Putts \(putts)",
                    systemImage: "circle.fill",
                    isHit: nil
                )
            }
        }
        .padding(.top, 2)
    }

    /// `isHit` semantics: `true` -> hit (green tint), `false` -> miss (subtle
    /// red tint), `nil` -> neutral count chip (e.g. putts).
    private func statChip(title: String, systemImage: String, isHit: Bool?) -> some View {
        let foreground: Color
        let background: Color
        switch isHit {
        case true?:
            foreground = palette.accent
            background = palette.accent.opacity(0.18)
        case false?:
            foreground = Color(red: 0.86, green: 0.42, blue: 0.42)
            background = Color(red: 0.86, green: 0.42, blue: 0.42).opacity(0.18)
        case nil:
            foreground = palette.primaryTextColor
            background = palette.tertiaryFill
        }
        return HStack(spacing: 4) {
            Image(systemName: systemImage)
                .font(.caption2.weight(.bold))
            Text(title)
                .font(.caption.weight(.semibold))
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .foregroundStyle(foreground)
        .background(background, in: Capsule(style: .continuous))
    }

    private func scoreToParBadge(for entry: LiveRoundState.HoleInspectionEntry) -> (label: String, foreground: Color, background: Color)? {
        guard let score = entry.score else { return nil }
        let delta = score - entry.par
        let label: String
        if delta == 0 { label = "E" }
        else if delta > 0 { label = "+\(delta)" }
        else { label = "\(delta)" }

        let foreground: Color
        let background: Color
        if delta < 0 {
            foreground = Color(red: 0.18, green: 0.58, blue: 0.32)
            background = foreground.opacity(0.18)
        } else if delta > 0 {
            foreground = Color(red: 0.86, green: 0.42, blue: 0.42)
            background = foreground.opacity(0.18)
        } else {
            foreground = palette.primaryTextColor
            background = palette.tertiaryFill
        }
        return (label, foreground, background)
    }

    private func scoreSubtitle(for entry: LiveRoundState.HoleInspectionEntry) -> String {
        if let score = entry.score {
            if entry.wasEditedAfterConfirmation {
                return "Score \(score) • edited after confirmation"
            }
            return entry.isConfirmed ? "Score \(score) • confirmed" : "Score \(score)"
        }

        if entry.isActive {
            return "Current live hole"
        }

        return "No score recorded yet"
    }
}

private struct FreshLiveRoundCurrentHoleEditorSheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var draft: LiveRoundState.CurrentHoleEditDraft

    private var palette: FreshLiveRoundPalette {
        FreshLiveRoundPalette.forColorScheme(colorScheme)
    }

    init(state: LiveRoundState) {
        self.state = state
        _draft = State(initialValue: state.makeCurrentHoleEditDraft())
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                        Text("Hole \(state.displayedHoleNumber) • Par \(state.displayedHoleSession.par)")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(palette.accent)
                        Text("Edit Current Hole")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.primaryTextColor)
                        Text("Correct score, putts, penalties, drops, and notes without leaving the live round.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryTextColor)
                    }

                    editorStepperRow(
                        title: "Score",
                        value: draft.score,
                        range: 1...20,
                        setValue: { draft.score = $0 }
                    )

                    editorStepperRow(
                        title: "Putts",
                        value: draft.putts,
                        range: 0...10,
                        setValue: { draft.putts = $0 }
                    )

                    HStack(spacing: ShellTokens.Spacing.x12) {
                        editorStepperRow(
                            title: "Penalties",
                            value: draft.penaltyCount,
                            range: 0...10,
                            setValue: { draft.penaltyCount = $0 }
                        )

                        editorStepperRow(
                            title: "Drops",
                            value: draft.dropCount,
                            range: 0...10,
                            setValue: { draft.dropCount = $0 }
                        )
                    }

                    editorTextField(
                        title: "Shot Outcomes",
                        prompt: "Outcome summary for this hole",
                        text: Binding(
                            get: { draft.shotOutcomeSummary },
                            set: { draft.shotOutcomeSummary = $0 }
                        )
                    )

                    editorTextField(
                        title: "Club Corrections",
                        prompt: "Correct clubs used if needed",
                        text: Binding(
                            get: { draft.clubCorrectionSummary },
                            set: { draft.clubCorrectionSummary = $0 }
                        )
                    )

                    editorTextField(
                        title: "Notes",
                        prompt: "Optional notes for this hole",
                        text: Binding(
                            get: { draft.notes },
                            set: { draft.notes = $0 }
                        )
                    )
                }
                .padding(ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x24)
            }
            .navigationTitle("Edit Current Hole")
            .navigationBarTitleDisplayMode(.inline)
            .freshRoundSheetCanvas(palette: palette)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        state.applyCurrentHoleEditDraft(draft)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(palette.modalCanvas)
    }

    private func editorStepperButton(
        systemImage: String,
        isEnabled: Bool,
        isProminent: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(isProminent ? palette.accent : palette.tertiaryFill, in: Circle())
                .foregroundStyle(isProminent ? palette.accentForeground : (isEnabled ? palette.primaryTextColor : palette.tertiaryTextColor))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func editorStepperRow(
        title: String,
        value: Int,
        range: ClosedRange<Int>,
        setValue: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)

            HStack(spacing: ShellTokens.Spacing.x12) {
                editorStepperButton(systemImage: "minus", isEnabled: value > range.lowerBound) {
                    setValue(max(range.lowerBound, value - 1))
                }

                Text("\(value)")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(palette.primaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ShellTokens.Spacing.x12)
                    .background(palette.secondaryFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                editorStepperButton(systemImage: "plus", isEnabled: value < range.upperBound, isProminent: true) {
                    setValue(min(range.upperBound, value + 1))
                }
            }
        }
    }

    private func editorTextField(
        title: String,
        prompt: String,
        text: Binding<String>
    ) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)

            TextField(prompt, text: text, axis: .vertical)
                .lineLimit(3, reservesSpace: true)
                .freshRoundInputFieldStyle(palette: palette)
        }
    }
}

private struct FreshLiveRoundShotHistorySheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.colorScheme) private var colorScheme

    private var palette: FreshLiveRoundPalette {
        FreshLiveRoundPalette.forColorScheme(colorScheme)
    }

    var body: some View {
        NavigationStack {
            Group {
                if state.displayedHoleSession.shots.isEmpty {
                    ContentUnavailableView(
                        "No Shots Yet",
                        systemImage: "figure.golf",
                        description: Text("Log a shot on this hole to build the shot history.")
                    )
                } else {
                    List {
                        Section("Hole \(state.displayedHoleNumber) • Par \(state.displayedHoleSession.par)") {
                            ForEach(state.displayedHoleSession.shots.reversed()) { shot in
                                shotHistoryRow(for: shot)
                                    .padding(.vertical, 4)
                                    .listRowBackground(palette.secondaryFill)
                                    .listRowSeparatorTint(palette.border)
                            }
                        }
                    }
                    .freshRoundListChrome(palette: palette)
                }
            }
            .navigationTitle("Shot History")
            .navigationBarTitleDisplayMode(.inline)
            .freshRoundSheetCanvas(palette: palette)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(palette.modalCanvas)
    }

    @ViewBuilder
    private func shotHistoryRow(for shot: ShotEvent) -> some View {
        let kind = state.shotHistoryEntryKind(for: shot)

        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: ShellTokens.Spacing.x8) {
                Text("Stroke \(shot.strokeNumber)")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)

                Spacer(minLength: 0)

                shotHistoryTrailingTag(for: shot, kind: kind)
            }

            Text(state.shotHistorySubtitle(for: shot))
                .font(.subheadline)
                .foregroundStyle(palette.secondaryTextColor)

            if let detail = state.shotHistoryDetail(for: shot) {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(palette.tertiaryTextColor)
            }
        }
    }

    @ViewBuilder
    private func shotHistoryTrailingTag(
        for shot: ShotEvent,
        kind: LiveRoundState.ShotHistoryEntryKind
    ) -> some View {
        switch kind {
        case .penalty:
            HStack(spacing: 4) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.caption.weight(.semibold))
                Text("Penalty")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(palette.accent)
        case .putt, .shot:
            Text(shot.clubName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accent)
        }
    }
}

private struct FreshLiveRoundConditionsSheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.colorScheme) private var colorScheme

    private var palette: FreshLiveRoundPalette {
        FreshLiveRoundPalette.forColorScheme(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                    windHeroCard
                    temperatureCard
                    skyCard
                    gpsCard

                    if let attribution = state.weatherAttributionText {
                        attributionCard(attribution)
                    }
                }
                .padding(ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x24)
            }
            .navigationTitle("Conditions")
            .navigationBarTitleDisplayMode(.inline)
            .freshRoundSheetCanvas(palette: palette)
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(palette.modalCanvas)
    }

    /// Hero card for wind. Replaces the old "Wind 12 km/h NW" list row
    /// with a glanceable read of the components that actually matter
    /// on course: a directional arrow rotated relative to the shot
    /// bearing, the speed in km/h, the head/cross breakdown, and the
    /// plays-like delta the calculator is currently applying.
    private var windHeroCard: some View {
        let hasWeather = state.weatherSnapshot != nil
        let isCalm = !state.hasUsableWindReading

        return VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            HStack(alignment: .center, spacing: ShellTokens.Spacing.x16) {
                heroWindArrow(diameter: 88, isCalm: !hasWeather || isCalm)

                VStack(alignment: .leading, spacing: 4) {
                    Text(hasWeather ? "Wind" : "Wind unavailable")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.secondaryTextColor)
                        .textCase(.uppercase)

                    if hasWeather {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text(windHeroSpeedValue)
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .foregroundStyle(palette.primaryTextColor)
                                .monospacedDigit()
                            Text("km/h")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(palette.secondaryTextColor)
                        }

                        Text(isCalm ? "Calm" : state.windRelativeCategory.label)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(palette.accent)
                    } else {
                        Text("Live conditions haven't loaded yet.")
                            .font(.subheadline)
                            .foregroundStyle(palette.secondaryTextColor)
                    }
                }
            }

            if hasWeather, let breakdown = state.windComponentBreakdownText {
                conditionsCallout(
                    systemImage: "scope",
                    title: "Components",
                    body: breakdown
                )
            }

            if hasWeather, state.playsLikeWindDeltaMeters != 0 {
                conditionsCallout(
                    systemImage: "ruler",
                    title: "Plays-like wind",
                    body: playsLikeDeltaText(meters: state.playsLikeWindDeltaMeters)
                )
            }
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(palette.secondaryFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    private var temperatureCard: some View {
        let hasWeather = state.weatherSnapshot != nil
        let tempDelta = state.playsLikeTemperatureDeltaMeters

        return conditionsMetricCard(
            iconSystemName: "thermometer.medium",
            title: "Temperature",
            value: hasWeather ? state.temperatureSummaryText : "--",
            footer: hasWeather && tempDelta != 0 ? playsLikeDeltaText(meters: tempDelta, suffix: " from temp") : nil
        )
    }

    private var skyCard: some View {
        let snapshot = state.weatherSnapshot
        return conditionsMetricCard(
            iconSystemName: snapshot?.symbolName ?? "cloud",
            title: "Sky",
            value: state.weatherConditionText,
            footer: nil
        )
    }

    private var gpsCard: some View {
        conditionsMetricCard(
            iconSystemName: "location.fill",
            title: "GPS",
            value: state.playerLocationStatusText,
            footer: nil
        )
    }

    private func attributionCard(_ attribution: String) -> some View {
        Text(attribution)
            .font(.footnote)
            .foregroundStyle(palette.tertiaryTextColor)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(ShellTokens.Spacing.x14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(palette.tertiaryFill)
            )
    }

    private func heroWindArrow(diameter: CGFloat, isCalm: Bool) -> some View {
        let rotationDegrees: Double = state.windRelativeMotionDegrees ?? 0

        return ZStack {
            Circle()
                .fill(palette.tertiaryFill)
                .overlay {
                    Circle().stroke(palette.border, lineWidth: 1)
                }

            // Compass tick marks (N/E/S/W positions on the dial) so the
            // arrow has a frame of reference and the player can read
            // the angle quickly even before parsing the category label.
            ForEach(0..<4, id: \.self) { index in
                Rectangle()
                    .fill(palette.border)
                    .frame(width: 1.5, height: 6)
                    .offset(y: -(diameter / 2) + 4)
                    .rotationEffect(.degrees(Double(index) * 90))
            }

            if isCalm {
                Image(systemName: "circle.dotted")
                    .font(.system(size: diameter * 0.36, weight: .semibold))
                    .foregroundStyle(palette.secondaryTextColor)
            } else {
                Image(systemName: "arrow.up")
                    .font(.system(size: diameter * 0.42, weight: .heavy))
                    .foregroundStyle(palette.accent)
                    .rotationEffect(.degrees(rotationDegrees))
            }
        }
        .frame(width: diameter, height: diameter)
        .animation(.easeInOut(duration: 0.3), value: rotationDegrees)
    }

    private func conditionsMetricCard(
        iconSystemName: String,
        title: String,
        value: String,
        footer: String?
    ) -> some View {
        HStack(alignment: .center, spacing: ShellTokens.Spacing.x14) {
            Image(systemName: iconSystemName)
                .font(.title2.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.accent)
                .frame(width: 36, height: 36)
                .background(
                    Circle().fill(palette.tertiaryFill)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(palette.secondaryTextColor)
                Text(value)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)
                if let footer {
                    Text(footer)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(palette.accent)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(ShellTokens.Spacing.x14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(palette.secondaryFill)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
    }

    private func conditionsCallout(
        systemImage: String,
        title: String,
        body: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(palette.accent)
                .frame(width: 22, height: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
                Text(body)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, ShellTokens.Spacing.x12)
        .padding(.vertical, ShellTokens.Spacing.x10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(palette.tertiaryFill)
        )
    }

    private var windHeroSpeedValue: String {
        guard let weather = state.weatherSnapshot else { return "--" }
        return "\(weather.windSpeedKilometersPerHour)"
    }

    private func playsLikeDeltaText(meters: Int, suffix: String = "") -> String {
        if meters > 0 {
            return "+\(meters) m to plays-like\(suffix)"
        } else if meters < 0 {
            return "\(meters) m to plays-like\(suffix)"
        } else {
            return "No effect on plays-like\(suffix)"
        }
    }
}

private struct FreshLiveRoundEndRoundSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    let onSaveAndExit: () -> Void
    let onDiscardRound: () -> Void

    private var palette: FreshLiveRoundPalette {
        FreshLiveRoundPalette.forColorScheme(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x24) {
                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                        HStack(alignment: .top, spacing: ShellTokens.Spacing.x12) {
                            ZStack {
                                Circle()
                                    .fill(palette.accent.opacity(0.14))
                                    .frame(width: 44, height: 44)

                                Image(systemName: "flag.checkered.2.crossed")
                                    .font(.headline.weight(.semibold))
                                    .foregroundStyle(palette.accent)
                            }

                            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x6) {
                                Text("ROUND STATUS")
                                    .font(ShellTokens.Typography.microEyebrow)
                                    .tracking(1.2)
                                    .foregroundStyle(palette.secondaryTextColor)

                                Text("Pause here or leave cleanly")
                                    .font(ShellTokens.Typography.sectionTitle)
                                    .foregroundStyle(palette.primaryTextColor)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Save this unfinished round so you can resume it later, or discard it completely if you're done with it.")
                                    .font(ShellTokens.Typography.body)
                                    .foregroundStyle(palette.secondaryTextColor)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }

                        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                            sheetSupportRow(
                                title: "Save & Exit",
                                detail: "Keep your current progress and reopen the round later."
                            )
                            sheetSupportRow(
                                title: "Discard Round",
                                detail: "Remove this unfinished round from the device completely."
                            )
                        }
                        .padding(ShellTokens.Spacing.x16)
                        .background(palette.secondaryFill, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous)
                                .stroke(palette.border.opacity(0.78), lineWidth: 1)
                        }
                    }

                    VStack(spacing: ShellTokens.Spacing.x12) {
                        sheetActionButton(
                            title: "Save & Exit",
                            subtitle: "Resume this round later",
                            isProminent: true
                        ) {
                            dismiss()
                            onSaveAndExit()
                        }

                        sheetActionButton(
                            title: "Keep Playing",
                            subtitle: "Close this sheet and continue the round",
                            isProminent: false
                        ) {
                            dismiss()
                        }

                        Button(role: .destructive) {
                            dismiss()
                            onDiscardRound()
                        } label: {
                            Text("Discard Round")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, ShellTokens.Spacing.x8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x12)
            }
            .navigationTitle("End Round")
            .navigationBarTitleDisplayMode(.inline)
            .freshRoundSheetCanvas(palette: palette)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(palette.modalCanvas)
    }

    private func sheetSupportRow(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(ShellTokens.Typography.microEyebrow)
                .tracking(0.8)
                .foregroundStyle(palette.primaryTextColor)

            Text(detail)
                .font(ShellTokens.Typography.body)
                .foregroundStyle(palette.secondaryTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func sheetActionButton(
        title: String,
        subtitle: String,
        isProminent: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .center, spacing: ShellTokens.Spacing.x12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(isProminent ? palette.accentForeground : palette.primaryTextColor)

                    Text(subtitle)
                        .font(ShellTokens.Typography.body)
                        .foregroundStyle(isProminent ? palette.accentForeground.opacity(0.88) : palette.secondaryTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Image(systemName: isProminent ? "arrow.right" : "pause.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(isProminent ? palette.accentForeground : palette.primaryTextColor)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ShellTokens.Spacing.x18)
            .padding(.vertical, ShellTokens.Spacing.x16)
            .background(
                isProminent ? palette.accent : palette.secondaryFill,
                in: RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous)
            )
            .overlay {
                if !isProminent {
                    RoundedRectangle(cornerRadius: ShellTokens.Radius.lg, style: .continuous)
                        .stroke(palette.border.opacity(0.82), lineWidth: 1)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct FreshLiveRoundHoleConfirmationSheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.colorScheme) private var colorScheme
    let onRoundFinished: () -> Void

    private var palette: FreshLiveRoundPalette {
        FreshLiveRoundPalette.forColorScheme(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    summaryHeader

                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                        summaryStepperRow(
                            title: "Score",
                            value: state.pendingHoleScore,
                            range: 1...20,
                            setValue: state.setPendingHoleScore
                        )

                        summaryStepperRow(
                            title: "Putts",
                            value: state.pendingHolePutts,
                            range: 0...10,
                            setValue: state.setPendingHolePutts
                        )

                        summaryStepperRow(
                            title: "Penalties",
                            value: state.pendingHolePenaltyCount,
                            range: 0...10,
                            setValue: state.setPendingHolePenaltyCount
                        )

                        summaryStepperRow(
                            title: "Drops",
                            value: state.pendingHoleDropCount,
                            range: 0...10,
                            setValue: state.setPendingHoleDropCount
                        )
                    }

                    VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
                        Text("Hole Notes")
                            .font(.headline.weight(.semibold))

                        TextField(
                            "Optional notes for this hole",
                            text: Binding(
                                get: { state.pendingHoleNotes ?? "" },
                                set: { state.setPendingHoleNotes($0) }
                            ),
                            axis: .vertical
                        )
                        .lineLimit(3, reservesSpace: true)
                        .freshRoundInputFieldStyle(palette: palette)
                    }

                    Button {
                        let previousHoleNumber = state.hole.number
                        guard state.confirmCurrentHole() else { return }
                        if state.hole.number == previousHoleNumber {
                            onRoundFinished()
                        }
                    } label: {
                        Text(state.canInspectNextHole ? "Confirm & Next Hole" : "Confirm & Finish Round")
                            .font(.headline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(palette.accent)
                    .disabled(!state.canConfirmHoleSummary)
                }
                .padding(ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x24)
            }
            .navigationTitle("Quick finish hole")
            .navigationBarTitleDisplayMode(.inline)
            .freshRoundSheetCanvas(palette: palette)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        state.dismissHoleConfirmation()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(palette.modalCanvas)
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
            Text("Hole \(state.displayedHoleNumber) • Par \(state.displayedHoleSession.par)")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.accent)
            Text("Picking up? Log the totals.")
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)
            Text("Pre-filled from your logged shots. Adjust the score and we'll move you to the next hole.")
                .font(.subheadline)
                .foregroundStyle(palette.secondaryTextColor)
        }
    }

    private func summaryStepperRow(
        title: String,
        value: Int?,
        range: ClosedRange<Int>,
        setValue: @escaping (Int?) -> Void
    ) -> some View {
        let resolvedValue = min(max(value ?? range.lowerBound, range.lowerBound), range.upperBound)

        return VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)

            HStack(spacing: ShellTokens.Spacing.x12) {
                Button {
                    setValue(max(range.lowerBound, resolvedValue - 1))
                } label: {
                    Image(systemName: "minus")
                        .font(.headline.weight(.semibold))
                        .frame(width: 42, height: 42)
                        .background(palette.tertiaryFill, in: Circle())
                        .foregroundStyle(resolvedValue > range.lowerBound ? palette.primaryTextColor : palette.tertiaryTextColor)
                }
                .buttonStyle(.plain)
                .disabled(resolvedValue <= range.lowerBound)

                Text("\(resolvedValue)")
                    .font(.title3.weight(.bold))
                    .monospacedDigit()
                    .foregroundStyle(palette.primaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ShellTokens.Spacing.x12)
                    .background(palette.secondaryFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                Button {
                    setValue(min(range.upperBound, resolvedValue + 1))
                } label: {
                    Image(systemName: "plus")
                        .font(.headline.weight(.semibold))
                        .frame(width: 42, height: 42)
                        .background(palette.accent, in: Circle())
                        .foregroundStyle(palette.accentForeground)
                }
                .buttonStyle(.plain)
                .disabled(resolvedValue >= range.upperBound)
            }
            .padding(.horizontal, ShellTokens.Spacing.x14)
            .padding(.vertical, ShellTokens.Spacing.x12)
            .background(palette.tertiaryFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
        }
    }

}

private struct FreshLiveRoundShotLoggerSheet: View {
    @ObservedObject var state: LiveRoundState
    @Environment(\.colorScheme) private var colorScheme
    @State var shotOutcomeIntensity: FreshLiveRoundShotOutcomeIntensity = .normal
    @State private var isLiePickerExpanded: Bool = false

    private let columns = [GridItem(.adaptive(minimum: 108), spacing: ShellTokens.Spacing.x12)]

    private var palette: FreshLiveRoundPalette {
        FreshLiveRoundPalette.forColorScheme(colorScheme)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x18) {
                    inferredLieBanner
                    contextHeader

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
                .padding(.horizontal, ShellTokens.Spacing.x20)
                .padding(.top, ShellTokens.Spacing.x16)
                .padding(.bottom, ShellTokens.Spacing.x24)
            }
            .navigationTitle(state.shotLoggingTitle)
            .navigationBarTitleDisplayMode(.inline)
            .freshRoundSheetCanvas(palette: palette)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        state.dismissShotLogger()
                    }
                }
            }
        }
        .modifier(FreshLiveRoundShotLoggerPresentationBackgroundModifier())
        .presentationDetents([.medium, .large])
        .presentationBackground(palette.modalCanvas)
        .onAppear {
            shotOutcomeIntensity = (state.pendingShotDirection == .farLeft || state.pendingShotDirection == .farRight) ? .far : .normal
        }
    }

    // MARK: - Top chrome

    private var inferredLieBanner: some View {
        let surface = state.pendingShotSurface

        return VStack(spacing: ShellTokens.Spacing.x10) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    isLiePickerExpanded.toggle()
                }
            } label: {
                HStack(spacing: ShellTokens.Spacing.x12) {
                    surfaceIconBadge(for: surface)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.pendingShotLieBannerTitle)
                            .font(.system(.subheadline, design: .rounded).weight(.bold))
                            .foregroundStyle(palette.primaryTextColor)
                        Text(state.pendingShotLieBannerSubtitle)
                            .font(.system(.caption, design: .rounded))
                            .foregroundStyle(palette.secondaryTextColor)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.tertiaryTextColor)
                        .rotationEffect(.degrees(isLiePickerExpanded ? -180 : 0))
                }
                .padding(.horizontal, ShellTokens.Spacing.x14)
                .padding(.vertical, ShellTokens.Spacing.x12)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(palette.secondaryFill)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)

            if isLiePickerExpanded {
                liePickerStrip
            }
        }
    }

    private var liePickerStrip: some View {
        HStack(spacing: ShellTokens.Spacing.x8) {
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
                            .font(.system(.caption2, design: .rounded).weight(.semibold))
                    }
                    .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryTextColor)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isSelected ? palette.accent : palette.loggerOptionFill)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? palette.accent.opacity(0.92) : palette.border, lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .transition(.move(edge: .top).combined(with: .opacity))
    }

    private func surfaceIconBadge(for surface: ShotEvent.Surface) -> some View {
        ZStack {
            Circle()
                .fill(palette.accent.opacity(0.16))
            Image(systemName: surfaceIconName(for: surface))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(palette.accent)
        }
        .frame(width: 36, height: 36)
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

    private var contextHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: ShellTokens.Spacing.x10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(state.pendingShotClubName)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.primaryTextColor)
                Text("\(state.pendingShotOriginLabel.lowercased(with: .current)) → \(state.pendingShotTargetLabel.lowercased(with: .current))")
                    .font(.system(.caption, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.secondaryTextColor)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(state.pendingShotDistanceLabel)
                    .font(.system(.title3, design: .rounded).weight(.bold))
                    .foregroundStyle(palette.accent)
                Text("to pin")
                    .font(.system(.caption2, design: .rounded).weight(.semibold))
                    .foregroundStyle(palette.tertiaryTextColor)
            }
        }
    }

    // MARK: - Context sections

    private var teeContextSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
            clubField

            shotOutcomeSection

            if state.availableShotTypes.contains(.provisionalBall) {
                provisionalChip
            }
        }
    }

    private var shotContextSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
            clubField
            shotOutcomeSection
        }
    }

    private var puttContextSection: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
            puttHoledMissedRow
            if state.pendingShotPuttHoled == false {
                puttMissPanel
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.28, dampingFraction: 0.86), value: state.pendingShotPuttHoled)
    }

    private var puttHoledMissedRow: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            sectionHeading(
                title: "How did the putt finish?",
                subtitle: "Tap holed or missed — required."
            )
            HStack(spacing: ShellTokens.Spacing.x12) {
                puttOutcomeChoice(
                    title: "Holed",
                    icon: "flag.checkered",
                    isSelected: state.pendingShotPuttHoled == true
                ) {
                    state.setPendingShotPuttHoled(true)
                }
                puttOutcomeChoice(
                    title: "Missed",
                    icon: "xmark.circle",
                    isSelected: state.pendingShotPuttHoled == false
                ) {
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
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                Text(title)
                    .font(.system(.headline, design: .rounded).weight(.bold))
            }
            .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryTextColor)
            .frame(maxWidth: .infinity, minHeight: 88)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(isSelected ? palette.accent : palette.loggerOptionFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(isSelected ? palette.accent.opacity(0.95) : palette.border, lineWidth: 1)
            }
            .shadow(color: isSelected ? palette.shadowColor.opacity(0.5) : .clear, radius: 12, y: 6)
            .scaleEffect(isSelected ? 1.02 : 1)
            .animation(.spring(response: 0.24, dampingFraction: 0.82), value: isSelected)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSelected)
    }

    private var puttMissPanel: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
            sectionHeading(
                title: "Where did it finish?",
                subtitle: "Tap the zone the ball came to rest in. Optional."
            )

            puttMissOutcomeDial

            optionalMetricStepperRow(
                title: "Miss distance",
                value: state.pendingShotPuttMissDistanceMeters,
                unsetLabel: "Add miss distance",
                suffix: "m",
                range: 0...30,
                setValue: { state.setPendingShotPuttMissDistanceMeters($0) }
            )
        }
    }

    private var puttMissOutcomeDial: some View {
        let layout = FreshLiveRoundShotOutcomeLayout.puttMiss

        return VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.tertiaryFill.opacity(0.92),
                                palette.panelFill.opacity(0.84)
                            ],
                            center: .center,
                            startRadius: 14,
                            endRadius: layout.ringDiameter / 2
                        )
                    )
                    .frame(width: layout.ringDiameter, height: layout.ringDiameter)
                    .overlay {
                        Circle()
                            .stroke(palette.border.opacity(0.9), lineWidth: 1)
                    }
                    .shadow(color: palette.shadowColor.opacity(0.6), radius: 14, y: 8)

                Circle()
                    .stroke(palette.border.opacity(0.22), lineWidth: 1)
                    .frame(width: layout.ringDiameter + 18, height: layout.ringDiameter + 18)

                ForEach(FreshLiveRoundShotOutcomeNode.allCases, id: \.self) { node in
                    puttMissOutcomeSegmentButton(node: node, layout: layout)
                }

                puttMissOutcomeCenter(size: layout.centerButtonSize)
            }
            .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .center)
            .frame(maxWidth: .infinity)

            puttMissSelectionChip
                .frame(maxWidth: .infinity)
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
        let segmentShape = FreshLiveRoundAnnularSegmentShape(
            startAngleDegrees: layout.startAngleDegrees(for: node),
            endAngleDegrees: layout.endAngleDegrees(for: node),
            innerRadiusRatio: layout.ringInnerRadiusRatio
        )
        let ringDiameter = layout.ringDiameter
        let labelPosition = layout.labelPosition(for: node)

        return Button {
            selectPuttMissOutcomeNode(node)
        } label: {
            ZStack {
                segmentShape
                    .fill(
                        LinearGradient(
                            colors: isSelected
                            ? [
                                palette.accent.opacity(0.96),
                                palette.accent
                            ]
                            : [
                                palette.loggerOptionFill.opacity(0.96),
                                palette.secondaryFill.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .overlay {
                        segmentShape
                            .stroke(isSelected ? palette.accent.opacity(0.92) : palette.border, lineWidth: 1)
                            .frame(width: ringDiameter, height: ringDiameter)
                    }
                    .overlay {
                        segmentShape
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.06), lineWidth: 0.75)
                            .blur(radius: 0.2)
                            .frame(width: ringDiameter, height: ringDiameter)
                    }
                    .shadow(color: isSelected ? palette.shadowColor.opacity(0.7) : .clear, radius: 10, y: 5)

                puttMissSegmentLabel(node: node)
                    .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryTextColor)
                    .position(labelPosition)
            }
            .frame(width: ringDiameter, height: ringDiameter)
        }
        .buttonStyle(.plain)
        .contentShape(segmentShape)
    }

    private func puttMissSegmentLabel(node: FreshLiveRoundShotOutcomeNode) -> some View {
        VStack(spacing: 3) {
            Image(systemName: outcomeSegmentIcon(for: node))
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
            Text(puttMissSegmentLabelText(for: node))
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(width: 60)
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
            Image(systemName: "scope")
                .font(.title3.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(palette.secondaryTextColor)
            Text("Cup")
                .font(.caption.weight(.bold))
                .foregroundStyle(palette.secondaryTextColor)
        }
        .frame(width: size.width, height: size.height)
        .background(
            Circle()
                .fill(palette.secondaryFill)
        )
        .overlay {
            Circle()
                .stroke(palette.border, lineWidth: 1)
        }
        .overlay {
            Circle()
                .stroke(palette.accent.opacity(0.42), style: StrokeStyle(lineWidth: 1.2, dash: [3, 3]))
                .padding(6)
        }
        .shadow(color: palette.shadowColor.opacity(0.5), radius: 10, y: 5)
        .accessibilityHidden(true)
    }

    private var puttMissSelectionChip: some View {
        let label = puttMissChipLabel
        let isEmpty = state.pendingShotPuttMissDirection == nil
            && state.pendingShotPuttMissDistance == nil

        return HStack(spacing: 8) {
            Image(systemName: isEmpty ? "hand.tap" : "scope")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(isEmpty ? palette.secondaryTextColor : palette.primaryTextColor)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEmpty ? palette.secondaryTextColor : palette.primaryTextColor)
                .contentTransition(.interpolate)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(palette.secondaryFill)
        )
        .overlay {
            Capsule().stroke(palette.border, lineWidth: 1)
        }
    }

    private var puttMissChipLabel: String {
        let direction = state.pendingShotPuttMissDirection
        let distance = state.pendingShotPuttMissDistance

        if direction == nil && distance == nil {
            return "Tap a zone to log the miss"
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

    private var clubField: some View {
        loggerMenuField(
            title: "Club",
            selectionTitle: state.pendingShotClubName
        ) {
            ForEach(state.availableClubNames, id: \.self) { clubName in
                Button(clubName) {
                    state.overridePendingShotClubName(clubName)
                }
            }
        }
    }

    private var provisionalChip: some View {
        let isSelected = state.pendingShotType == .provisionalBall
        return Button {
            state.setPendingShotType(isSelected ? nil : .provisionalBall)
        } label: {
            HStack(spacing: 8) {
                Image(systemName: isSelected ? "flag.2.crossed.fill" : "flag.2.crossed")
                    .font(.subheadline.weight(.semibold))
                Text("Hit a provisional ball")
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                Spacer(minLength: 0)
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryTextColor)
            .padding(.horizontal, ShellTokens.Spacing.x14)
            .padding(.vertical, ShellTokens.Spacing.x12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? palette.accent : palette.loggerOptionFill)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? palette.accent.opacity(0.92) : palette.border, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add detail disclosure

    private var addDetailDisclosure: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x14) {
            Button {
                withAnimation(.spring(response: 0.28, dampingFraction: 0.86)) {
                    state.toggleShotLoggerAddDetailVisibility()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                    Text(state.isShowingShotLoggerAddDetail ? "Hide detail" : "Add detail")
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                        .rotationEffect(.degrees(state.isShowingShotLoggerAddDetail ? -180 : 0))
                }
                .foregroundStyle(palette.secondaryTextColor)
                .padding(.horizontal, ShellTokens.Spacing.x14)
                .padding(.vertical, ShellTokens.Spacing.x12)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(palette.tertiaryFill.opacity(0.55))
                )
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
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                HStack(spacing: ShellTokens.Spacing.x12) {
                    metricStepperRow(
                        title: "Penalties",
                        value: state.pendingShotPenaltyCount,
                        range: 0...10,
                        setValue: state.setPendingShotPenaltyCount
                    )
                    metricStepperRow(
                        title: "Drops",
                        value: state.pendingShotDropCount,
                        range: 0...10,
                        setValue: state.setPendingShotDropCount
                    )
                }

                metricStepperRow(
                    title: "Stroke number",
                    value: state.pendingShotStrokeNumber,
                    range: 1...20,
                    setValue: state.setPendingShotStrokeNumber
                )

                optionSection(
                    title: "Strike quality",
                    options: ShotEvent.StrikeResult.allCases,
                    selection: state.pendingShotStrike,
                    label: strikeLabel(for:),
                    action: { option in
                        state.setPendingShotStrike(state.pendingShotStrike == option ? nil : option)
                    },
                    allowsDeselection: true
                )

                noteField
            }

        case .putt:
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x16) {
                optionalMetricStepperRow(
                    title: "Putt count override",
                    value: state.pendingShotPuttCount,
                    unsetLabel: "Auto (\(max(1, state.currentPlayerTotalPutts + 1)))",
                    range: 1...4,
                    setValue: { state.setPendingShotPuttCount($0) }
                )

                optionalMetricStepperRow(
                    title: "First putt distance",
                    value: state.pendingShotFirstPuttDistanceMeters,
                    unsetLabel: "Add starting distance",
                    suffix: "m",
                    range: 0...60,
                    setValue: { state.setPendingShotFirstPuttDistanceMeters($0) }
                )

                metricStepperRow(
                    title: "Penalties",
                    value: state.pendingShotPenaltyCount,
                    range: 0...10,
                    setValue: state.setPendingShotPenaltyCount
                )

                noteField
            }
        }
    }

    private var noteField: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            Text("Note")
                .font(.system(.subheadline, design: .rounded).weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)

            TextField(
                "Optional context for this shot",
                text: Binding(
                    get: { state.pendingShotNote ?? "" },
                    set: { state.setPendingShotNote($0) }
                ),
                axis: .vertical
            )
            .lineLimit(3, reservesSpace: true)
            .freshRoundInputFieldStyle(palette: palette)
        }
    }

    // MARK: - CTA

    private var primaryCTA: some View {
        Button {
            state.confirmPendingShot()
        } label: {
            Text(state.pendingShotConfirmCTAText)
                .font(.system(.title3, design: .rounded).weight(.bold))
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .tint(palette.accent)
        .disabled(!state.canConfirmPendingShot)
        .padding(.top, ShellTokens.Spacing.x4)
    }

    private func sectionHeading(title: String, subtitle: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.system(.headline, design: .rounded).weight(.bold))
                .foregroundStyle(palette.primaryTextColor)
            if let subtitle {
                Text(subtitle)
                    .font(.system(.caption, design: .rounded))
                    .foregroundStyle(palette.secondaryTextColor)
            }
        }
    }

    private func optionSection<Option: Hashable>(
        title: String,
        options: [Option],
        selection: Option?,
        label: @escaping (Option) -> String,
        action: @escaping (Option) -> Void,
        allowsDeselection: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)
                if allowsDeselection {
                    Text("Tap the active choice again to clear it.")
                        .font(.caption)
                        .foregroundStyle(palette.secondaryTextColor)
                }
            }

            LazyVGrid(columns: columns, spacing: ShellTokens.Spacing.x12) {
                ForEach(options, id: \.self) { option in
                    let isSelected = selection == option
                    Button {
                        action(option)
                    } label: {
                        Text(label(option))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryTextColor)
                            .frame(maxWidth: .infinity, minHeight: 56)
                            .background(
                                isSelected ? palette.accent : palette.loggerOptionFill,
                                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
                            )
                            .overlay {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(isSelected ? palette.accent.opacity(0.92) : palette.border, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var shotOutcomeSection: some View {
        let layout = FreshLiveRoundShotOutcomeLayout.standard
        let intensity = shotOutcomeIntensity

        return VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x4) {
                Text("Where did it land?")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)
                Text("Tap a zone — diagonals log distance and direction in one tap.")
                    .font(.caption)
                    .foregroundStyle(palette.secondaryTextColor)
            }

            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                palette.tertiaryFill.opacity(0.92),
                                palette.panelFill.opacity(0.84)
                            ],
                            center: .center,
                            startRadius: 18,
                            endRadius: layout.ringDiameter / 2
                        )
                    )
                    .frame(width: layout.ringDiameter, height: layout.ringDiameter)
                    .overlay {
                        Circle()
                            .stroke(palette.border.opacity(0.9), lineWidth: 1)
                    }
                    .shadow(color: palette.shadowColor.opacity(0.6), radius: 14, y: 8)

                Circle()
                    .stroke(palette.border.opacity(0.22), lineWidth: 1)
                    .frame(width: layout.ringDiameter + 20, height: layout.ringDiameter + 20)

                ForEach(FreshLiveRoundShotOutcomeNode.allCases, id: \.self) { node in
                    outcomeRingSegmentButton(node: node, layout: layout, intensity: intensity)
                }

                outcomeCenterHitButton(size: layout.centerButtonSize)
            }
            .frame(width: layout.canvasSize.width, height: layout.canvasSize.height, alignment: .center)
            .frame(maxWidth: .infinity)

            outcomeIntensitySelector

            shotOutcomeSelectionChip
                .frame(maxWidth: .infinity)
        }
        .sensoryFeedback(.selection, trigger: shotOutcomeSelectionToken)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.pendingShotDirection)
        .animation(.spring(response: 0.32, dampingFraction: 0.78), value: state.pendingShotDistance)
        .animation(.easeInOut(duration: 0.18), value: shotOutcomeIntensity)
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
        HStack(spacing: 6) {
            Image(systemName: "scope")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)
            Text("Miss intensity")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(palette.secondaryTextColor)

            Spacer(minLength: 8)

            HStack(spacing: 0) {
                ForEach(FreshLiveRoundShotOutcomeIntensity.allCases, id: \.self) { option in
                    let isActive = shotOutcomeIntensity == option
                    Button {
                        setShotOutcomeIntensity(option)
                    } label: {
                        Text(option.label)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(isActive ? palette.accentForeground : palette.primaryTextColor)
                            .frame(minWidth: 60)
                            .padding(.vertical, 6)
                            .padding(.horizontal, 12)
                            .background(
                                Capsule()
                                    .fill(isActive ? palette.accent : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                Capsule().fill(palette.secondaryFill)
            )
            .overlay {
                Capsule().stroke(palette.border, lineWidth: 1)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func outcomeCenterHitButton(size: CGSize) -> some View {
        let isCleanStrike = state.pendingShotDirection == .hit && state.pendingShotDistance == .onNumber

        return Button {
            state.selectShotDirection(.hit)
            state.selectShotDistance(.onNumber)
        } label: {
            VStack(spacing: 2) {
                Image(systemName: "target")
                    .font(.title2.weight(.semibold))
                    .symbolRenderingMode(.hierarchical)
                Text("Hit")
                    .font(.footnote.weight(.bold))
            }
            .foregroundStyle(isCleanStrike ? palette.accentForeground : palette.accent)
            .frame(width: size.width, height: size.height)
            .background(
                ZStack {
                    Circle()
                        .fill(isCleanStrike ? palette.accent : palette.secondaryFill)
                    Circle()
                        .stroke(
                            palette.accent.opacity(isCleanStrike ? 0 : 0.42),
                            style: StrokeStyle(lineWidth: 1.2, dash: [3, 3])
                        )
                        .padding(7)
                }
            )
            .overlay {
                Circle()
                    .stroke(
                        isCleanStrike ? palette.accent.opacity(0.92) : palette.border,
                        lineWidth: 1
                    )
            }
            .shadow(color: palette.shadowColor.opacity(isCleanStrike ? 0.7 : 0.5), radius: 12, y: 6)
            .scaleEffect(isCleanStrike ? 1.04 : 1)
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
    }

    private var shotOutcomeSelectionChip: some View {
        let label = shotOutcomeChipLabel
        let isCleanStrike = state.pendingShotDirection == .hit && state.pendingShotDistance == .onNumber
        let isEmpty = state.pendingShotDirection == nil && state.pendingShotDistance == nil

        return HStack(spacing: 8) {
            Image(systemName: chipIconName(isCleanStrike: isCleanStrike, isEmpty: isEmpty))
                .font(.footnote.weight(.semibold))
                .foregroundStyle(
                    isCleanStrike
                    ? palette.accent
                    : (isEmpty ? palette.secondaryTextColor : palette.primaryTextColor)
                )
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(isEmpty ? palette.secondaryTextColor : palette.primaryTextColor)
                .contentTransition(.interpolate)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule().fill(palette.secondaryFill)
        )
        .overlay {
            Capsule()
                .stroke(
                    isCleanStrike ? palette.accent.opacity(0.55) : palette.border,
                    lineWidth: 1
                )
        }
    }

    private func chipIconName(isCleanStrike: Bool, isEmpty: Bool) -> String {
        if isEmpty { return "hand.tap" }
        if isCleanStrike { return "checkmark.circle.fill" }
        return "scope"
    }

    private var shotOutcomeChipLabel: String {
        let direction = state.pendingShotDirection
        let distance = state.pendingShotDistance

        if direction == nil && distance == nil {
            return "Tap a zone to log the shot"
        }
        if direction == .hit && distance == .onNumber {
            return "Clean strike"
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
            return "Clean strike"
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
        let isSelected = isShotOutcomeNodeSelected(node)
        let segmentShape = FreshLiveRoundAnnularSegmentShape(
            startAngleDegrees: layout.startAngleDegrees(for: node),
            endAngleDegrees: layout.endAngleDegrees(for: node),
            innerRadiusRatio: layout.ringInnerRadiusRatio
        )
        let ringDiameter = layout.ringDiameter
        let labelPosition = layout.labelPosition(for: node)

        return Button {
            selectShotOutcomeNode(node)
        } label: {
            ZStack {
                segmentShape
                    .fill(
                        LinearGradient(
                            colors: isSelected
                            ? [
                                palette.accent.opacity(0.96),
                                palette.accent
                            ]
                            : [
                                palette.loggerOptionFill.opacity(0.96),
                                palette.secondaryFill.opacity(0.86)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: ringDiameter, height: ringDiameter)
                    .overlay {
                        segmentShape
                            .stroke(isSelected ? palette.accent.opacity(0.92) : palette.border, lineWidth: 1)
                            .frame(width: ringDiameter, height: ringDiameter)
                    }
                    .overlay {
                        segmentShape
                            .stroke(Color.white.opacity(isSelected ? 0.18 : 0.06), lineWidth: 0.75)
                            .blur(radius: 0.2)
                            .frame(width: ringDiameter, height: ringDiameter)
                    }
                    .shadow(color: isSelected ? palette.shadowColor.opacity(0.7) : .clear, radius: 10, y: 5)

                outcomeSegmentLabel(node: node, intensity: intensity)
                    .foregroundStyle(isSelected ? palette.accentForeground : palette.primaryTextColor)
                    .position(labelPosition)
            }
            .frame(width: ringDiameter, height: ringDiameter)
        }
        .buttonStyle(.plain)
        .contentShape(segmentShape)
    }

    private func outcomeSegmentLabel(
        node: FreshLiveRoundShotOutcomeNode,
        intensity: FreshLiveRoundShotOutcomeIntensity
    ) -> some View {
        let isFar = intensity == .far && node.lateralLean != .none

        return VStack(spacing: 3) {
            Image(systemName: outcomeSegmentIcon(for: node))
                .font(.subheadline.weight(.semibold))
                .symbolRenderingMode(.hierarchical)
            Text(outcomeSegmentLabelText(for: node, isFar: isFar))
                .font(.caption2.weight(.semibold))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.85)
        }
        .frame(width: 64)
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

    private func loggerMenuField<Content: View>(
        title: String,
        selectionTitle: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)

            Menu {
                content()
            } label: {
                HStack {
                    Text(selectionTitle)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(palette.primaryTextColor)
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(palette.secondaryTextColor)
                }
                .padding(.horizontal, ShellTokens.Spacing.x14)
                .padding(.vertical, ShellTokens.Spacing.x14)
                .background(palette.loggerOptionFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
        }
    }

    private func metricStepperRow(
        title: String,
        value: Int,
        suffix: String = "",
        range: ClosedRange<Int>,
        setValue: @escaping (Int) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(palette.primaryTextColor)

            HStack(spacing: ShellTokens.Spacing.x12) {
                stepperButton(systemImage: "minus", isEnabled: value > range.lowerBound) {
                    setValue(max(range.lowerBound, value - 1))
                }

                Text("\(value)\(suffix)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ShellTokens.Spacing.x12)
                    .background(palette.loggerOptionFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                stepperButton(systemImage: "plus", isEnabled: value < range.upperBound) {
                    setValue(min(range.upperBound, value + 1))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func optionalMetricStepperRow(
        title: String,
        value: Int?,
        unsetLabel: String,
        suffix: String = "",
        range: ClosedRange<Int>,
        setValue: @escaping (Int?) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x10) {
            HStack {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(palette.primaryTextColor)
                Spacer()
                if value != nil {
                    Button("Clear") {
                        setValue(nil)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(palette.accent)
                }
            }

            if let value {
                HStack(spacing: ShellTokens.Spacing.x12) {
                    stepperButton(systemImage: "minus", isEnabled: value > range.lowerBound) {
                        setValue(max(range.lowerBound, value - 1))
                    }

                    Text("\(value)\(suffix)")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(palette.primaryTextColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ShellTokens.Spacing.x12)
                        .background(palette.loggerOptionFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                    stepperButton(systemImage: "plus", isEnabled: value < range.upperBound) {
                        setValue(min(range.upperBound, value + 1))
                    }
                }
            } else {
                Button {
                    setValue(range.lowerBound)
                } label: {
                    HStack {
                        Text(unsetLabel)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(palette.secondaryTextColor)
                        Spacer()
                        Image(systemName: "plus.circle.fill")
                            .foregroundStyle(palette.accent)
                    }
                    .padding(.horizontal, ShellTokens.Spacing.x14)
                    .padding(.vertical, ShellTokens.Spacing.x14)
                    .background(palette.loggerOptionFill, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func stepperButton(systemImage: String, isEnabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.headline.weight(.semibold))
                .frame(width: 42, height: 42)
                .background(
                    (isEnabled ? palette.accent : palette.loggerOptionFill),
                    in: Circle()
                )
                .foregroundStyle(isEnabled ? palette.accentForeground : palette.tertiaryTextColor)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
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

    private func shotTypeLabel(for shotType: ShotEvent.ShotType) -> String {
        switch shotType {
        case .teeShot: return "Tee Shot"
        case .provisionalBall: return "Provisional Ball"
        case .approach: return "Approach"
        case .layup: return "Layup"
        case .recovery: return "Recovery"
        case .chip: return "Chip"
        case .pitch: return "Pitch"
        case .bunkerShot: return "Bunker"
        case .putt: return "Putt"
        }
    }
}
