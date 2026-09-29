import SwiftUI

/// Multi-stage loading overlay rendered as a `.fullScreenCover` while a
/// discovered course is being imported. Mirrors the pipeline stages in
/// `CourseImportStage`: each row is either pending (greyed, awaiting),
/// active (spinner, current step), or completed (check, finished).
///
/// Three terminal renders:
/// - Approved → the host dismisses immediately and selects the course.
/// - Provisional → "Use anyway" / "Pick another course" actions surface
///   alongside the AI's concerns.
/// - Failed → red banner + "Try another course" / "Retry" actions.
struct CourseImportLoadingOverlay: View {
    let courseName: String
    let stage: CourseImportStage?
    let validation: CourseValidationResult?
    let onUseProvisional: () -> Void
    let onRetry: () -> Void
    let onDismiss: () -> Void

    private var pipelineStages: [CourseImportStage] {
        [
            .fetchingGeometry,
            .converting,
            .runningDeterministicGates,
            .runningAIReview,
            .persisting
        ]
    }

    var body: some View {
        ZStack {
            Book.paper
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(spacing: 0) {
                    ForEach(Array(pipelineStages.enumerated()), id: \.element.id) { index, pipelineStage in
                        if index > 0 { BookHairline().padding(.leading, 36) }
                        stageRow(pipelineStage)
                    }
                }

                Spacer()

                terminalSection
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .foregroundStyle(Book.ink)
        .tint(Book.stamp)
        .animation(.easeInOut(duration: 0.2), value: stage?.id)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            BookNote("Importing course")

            Text(courseName)
                .font(Book.Typeface.display)
                .fixedSize(horizontal: false, vertical: true)

            Text(stage?.headline ?? "Preparing…")
                .font(.subheadline)
                .foregroundStyle(Book.pencil)
                .lineLimit(2)
                .contentTransition(.opacity)
        }
        .padding(.bottom, 8)
    }

    @ViewBuilder
    private func stageRow(_ pipelineStage: CourseImportStage) -> some View {
        let status = stageStatus(for: pipelineStage)
        HStack(alignment: .center, spacing: 14) {
            stageIndicator(for: status)
                .frame(width: 22)
            Text(pipelineStage.headline)
                .font(.subheadline.weight(status == .active ? .semibold : .regular))
                .foregroundStyle(status == .pending ? Book.pencil : Book.ink)
            Spacer()
        }
        .frame(minHeight: 44)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func stageIndicator(for status: StageStatus) -> some View {
        switch status {
        case .pending:
            Circle().strokeBorder(Book.rule, lineWidth: 1.5).frame(width: 16, height: 16)
                .accessibilityLabel("Waiting")
        case .active:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Book.stamp)
                .accessibilityLabel("Done")
        case .skipped:
            Image(systemName: "minus")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Book.pencil)
                .accessibilityLabel("Skipped")
        }
    }

    private enum StageStatus { case pending, active, completed, skipped }

    private func stageStatus(for pipelineStage: CourseImportStage) -> StageStatus {
        guard let stage else { return .pending }
        switch stage {
        case .failed:
            return pipelineRank(of: pipelineStage) <= currentRank(stage) ? .completed : .pending
        case .completed:
            return .completed
        default:
            let pipelineIdx = pipelineRank(of: pipelineStage)
            let currentIdx = currentRank(stage)
            if pipelineIdx < currentIdx { return .completed }
            if pipelineIdx == currentIdx { return .active }
            return .pending
        }
    }

    private func pipelineRank(of pipelineStage: CourseImportStage) -> Int {
        switch pipelineStage {
        case .fetchingGeometry: return 0
        case .converting: return 1
        case .runningDeterministicGates: return 2
        case .runningAIReview: return 3
        case .persisting: return 4
        case .completed: return 5
        case .failed: return 6
        }
    }

    private func currentRank(_ stage: CourseImportStage) -> Int {
        pipelineRank(of: stage)
    }

    @ViewBuilder
    private var terminalSection: some View {
        if let stage {
            switch stage {
            case .failed(let reason):
                failureCard(reason: reason)
            case .completed(_, let validation):
                if validation.outcome == .provisional {
                    provisionalCard(validation: validation)
                } else {
                    EmptyView()
                }
            default:
                EmptyView()
            }
        }
    }

    private func failureCard(reason: String) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("We couldn't import this course", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Book.warning)

            Text(reason)
                .font(.callout)
                .fixedSize(horizontal: false, vertical: true)

            actions(primaryTitle: "Try again", primarySymbol: "arrow.clockwise", primary: onRetry)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bookLeaf(cornerRadius: 14)
    }

    private func provisionalCard(validation: CourseValidationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            BookNote(validation.aiAvailable ? "Imported with concerns" : "Imported, needs a check")

            if let summary = validation.aiSummary {
                Text(summary)
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !validation.aiAvailable {
                Text("We couldn’t run the extra quality check on this device, so this course is marked as needing review. Distances may need a quick sanity check.")
                    .font(.callout)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !validation.importNotes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(validation.importNotes.enumerated()), id: \.offset) { _, note in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "pencil")
                                .font(.footnote)
                                .foregroundStyle(Book.pencil)
                            Text(note)
                                .font(.footnote)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            if !validation.aiConcerns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(validation.aiConcerns.enumerated()), id: \.offset) { _, concern in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(Book.pencil)
                            Text(concern)
                                .font(.footnote)
                                .foregroundStyle(Book.pencil)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }

            actions(primaryTitle: "Use this course", primarySymbol: "arrow.right", primary: onUseProvisional)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .bookLeaf(cornerRadius: 14)
    }

    private func actions(primaryTitle: String, primarySymbol: String, primary: @escaping () -> Void) -> some View {
        VStack(spacing: 8) {
            Button(action: primary) {
                HStack {
                    Text(primaryTitle)
                    Spacer(minLength: 12)
                    Image(systemName: primarySymbol)
                }
            }
            .buttonStyle(BookStampButtonStyle())

            Button("Pick another course", action: onDismiss)
                .buttonStyle(BookStampButtonStyle(prominent: false))
        }
        .padding(.top, 4)
    }
}
