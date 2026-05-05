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
            ShellTokens.ColorRole.bgApp
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                header

                ForEach(pipelineStages, id: \.id) { pipelineStage in
                    stageRow(pipelineStage)
                }

                Spacer()

                terminalSection
            }
            .padding(.horizontal, ShellTokens.Spacing.x24)
            .padding(.vertical, ShellTokens.Spacing.x32)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .animation(.easeInOut(duration: 0.2), value: stage?.id)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
            Text("Importing course")
                .font(ShellTokens.Typography.eyebrow)
                .tracking(1.2)
                .foregroundStyle(ShellTokens.ColorRole.pine700)

            Text(courseName)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)

            Text(stage?.headline ?? "Preparing…")
                .font(.subheadline)
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                .lineLimit(2)
                .contentTransition(.opacity)
        }
        .padding(.bottom, ShellTokens.Spacing.x12)
    }

    @ViewBuilder
    private func stageRow(_ pipelineStage: CourseImportStage) -> some View {
        let status = stageStatus(for: pipelineStage)
        HStack(alignment: .center, spacing: ShellTokens.Spacing.x14) {
            stageIndicator(for: status)
            Text(pipelineStage.headline)
                .font(.subheadline.weight(status == .active ? .semibold : .regular))
                .foregroundStyle(
                    status == .pending
                    ? ShellTokens.ColorRole.textTertiary
                    : ShellTokens.ColorRole.textPrimary
                )
            Spacer()
        }
    }

    @ViewBuilder
    private func stageIndicator(for status: StageStatus) -> some View {
        switch status {
        case .pending:
            Image(systemName: "circle")
                .foregroundStyle(ShellTokens.ColorRole.textTertiary)
        case .active:
            ProgressView()
                .controlSize(.small)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(ShellTokens.ColorRole.pine700)
        case .skipped:
            Image(systemName: "minus.circle.fill")
                .foregroundStyle(ShellTokens.ColorRole.textTertiary)
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
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Label("We couldn't import this course", systemImage: "exclamationmark.triangle.fill")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.red)

            Text(reason)
                .font(.callout)
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: ShellTokens.Spacing.x12) {
                Button("Pick another course", action: onDismiss)
                    .buttonStyle(.bordered)

                Button("Try again", action: onRetry)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ShellTokens.ColorRole.surfacePrimary,
            in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(.red.opacity(0.4), lineWidth: 1)
        )
    }

    private func provisionalCard(validation: CourseValidationResult) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Label(
                validation.aiAvailable ? "Course imported with concerns" : "Course imported provisionally",
                systemImage: "info.circle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(ShellTokens.ColorRole.pine700)

            if let summary = validation.aiSummary {
                Text(summary)
                    .font(.callout)
                    .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !validation.aiAvailable {
                Text("We couldn’t run the extra quality check on this device, so this course is marked as needing review. Distances may need a quick sanity check.")
                    .font(.callout)
                    .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !validation.aiConcerns.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(validation.aiConcerns.enumerated()), id: \.offset) { _, concern in
                        HStack(alignment: .top, spacing: 8) {
                            Text("•").foregroundStyle(ShellTokens.ColorRole.textSecondary)
                            Text(concern)
                                .font(.footnote)
                                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
                        }
                    }
                }
            }

            HStack(spacing: ShellTokens.Spacing.x12) {
                Button("Pick another course", action: onDismiss)
                    .buttonStyle(.bordered)

                Button("Use this course", action: onUseProvisional)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            ShellTokens.ColorRole.surfaceTinted,
            in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(ShellTokens.ColorRole.pine700.opacity(0.4), lineWidth: 1)
        )
    }
}
