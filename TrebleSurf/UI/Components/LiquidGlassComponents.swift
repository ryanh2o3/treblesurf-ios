// LiquidGlassComponents.swift
// iOS 26 Liquid Glass Design System Components with Loading States
import SwiftUI

// Note: These components are designed to work with iOS 15+ and provide
// Liquid Glass-like effects using available system materials

// MARK: - Shimmer Effect
struct ShimmerEffect: ViewModifier {
    @State private var phase: CGFloat = 0
    var duration: Double = 1.5
    var bounce: Bool = false
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let gradientWidth = geometry.size.width * 0.3
                    
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.5),
                            Color.white.opacity(0.3),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: gradientWidth)
                    .offset(x: phase * (geometry.size.width + gradientWidth) - gradientWidth)
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: duration)
                        .repeatForever(autoreverses: bounce)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer(duration: Double = 1.5, bounce: Bool = false) -> some View {
        modifier(ShimmerEffect(duration: duration, bounce: bounce))
    }
}

// MARK: - Skeleton Shapes
struct SkeletonShape: View {
    var cornerRadius: CGFloat = 8
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.15))
            .shimmer()
    }
}

struct SkeletonCircle: View {
    var body: some View {
        Circle()
            .fill(Color.gray.opacity(0.15))
            .shimmer()
    }
}

struct SkeletonLine: View {
    var height: CGFloat = 12
    var width: CGFloat? = nil
    var cornerRadius: CGFloat = 6
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color.gray.opacity(0.15))
            .frame(width: width, height: height)
            .shimmer()
    }
}

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
    @State private var isAnimating = false
    
    init(_ message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(lineWidth: 3)
                    .foregroundColor(.gray.opacity(0.2))
                    .frame(width: 40, height: 40)
                
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .foregroundColor(.blue)
                    .frame(width: 40, height: 40)
                    .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                    .animation(
                        Animation.linear(duration: 1)
                            .repeatForever(autoreverses: false),
                        value: isAnimating
                    )
            }
            .onAppear {
                isAnimating = true
            }
            
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

// MARK: - Skeleton Card Components

/// Skeleton loader for buoy/spot list cards
struct SkeletonListCard: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icon skeleton
            SkeletonCircle()
                .frame(width: 60, height: 60)
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                SkeletonLine(width: 150)
                    .frame(height: 16)
                
                SkeletonLine(width: 100)
                    .frame(height: 14)
                
                HStack(spacing: 12) {
                    SkeletonLine(width: 60)
                        .frame(height: 12)
                    
                    SkeletonLine(width: 60)
                        .frame(height: 12)
                }
            }
            
            Spacer()
            
            // Chevron placeholder
            SkeletonShape(cornerRadius: 4)
                .frame(width: 8, height: 14)
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

/// Skeleton loader for report cards
struct SkeletonReportCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media skeleton
            SkeletonShape(cornerRadius: 0)
                .frame(width: 160, height: 100)
            
            // Content skeleton
            VStack(alignment: .leading, spacing: 8) {
                SkeletonLine(width: 130)
                    .frame(height: 16)
                
                HStack(spacing: 4) {
                    SkeletonLine(width: 50)
                        .frame(height: 12)
                    SkeletonShape(cornerRadius: 2)
                        .frame(width: 4, height: 4)
                    SkeletonLine(width: 40)
                        .frame(height: 12)
                }
                
                SkeletonLine(width: 100)
                    .frame(height: 10)
            }
            .padding(12)
        }
        .frame(width: 160, height: 180)
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

/// Skeleton loader for weather buoy cards
struct SkeletonBuoyCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header skeleton
            HStack {
                HStack(spacing: 8) {
                    SkeletonCircle()
                        .frame(width: 32, height: 32)
                    
                    SkeletonLine(width: 80)
                        .frame(height: 14)
                }
                
                Spacer()
            }
            
            // Data grid skeleton
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonLine(width: 50)
                            .frame(height: 18)
                        SkeletonLine(width: 70)
                            .frame(height: 10)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonLine(width: 40)
                            .frame(height: 18)
                        SkeletonLine(width: 50)
                            .frame(height: 10)
                    }
                }
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonLine(width: 45)
                            .frame(height: 14)
                        SkeletonLine(width: 60)
                            .frame(height: 10)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .leading, spacing: 4) {
                        SkeletonLine(width: 35)
                            .frame(height: 14)
                        SkeletonLine(width: 40)
                            .frame(height: 10)
                    }
                }
            }
        }
        .padding(16)
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

/// Skeleton loader for current conditions card
struct SkeletonCurrentConditions: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SkeletonLine(width: 150)
                .frame(height: 16)
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonLine(width: 80)
                        .frame(height: 28)
                    SkeletonLine(width: 90)
                        .frame(height: 10)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonLine(width: 70)
                        .frame(height: 20)
                    SkeletonLine(width: 40)
                        .frame(height: 10)
                }
                
                Spacer()
                
                VStack(alignment: .leading, spacing: 4) {
                    SkeletonLine(width: 60)
                        .frame(height: 20)
                    SkeletonLine(width: 35)
                        .frame(height: 10)
                }
            }
            
            SkeletonLine(width: 200)
                .frame(height: 12)
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

/// Generic skeleton content view for replacing entire sections
struct SkeletonContentView: View {
    var itemCount: Int = 3
    var itemType: SkeletonItemType = .list
    
    enum SkeletonItemType {
        case list
        case report
        case buoy
    }
    
    var body: some View {
        LazyVStack(spacing: 16) {
            ForEach(0..<itemCount, id: \.self) { _ in
                switch itemType {
                case .list:
                    SkeletonListCard()
                case .report:
                    SkeletonReportCard()
                case .buoy:
                    SkeletonBuoyCard()
                }
            }
        }
        .transition(.opacity)
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
#Preview("Glass Components") {
    ScrollView {
        VStack(spacing: 20) {
            GlassSectionHeader("Standard Components", subtitle: "Basic glass design elements")
            
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
    }
    .background(Color(.systemBackground))
}

#Preview("Skeleton Loaders") {
    ScrollView {
        VStack(spacing: 20) {
            GlassSectionHeader("Skeleton Components", subtitle: "Loading state animations")
            
            Text("List Card Skeleton")
                .font(.caption)
                .foregroundColor(.secondary)
            SkeletonListCard()
            
            Text("Report Card Skeleton")
                .font(.caption)
                .foregroundColor(.secondary)
            SkeletonReportCard()
            
            Text("Buoy Card Skeleton")
                .font(.caption)
                .foregroundColor(.secondary)
            SkeletonBuoyCard()
            
            Text("Current Conditions Skeleton")
                .font(.caption)
                .foregroundColor(.secondary)
            SkeletonCurrentConditions()
                .padding(.horizontal)
        }
        .padding()
    }
    .background(Color(.systemBackground))
}
