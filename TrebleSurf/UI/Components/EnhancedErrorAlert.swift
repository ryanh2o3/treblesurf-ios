import SwiftUI

struct EnhancedErrorAlert: View {
    let error: APIErrorHandler.ErrorDisplay
    let onDismiss: () -> Void
    let onRetry: (() -> Void)?
    let onAuthenticate: (() -> Void)?
    let onImageRetry: (() -> Void)?
    
    init(error: APIErrorHandler.ErrorDisplay, onDismiss: @escaping () -> Void, onRetry: (() -> Void)? = nil, onAuthenticate: (() -> Void)? = nil, onImageRetry: (() -> Void)? = nil) {
        self.error = error
        self.onDismiss = onDismiss
        self.onRetry = onRetry
        self.onAuthenticate = onAuthenticate
        self.onImageRetry = onImageRetry
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Error Icon
            Image(systemName: getErrorIcon())
                .font(.system(size: 48))
                .foregroundColor(.red)
                .padding(.top, 8)
            
            // Error Title
            Text(error.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            // Error Message
            if !error.requiresImageRetry {
            Text(error.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            }
            
            // Help Text - only show when not an image validation error
            if !error.requiresImageRetry {
                VStack(alignment: .leading, spacing: 8) {
                    Text("How to fix:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Text(error.help)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                .padding(.horizontal)
                .padding(.vertical, 12)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
            
            // Special guidance for image validation errors
            if error.requiresImageRetry {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Image Requirements:")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    VStack(alignment: .leading, spacing: 3) {
                        Text("• Show ocean, waves, beach, or coastline")
                        Text("• Be clear and focused on surf conditions")
                        Text("• Avoid images of people, objects, or other subjects")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                )
            }
            
            // Action Buttons
            VStack(spacing: 12) {
                // Prioritize image retry button for image validation errors
                if error.requiresImageRetry {
                    Button(action: {
                        if let onImageRetry = onImageRetry {
                            onImageRetry()
                        } else {
                            onDismiss()
                        }
                    }) {
                        HStack {
                            Image(systemName: "photo.badge.plus")
                            Text("Upload Different Image")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                if let onAuthenticate = onAuthenticate, error.requiresAuthentication {
                    Button(action: onAuthenticate) {
                        HStack {
                            Image(systemName: "person.circle")
                            Text("Log In")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                if let onRetry = onRetry, error.isRetryable {
                    Button(action: onRetry) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                            Text("Try Again")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
                
                Button(action: onDismiss) {
                    Text("Dismiss")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(.systemGray4))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(radius: 10)
    }
    
    private func getErrorIcon() -> String {
        if error.requiresAuthentication {
            return "person.crop.circle.badge.exclamationmark"
        } else if error.requiresImageRetry {
            return "photo.badge.exclamationmark"
        } else if error.isRetryable {
            return "exclamationmark.triangle"
        } else {
            return "xmark.circle"
        }
    }
}

#Preview {
    let sampleError = APIErrorHandler.ErrorDisplay(
        title: "Image not surf-related",
        message: "The image does not appear to show surf conditions",
        help: "Please upload a photo that clearly shows the ocean, waves, beach, or coastline.",
        errorType: .imageNotSurfRelated,
        fieldName: "image",
        isRetryable: false,
        requiresAuthentication: false,
        requiresImageRetry: true
    )
    
    return EnhancedErrorAlert(
        error: sampleError,
        onDismiss: {},
        onRetry: nil,
        onAuthenticate: nil,
        onImageRetry: {}
    )
    .padding()
}
