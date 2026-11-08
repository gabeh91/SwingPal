import SwiftUI

/// Purchases remain unavailable until a real StoreKit offer and verified
/// entitlement flow are configured. Dismissing this sheet never grants access.
struct PremiumGateView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Image(systemName: "seal")
                        .font(.system(size: 40, weight: .light))
                        .accessibilityHidden(true)
                    Text("Premium isn’t available yet")
                        .font(Book.Typeface.display)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Purchases and restores aren’t offered in this version of SwingPal. Nothing about your access has changed.")
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                    BookHairline()
                    Text("Rounds, courses, the yardage book and scoring are all available now.")
                        .foregroundStyle(Book.pencil)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(22)
            }
            .background(Book.paper.ignoresSafeArea())
            .foregroundStyle(Book.ink)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: onDismiss)
                        .frame(minHeight: 44)
                }
            }
        }
        .tint(Book.stamp)
        .presentationDetents(dynamicTypeSize.isAccessibilitySize ? [.large] : [.medium, .large])
        .presentationBackground(Book.paper)
    }
}
