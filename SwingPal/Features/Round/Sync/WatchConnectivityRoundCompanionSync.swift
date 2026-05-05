import Foundation
#if canImport(WatchConnectivity)
import WatchConnectivity
#endif
#if os(iOS)
import MapKit
import UIKit
#endif

enum WatchCompanionInstallState: Equatable {
    case unsupported
    case notPaired
    case watchAppNotInstalled
    case installedButNotReachable
    case ready

    static func resolve(
        isSupported: Bool,
        isPaired: Bool,
        isWatchAppInstalled: Bool,
        isReachable: Bool
    ) -> WatchCompanionInstallState {
        guard isSupported else {
            return .unsupported
        }

        guard isPaired else {
            return .notPaired
        }

        guard isWatchAppInstalled else {
            return .watchAppNotInstalled
        }

        return isReachable ? .ready : .installedButNotReachable
    }
}

final class WatchConnectivityRoundCompanionSync: NSObject, RoundCompanionSyncing, RoundCompanionActionReceiving {
    private enum PayloadKey {
        static let action = "roundCompanionAction"
    }

    private let decoder = JSONDecoder()
    private var incomingActionHandler: ((RoundCompanionAction) -> Void)?
    private var latestPublishedSnapshot: RoundCompanionSnapshot?
    #if os(iOS)
    private var latestPreviewFingerprint: String?
    private var latestPreviewImageData: Data?
    #endif

    override init() {
        super.init()
        activateSessionIfAvailable()
    }

    func publish(snapshot: RoundCompanionSnapshot) {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        let session = WCSession.default
        latestPublishedSnapshot = snapshot
        let deliveredSnapshot = snapshotForCurrentSession(snapshot)
        guard canPublish(to: session) else { return }
        publishContext(snapshot: deliveredSnapshot, previewImageData: cachedPreviewImageData(for: deliveredSnapshot), using: session)
        #if os(iOS)
        renderAndPublishPreviewIfNeeded(for: deliveredSnapshot, using: session)
        #endif
        #endif
    }

    func clear() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        do {
            try WCSession.default.updateApplicationContext([:])
        } catch {
            return
        }
        #endif
    }

    func setIncomingActionHandler(_ handler: @escaping (RoundCompanionAction) -> Void) {
        incomingActionHandler = handler
    }

    private func activateSessionIfAvailable() {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return }
        WCSession.default.delegate = self
        WCSession.default.activate()
        #endif
    }

    #if canImport(WatchConnectivity)
    private func canPublish(to session: WCSession) -> Bool {
        let installState = WatchCompanionInstallState.resolve(
            isSupported: WCSession.isSupported(),
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable
        )

        switch installState {
        case .unsupported, .notPaired, .watchAppNotInstalled:
            logInstallDiagnostics(for: session)
            return false
        case .installedButNotReachable, .ready:
            return true
        }
    }

    private func logInstallDiagnostics(for session: WCSession) {
        let installState = WatchCompanionInstallState.resolve(
            isSupported: WCSession.isSupported(),
            isPaired: session.isPaired,
            isWatchAppInstalled: session.isWatchAppInstalled,
            isReachable: session.isReachable
        )

        print(
            """
            WatchConnectivity install state: \(installState) \
            paired=\(session.isPaired) \
            watchAppInstalled=\(session.isWatchAppInstalled) \
            reachable=\(session.isReachable) \
            activation=\(session.activationState.rawValue)
            """
        )
    }

    private func republishLatestSnapshotIfPossible(using session: WCSession) {
        guard let latestPublishedSnapshot else { return }
        guard canPublish(to: session) else { return }
        publish(snapshot: latestPublishedSnapshot)
    }

    private func publishContext(
        snapshot: RoundCompanionSnapshot,
        previewImageData: Data?,
        using session: WCSession
    ) {
        do {
            let context = try RoundCompanionContextPayload.context(
                snapshot: snapshot,
                previewImageData: previewImageData
            )
            try session.updateApplicationContext(context)
        } catch {
            print("WatchConnectivity publish failed: \(error)")
            logInstallDiagnostics(for: session)
        }
    }

    #if os(iOS)
    private func cachedPreviewImageData(for snapshot: RoundCompanionSnapshot) -> Data? {
        guard previewFingerprint(for: snapshot.previewSpec) == latestPreviewFingerprint else {
            return nil
        }
        return latestPreviewImageData
    }

    private func renderAndPublishPreviewIfNeeded(
        for snapshot: RoundCompanionSnapshot,
        using session: WCSession
    ) {
        let fingerprint = previewFingerprint(for: snapshot.previewSpec)
        guard fingerprint != latestPreviewFingerprint else { return }
        latestPreviewFingerprint = fingerprint

        guard let previewSpec = snapshot.previewSpec else {
            latestPreviewImageData = nil
            publishContext(snapshot: snapshot, previewImageData: nil, using: session)
            return
        }

        Task { [weak self] in
            guard let self else { return }
            let imageData = await RoundCompanionPreviewRenderer.renderImageData(for: previewSpec)
            self.latestPreviewImageData = imageData
            self.publishContext(snapshot: snapshot, previewImageData: imageData, using: session)
        }
    }

    private func previewFingerprint(for previewSpec: RoundCompanionPreviewSpec?) -> String? {
        guard let previewSpec else { return nil }
        let originLat = (previewSpec.originCoordinate.latitude * 10_000).rounded()
        let originLon = (previewSpec.originCoordinate.longitude * 10_000).rounded()
        let targetLat = (previewSpec.targetCoordinate.latitude * 10_000).rounded()
        let targetLon = (previewSpec.targetCoordinate.longitude * 10_000).rounded()

        return [
            String(previewSpec.holeBounds.minLatitude),
            String(previewSpec.holeBounds.maxLatitude),
            String(previewSpec.holeBounds.minLongitude),
            String(previewSpec.holeBounds.maxLongitude),
            String(originLat),
            String(originLon),
            String(targetLat),
            String(targetLon),
        ].joined(separator: "|")
    }
    #endif
    #endif

    private func handleIncomingActionData(_ data: Data) {
        guard let action = try? decoder.decode(RoundCompanionAction.self, from: data) else { return }
        incomingActionHandler?(action)
    }

    private func snapshotForCurrentSession(_ snapshot: RoundCompanionSnapshot) -> RoundCompanionSnapshot {
        #if canImport(WatchConnectivity)
        guard WCSession.isSupported() else { return snapshot }
        let session = WCSession.default
        let nextConnectionState: RoundCompanionConnectionState = session.isReachable ? .connected : .disconnected

        return .init(
            distanceUnit: snapshot.distanceUnit,
            holeNumber: snapshot.holeNumber,
            par: snapshot.par,
            selectedClubName: snapshot.selectedClubName,
            availableClubNames: snapshot.availableClubNames,
            frontDistanceMeters: snapshot.frontDistanceMeters,
            distanceToTargetMeters: snapshot.distanceToTargetMeters,
            backDistanceMeters: snapshot.backDistanceMeters,
            loggedShotCount: snapshot.loggedShotCount,
            shotNumber: snapshot.shotNumber,
            puttCount: snapshot.puttCount,
            penaltyCount: snapshot.penaltyCount,
            currentSurface: snapshot.currentSurface,
            holeScore: snapshot.holeScore,
            canFinishHole: snapshot.canFinishHole,
            isInspectingHole: snapshot.isInspectingHole,
            lastMutationSource: snapshot.lastMutationSource,
            lastMutationAt: snapshot.lastMutationAt,
            connectionState: nextConnectionState,
            previewSpec: snapshot.previewSpec
        )
        #else
        return snapshot
        #endif
    }
}

#if canImport(WatchConnectivity)
extension WatchConnectivityRoundCompanionSync: WCSessionDelegate {
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        logInstallDiagnostics(for: session)
        republishLatestSnapshotIfPossible(using: session)
    }

    #if os(iOS)
    func sessionWatchStateDidChange(_ session: WCSession) {
        logInstallDiagnostics(for: session)
        republishLatestSnapshotIfPossible(using: session)
    }

    func sessionDidBecomeInactive(_ session: WCSession) {}

    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
        handleIncomingActionData(messageData)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : Any] = [:]) {
        guard let data = userInfo[PayloadKey.action] as? Data else { return }
        handleIncomingActionData(data)
    }
}
#endif

#if os(iOS)
private struct RoundCompanionPreviewGeometry {
    let holeCenter: CLLocationCoordinate2D
    let origin: CLLocationCoordinate2D
    let target: CLLocationCoordinate2D
    let holeHeightMeters: CLLocationDistance
    let holeWidthMeters: CLLocationDistance
    let corridorDistance: CLLocationDistance

    static func make(for previewSpec: RoundCompanionPreviewSpec) -> RoundCompanionPreviewGeometry {
        let bounds = previewSpec.holeBounds
        let holeCenter = CLLocationCoordinate2D(
            latitude: (bounds.minLatitude + bounds.maxLatitude) / 2,
            longitude: (bounds.minLongitude + bounds.maxLongitude) / 2
        )

        let rawOrigin = coordinate(from: previewSpec.originCoordinate)
        let rawTarget = coordinate(from: previewSpec.targetCoordinate)
        let target = safeCoordinate(rawTarget, fallback: holeCenter, bounds: bounds)
        let origin = safeCoordinate(rawOrigin, fallback: holeCenter, bounds: bounds)

        let holeHeightMeters = CLLocation(latitude: bounds.minLatitude, longitude: holeCenter.longitude)
            .distance(from: CLLocation(latitude: bounds.maxLatitude, longitude: holeCenter.longitude))
        let holeWidthMeters = CLLocation(latitude: holeCenter.latitude, longitude: bounds.minLongitude)
            .distance(from: CLLocation(latitude: holeCenter.latitude, longitude: bounds.maxLongitude))
        let corridorDistance = CLLocation(latitude: origin.latitude, longitude: origin.longitude)
            .distance(from: CLLocation(latitude: target.latitude, longitude: target.longitude))

        return .init(
            holeCenter: holeCenter,
            origin: origin,
            target: target,
            holeHeightMeters: holeHeightMeters,
            holeWidthMeters: holeWidthMeters,
            corridorDistance: corridorDistance
        )
    }

    private static func safeCoordinate(
        _ coordinate: CLLocationCoordinate2D,
        fallback: CLLocationCoordinate2D,
        bounds: RoundCompanionPreviewBounds
    ) -> CLLocationCoordinate2D {
        guard CLLocationCoordinate2DIsValid(coordinate),
              coordinate.latitude.isFinite,
              coordinate.longitude.isFinite
        else {
            return fallback
        }

        guard coordinate.latitude >= bounds.minLatitude,
              coordinate.latitude <= bounds.maxLatitude,
              coordinate.longitude >= bounds.minLongitude,
              coordinate.longitude <= bounds.maxLongitude
        else {
            return fallback
        }

        return coordinate
    }

    private static func coordinate(from coordinate: RoundCompanionPreviewCoordinate) -> CLLocationCoordinate2D {
        .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }
}

private struct RoundCompanionPreviewViewport {
    let center: CLLocationCoordinate2D
    let latitudinalMeters: CLLocationDistance
    let longitudinalMeters: CLLocationDistance

    var region: MKCoordinateRegion {
        MKCoordinateRegion(
            center: center,
            latitudinalMeters: latitudinalMeters,
            longitudinalMeters: longitudinalMeters
        )
    }

    static func make(for previewSpec: RoundCompanionPreviewSpec) -> RoundCompanionPreviewViewport {
        let geometry = RoundCompanionPreviewGeometry.make(for: previewSpec)

        let bias = 0.58
        let center = CLLocationCoordinate2D(
            latitude: geometry.origin.latitude + (geometry.target.latitude - geometry.origin.latitude) * bias,
            longitude: geometry.origin.longitude + (geometry.target.longitude - geometry.origin.longitude) * bias
        )

        let latitudinalMeters = max(max(geometry.corridorDistance * 1.16, geometry.holeHeightMeters * 1.05), 170)
        let unclampedWidth = max(max(geometry.corridorDistance * 0.26, geometry.holeWidthMeters * 0.74), 76)
        let longitudinalMeters = min(unclampedWidth, latitudinalMeters * 0.52)

        return .init(
            center: center,
            latitudinalMeters: latitudinalMeters,
            longitudinalMeters: longitudinalMeters
        )
    }
}

private enum RoundCompanionPreviewRenderer {
    static func renderImageData(for previewSpec: RoundCompanionPreviewSpec) async -> Data? {
        let size = CGSize(width: 108, height: 192)
        let snapshot = await makeSnapshot(for: previewSpec, size: size)
        guard let snapshot else { return nil }
        let geometry = RoundCompanionPreviewGeometry.make(for: previewSpec)

        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            snapshot.image.draw(in: rect)

            UIColor(white: 0, alpha: 0.10).setFill()
            context.cgContext.fill(rect)
            drawVignette(in: rect, context: context.cgContext)

            let origin = snapshot.point(for: geometry.origin)
            let target = snapshot.point(for: geometry.target)

            let path = UIBezierPath()
            path.move(to: origin)
            path.addLine(to: target)
            path.setLineDash([4, 4], count: 2, phase: 0)
            path.lineWidth = 2
            UIColor.white.withAlphaComponent(0.85).setStroke()
            path.stroke()

            drawMarker(at: target, in: context.cgContext, systemName: "flag.fill", tint: UIColor.white)
            drawBall(at: origin, in: context.cgContext)
        }

        return image.jpegData(compressionQuality: 0.72)
    }

    private static func makeSnapshot(
        for previewSpec: RoundCompanionPreviewSpec,
        size: CGSize
    ) async -> MKMapSnapshotter.Snapshot? {
        let options = MKMapSnapshotter.Options()
        options.size = size
        options.scale = UIScreen.main.scale
        options.mapType = .satellite
        options.showsBuildings = false
        options.region = RoundCompanionPreviewViewport.make(for: previewSpec).region

        return await withCheckedContinuation { continuation in
            MKMapSnapshotter(options: options).start(with: .main) { snapshot, _ in
                continuation.resume(returning: snapshot)
            }
        }
    }

    private static func coordinate(from coordinate: RoundCompanionPreviewCoordinate) -> CLLocationCoordinate2D {
        .init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private static func drawMarker(
        at point: CGPoint,
        in context: CGContext,
        systemName: String,
        tint: UIColor
    ) {
        let configuration = UIImage.SymbolConfiguration(pointSize: 17, weight: .bold)
        guard let image = UIImage(systemName: systemName, withConfiguration: configuration)?
            .withTintColor(tint, renderingMode: .alwaysOriginal),
              let cgImage = image.cgImage
        else { return }

        let rect = CGRect(x: point.x - 8, y: point.y - 10, width: 16, height: 18)
        context.draw(cgImage, in: rect)
    }

    private static func drawBall(at point: CGPoint, in context: CGContext) {
        let glowRect = CGRect(x: point.x - 13, y: point.y - 13, width: 26, height: 26)
        context.setFillColor(UIColor.white.withAlphaComponent(0.18).cgColor)
        context.fillEllipse(in: glowRect)

        let ballRect = CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14)
        context.setFillColor(UIColor.white.cgColor)
        context.fillEllipse(in: ballRect)
        context.setStrokeColor(UIColor.black.withAlphaComponent(0.24).cgColor)
        context.setLineWidth(1)
        context.strokeEllipse(in: ballRect)
    }

    private static func drawVignette(in rect: CGRect, context: CGContext) {
        guard let verticalGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.black.withAlphaComponent(0.58).cgColor,
                UIColor.clear.cgColor,
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.66).cgColor,
            ] as CFArray,
            locations: [0.0, 0.17, 0.72, 1.0]
        ) else {
            return
        }

        context.saveGState()
        context.drawLinearGradient(
            verticalGradient,
            start: CGPoint(x: rect.midX, y: rect.minY),
            end: CGPoint(x: rect.midX, y: rect.maxY),
            options: []
        )
        context.restoreGState()

        guard let horizontalGradient = CGGradient(
            colorsSpace: CGColorSpaceCreateDeviceRGB(),
            colors: [
                UIColor.black.withAlphaComponent(0.34).cgColor,
                UIColor.clear.cgColor,
            ] as CFArray,
            locations: [0.0, 1.0]
        ) else {
            return
        }

        let sideWidth = rect.width * 0.24

        context.saveGState()
        context.clip(to: CGRect(x: rect.minX, y: rect.minY, width: sideWidth, height: rect.height))
        context.drawLinearGradient(
            horizontalGradient,
            start: CGPoint(x: rect.minX, y: rect.midY),
            end: CGPoint(x: rect.minX + sideWidth, y: rect.midY),
            options: []
        )
        context.restoreGState()

        context.saveGState()
        context.clip(to: CGRect(x: rect.maxX - sideWidth, y: rect.minY, width: sideWidth, height: rect.height))
        context.drawLinearGradient(
            horizontalGradient,
            start: CGPoint(x: rect.maxX, y: rect.midY),
            end: CGPoint(x: rect.maxX - sideWidth, y: rect.midY),
            options: [.drawsBeforeStartLocation]
        )
        context.restoreGState()
    }
}
#endif
