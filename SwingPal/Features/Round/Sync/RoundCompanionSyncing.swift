import Foundation

enum DistanceUnit: String, Equatable, Codable, CaseIterable {
    case meters
    case yards

    var shortSuffix: String {
        switch self {
        case .meters: return "m"
        case .yards: return "yd"
        }
    }

    func scalarValue(fromMeters meters: Int) -> Int {
        guard meters > 0 else { return 0 }
        switch self {
        case .meters:
            return meters
        case .yards:
            return Int((Double(meters) * 1.0936133).rounded())
        }
    }

    func shortLabel(forMeters meters: Int) -> String {
        "\(scalarValue(fromMeters: meters))\(shortSuffix)"
    }

    func travelLabel(forKilometers kilometers: Double) -> String {
        switch self {
        case .meters:
            return "\(kilometers.formatted(.number.precision(.fractionLength(1)))) km"
        case .yards:
            let miles = kilometers * 0.621371
            return "\(miles.formatted(.number.precision(.fractionLength(1)))) mi"
        }
    }
}

protocol RoundCompanionSyncing: AnyObject {
    func publish(snapshot: RoundCompanionSnapshot)
    func clear()
}

protocol RoundCompanionActionReceiving: AnyObject {
    func setIncomingActionHandler(_ handler: @escaping (RoundCompanionAction) -> Void)
}

enum RoundCompanionMutationSource: String, Equatable, Codable {
    case phone
    case watch
}

enum RoundCompanionConnectionState: String, Equatable, Codable {
    case connected
    case syncing
    case disconnected
}

struct RoundCompanionPreviewBounds: Equatable, Codable {
    let minLatitude: Double
    let maxLatitude: Double
    let minLongitude: Double
    let maxLongitude: Double
}

struct RoundCompanionPreviewCoordinate: Equatable, Codable {
    let latitude: Double
    let longitude: Double
}

struct RoundCompanionPreviewSpec: Equatable, Codable {
    let holeBounds: RoundCompanionPreviewBounds
    let originCoordinate: RoundCompanionPreviewCoordinate
    let targetCoordinate: RoundCompanionPreviewCoordinate
}

#if !os(watchOS)
// `RoundCompanionPreviewCorridorBounds` synthesises preview rectangles
// from `SwingPalCourse` data on the phone, then ships the result to the
// watch as a plain `RoundCompanionPreviewBounds`. The watch target
// doesn't include `SwingPalCourse.swift`, so we keep the producer
// gated to non-watchOS to keep the shared sync types compiling on
// both platforms.
enum RoundCompanionPreviewCorridorBounds {
    private static let preferredKinds: [SwingPalCourse.Hole.FeatureKind] = [.tee, .fairway, .layup, .green]

    static func resolve(
        for hole: SwingPalCourse.Hole,
        bufferMeters: Double = 10
    ) -> RoundCompanionPreviewBounds? {
        let corridorCoordinates = hole.features
            .filter { preferredKinds.contains($0.kind) }
            .flatMap(\.coordinates)

        let resolvedBounds = SwingPalCourse.Hole.bounds(
            containing: corridorCoordinates,
            bufferMeters: bufferMeters
        ) ?? hole.bounds

        guard let resolvedBounds else {
            return nil
        }

        return .init(
            minLatitude: resolvedBounds.minLatitude,
            maxLatitude: resolvedBounds.maxLatitude,
            minLongitude: resolvedBounds.minLongitude,
            maxLongitude: resolvedBounds.maxLongitude
        )
    }
}
#endif

enum RoundCompanionAction: Equatable, Codable {
    case changeClub(name: String)
    case logShot(direction: String, distance: String, surface: String?)
    case addPenalty
    case markDrop
    case addPutt
    case finishHole
    case undoLastAction
    case recenterTarget
}

struct RoundCompanionSnapshot: Equatable, Codable {
    let distanceUnit: DistanceUnit
    let holeNumber: Int
    let par: Int
    let selectedClubName: String
    let availableClubNames: [String]
    let frontDistanceMeters: Int
    let distanceToTargetMeters: Int
    let backDistanceMeters: Int
    let loggedShotCount: Int
    let shotNumber: Int
    let puttCount: Int
    let penaltyCount: Int
    let currentSurface: String
    let holeScore: Int
    let canFinishHole: Bool
    let isInspectingHole: Bool
    let lastMutationSource: RoundCompanionMutationSource
    let lastMutationAt: Date
    let connectionState: RoundCompanionConnectionState
    let previewSpec: RoundCompanionPreviewSpec?
}

enum RoundCompanionContextPayload {
    private enum PayloadKey {
        static let snapshot = "roundCompanionSnapshot"
        static let previewImage = "roundCompanionPreviewImage"
    }

    static func context(
        snapshot: RoundCompanionSnapshot,
        previewImageData: Data?
    ) throws -> [String: Any] {
        let encoder = JSONEncoder()
        var context: [String: Any] = [
            PayloadKey.snapshot: try encoder.encode(snapshot)
        ]

        if let previewImageData {
            context[PayloadKey.previewImage] = previewImageData
        }

        return context
    }

    static func snapshot(from context: [String: Any]) throws -> RoundCompanionSnapshot {
        let decoder = JSONDecoder()
        guard let data = context[PayloadKey.snapshot] as? Data else {
            throw NSError(domain: "RoundCompanionContextPayload", code: 1)
        }
        return try decoder.decode(RoundCompanionSnapshot.self, from: data)
    }

    static func previewImageData(from context: [String: Any]) -> Data? {
        context[PayloadKey.previewImage] as? Data
    }
}

final class NoOpRoundCompanionSync: RoundCompanionSyncing {
    func publish(snapshot: RoundCompanionSnapshot) {}

    func clear() {}
}
