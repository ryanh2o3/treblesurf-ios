// MatchingReportCard.swift
import SwiftUI

struct MatchingReportCard: View {
    @ObservedObject var report: SurfReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Media preview - show image, video thumbnail, or placeholder
            ZStack(alignment: .topTrailing) {
                Group {
                    if let imageData = report.imageData,
                       let data = Data(base64Encoded: imageData),
                       let uiImage = UIImage(data: data) {
                        // Show image or video thumbnail
                        ZStack {
                            Image(uiImage: uiImage)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 140, height: 140)
                                .clipped()
                                .cornerRadius(8)

                            // Show play button if this report has a meaningful video key
                            if let videoKey = report.videoKey, !videoKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 30))
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
                                .frame(width: 140, height: 140)
                                .clipped()
                                .cornerRadius(8)

                            // Play button overlay
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 30))
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.3))
                                .clipShape(Circle())
                        }
                    } else {
                        // Show placeholder based on media type
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 140, height: 140)
                            .cornerRadius(8)
                            .overlay(
                                VStack(spacing: 4) {
                                    Image(systemName: ReportCardHelpers.mediaTypeIcon(for: report.mediaType))
                                        .font(.system(size: 24))
                                        .foregroundColor(.secondary)
                                    Text(ReportCardHelpers.mediaTypeText(for: report.mediaType))
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            )
                    }
                }

                // Show similarity badge if available
                if let similarity = report.combinedSimilarity {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 8))
                        Text("\(Int(similarity * 100))%")
                            .font(.system(size: 10))
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.green)
                    .cornerRadius(8)
                    .padding(6)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(report.surfSize)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("\u{2022}")
                    Text(report.quality)
                        .font(.subheadline)
                }
                .foregroundColor(.primary)

                Text(report.time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
        .frame(width: 156)
    }
}
