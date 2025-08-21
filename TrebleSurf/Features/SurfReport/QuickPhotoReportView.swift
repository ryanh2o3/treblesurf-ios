import SwiftUI
import PhotosUI

struct QuickPhotoReportView: View {
    let spotId: String
    let spotName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = QuickPhotoReportViewModel()
    @State private var showingPhotoPicker = false
    
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
                
                // Photo section
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
                            
                            Button("Change Photo") {
                                viewModel.clearImage()
                            }
                            .foregroundColor(.blue)
                            .font(.subheadline)
                        }
                    } else {
                        // Custom button that handles both presigned URL generation and photo picker
                        Button(action: {
                            // Start presigned URL generation immediately
                            Task {
                                await viewModel.preGenerateUploadURL()
                            }
                            // Show photo picker
                            showingPhotoPicker = true
                        }) {
                            VStack(spacing: 16) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                                
                                Text("Add Photo")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                                
                                Text("Tap to select a photo of current conditions")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(16)
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
        }
    }
}

#Preview {
    QuickPhotoReportView(spotId: "test", spotName: "Test Spot")
}
