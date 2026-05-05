import Foundation

struct SwingPalCourse: Identifiable, Equatable, Codable {
    struct Coordinate: Equatable, Codable {
        let latitude: Double
        let longitude: Double
    }

    enum SourceKind: String, Equatable, Codable {
        case openGolfAPI
        case openStreetMap
        case swingPalCurated
        case community

        var label: String {
            switch self {
            case .openGolfAPI:
                return "OpenGolfAPI"
            case .openStreetMap:
                return "OSM"
            case .swingPalCurated:
                return "Curated"
            case .community:
                return "Community"
            }
        }
    }

    struct SourceReference: Identifiable, Equatable, Codable {
        let id: UUID
        let kind: SourceKind
        let externalID: String?
        let note: String?

        init(id: UUID = UUID(), kind: SourceKind, externalID: String? = nil, note: String? = nil) {
            self.id = id
            self.kind = kind
            self.externalID = externalID
            self.note = note
        }
    }

    enum ConfidenceLevel: String, Equatable, Codable {
        case provisional
        case reviewed
        case verified
    }

    struct QualitySnapshot: Equatable, Codable {
        let overallConfidence: ConfidenceLevel
        let geometryConfidence: ConfidenceLevel
        let metadataConfidence: ConfidenceLevel

        var readinessLabel: String {
            switch overallConfidence {
            case .provisional:
                return "Needs a check"
            case .reviewed:
                return "Round-ready"
            case .verified:
                return "Verified"
            }
        }
    }

    enum CommunityAccess: String, Equatable, Codable {
        case closed
        case reviewOnly
        case open

        var label: String {
            switch self {
            case .closed:
                return "Closed"
            case .reviewOnly:
                return "Review only"
            case .open:
                return "Open"
            }
        }
    }

    struct CommunityState: Equatable, Codable {
        let access: CommunityAccess
        let correctionCount: Int

        var summaryLabel: String {
            switch access {
            case .closed:
                return "Corrections paused"
            case .reviewOnly:
                return "Corrections under review"
            case .open:
                return correctionCount == 0 ? "Community corrections open" : "\(correctionCount) community refinements"
            }
        }
    }

    struct Tee: Identifiable, Equatable, Codable {
        let id: UUID
        let name: String
        let yards: Int

        init(id: UUID = UUID(), name: String, yards: Int) {
            self.id = id
            self.name = name
            self.yards = yards
        }
    }

    struct Hole: Identifiable, Equatable, Codable {
        struct Bounds: Equatable, Codable {
            let minLatitude: Double
            let maxLatitude: Double
            let minLongitude: Double
            let maxLongitude: Double

            var center: Coordinate {
                .init(
                    latitude: (minLatitude + maxLatitude) / 2,
                    longitude: (minLongitude + maxLongitude) / 2
                )
            }

            var latitudeDelta: Double {
                maxLatitude - minLatitude
            }

            var longitudeDelta: Double {
                maxLongitude - minLongitude
            }

            func contains(_ coordinate: Coordinate) -> Bool {
                coordinate.latitude >= minLatitude &&
                coordinate.latitude <= maxLatitude &&
                coordinate.longitude >= minLongitude &&
                coordinate.longitude <= maxLongitude
            }

            func clamped(_ coordinate: Coordinate) -> Coordinate {
                .init(
                    latitude: min(max(coordinate.latitude, minLatitude), maxLatitude),
                    longitude: min(max(coordinate.longitude, minLongitude), maxLongitude)
                )
            }
        }

        struct HoleViewportBounds: Equatable, Codable {
            let minX: Double
            let maxX: Double
            let minY: Double
            let maxY: Double

            init(bounds: Bounds) {
                minX = bounds.minLongitude
                maxX = bounds.maxLongitude
                minY = bounds.minLatitude
                maxY = bounds.maxLatitude
            }
        }

        struct TargetZone: Equatable, Codable {
            let bounds: Bounds

            var center: Coordinate {
                bounds.center
            }

            func contains(_ coordinate: Coordinate) -> Bool {
                bounds.contains(coordinate)
            }

            func clamped(_ coordinate: Coordinate) -> Coordinate {
                bounds.clamped(coordinate)
            }
        }

        enum FeatureKind: String, Equatable, Codable {
            case tee
            case fairway
            case green
            case bunker
            case water
            case layup
        }

        struct Feature: Identifiable, Equatable, Codable {
            let id: UUID
            let kind: FeatureKind
            let label: String
            let coordinates: [Coordinate]

            init(
                id: UUID = UUID(),
                kind: FeatureKind,
                label: String,
                coordinates: [Coordinate]
            ) {
                self.id = id
                self.kind = kind
                self.label = label
                self.coordinates = coordinates
            }
        }

        let id: UUID
        let number: Int
        let par: Int
        let features: [Feature]

        init(
            id: UUID = UUID(),
            number: Int,
            par: Int,
            features: [Feature]
        ) {
            self.id = id
            self.number = number
            self.par = par
            self.features = features
        }

        var bounds: Bounds? {
            Self.bounds(containing: features.flatMap(\.coordinates), bufferMeters: 20)
        }

        var viewportBounds: HoleViewportBounds? {
            bounds.map(HoleViewportBounds.init(bounds:))
        }

        static func bounds(
            containing coordinates: [Coordinate],
            bufferMeters: Double = 0
        ) -> Bounds? {
            guard !coordinates.isEmpty else {
                return nil
            }

            let latitudes = coordinates.map(\.latitude)
            let longitudes = coordinates.map(\.longitude)

            let minLatitude = latitudes.min() ?? 0
            let maxLatitude = latitudes.max() ?? 0
            let minLongitude = longitudes.min() ?? 0
            let maxLongitude = longitudes.max() ?? 0

            let centerLatitude = (minLatitude + maxLatitude) / 2
            let latitudeBuffer = bufferMeters / 111_111
            let longitudeScale = max(cos(centerLatitude * .pi / 180), 0.1)
            let longitudeBuffer = bufferMeters / (111_111 * longitudeScale)

            return Bounds(
                minLatitude: minLatitude - latitudeBuffer,
                maxLatitude: maxLatitude + latitudeBuffer,
                minLongitude: minLongitude - longitudeBuffer,
                maxLongitude: maxLongitude + longitudeBuffer
            )
        }

        static func targetZone(
            containing coordinates: [Coordinate],
            bufferMeters: Double = 0
        ) -> TargetZone? {
            bounds(containing: coordinates, bufferMeters: bufferMeters).map(TargetZone.init(bounds:))
        }

        func targetZone(
            combining kinds: [FeatureKind],
            bufferMeters: Double = 0
        ) -> TargetZone? {
            let coordinates = features
                .filter { kinds.contains($0.kind) }
                .flatMap(\.coordinates)
            return Self.targetZone(containing: coordinates, bufferMeters: bufferMeters)
        }
    }

    let id: UUID
    let name: String
    let distanceKilometers: Double
    let coordinate: Coordinate
    let holeCount: Int
    let par: Int
    let sourceReferences: [SourceReference]
    let quality: QualitySnapshot
    let community: CommunityState
    let tees: [Tee]
    let holes: [Hole]

    init(
        id: UUID = UUID(),
        name: String,
        distanceKilometers: Double,
        coordinate: Coordinate,
        holeCount: Int,
        par: Int,
        sourceReferences: [SourceReference],
        quality: QualitySnapshot,
        community: CommunityState,
        tees: [Tee],
        holes: [Hole]
    ) {
        self.id = id
        self.name = name
        self.distanceKilometers = distanceKilometers
        self.coordinate = coordinate
        self.holeCount = holeCount
        self.par = par
        self.sourceReferences = sourceReferences
        self.quality = quality
        self.community = community
        self.tees = tees
        self.holes = holes
    }
}

extension SwingPalCourse {
    private static func offsetCoordinate(
        from coordinate: Coordinate,
        northMeters: Double,
        eastMeters: Double
    ) -> Coordinate {
        let latitudeDelta = northMeters / 111_111
        let longitudeScale = max(cos(coordinate.latitude * .pi / 180), 0.1)
        let longitudeDelta = eastMeters / (111_111 * longitudeScale)
        return .init(
            latitude: coordinate.latitude + latitudeDelta,
            longitude: coordinate.longitude + longitudeDelta
        )
    }

    private static func ring(
        around coordinate: Coordinate,
        northMeters: Double,
        eastMeters: Double,
        widthMeters: Double,
        heightMeters: Double
    ) -> [Coordinate] {
        [
            offsetCoordinate(from: coordinate, northMeters: northMeters + heightMeters / 2, eastMeters: eastMeters - widthMeters / 2),
            offsetCoordinate(from: coordinate, northMeters: northMeters + heightMeters / 2, eastMeters: eastMeters + widthMeters / 2),
            offsetCoordinate(from: coordinate, northMeters: northMeters - heightMeters / 2, eastMeters: eastMeters + widthMeters / 2),
            offsetCoordinate(from: coordinate, northMeters: northMeters - heightMeters / 2, eastMeters: eastMeters - widthMeters / 2)
        ]
    }

    private static func defaultCoordinate(for courseName: String) -> Coordinate {
        switch courseName {
        case "Kingston Heath":
            return .init(latitude: -37.9588, longitude: 145.0328)
        case "Peninsula Kingswood":
            return .init(latitude: -38.2432, longitude: 145.1378)
        default:
            return .init(latitude: -37.9742, longitude: 145.0338)
        }
    }

    static func test(
        name: String,
        distanceKilometers: Double,
        holeCount: Int = 18,
        par: Int = 72,
        coordinate: Coordinate? = nil,
        sourceReferences: [SourceReference]? = nil,
        quality: QualitySnapshot = .init(
            overallConfidence: .reviewed,
            geometryConfidence: .reviewed,
            metadataConfidence: .verified
        ),
        community: CommunityState = .init(
            access: .open,
            correctionCount: 2
        )
    ) -> SwingPalCourse {
        let baseCoordinate = coordinate ?? defaultCoordinate(for: name)
        let tees: [Tee] = [
            .init(name: "Championship", yards: 6950),
            .init(name: "Member", yards: 6420),
            .init(name: "Forward", yards: 5790)
        ]

        let holes: [Hole] = (1...holeCount).map { holeNumber in
            let holePar = holeNumber == 1 ? 4 : 4
            let holeOrigin = offsetCoordinate(
                from: baseCoordinate,
                northMeters: Double(holeNumber - 1) * 24,
                eastMeters: Double((holeNumber - 1) % 3) * 10
            )
            return Hole(
                number: holeNumber,
                par: holePar,
                features: [
                    .init(
                        kind: .tee,
                        label: "Tee box",
                        coordinates: ring(
                            around: holeOrigin,
                            northMeters: -170,
                            eastMeters: -18,
                            widthMeters: 16,
                            heightMeters: 10
                        )
                    ),
                    .init(
                        kind: .fairway,
                        label: "Primary corridor",
                        coordinates: ring(
                            around: holeOrigin,
                            northMeters: -12,
                            eastMeters: 4,
                            widthMeters: 52,
                            heightMeters: 156
                        )
                    ),
                    .init(
                        kind: .green,
                        label: "Target green",
                        coordinates: ring(
                            around: holeOrigin,
                            northMeters: 56,
                            eastMeters: 6,
                            widthMeters: 28,
                            heightMeters: 20
                        )
                    ),
                    .init(
                        kind: .bunker,
                        label: "Front bunker",
                        coordinates: ring(
                            around: holeOrigin,
                            northMeters: 42,
                            eastMeters: 26,
                            widthMeters: 14,
                            heightMeters: 10
                        )
                    )
                ]
            )
        }

        return SwingPalCourse(
            name: name,
            distanceKilometers: distanceKilometers,
            coordinate: baseCoordinate,
            holeCount: holeCount,
            par: par,
            sourceReferences: sourceReferences ?? [
                .init(kind: .openGolfAPI, externalID: "og-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))"),
                .init(kind: .openStreetMap, externalID: "osm-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))")
            ],
            quality: quality,
            community: community,
            tees: tees,
            holes: holes
        )
    }
}
