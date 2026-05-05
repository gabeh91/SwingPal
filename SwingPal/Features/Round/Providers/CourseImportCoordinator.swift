import Foundation
import OSLog

/// Identifiable progress states surfaced to the loading overlay. Phase 3
/// adds `runningAIReview`; Phase 4 adds `persisting`.
enum CourseImportStage: Equatable, Identifiable {
    case fetchingGeometry
    case converting
    case runningDeterministicGates
    case runningAIReview
    case persisting
    case completed(SwingPalCourse, CourseValidationResult)
    case failed(reason: String)

    var id: String {
        switch self {
        case .fetchingGeometry: return "fetchingGeometry"
        case .converting: return "converting"
        case .runningDeterministicGates: return "runningDeterministicGates"
        case .runningAIReview: return "runningAIReview"
        case .persisting: return "persisting"
        case .completed: return "completed"
        case .failed: return "failed"
        }
    }

    var isTerminal: Bool {
        switch self {
        case .completed, .failed: return true
        default: return false
        }
    }

    /// Display copy for the loading overlay. The associated values stay out
    /// of the headline because the overlay renders a richer body for them.
    var headline: String {
        switch self {
        case .fetchingGeometry: return "Downloading course layout…"
        case .converting: return "Building the hole-by-hole layout…"
        case .runningDeterministicGates: return "Checking the data is sound…"
        case .runningAIReview: return "Double-checking the course quality…"
        case .persisting: return "Saving this course for next time…"
        case .completed: return "Ready to play."
        case .failed(let reason): return reason
        }
    }
}

/// Hook the AI advisory step plugs into in Phase 3. Phase 2 ships
/// `NoAICourseValidator` which always reports unavailable so the
/// coordinator marks the import provisional without contacting any model.
protocol AICourseValidating {
    func review(_ course: SwingPalCourse) async -> AICourseReview
}

struct AICourseReview: Equatable {
    enum Verdict: String, Equatable {
        case ok
        case concerns
        case broken
    }
    let verdict: Verdict
    let concerns: [String]
    let oneLineSummary: String?
    let aiAvailable: Bool

    static let unavailable = AICourseReview(
        verdict: .ok,
        concerns: [],
        oneLineSummary: nil,
        aiAvailable: false
    )
}

/// Phase 2 stand-in for the AI step. Always reports the model unavailable
/// so the coordinator emits a `provisional` import without any network /
/// model calls. Phase 3 swaps in `FoundationModelsCourseValidator`.
struct NoAICourseValidator: AICourseValidating {
    func review(_ course: SwingPalCourse) async -> AICourseReview { .unavailable }
}

/// Orchestrates the full import pipeline as an `AsyncStream<CourseImportStage>`.
/// Each stage runs sequentially; the stream emits a stage as it begins,
/// then terminates on `.completed` or `.failed`.
final class CourseImportCoordinator {
    private static let logger = Logger(subsystem: "com.swingpal.app", category: "CourseImport")

    private let fetcher: any OSMCourseGeometryFetching
    private let aiValidator: any AICourseValidating

    init(
        fetcher: any OSMCourseGeometryFetching = LiveOSMCourseGeometryFetcher(),
        aiValidator: any AICourseValidating = NoAICourseValidator()
    ) {
        self.fetcher = fetcher
        self.aiValidator = aiValidator
    }

    /// Drives the import for `discovered` and yields each pipeline stage.
    /// Cancellation propagates via the surrounding `Task` — cancelling the
    /// task that consumes the stream will abort the in-flight network /
    /// validator call at the next suspension point.
    func importCourse(_ discovered: DiscoveredCourse) -> AsyncStream<CourseImportStage> {
        AsyncStream { continuation in
            let task = Task { [fetcher, aiValidator] in
                do {
                    continuation.yield(.fetchingGeometry)
                    let raw = try await fetcher.fetchGeometry(for: discovered)
                    try Task.checkCancellation()

                    continuation.yield(.converting)
                    let converted = try RuntimeOSMCourseConverter.convert(
                        rawOSM: raw,
                        for: discovered
                    )
                    try Task.checkCancellation()

                    continuation.yield(.runningDeterministicGates)
                    let deterministicFailures = DeterministicCourseValidator.validate(converted)
                    if !deterministicFailures.isEmpty {
                        Self.logger.info(
                            "Deterministic validation rejected course: \(deterministicFailures.joined(separator: "; "), privacy: .public)"
                        )
                        let result = CourseValidationResult(
                            outcome: .rejected,
                            deterministicFailures: deterministicFailures
                        )
                        continuation.yield(
                            .failed(reason: deterministicFailures.first
                                ?? "We couldn't validate this course's data.")
                        )
                        continuation.finish()
                        _ = result
                        return
                    }

                    continuation.yield(.runningAIReview)
                    let aiReview = await aiValidator.review(converted)
                    try Task.checkCancellation()

                    let result = makeValidationResult(deterministicFailures: deterministicFailures, aiReview: aiReview)

                    if result.outcome == .rejected {
                        continuation.yield(
                            .failed(reason: aiReview.oneLineSummary
                                ?? "The on-device AI flagged this course as unusable.")
                        )
                        continuation.finish()
                        return
                    }

                    let finalCourse = applyValidationToCourse(converted, result: result)

                    continuation.yield(.completed(finalCourse, result))
                    continuation.finish()
                } catch is CancellationError {
                    continuation.yield(.failed(reason: "Import cancelled."))
                    continuation.finish()
                } catch let error as LocalizedError {
                    continuation.yield(
                        .failed(reason: error.errorDescription ?? "Couldn't import this course.")
                    )
                    continuation.finish()
                } catch {
                    Self.logger.error("Import error: \(String(describing: error), privacy: .public)")
                    continuation.yield(.failed(reason: "Couldn't import this course."))
                    continuation.finish()
                }
            }

            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }

    private func makeValidationResult(
        deterministicFailures: [String],
        aiReview: AICourseReview
    ) -> CourseValidationResult {
        let outcome: CourseValidationResult.Outcome
        if !deterministicFailures.isEmpty {
            outcome = .rejected
        } else {
            switch aiReview.verdict {
            case .broken:
                outcome = .rejected
            case .concerns:
                outcome = .provisional
            case .ok:
                outcome = aiReview.aiAvailable ? .approved : .provisional
            }
        }
        return CourseValidationResult(
            outcome: outcome,
            deterministicFailures: deterministicFailures,
            aiConcerns: aiReview.concerns,
            aiSummary: aiReview.oneLineSummary,
            aiAvailable: aiReview.aiAvailable
        )
    }

    /// Stamps the validation outcome onto the course's quality flags so
    /// downstream UI (course-card readiness pill, live-round banners) can
    /// indicate the course is provisional without re-running validation.
    private func applyValidationToCourse(
        _ course: SwingPalCourse,
        result: CourseValidationResult
    ) -> SwingPalCourse {
        let confidence: SwingPalCourse.ConfidenceLevel
        switch result.outcome {
        case .approved: confidence = .reviewed
        case .provisional: confidence = .provisional
        case .rejected: confidence = .provisional
        }

        return SwingPalCourse(
            id: course.id,
            name: course.name,
            distanceKilometers: course.distanceKilometers,
            coordinate: course.coordinate,
            holeCount: course.holeCount,
            par: course.par,
            sourceReferences: course.sourceReferences,
            quality: SwingPalCourse.QualitySnapshot(
                overallConfidence: confidence,
                geometryConfidence: confidence,
                metadataConfidence: confidence
            ),
            community: course.community,
            tees: course.tees,
            holes: course.holes
        )
    }
}
