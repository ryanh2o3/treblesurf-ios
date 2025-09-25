import SwiftUI
import PhotosUI
import AVKit

struct QuickPhotoReportView: View {
    let spotId: String
    let spotName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QuickPhotoReportViewModel()
    @State private var showingPhotoPicker = false
    @State private var showingVideoPicker = false
    @State private var showingVideoPlayer = false
    @State private var videoURL: URL?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 8) {
                    Text("Quick Photo Report")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("Share current conditions at \(spotName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top)
                
                // Media section
                VStack(spacing: 16) {
                    if let imageData = viewModel.selectedImage {
                        VStack(spacing: 12) {
                            Image(uiImage: imageData)
                                .resizable()
                                .aspectRatio(contentMode: .fit)
                                .frame(maxHeight: 300)
                                .cornerRadius(16)
                            
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
                            
                            // Image validation status
                            if viewModel.isValidatingImage {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Validating image...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if let validationError = viewModel.imageValidationError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(validationError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal)
                            } else if viewModel.imageValidationPassed {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Image validated successfully")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            // Timestamp status
                            if viewModel.photoTimestampExtracted {
                                Text("📸 Photo timestamp detected: \(formatDate(viewModel.selectedDateTime))")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                    .padding(.horizontal)
                            }
                            
                            Button("Change Photo") {
                                viewModel.clearImage()
                            }
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        }
                    } else if let videoThumbnail = viewModel.selectedVideoThumbnail {
                        VStack(spacing: 12) {
                            ZStack {
                                Image(uiImage: videoThumbnail)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(maxHeight: 300)
                                    .clipped()
                                    .cornerRadius(16)
                                
                                // Play button overlay
                                Image(systemName: "play.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white)
                                    .background(Color.black.opacity(0.3))
                                    .clipShape(Circle())
                            }
                            .onTapGesture {
                                if let videoURL = viewModel.selectedVideoURL {
                                    self.videoURL = videoURL
                                    showingVideoPlayer = true
                                }
                            }
                            
                            // Video upload progress indicator
                            if viewModel.isUploadingVideoThumbnail {
                                VStack(spacing: 12) {
                                    ProgressView()
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .frame(height: 8)
                                    
                                    Text("Uploading video thumbnail...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            } else if viewModel.isUploadingVideo {
                                VStack(spacing: 12) {
                                    ProgressView(value: viewModel.videoUploadProgress)
                                        .progressViewStyle(LinearProgressViewStyle())
                                        .frame(height: 8)
                                    
                                    Text("Uploading video...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.horizontal)
                            } else if viewModel.videoUploadProgress >= 1.0 && viewModel.videoThumbnailKey != nil {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Video and thumbnail uploaded successfully")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    }
                                }
                            
                            // Video validation status
                            if viewModel.isValidatingVideo {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Validating video...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else if let validationError = viewModel.videoValidationError {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.red)
                                    Text(validationError)
                                        .font(.caption)
                                        .foregroundColor(.red)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal)
                            } else if viewModel.videoValidationPassed {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Video validated successfully")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                }
                            }
                            
                            // Video timestamp status
                            if viewModel.photoTimestampExtracted {
                                Text("🎥 Video timestamp detected: \(formatDate(viewModel.selectedDateTime))")
                                    .font(.subheadline)
                                    .foregroundColor(.green)
                                    .padding(.horizontal)
                            }
                            
                            Button("Change Video") {
                                viewModel.clearVideo()
                            }
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        }
                    } else {
                        // Media selection buttons
                        VStack(spacing: 16) {
                            HStack(spacing: 16) {
                                // Photo button
                                Button(action: {
                                    // Start presigned URL generation immediately
                                    Task {
                                        await viewModel.preGenerateUploadURL()
                                    }
                                    // Show photo picker
                                    showingPhotoPicker = true
                                }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.blue)
                                        
                                        Text("Add Photo")
                                            .font(.headline)
                                            .foregroundColor(.blue)
                                        
                                        Text("Select a photo")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(12)
                                }
                                
                                // Video button
                                Button(action: {
                                    showingVideoPicker = true
                                }) {
                                    VStack(spacing: 12) {
                                        Image(systemName: "video.fill")
                                            .font(.system(size: 30))
                                            .foregroundColor(.green)
                                        
                                        Text("Add Video")
                                            .font(.headline)
                                            .foregroundColor(.green)
                                        
                                        Text("Select a video")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 40)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(12)
                                }
                            }
                            
                            Text("Choose a photo or video of current conditions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            
                            // Show loading state when video is being processed
                            if viewModel.isValidatingVideo || viewModel.isUploadingVideo {
                                VStack(spacing: 8) {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Processing video...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                .padding(.top, 8)
                            }
                        }
                    }
                }
                
                // Basic conditions
                VStack(alignment: .leading, spacing: 16) {
                    Text("Quick Conditions")
                        .font(.headline)
                    
                    // Wave size picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Wave Size")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Wave Size", selection: $viewModel.waveSize) {
                            ForEach(WaveSize.allCases, id: \.self) { size in
                                Text(size.displayName).tag(size)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Quality picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Quality")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("Quality", selection: $viewModel.quality) {
                            ForEach(Quality.allCases, id: \.self) { quality in
                                Text(quality.displayName).tag(quality)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding(.horizontal)
                
                // Timestamp selector (shown when no timestamp found)
                if viewModel.showTimestampSelector {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("When was this media taken?")
                            .font(.headline)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text("No timestamp found in media - please select the time")
                                .font(.subheadline)
                                .foregroundColor(.orange)
                            
                            DatePicker(
                                "Media Date & Time",
                                selection: $viewModel.selectedDateTime,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                            .datePickerStyle(WheelDatePickerStyle())
                        }
                    }
                    .padding(.horizontal)
                }
                
                Spacer()
                
                // Submit button
                Button(action: {
                    Task {
                        await viewModel.submitQuickReport(spotId: spotId)
                    }
                }) {
                    HStack {
                        if viewModel.isSubmitting {
                            ProgressView()
                                .scaleEffect(0.8)
                                .foregroundColor(.white)
                        } else {
                            Image(systemName: "paperplane.fill")
                        }
                        
                        Text(viewModel.isSubmitting ? "Submitting..." : "Submit Report")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(viewModel.canSubmit ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                .padding(.horizontal)
                .padding(.bottom)
            }
            .navigationTitle("Quick Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.setSpotId(spotId)
            }
            .onReceive(viewModel.$shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $viewModel.imageSelection, matching: .images)
            .photosPicker(isPresented: $showingVideoPicker, selection: $viewModel.selectedVideo, matching: .videos)
            .alert("Success", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Your quick surf report has been submitted!")
            }
            .sheet(isPresented: $viewModel.showErrorAlert) {
                if let error = viewModel.currentError {
                    EnhancedErrorAlert(
                        error: error,
                        onDismiss: {
                            viewModel.clearAllErrors()
                        },
                        onRetry: {
                            // Retry the last action based on error type
                            if error.requiresImageRetry {
                                // Retry image upload
                                viewModel.retryImageUpload(spotId: spotId)
                                // Reset the photo picker state to show it again
                                showingPhotoPicker = true
                            } else if error.isRetryable {
                                // Retry submission
                                viewModel.retrySubmission(spotId: spotId)
                            }
                        },
                        onAuthenticate: {
                            // Handle authentication - this would typically redirect to login
                            viewModel.clearAllErrors()
                            dismiss()
                        },
                        onImageRetry: {
                            // Handle image retry specifically
                            viewModel.retryImageUpload(spotId: spotId)
                            // Reset the photo picker state to show it again
                            showingPhotoPicker = true
                        }
                    )
                    .presentationDetents([.medium, .large])
                }
            }
            .sheet(isPresented: $showingVideoPlayer) {
                if let videoURL = videoURL {
                    VideoPlayer(player: AVPlayer(url: videoURL))
                        .onDisappear {
                            // Clean up video URL when sheet is dismissed
                            self.videoURL = nil
                        }
                }
            }
            .onDisappear {
                print("🚪 [QUICK_CANCEL] ===== QUICK PHOTO REPORT DISMISSED =====")
                // Clean up any uploaded media when the view is dismissed
                viewModel.cleanupUnusedUploads()
            }
        }
    }
}

    // MARK: - Helper Functions
    
    // Helper function to format the date for display
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }


#Preview {
    QuickPhotoReportView(spotId: "test", spotName: "Test Spot")
}
