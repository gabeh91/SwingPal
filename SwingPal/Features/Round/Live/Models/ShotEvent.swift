import Foundation

struct ShotEvent: Identifiable, Equatable, Codable {
    enum Surface: String, Equatable, Codable {
        case tee
        case fairway
        case rough
        case bunker
        case green
    }

    enum DirectionResult: String, Codable, Equatable, CaseIterable {
        case hit
        case left
        case farLeft
        case right
        case farRight
    }

    enum DistanceResult: String, Codable, Equatable, CaseIterable {
        case onNumber
        case long
        case short
    }

    enum StrikeResult: String, Codable, Equatable, CaseIterable {
        case pure
        case thin
        case chunk
        case top
        case slice
        case hook
    }

    enum ShotType: String, Codable, Equatable, CaseIterable {
        case teeShot
        case provisionalBall
        case approach
        case layup
        case recovery
        case chip
        case pitch
        case bunkerShot
        case putt
        /// The putter used from off the green. It's a shot around the green,
        /// not a putt: putts are only counted on the putting surface.
        case fringePutt
    }

    /// Where a chip, pitch or bunker shot finished: the result that matters
    /// around the green, in place of left/right and long/short.
    enum ShortGameResult: String, Codable, Equatable, CaseIterable {
        case holed
        /// Inside about a metre.
        case tapIn
        /// One to three metres.
        case makeable
        /// On the green with three metres or more left.
        case longPutt
        /// Still off the green.
        case missedGreen
    }

    struct PuttDetail: Equatable, Codable {
        let puttCount: Int
        let firstPuttDistanceMeters: Int?
        /// Whether this putt actually went in. `false` for misses; `true` for
        /// hole-outs. Older logs that pre-date the on-green redesign won't
        /// have this set, so we decode it with a `false` default.
        let holed: Bool
        /// How far the ball came to rest from the cup when the putt missed
        /// (in metres). `nil` when the putt was holed or the player chose
        /// not to record a quantitative miss distance.
        let missDistanceMeters: Int?
        /// How many putts this one entry stands for, when the green was
        /// logged in one go after holing out ("a two-putt"). `nil` for a
        /// putt logged on its own.
        let puttsTogether: Int?

        init(
            puttCount: Int,
            firstPuttDistanceMeters: Int? = nil,
            holed: Bool = false,
            missDistanceMeters: Int? = nil,
            puttsTogether: Int? = nil
        ) {
            self.puttCount = max(1, puttCount)
            self.firstPuttDistanceMeters = firstPuttDistanceMeters
            self.holed = holed
            self.missDistanceMeters = missDistanceMeters.map { max(0, $0) }
            self.puttsTogether = puttsTogether.map { max(1, $0) }
        }

        private enum CodingKeys: String, CodingKey {
            case puttCount
            case firstPuttDistanceMeters
            case holed
            case missDistanceMeters
            case puttsTogether
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.puttCount = max(1, try container.decode(Int.self, forKey: .puttCount))
            self.firstPuttDistanceMeters = try container.decodeIfPresent(Int.self, forKey: .firstPuttDistanceMeters)
            self.holed = try container.decodeIfPresent(Bool.self, forKey: .holed) ?? false
            self.missDistanceMeters = try container.decodeIfPresent(Int.self, forKey: .missDistanceMeters)
            self.puttsTogether = try container.decodeIfPresent(Int.self, forKey: .puttsTogether)
        }
    }

    let id: UUID
    let clubName: String
    let distanceToTargetMeters: Int
    let strokeNumber: Int
    let penaltyCount: Int
    let dropCount: Int
    let surface: Surface
    let direction: DirectionResult
    let distanceResult: DistanceResult
    let shotType: ShotType?
    let strikeResult: StrikeResult?
    let puttDetail: PuttDetail?
    /// A full shot that went in: a hole in one, a chip-in, a holed approach.
    /// Putts record this in `puttDetail`. Absent in older logs.
    let holedOut: Bool?
    /// Set on shots logged with the short-game screen. Absent in older logs.
    let shortGameResult: ShortGameResult?
    let note: String?
    let createdAt: Date

    /// A chip, pitch or bunker shot around the green.
    var isShortGameShot: Bool {
        shortGameResult != nil || shotType == .chip || shotType == .pitch || shotType == .bunkerShot || shotType == .fringePutt
    }

    init(
        id: UUID = UUID(),
        clubName: String,
        distanceToTargetMeters: Int,
        strokeNumber: Int = 1,
        penaltyCount: Int = 0,
        dropCount: Int = 0,
        surface: Surface = .fairway,
        direction: DirectionResult = .hit,
        distanceResult: DistanceResult = .onNumber,
        shotType: ShotType? = nil,
        strikeResult: StrikeResult? = nil,
        puttDetail: PuttDetail? = nil,
        holedOut: Bool? = nil,
        shortGameResult: ShortGameResult? = nil,
        note: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.clubName = clubName
        self.distanceToTargetMeters = distanceToTargetMeters
        self.strokeNumber = max(1, strokeNumber)
        self.penaltyCount = max(0, penaltyCount)
        self.dropCount = max(0, dropCount)
        self.surface = surface
        self.direction = direction
        self.distanceResult = distanceResult
        self.strikeResult = strikeResult
        self.shotType = shotType
        self.puttDetail = puttDetail
        self.holedOut = holedOut == true ? true : nil
        self.shortGameResult = shortGameResult
        self.note = note?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        self.createdAt = createdAt
    }

    /// Club name on the events written by quick penalties and re-tee, which
    /// record a penalty stroke without a swing.
    static let syntheticPenaltyClubName = "Penalty"

    /// A penalty-only event. It occupies one stroke number and its single
    /// stroke is its penalty, so it must not also count as a swing or a putt.
    var isSyntheticPenalty: Bool {
        clubName == Self.syntheticPenaltyClubName && penaltyCount > 0
    }

    /// A stroke on the putting surface. Chips and the putter from off the
    /// green are shots around the green, not putts.
    var isPuttStroke: Bool {
        !isSyntheticPenalty && !isShortGameShot && (puttDetail != nil || shotType == .putt || surface == .green)
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
