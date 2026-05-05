import Foundation

struct WatchRoundGlanceMetric: Equatable {
    let title: String
    let value: String
}

struct WatchRoundMapFooterMetric: Equatable {
    let title: String
    let value: String
}

struct WatchRoundMapPresentation: Equatable {
    let ballX: Double
    let ballY: Double
    let targetX: Double
    let targetMarkerY: Double
    let frontMarkerX: Double
    let frontMarkerY: Double
    let backMarkerX: Double
    let backMarkerY: Double
    let greenTopY: Double
    let greenBottomY: Double
    let frontLabel: String
    let targetLabel: String
    let backLabel: String
}

struct WatchRoundCompanionViewModel: Equatable {
    let pinYardageText: String
    let selectedClubText: String
    let clubOptions: [String]
    let heroStatusText: String
    let heroContextText: String
    let showsTrustBanner: Bool
    let trustBannerTitle: String
    let trustBannerDetail: String
    let glanceMetrics: [WatchRoundGlanceMetric]
    let holeLabel: String
    let frontYardageText: String
    let backYardageText: String
    let shotCountText: String
    let syncBadgeText: String
    let lastMutationSourceText: String
    let primaryYardage: String
    let clubLabel: String
    let frontYardage: String
    let backYardage: String
    let shotLabel: String
    let scoreLabel: String
    let surfaceLabel: String
    let connectionLabel: String
    let canFinishHole: Bool
    let canSendCriticalActions: Bool
    let logShotButtonTitle: String
    let mapPresentation: WatchRoundMapPresentation
    let mapFooterMetrics: [WatchRoundMapFooterMetric]
    let swipeHintText: String

    init(
        snapshot: RoundCompanionSnapshot?,
        connectionState: RoundCompanionConnectionState? = nil,
        queuedActionCount: Int = 0,
        canQueueOfflineActions: Bool = false,
        actionFeedback: String? = nil
    ) {
        let resolvedConnectionState = connectionState ?? snapshot?.connectionState ?? .disconnected
        let trustBanner = Self.trustBanner(
            connectionState: resolvedConnectionState,
            queuedActionCount: queuedActionCount,
            canQueueOfflineActions: canQueueOfflineActions
        )
        let canSendCriticalActions = resolvedConnectionState != .disconnected || canQueueOfflineActions

        guard let snapshot else {
            pinYardageText = "--"
            selectedClubText = "No Round"
            clubOptions = Self.defaultClubOptions
            heroStatusText = "Awaiting Phone"
            heroContextText = "Connect a live round on iPhone."
            showsTrustBanner = trustBanner.showsBanner
            trustBannerTitle = trustBanner.title
            trustBannerDetail = trustBanner.detail
            glanceMetrics = Self.placeholderGlanceMetrics
            frontYardageText = "--"
            backYardageText = "--"
            shotCountText = "Shot --"
            syncBadgeText = Self.syncBadgeText(
                actionFeedback: actionFeedback,
                connectionState: resolvedConnectionState,
                lastMutationSource: nil,
                queuedActionCount: queuedActionCount
            )
            lastMutationSourceText = "Awaiting Phone"
            primaryYardage = "--"
            clubLabel = "No Round"
            holeLabel = "Waiting for phone"
            frontYardage = "--"
            backYardage = "--"
            shotLabel = "Shot --"
            scoreLabel = "Score --"
            surfaceLabel = "Surface --"
            connectionLabel = syncBadgeText
            canFinishHole = false
            self.canSendCriticalActions = canSendCriticalActions
            logShotButtonTitle = "Log Shot"
            mapPresentation = Self.placeholderMapPresentation
            mapFooterMetrics = Self.placeholderMapFooterMetrics
            swipeHintText = "Swipe left for actions"
            return
        }

        let unit = snapshot.distanceUnit
        pinYardageText = unit.shortLabel(forMeters: snapshot.distanceToTargetMeters)
        selectedClubText = snapshot.selectedClubName
        clubOptions = Self.makeClubOptions(
            availableClubNames: snapshot.availableClubNames,
            selectedClubName: snapshot.selectedClubName
        )
        heroStatusText = Self.heroStatusText(
            actionFeedback: actionFeedback,
            connectionState: resolvedConnectionState,
            queuedActionCount: queuedActionCount
        )
        heroContextText = Self.heroContextText(
            connectionState: resolvedConnectionState,
            lastMutationSource: snapshot.lastMutationSource,
            canQueueOfflineActions: canQueueOfflineActions
        )
        showsTrustBanner = trustBanner.showsBanner
        trustBannerTitle = trustBanner.title
        trustBannerDetail = trustBanner.detail
        glanceMetrics = [
            .init(title: "Front", value: unit.shortLabel(forMeters: snapshot.frontDistanceMeters)),
            .init(title: "Back", value: unit.shortLabel(forMeters: snapshot.backDistanceMeters)),
            .init(title: "Shot", value: String(snapshot.shotNumber)),
            .init(title: "Score", value: String(snapshot.holeScore)),
            .init(title: "Surface", value: snapshot.currentSurface),
        ]
        frontYardageText = unit.shortLabel(forMeters: snapshot.frontDistanceMeters)
        backYardageText = unit.shortLabel(forMeters: snapshot.backDistanceMeters)
        shotCountText = "Shot \(snapshot.shotNumber)"
        lastMutationSourceText = Self.lastMutationSourceText(for: snapshot.lastMutationSource)
        syncBadgeText = Self.syncBadgeText(
            actionFeedback: actionFeedback,
            connectionState: resolvedConnectionState,
            lastMutationSource: snapshot.lastMutationSource,
            queuedActionCount: queuedActionCount
        )
        primaryYardage = unit.shortLabel(forMeters: snapshot.distanceToTargetMeters)
        clubLabel = snapshot.selectedClubName
        holeLabel = "Hole \(snapshot.holeNumber) • Par \(snapshot.par)"
        frontYardage = unit.shortLabel(forMeters: snapshot.frontDistanceMeters)
        backYardage = unit.shortLabel(forMeters: snapshot.backDistanceMeters)
        shotLabel = "Shot \(snapshot.shotNumber)"
        scoreLabel = "Score \(snapshot.holeScore)"
        surfaceLabel = snapshot.currentSurface
        connectionLabel = syncBadgeText
        canFinishHole = snapshot.canFinishHole
        self.canSendCriticalActions = canSendCriticalActions
        logShotButtonTitle = "Log Shot"
        mapPresentation = Self.makeMapPresentation(from: snapshot)
        mapFooterMetrics = [
            .init(title: "Front", value: unit.shortLabel(forMeters: snapshot.frontDistanceMeters)),
            .init(title: "Pin", value: unit.shortLabel(forMeters: snapshot.distanceToTargetMeters)),
            .init(title: "Back", value: unit.shortLabel(forMeters: snapshot.backDistanceMeters)),
        ]
        swipeHintText = "Swipe left for actions"
    }

    private struct TrustBannerState {
        let showsBanner: Bool
        let title: String
        let detail: String
    }

    private static let placeholderGlanceMetrics = [
        WatchRoundGlanceMetric(title: "Front", value: "--"),
        WatchRoundGlanceMetric(title: "Back", value: "--"),
        WatchRoundGlanceMetric(title: "Shot", value: "--"),
        WatchRoundGlanceMetric(title: "Score", value: "--"),
        WatchRoundGlanceMetric(title: "Surface", value: "--"),
    ]

    private static let placeholderMapFooterMetrics = [
        WatchRoundMapFooterMetric(title: "Front", value: "--"),
        WatchRoundMapFooterMetric(title: "Pin", value: "--"),
        WatchRoundMapFooterMetric(title: "Back", value: "--"),
    ]

    private static let placeholderMapPresentation = WatchRoundMapPresentation(
        ballX: 0.50,
        ballY: 0.84,
        targetX: 0.54,
        targetMarkerY: 0.28,
        frontMarkerX: 0.34,
        frontMarkerY: 0.34,
        backMarkerX: 0.72,
        backMarkerY: 0.24,
        greenTopY: 0.18,
        greenBottomY: 0.38,
        frontLabel: "--",
        targetLabel: "--",
        backLabel: "--"
    )

    private static func connectionLabel(for state: RoundCompanionConnectionState) -> String {
        switch state {
        case .connected:
            return "Connected"
        case .syncing:
            return "Syncing"
        case .disconnected:
            return "Offline"
        }
    }

    private static func heroStatusText(
        actionFeedback: String?,
        connectionState: RoundCompanionConnectionState,
        queuedActionCount: Int
    ) -> String {
        if let actionFeedback {
            return actionFeedback
        }

        switch connectionState {
        case .connected:
            return "Live Round"
        case .syncing:
            return queuedActionCount > 0 ? "\(queuedActionCount) Queued" : "Syncing"
        case .disconnected:
            return "Offline"
        }
    }

    private static func heroContextText(
        connectionState: RoundCompanionConnectionState,
        lastMutationSource: RoundCompanionMutationSource,
        canQueueOfflineActions: Bool
    ) -> String {
        switch connectionState {
        case .connected:
            switch lastMutationSource {
            case .phone:
                return "Updated from iPhone."
            case .watch:
                return "Saved from Watch."
            }
        case .syncing:
            return "Queued actions will sync shortly."
        case .disconnected:
            return canQueueOfflineActions
            ? "Latest yardage is stale. New actions will queue."
            : "Reconnect to resume live sync."
        }
    }

    private static func lastMutationSourceText(for source: RoundCompanionMutationSource) -> String {
        switch source {
        case .phone:
            return "Updated from iPhone"
        case .watch:
            return "Updated from Watch"
        }
    }

    private static func syncBadgeText(
        actionFeedback: String?,
        connectionState: RoundCompanionConnectionState,
        lastMutationSource: RoundCompanionMutationSource?,
        queuedActionCount: Int
    ) -> String {
        switch connectionState {
        case .disconnected:
            return "Offline"
        case .syncing:
            return queuedActionCount > 0 ? "\(queuedActionCount) queued" : "Syncing"
        case .connected:
            if let actionFeedback {
                return actionFeedback
            }

            guard let lastMutationSource else {
                return connectionLabel(for: connectionState)
            }

            switch lastMutationSource {
            case .phone:
                return "Live on iPhone"
            case .watch:
                return "Saved from Watch"
            }
        }
    }

    private static func trustBanner(
        connectionState: RoundCompanionConnectionState,
        queuedActionCount: Int,
        canQueueOfflineActions: Bool
    ) -> TrustBannerState {
        switch connectionState {
        case .connected:
            return .init(showsBanner: false, title: "", detail: "")
        case .syncing:
            let title = queuedActionCount > 0 ? "\(queuedActionCount) actions queued" : "Syncing actions"
            return .init(
                showsBanner: true,
                title: title,
                detail: "Actions will replay when the iPhone link settles."
            )
        case .disconnected:
            if canQueueOfflineActions {
                return .init(
                    showsBanner: true,
                    title: "Offline, but queue-ready",
                    detail: "You can keep logging. Changes will send when the iPhone reconnects."
                )
            }

            return .init(
                showsBanner: true,
                title: "Phone unavailable",
                detail: "Reconnect before sending new critical actions."
            )
        }
    }

    private static let defaultClubOptions = [
        "Driver",
        "3W",
        "5W",
        "3H",
        "4H",
        "5H",
        "4i",
        "5i",
        "6i",
        "7i",
        "8i",
        "9i",
        "PW",
        "GW",
        "SW",
        "LW",
        "Putter",
    ]

    private static func makeClubOptions(
        availableClubNames: [String],
        selectedClubName: String
    ) -> [String] {
        let normalizedAvailable = availableClubNames.reduce(into: [String]()) { partialResult, clubName in
            if !partialResult.contains(clubName) {
                partialResult.append(clubName)
            }
        }

        if normalizedAvailable.isEmpty {
            if defaultClubOptions.contains(selectedClubName) {
                return defaultClubOptions
            }

            return [selectedClubName] + defaultClubOptions
        }

        if normalizedAvailable.contains(selectedClubName) {
            return normalizedAvailable
        }

        return normalizedAvailable + [selectedClubName]
    }

    private static func makeMapPresentation(from snapshot: RoundCompanionSnapshot) -> WatchRoundMapPresentation {
        let ballY = 0.86
        let topY = 0.16
        let maxDistance = max(
            snapshot.frontDistanceMeters,
            snapshot.distanceToTargetMeters,
            snapshot.backDistanceMeters,
            120
        )
        let verticalRange = ballY - topY
        let scale = verticalRange / Double(maxDistance)

        func markerY(for distance: Int) -> Double {
            let proposed = ballY - (Double(distance) * scale)
            return min(max(proposed, topY), ballY - 0.06)
        }

        let frontY = markerY(for: snapshot.frontDistanceMeters)
        let targetY = markerY(for: snapshot.distanceToTargetMeters)
        let backY = markerY(for: snapshot.backDistanceMeters)
        let greenTopY = max(min(frontY, targetY, backY) - 0.06, 0.08)
        let greenBottomY = min(max(frontY, targetY, backY) + 0.04, 0.46)

        return WatchRoundMapPresentation(
            ballX: 0.50,
            ballY: ballY,
            targetX: 0.55,
            targetMarkerY: targetY,
            frontMarkerX: 0.32,
            frontMarkerY: frontY,
            backMarkerX: 0.76,
            backMarkerY: backY,
            greenTopY: greenTopY,
            greenBottomY: greenBottomY,
            frontLabel: String(snapshot.frontDistanceMeters),
            targetLabel: String(snapshot.distanceToTargetMeters),
            backLabel: String(snapshot.backDistanceMeters)
        )
    }
}
