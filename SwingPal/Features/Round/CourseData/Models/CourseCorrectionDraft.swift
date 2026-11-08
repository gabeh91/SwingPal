import Foundation

struct CourseCorrectionDraft: Identifiable, Equatable, Codable {
    enum Kind: String, Equatable, Codable {
        case teeLocation
        case bunkerShape
        case fairwayShape
        case greenShape
        case hazardPlacement
        case teeMetadata
        case routing
        case generalNote

        var summaryLabel: String {
            switch self {
            case .teeLocation:
                return "tee update"
            case .bunkerShape:
                return "bunker update"
            case .fairwayShape:
                return "fairway update"
            case .greenShape:
                return "green update"
            case .hazardPlacement:
                return "hazard update"
            case .teeMetadata:
                return "tee info update"
            case .routing:
                return "routing update"
            case .generalNote:
                return "course note"
            }
        }
    }

    enum Status: String, Equatable, Codable {
        case draft
        case submitted
        case underReview
        case applied
        case rejected
    }

    struct Evidence: Identifiable, Equatable, Codable {
        enum Kind: String, Equatable, Codable {
            case note
            case screenshot
            case gpsMarker
        }

        let id: UUID
        let kind: Kind
        let value: String

        init(id: UUID = UUID(), kind: Kind, value: String) {
            self.id = id
            self.kind = kind
            self.value = value
        }
    }

    let id: UUID
    let courseID: UUID
    let courseName: String
    let kind: Kind
    let holeNumber: Int?
    let detail: String
    let proposedCoordinate: SwingPalCourse.Coordinate?
    let evidences: [Evidence]
    let status: Status

    init(
        id: UUID = UUID(),
        courseID: UUID,
        courseName: String,
        kind: Kind,
        holeNumber: Int? = nil,
        detail: String,
        proposedCoordinate: SwingPalCourse.Coordinate? = nil,
        evidences: [Evidence],
        status: Status = .draft
    ) {
        self.id = id
        self.courseID = courseID
        self.courseName = courseName
        self.kind = kind
        self.holeNumber = holeNumber
        self.detail = detail
        self.proposedCoordinate = proposedCoordinate
        self.evidences = evidences
        self.status = status
    }

    var summaryTitle: String {
        if let holeNumber {
            return "Hole \(holeNumber) \(kind.summaryLabel)"
        }
        return "\(courseName) \(kind.summaryLabel)"
    }

    var summaryCaption: String {
        switch evidences.count {
        case 0:
            return "Add evidence before submitting"
        case 1:
            return "1 piece of evidence attached"
        default:
            return "\(evidences.count) pieces of evidence attached"
        }
    }

    var canSubmit: Bool {
        !detail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !evidences.isEmpty
    }
}
