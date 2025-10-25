// LiquidGlassComponents.swift
// iOS 18 Liquid Glass Design System Components
import SwiftUI

// Note: These components are designed to work with iOS 15+ and provide
// Liquid Glass-like effects using available system materials

// MARK: - Glass Button Styles
struct GlassButtonStyle: ButtonStyle {
    let prominence: GlassProminence
    
    enum GlassProminence {
        case standard
        case prominent
    }
    
    init(prominence: GlassProminence = .standard) {
        self.prominence = prominence
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Glass Card Component
struct GlassCard<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    
    init(cornerRadius: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(.ultraThinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(.quaternary, lineWidth: 0.5)
                    )
            )
    }
}

// MARK: - Glass Navigation Bar
struct GlassNavigationBar<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .padding()
            .background(
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea(edges: .top)
            )
    }
}

// MARK: - Glass Section Header
struct GlassSectionHeader: View {
    let title: String
    let subtitle: String?
    
    init(_ title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
    }
}

// MARK: - Glass Loading Indicator
struct GlassLoadingIndicator: View {
    let message: String
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Glass Error Alert
struct GlassErrorAlert: View {
    let title: String
    let message: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text(title)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            
            Button("Retry", action: action)
                .buttonStyle(GlassButtonStyle(prominence: .prominent))
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 20) {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Sample Card")
                    .font(.headline)
                Text("This is a sample glass card component")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
        
        HStack(spacing: 12) {
            Button("Standard") { }
                .buttonStyle(GlassButtonStyle())
            
            Button("Prominent") { }
                .buttonStyle(GlassButtonStyle(prominence: .prominent))
        }
        
        GlassLoadingIndicator("Loading data...")
        
        GlassErrorAlert(
            title: "Error",
            message: "Something went wrong. Please try again."
        ) {
            // Retry action
        }
    }
    .padding()
    .background(Color(.systemBackground))
}
