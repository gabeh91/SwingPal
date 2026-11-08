import SwiftUI

struct AuthFlowModalView: View {
    let onDismiss: () -> Void

    @StateObject private var viewModel: AuthViewModel

    init(authService: AuthService, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        _viewModel = StateObject(
            wrappedValue: AuthViewModel(
                authService: authService,
                appleCoordinatorFactory: { AppleSignInCoordinator() }
            )
        )
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            AuthFlowView(viewModel: viewModel)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Book.ink)
                    .frame(width: 44, height: 44)
                    .background(Book.leaf, in: Circle())
                    .overlay {
                        Circle()
                            .stroke(Book.rule, lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)
            .padding(.top, 20)
            .padding(.leading, 20)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
