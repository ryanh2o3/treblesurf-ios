// SharedComponents.swift
import SwiftUI

// MARK: - SurfReportCard
struct SurfReportCard: View {
    let report: SurfReport
    let width: CGFloat
    let height: CGFloat
    
    init(report: SurfReport, width: CGFloat = 160, height: CGFloat = 180) {
        self.report = report
        self.width = width
        self.height = height
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media section - show image, video thumbnail, or placeholder
            if let imageData = report.imageData,
               let data = Data(base64Encoded: imageData),
               let uiImage = UIImage(data: data) {
                // Show image or video thumbnail
                ZStack {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height * 0.55)
                        .clipped()
                    
                    // Show play button if this report has a meaningful video key
                    if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: width > 120 ? 32 : 20))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                }
            } else if let videoThumbnail = report.videoThumbnail {
                // Show video thumbnail with play button
                ZStack {
                    Image(uiImage: videoThumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: width, height: height * 0.55)
                        .clipped()
                    
                    // Play button overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: width > 120 ? 32 : 20))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            } else {
                // Show placeholder based on media type
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: width, height: height * 0.55)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: mediaTypeIcon(for: report.mediaType))
                                .font(.system(size: width > 120 ? 24 : 16))
                                .foregroundColor(.secondary)
                            Text(mediaTypeText(for: report.mediaType))
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
            }
            
            // Content section
            VStack(alignment: .leading, spacing: 4) {
                Text(report.countryRegionSpot)
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(report.surfSize)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    Text("•")
                        .foregroundColor(.secondary)
                    Text(report.quality)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text(report.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
        }
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
        .onReceive(report.objectWillChange) { _ in
            // Force UI update when imageData changes
        }
    }
    
    // MARK: - Helper Functions
    private func mediaTypeIcon(for mediaType: String?) -> String {
        switch mediaType?.lowercased() {
        case "image":
            return "photo"
        case "video":
            return "video"
        case "both":
            return "photo.on.rectangle"
        default:
            return "photo"
        }
    }
    
    private func mediaTypeText(for mediaType: String?) -> String {
        switch mediaType?.lowercased() {
        case "image":
            return "Photo"
        case "video":
            return "Video"
        case "both":
            return "Media"
        default:
            return "Photo"
        }
    }
}

// MARK: - ReadingCard
struct ReadingCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let iconColor: Color
    
    init(title: String, value: String, unit: String, icon: String, iconColor: Color = .blue) {
        self.title = title
        self.value = value
        self.unit = unit
        self.icon = icon
        self.iconColor = iconColor
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            HStack(alignment: .firstTextBaseline) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.bold)
                
                Text(unit)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, minHeight: 100, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16) // Increased corner radius for iOS 18 Liquid Glass
                .fill(.ultraThinMaterial) // Use system material instead of custom background
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5) // Use system stroke color
                )
        )
    }
}

// MARK: - Preview
#Preview {
    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
        ReadingCard(
            title: "Swell Height",
            value: "2.1",
            unit: "m",
            icon: "water.waves"
        )
        
        ReadingCard(
            title: "Swell Period", 
            value: "12",
            unit: "sec",
            icon: "timer"
        )
    }
    .padding()
}
