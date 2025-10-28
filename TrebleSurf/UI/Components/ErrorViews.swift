//
//  ErrorViews.swift
//  TrebleSurf
//
//  SwiftUI components for error presentation
//

import SwiftUI

// MARK: - Error Alert Modifier

struct ErrorAlertModifier: ViewModifier {
    @Binding var errorPresentation: ErrorPresentation?
    let onRetry: (() -> Void)?
    let onDismiss: (() -> Void)?
    
    func body(content: Content) -> some View {
        content
            .alert(item: Binding(
                get: { errorPresentation.map { AlertWrapper(presentation: $0) } },
                set: { errorPresentation = $0?.presentation }
            )) { wrapper in
                makeAlert(from: wrapper.presentation)
            }
    }
    
    private func makeAlert(from presentation: ErrorPresentation) -> Alert {
        let primaryButton: Alert.Button
        let secondaryButton: Alert.Button?
        
        // Determine buttons based on actions
        if presentation.actions.contains(.retry) {
            primaryButton = .default(Text("Try Again")) {
                onRetry?()
            }
            secondaryButton = .cancel {
                onDismiss?()
            }
        } else if presentation.actions.contains(.signIn) {
            primaryButton = .default(Text("Sign In")) {
                // Handle sign in action
                onRetry?()
            }
            secondaryButton = .cancel {
                onDismiss?()
            }
        } else {
            primaryButton = .default(Text("OK")) {
                onDismiss?()
            }
            secondaryButton = nil
        }
        
        let message = [presentation.message, presentation.helpText]
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        
        if let secondaryButton = secondaryButton {
            return Alert(
                title: Text(presentation.title),
                message: Text(message),
                primaryButton: primaryButton,
                secondaryButton: secondaryButton
            )
        } else {
            return Alert(
                title: Text(presentation.title),
                message: Text(message),
                dismissButton: primaryButton
            )
        }
    }
    
    // Wrapper to make ErrorPresentation identifiable for alert
    private struct AlertWrapper: Identifiable {
        let id = UUID()
        let presentation: ErrorPresentation
    }
}

extension View {
    /// Present an error alert with automatic action handling
    func errorAlert(
        error: Binding<ErrorPresentation?>,
        onRetry: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> some View {
        modifier(ErrorAlertModifier(errorPresentation: error, onRetry: onRetry, onDismiss: onDismiss))
    }
}

// MARK: - Inline Error View

struct InlineErrorView: View {
    let message: String
    let isCompact: Bool
    
    init(_ message: String, compact: Bool = false) {
        self.message = message
        self.isCompact = compact
    }
    
    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(isCompact ? .caption : .subheadline)
            
            Text(message)
                .font(isCompact ? .caption : .subheadline)
                .foregroundColor(.red)
                .fixedSize(horizontal: false, vertical: true)
            
            Spacer(minLength: 0)
        }
        .padding(isCompact ? 8 : 12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Field Error View

struct FieldErrorView: View {
    let message: String
    
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.caption)
            Text(message)
                .font(.caption)
        }
        .foregroundColor(.red)
    }
}

// MARK: - Error Banner View

struct ErrorBannerView: View {
    let presentation: ErrorPresentation
    let onRetry: (() -> Void)?
    let onDismiss: () -> Void
    
    @State private var isVisible = true
    
    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: 12) {
                // Header
                HStack {
                    Image(systemName: iconName)
                        .font(.title2)
                        .foregroundColor(iconColor)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(presentation.title)
                            .font(.headline)
                        Text(presentation.message)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button(action: dismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Help text
                if !presentation.helpText.isEmpty {
                    Text(presentation.helpText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // Actions
                if !presentation.actions.isEmpty {
                    HStack(spacing: 12) {
                        ForEach(presentation.actions.indices, id: \.self) { index in
                            actionButton(for: presentation.actions[index])
                        }
                    }
                }
            }
            .padding()
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            .padding(.horizontal)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }
    
    private var iconName: String {
        switch presentation.errorCode.prefix(3) {
        case "NET": return "wifi.exclamationmark"
        case "AUT": return "person.crop.circle.badge.exclamationmark"
        case "VAL": return "exclamationmark.triangle"
        case "MED": return "photo.badge.exclamationmark"
        default: return "exclamationmark.circle"
        }
    }
    
    private var iconColor: Color {
        switch presentation.errorCode.prefix(3) {
        case "NET": return .orange
        case "AUT": return .blue
        case "VAL": return .yellow
        default: return .red
        }
    }
    
    private var backgroundColor: Color {
        Color(.systemBackground)
    }
    
    private func actionButton(for action: ErrorAction) -> some View {
        Button(action: {
            handleAction(action)
        }) {
            Text(action.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(action.isPrimary ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(action.isPrimary ? Color.blue : Color.secondary.opacity(0.2))
                .cornerRadius(8)
        }
    }
    
    private func handleAction(_ action: ErrorAction) {
        switch action {
        case .retry:
            onRetry?()
            dismiss()
        case .dismiss:
            dismiss()
        default:
            // Other actions handled by parent
            dismiss()
        }
    }
    
    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let presentation: ErrorPresentation
    let onRetry: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            VStack(spacing: 8) {
                Text(presentation.title)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(presentation.message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            if !presentation.helpText.isEmpty {
                Text(presentation.helpText)
                    .font(.callout)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            if let onRetry = onRetry, presentation.isRetryable {
                Button(action: onRetry) {
                    Text("Try Again")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 40)
            }
        }
        .padding()
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension ErrorPresentation {
    static let previewNetwork = ErrorPresentation(
        from: TrebleSurfError.noConnection
    )
    
    static let previewAuth = ErrorPresentation(
        from: TrebleSurfError.sessionExpired
    )
    
    static let previewValidation = ErrorPresentation(
        from: TrebleSurfError.validationFailed(fields: [
            "email": "Invalid email format",
            "password": "Password too short"
        ])
    )
    
    static let previewMedia = ErrorPresentation(
        from: TrebleSurfError.imageNotSurfRelated
    )
}

struct ErrorViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Inline Error
            InlineErrorView("This field is required")
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Inline Error")
            
            // Field Error
            FieldErrorView(message: "Invalid email format")
                .previewLayout(.sizeThatFits)
                .previewDisplayName("Field Error")
            
            // Error Banner
            ErrorBannerView(
                presentation: .previewNetwork,
                onRetry: {},
                onDismiss: {}
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Error Banner")
            
            // Error State
            ErrorStateView(
                presentation: .previewAuth,
                onRetry: {}
            )
            .previewLayout(.sizeThatFits)
            .previewDisplayName("Error State")
        }
    }
}
#endif

