import SwiftUI

struct CourseCorrectionSheet: View {
    let course: SwingPalCourse
    let existingSubmissionCount: Int
    let onSubmit: (CourseCorrectionDraft) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedKind: CourseCorrectionDraft.Kind = .bunkerShape
    @State private var holeMode = true
    @State private var selectedHole = 1
    @State private var detail = ""
    @State private var evidenceNote = ""

    private var draft: CourseCorrectionDraft {
        CourseCorrectionDraft(
            courseID: course.id,
            courseName: course.name,
            kind: selectedKind,
            holeNumber: holeMode ? selectedHole : nil,
            detail: detail,
            evidences: evidenceNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? []
                : [.init(kind: .note, value: evidenceNote)]
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: ShellTokens.Spacing.x20) {
                    hero
                    kindSection
                    scopeSection
                    detailSection
                    evidenceSection

                    Button {
                        onSubmit(draft)
                        dismiss()
                    } label: {
                        HStack {
                            Text("Submit Local Report")
                                .font(.headline)
                            Spacer()
                            Text(draft.summaryTitle)
                                .font(.subheadline.weight(.medium))
                                .lineLimit(1)
                                .foregroundStyle(ShellTokens.ColorRole.textInverse.opacity(0.82))
                        }
                        .padding(.horizontal, ShellTokens.Spacing.x16)
                        .padding(.vertical, ShellTokens.Spacing.x16)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(ShellTokens.ColorRole.textInverse)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        LinearGradient(
                            colors: [
                                ShellTokens.ColorRole.pine700,
                                ShellTokens.ColorRole.pine500
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                    )
                    .shadow(color: ShellTokens.Shadow.floating, radius: 12, y: 6)
                    .disabled(!draft.canSubmit)
                    .opacity(draft.canSubmit ? 1 : 0.45)
                }
                .padding(ShellTokens.Spacing.x20)
                .padding(.bottom, ShellTokens.Spacing.x24)
            }
            .background(ShellTokens.ColorRole.bgApp)
            .navigationTitle("Report Course Data")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.fraction(0.72), .large])
        .presentationDragIndicator(.visible)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            HStack {
                Text("Community Refinement")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(ShellTokens.ColorRole.pine700)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(ShellTokens.ColorRole.pine700.opacity(0.10), in: Capsule())
                Spacer()
                Text(existingSubmissionCount == 0 ? "First report" : "\(existingSubmissionCount) local reports")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(ShellTokens.ColorRole.textSecondary)
            }

            Text(course.name)
                .font(.system(size: 30, weight: .semibold, design: .serif))
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)

            Text("If something is off, submit a correction and we’ll use it to improve this course.")
                .font(.subheadline)
                .foregroundStyle(ShellTokens.ColorRole.textSecondary)
        }
        .padding(ShellTokens.Spacing.x20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [
                    ShellTokens.ColorRole.surfacePrimary,
                    ShellTokens.ColorRole.surfaceSecondary
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
        )
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.lg)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
    }

    private var kindSection: some View {
        sectionCard(title: "Correction Type") {
            Menu {
                ForEach([
                    CourseCorrectionDraft.Kind.teeLocation,
                    .bunkerShape,
                    .fairwayShape,
                    .greenShape,
                    .hazardPlacement,
                    .teeMetadata,
                    .routing,
                    .generalNote
                ], id: \.self) { kind in
                    Button(kind.summaryLabel.capitalized) {
                        selectedKind = kind
                    }
                }
            } label: {
                HStack {
                    Text(selectedKind.summaryLabel.capitalized)
                        .font(.headline)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                .padding(.horizontal, ShellTokens.Spacing.x16)
                .padding(.vertical, ShellTokens.Spacing.x12)
                .background(ShellTokens.ColorRole.surfaceSecondary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
            }
            .buttonStyle(.plain)
        }
    }

    private var scopeSection: some View {
        sectionCard(title: "Scope") {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
                Picker("Scope", selection: $holeMode) {
                    Text("Hole-specific").tag(true)
                    Text("Whole course").tag(false)
                }
                .pickerStyle(.segmented)

                if holeMode {
                    Stepper(value: $selectedHole, in: 1...max(course.holeCount, 1)) {
                        Text("Hole \(selectedHole)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(ShellTokens.ColorRole.textPrimary)
                    }
                    .padding(.horizontal, ShellTokens.Spacing.x16)
                    .padding(.vertical, ShellTokens.Spacing.x12)
                    .background(ShellTokens.ColorRole.surfaceSecondary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
                }
            }
        }
    }

    private var detailSection: some View {
        sectionCard(title: "What needs changing?") {
            TextEditor(text: $detail)
                .frame(minHeight: 120)
                .padding(10)
                .scrollContentBackground(.hidden)
                .background(ShellTokens.ColorRole.surfaceSecondary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
                .overlay(alignment: .topLeading) {
                    if detail.isEmpty {
                        Text("Describe what is wrong and what should change.")
                            .foregroundStyle(ShellTokens.ColorRole.textTertiary)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 22)
                            .allowsHitTesting(false)
                    }
                }
        }
    }

    private var evidenceSection: some View {
        sectionCard(title: "Evidence") {
            VStack(alignment: .leading, spacing: ShellTokens.Spacing.x8) {
                TextField("Add a note from your round, scorecard, or visual check", text: $evidenceNote)
                    .textInputAutocapitalization(.sentences)
                    .padding(.horizontal, ShellTokens.Spacing.x16)
                    .padding(.vertical, ShellTokens.Spacing.x12)
                    .background(ShellTokens.ColorRole.surfaceSecondary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))

                Text(draft.summaryCaption)
                    .font(.caption)
                    .foregroundStyle(draft.canSubmit ? ShellTokens.ColorRole.pine700 : ShellTokens.ColorRole.textTertiary)
            }
        }
    }

    private func sectionCard<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: ShellTokens.Spacing.x12) {
            Text(title)
                .font(.headline)
                .foregroundStyle(ShellTokens.ColorRole.textPrimary)
            content()
        }
        .padding(ShellTokens.Spacing.x16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(ShellTokens.ColorRole.surfacePrimary, in: RoundedRectangle(cornerRadius: ShellTokens.Radius.md))
        .overlay(
            RoundedRectangle(cornerRadius: ShellTokens.Radius.md)
                .stroke(ShellTokens.ColorRole.strokeDefault, lineWidth: 1)
        )
    }
}
