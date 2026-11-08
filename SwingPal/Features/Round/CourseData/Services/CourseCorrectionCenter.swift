import Foundation
import Combine

protocol CourseCorrectionStoring {
    func loadCorrections() -> [CourseCorrectionDraft]
    func saveCorrections(_ corrections: [CourseCorrectionDraft])
}

struct UserDefaultsCourseCorrectionStore: CourseCorrectionStoring {
    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "com.ghtech.swingpal.course-corrections"
    ) {
        self.defaults = defaults
        self.key = key
    }

    func loadCorrections() -> [CourseCorrectionDraft] {
        guard let data = defaults.data(forKey: key) else {
            return []
        }
        return (try? JSONDecoder().decode([CourseCorrectionDraft].self, from: data)) ?? []
    }

    func saveCorrections(_ corrections: [CourseCorrectionDraft]) {
        guard let data = try? JSONEncoder().encode(corrections) else {
            return
        }
        defaults.set(data, forKey: key)
    }
}

struct CourseCorrectionModerationSummary: Equatable {
    let totalCount: Int
    let headline: String
    let detail: String
}

struct CourseCorrectionActivityItem: Identifiable, Equatable {
    let id: UUID
    let title: String
    let detail: String
    let statusLabel: String
}

final class CourseCorrectionCenter: ObservableObject {
    @Published private(set) var corrections: [CourseCorrectionDraft] = []
    private let store: CourseCorrectionStoring

    init(store: CourseCorrectionStoring = UserDefaultsCourseCorrectionStore()) {
        self.store = store
        self.corrections = store.loadCorrections()
    }

    func submit(_ draft: CourseCorrectionDraft) {
        corrections.insert(draft.withStatus(.submitted), at: 0)
        persist()
    }

    func corrections(for courseID: UUID) -> [CourseCorrectionDraft] {
        corrections.filter { $0.courseID == courseID }
    }

    func moderationSummary(for courseID: UUID) -> CourseCorrectionModerationSummary {
        let courseCorrections = corrections(for: courseID)
        guard !courseCorrections.isEmpty else {
            return .init(
                totalCount: 0,
                headline: "No reports yet",
                detail: "Local reports will appear here before sync and moderation."
            )
        }

        let groupedStatuses = Dictionary(grouping: courseCorrections, by: \.status)
        let underReviewCount = groupedStatuses[.underReview]?.count ?? 0
        let submittedCount = groupedStatuses[.submitted]?.count ?? 0
        let appliedCount = groupedStatuses[.applied]?.count ?? 0

        let headline: String
        if underReviewCount > 0 {
            headline = "\(underReviewCount) under review"
        } else if appliedCount > 0 {
            headline = "\(appliedCount) applied"
        } else {
            headline = "\(submittedCount) pending sync"
        }

        let detailParts = [
            submittedCount > 0 ? "\(submittedCount) newly submitted" : nil,
            underReviewCount > 0 ? "\(underReviewCount) in moderation" : nil,
            appliedCount > 0 ? "\(appliedCount) applied locally" : nil
        ].compactMap { $0 }

        return .init(
            totalCount: courseCorrections.count,
            headline: headline,
            detail: detailParts.isEmpty ? "Awaiting the first local report." : detailParts.joined(separator: " • ")
        )
    }

    func recentActivity(for courseID: UUID, limit: Int = 3) -> [CourseCorrectionActivityItem] {
        corrections(for: courseID)
            .prefix(limit)
            .map {
                CourseCorrectionActivityItem(
                    id: $0.id,
                    title: $0.summaryTitle,
                    detail: $0.detail,
                    statusLabel: $0.status.activityLabel
                )
            }
    }

    private func persist() {
        store.saveCorrections(corrections)
    }
}

private extension CourseCorrectionDraft {
    func withStatus(_ status: Status) -> CourseCorrectionDraft {
        CourseCorrectionDraft(
            id: id,
            courseID: courseID,
            courseName: courseName,
            kind: kind,
            holeNumber: holeNumber,
            detail: detail,
            proposedCoordinate: proposedCoordinate,
            evidences: evidences,
            status: status
        )
    }
}

private extension CourseCorrectionDraft.Status {
    var activityLabel: String {
        switch self {
        case .draft:
            return "Draft"
        case .submitted:
            return "Pending sync"
        case .underReview:
            return "In moderation"
        case .applied:
            return "Applied locally"
        case .rejected:
            return "Needs revision"
        }
    }
}
