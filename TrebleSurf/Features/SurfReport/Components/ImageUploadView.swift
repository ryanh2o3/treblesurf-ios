import SwiftUI
import PhotosUI

struct ImageUploadView: View {
    @ObservedObject var viewModel: SurfReportSubmissionViewModel
    @State private var showingPhotoPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let selectedImage = viewModel.selectedImage {
                // Display selected image
                Image(uiImage: selectedImage)
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
                
                // Show image validation error if present
                if let imageError = viewModel.getFieldError(for: "image") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Image Issue")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        Text(imageError)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Button(action: {
                            viewModel.clearImage()
                        }) {
                            HStack {
                                Image(systemName: "photo.badge.plus")
                                Text("Choose Different Image")
                            }
                            .font(.caption)
                            .foregroundColor(.blue)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.05))
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                    )
                }
                
                // Clear image button
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
                            .font(.system(size: 40))
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
                    .padding(.vertical, 40)
                    .background(Color.blue.opacity(0.05))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    )
                }
                
                // Show image validation error guidance even when no image is selected
                if let imageError = viewModel.getFieldError(for: "image") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Previous Image Issue")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.orange)
                        }
                        
                        Text(imageError)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.leading)
                        
                        Text("Please try uploading a different image that clearly shows surf conditions.")
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
        }
        .padding()
        .photosPicker(isPresented: $showingPhotoPicker, selection: $viewModel.imageSelection, matching: .images)
        .onChange(of: viewModel.shouldShowPhotoPicker) { shouldShow in
            if shouldShow {
                showingPhotoPicker = true
            }
        }
        .onChange(of: showingPhotoPicker) { isShowing in
            if isShowing {
                // Reset the flag when photo picker is shown
                viewModel.shouldShowPhotoPicker = false
            }
        }
    }
}

#Preview {
    ImageUploadView(viewModel: SurfReportSubmissionViewModel())
}
