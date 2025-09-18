import SwiftUI
import PhotosUI
import AVKit

struct ImageUploadView: View {
    @ObservedObject var viewModel: SurfReportSubmissionViewModel
    @State private var showingPhotoPicker = false
    @State private var showingVideoPicker = false
    @State private var showingVideoPlayer = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let selectedImage = viewModel.selectedImage {
                // Display selected image
                imagePreview(selectedImage)
            } else if let selectedVideoURL = viewModel.selectedVideoURL,
                      let thumbnail = viewModel.selectedVideoThumbnail {
                // Display selected video with thumbnail
                videoPreview(selectedVideoURL, thumbnail: thumbnail)
            } else {
                // Show media selection options
                mediaSelectionButtons
            }
        }
        .padding()
        .photosPicker(isPresented: $showingPhotoPicker, selection: $viewModel.imageSelection, matching: .images)
        .photosPicker(isPresented: $showingVideoPicker, selection: $viewModel.videoSelection, matching: .videos)
        .onChange(of: viewModel.shouldShowPhotoPicker) { shouldShow in
            if shouldShow {
                showingPhotoPicker = true
            }
        }
        .onChange(of: showingPhotoPicker) { isShowing in
            if isShowing {
                viewModel.shouldShowPhotoPicker = false
            }
        }
        .sheet(isPresented: $showingVideoPlayer) {
            if let videoURL = viewModel.selectedVideoURL {
                VideoPlayer(player: AVPlayer(url: videoURL))
                    .ignoresSafeArea()
            }
        }
    }
    
    // MARK: - Image Preview
    private func imagePreview(_ image: UIImage) -> some View {
        VStack(spacing: 16) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxHeight: 300)
                .cornerRadius(12)
                .shadow(radius: 5)
            
            // Upload progress indicator
            if viewModel.isUploadingImage {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.uploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                    
                    Text("Uploading image...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else if viewModel.uploadProgress >= 1.0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Image uploaded successfully")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Show validation error if present
            if let imageError = viewModel.getFieldError(for: "image") {
                validationErrorView(error: imageError, mediaType: "Image")
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.clearImage()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove Photo")
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    showingPhotoPicker = true
                }) {
                    HStack {
                        Image(systemName: "photo.badge.plus")
                        Text("Change Photo")
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Video Preview
    private func videoPreview(_ videoURL: URL, thumbnail: UIImage) -> some View {
        VStack(spacing: 16) {
            ZStack {
                Image(uiImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 300)
                    .cornerRadius(12)
                    .shadow(radius: 5)
                
                // Play button overlay
                Button(action: {
                    showingVideoPlayer = true
                }) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.3))
                        .clipShape(Circle())
                }
            }
            
            // Upload progress indicator
            if viewModel.isUploadingVideo {
                VStack(spacing: 12) {
                    ProgressView(value: viewModel.videoUploadProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 8)
                    
                    Text("Uploading video...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
            } else if viewModel.videoUploadProgress >= 1.0 {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Video uploaded successfully")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
            
            // Show validation error if present
            if let videoError = viewModel.getFieldError(for: "video") {
                validationErrorView(error: videoError, mediaType: "Video")
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button(action: {
                    viewModel.clearVideo()
                }) {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remove Video")
                    }
                    .foregroundColor(.red)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
                
                Button(action: {
                    showingVideoPicker = true
                }) {
                    HStack {
                        Image(systemName: "video.badge.plus")
                        Text("Change Video")
                    }
                    .foregroundColor(.blue)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Media Selection Buttons
    private var mediaSelectionButtons: some View {
        VStack(spacing: 16) {
            // Photo selection button
            Button(action: {
                Task {
                    await viewModel.preGenerateUploadURL()
                }
                showingPhotoPicker = true
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    
                    Text("Add Photo")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("Upload a photo of current conditions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                )
            }
            
            // Video selection button
            Button(action: {
                showingVideoPicker = true
            }) {
                VStack(spacing: 12) {
                    Image(systemName: "video.fill")
                        .font(.system(size: 32))
                        .foregroundColor(.green)
                    
                    Text("Add Video")
                        .font(.headline)
                        .foregroundColor(.green)
                    
                    Text("Upload a video of current conditions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
                .background(Color.green.opacity(0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.3), lineWidth: 2)
                )
            }
            
            // Show validation error guidance even when no media is selected
            if let imageError = viewModel.getFieldError(for: "image") {
                validationErrorView(error: imageError, mediaType: "Image")
            } else if let videoError = viewModel.getFieldError(for: "video") {
                validationErrorView(error: videoError, mediaType: "Video")
            }
        }
    }
    
    // MARK: - Validation Error View
    private func validationErrorView(error: String, mediaType: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("\(mediaType) Issue")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.orange)
            }
            
            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.leading)
            
            Text("Please try uploading a different \(mediaType.lowercased()) that clearly shows surf conditions.")
                .font(.caption)
                .foregroundColor(.secondary)
                .italic()
        }
        .padding()
        .background(Color.orange.opacity(0.05))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.orange.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    ImageUploadView(viewModel: SurfReportSubmissionViewModel())
}