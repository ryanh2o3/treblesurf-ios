import SwiftUI
import UIKit
import Foundation

struct RecentReportsSection: View {
    let reports: [SurfReport]
    let isLoading: Bool
    let onSelect: (SurfReport) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recent Reports")
                .font(.headline)
                .padding(.horizontal)
            
            if isLoading {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 15) {
                        ForEach(0..<3, id: \.self) { _ in
                            SkeletonReportCard()
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity)
            } else if reports.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "doc.text.magnifyingglass")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No recent reports")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(height: 120)
                    Spacer()
                }
                .padding(.horizontal)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(alignment: .top, spacing: 15) {
                        ForEach(reports) { report in
                            reportCard(report)
                                .onTapGesture {
                                    onSelect(report)
                                }
                                .transition(.opacity.combined(with: .scale(scale: 0.95)))
                        }
                    }
                    .padding(.horizontal)
                }
                .transition(.opacity)
            }
        }
    }
    
    private func reportCard(_ report: SurfReport) -> some View {
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
                        .frame(width: 160, height: 100)
                        .clipped()
                    
                    // Show play button if this report has a meaningful video key
                    if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32))
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
                        .frame(width: 160, height: 100)
                        .clipped()
                    
                    // Play button overlay
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            } else {
                // Show placeholder based on media type
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 160, height: 100)
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: mediaTypeIcon(for: report.mediaType))
                                .font(.system(size: 24))
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
        .frame(width: 160, height: 180)
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
