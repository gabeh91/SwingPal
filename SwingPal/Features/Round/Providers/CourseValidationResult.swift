import Foundation

/// Outcome of running a downloaded course through the validation pipeline.
/// Phase 2 only populates `deterministicFailures`; Phase 3 layers in the
/// AI advisory output.
struct CourseValidationResult: Equatable {
    enum Outcome: String, Equatable, Codable {
        /// Deterministic gates passed and AI (if available) raised no
        /// concerns. The course is round-ready as `quality.reviewed`.
        case approved
        /// Deterministic gates passed but the AI flagged concerns OR the AI
        /// review was unavailable. Course is usable but flagged
        /// `quality.provisional` so the UI sets expectations.
        case provisional
        /// Hard-block. Either deterministic gates failed or the AI verdict
        /// was `broken`. The course should not be used; the UI asks the
        /// user to pick a different one.
        case rejected
    }

    let outcome: Outcome
    let deterministicFailures: [String]
    let aiConcerns: [String]
    let aiSummary: String?
    let aiAvailable: Bool
    /// What the import had to fill in itself (e.g. an estimated green), in
    /// plain language, so the player knows where distances are approximate.
    let importNotes: [String]

    var isUsable: Bool { outcome != .rejected }
    var requiresUserAcknowledgement: Bool { outcome == .provisional }

    init(
        outcome: Outcome,
        deterministicFailures: [String] = [],
        aiConcerns: [String] = [],
        aiSummary: String? = nil,
        aiAvailable: Bool = false,
        importNotes: [String] = []
    ) {
        self.outcome = outcome
        self.deterministicFailures = deterministicFailures
        self.aiConcerns = aiConcerns
        self.aiSummary = aiSummary
        self.aiAvailable = aiAvailable
        self.importNotes = importNotes
    }
}
