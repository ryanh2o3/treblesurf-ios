// RecentReportCard.swift
import SwiftUI

struct RecentReportCard: View {
    let report: SurfReport

    var body: some View {
        HStack {
            // Media preview - show image, video thumbnail, or placeholder
            Group {
                if let imageData = report.imageData,
                   let data = Data(base64Encoded: imageData),
                   let uiImage = UIImage(data: data) {
                    // Show image or video thumbnail
                    ZStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)

                        // Show play button if this report has a meaningful video key
                        if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 20))
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
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)

                        // Play button overlay
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.3))
                            .clipShape(Circle())
                    }
                } else {
                    // Show placeholder based on media type
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 60, height: 60)
                        .cornerRadius(8)
                        .overlay(
                            VStack(spacing: 2) {
                                Image(systemName: ReportCardHelpers.mediaTypeIcon(for: report.mediaType))
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                                Text(ReportCardHelpers.mediaTypeText(for: report.mediaType))
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        )
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(report.countryRegionSpot)
                    .font(.headline)

                HStack {
                    Text(report.surfSize)
                    Text("\u{2022}")
                    Text(report.quality)
                }
                .font(.subheadline)

                Text(report.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Chevron indicator
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
}
