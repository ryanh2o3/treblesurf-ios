import SwiftUI
import PhotosUI

struct SurfReportSubmissionView: View {
    let spotId: String
    let spotName: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel = SurfReportSubmissionViewModel()
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                progressIndicator
                stepContent
                navigationButtons
            }
            .navigationTitle("Detailed Report")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        print("🚪 [CANCEL] ===== CANCEL BUTTON PRESSED =====")
                        print("🚪 [CANCEL] User canceled surf report form")
                        viewModel.cleanupUnusedUploads()
                        dismiss()
                    }
                }
            }
            .onAppear {
                viewModel.setSpotId(spotId)
            }
            .onChange(of: viewModel.currentStep) { step in
                // If we're on the image step and should show photo picker, trigger it
                if step == 6 && viewModel.shouldShowPhotoPicker {
                    // Small delay to ensure the view is fully loaded
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        viewModel.shouldShowPhotoPicker = true
                    }
                }
            }
            .onReceive(viewModel.$shouldDismiss) { shouldDismiss in
                if shouldDismiss {
                    dismiss()
                }
            }
            .alert("Success", isPresented: $viewModel.showSuccessAlert) {
                Button("OK") { }
            } message: {
                Text("Your surf report has been submitted successfully!")
            }
            .sheet(isPresented: $viewModel.showErrorAlert) {
                errorAlertContent
            }
        }
    }
    
    // MARK: - View Components
    
    private var progressIndicator: some View {
        ProgressView(value: Double(viewModel.currentStep + 1), total: Double(viewModel.steps.count))
            .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            .padding()
    }
    
    private var stepContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                stepHeader
                optionsGrid
                imageUploadSection
                dateTimePicker
                Spacer(minLength: 100)
            }
            .padding(.vertical)
        }
    }
    
    private var stepHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(viewModel.currentStepTitle)
                .font(.title2)
                .fontWeight(.bold)
            
            Text(viewModel.currentStepDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
    }
    
    private var optionsGrid: some View {
        Group {
            if !viewModel.currentStepOptions.isEmpty {
                VStack(spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
                        ForEach(viewModel.currentStepOptions, id: \.id) { option in
                            OptionCard(
                                option: option,
                                isSelected: viewModel.selectedOptions[viewModel.currentStep] == option.id,
                                onTap: {
                                    viewModel.selectOption(option.id)
                                },
                                hasError: viewModel.hasFieldError(for: getCurrentFieldName())
                            )
                        }
                    }
                    
                    // Show field validation error if present
                    if let fieldError = viewModel.getFieldError(for: getCurrentFieldName()) {
                        FieldValidationError(
                            errorMessage: fieldError,
                            fieldName: getCurrentFieldName()
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    private var imageUploadSection: some View {
        Group {
            if viewModel.currentStep == 6 {
                ImageUploadView(viewModel: viewModel)
            }
        }
    }
    
    private var dateTimePicker: some View {
        Group {
            if viewModel.currentStep == 7 {
                VStack(alignment: .leading, spacing: 16) {
                    Text("When did you surf?")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        timestampStatusText
                        
                        DatePicker(
                            "Surf Date & Time",
                            selection: $viewModel.selectedDateTime,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(WheelDatePickerStyle())
                        .padding(.horizontal)
                    }
                }
            }
        }
    }
    
    private var timestampStatusText: some View {
        Group {
            if (viewModel.selectedImage != nil || viewModel.selectedVideoURL != nil) && viewModel.photoTimestampExtracted {
                let mediaType = viewModel.selectedVideoURL != nil ? "Video" : "Photo"
                let emoji = viewModel.selectedVideoURL != nil ? "🎥" : "📸"
                Text("\(emoji) \(mediaType) timestamp detected: \(formatDate(viewModel.selectedDateTime))")
                    .font(.subheadline)
                    .foregroundColor(.green)
                    .padding(.horizontal)
            } else if (viewModel.selectedImage != nil || viewModel.selectedVideoURL != nil) && !viewModel.photoTimestampExtracted {
                let mediaType = viewModel.selectedVideoURL != nil ? "video" : "photo"
                let emoji = viewModel.selectedVideoURL != nil ? "🎥" : "📸"
                Text("\(emoji) \(mediaType.capitalized) added but no timestamp found - please select date manually")
                    .font(.subheadline)
                    .foregroundColor(.orange)
                    .padding(.horizontal)
            } else {
                Text("📅 Please select when you surfed")
                    .font(.subheadline)
                    .foregroundColor(.blue)
                    .padding(.horizontal)
            }
        }
    }
    
    private var navigationButtons: some View {
        VStack(spacing: 16) {
            // Step indicators
            HStack(spacing: 8) {
                ForEach(0..<viewModel.steps.count, id: \.self) { index in
                    Circle()
                        .fill(viewModel.getStepStatusColor(for: index))
                        .frame(width: 8, height: 8)
                }
            }
            
            HStack(spacing: 16) {
                if viewModel.currentStep > 0 {
                    Button("Back") {
                        viewModel.previousStep()
                    }
                    .foregroundColor(.secondary)
                }
                
                Spacer()
                
                nextOrSubmitButton
            }
            .padding(.horizontal)
        }
        .padding()
        .background(Color(.systemBackground))
        .shadow(radius: 2)
    }
    
    private var nextOrSubmitButton: some View {
        Group {
            if viewModel.currentStep < viewModel.steps.count - 1 {
                Button("Next") {
                    viewModel.nextStep()
                }
                .disabled(viewModel.shouldDisableNextButton)
                .foregroundColor(viewModel.shouldDisableNextButton ? .secondary : .blue)
            } else {
                Button("Submit Report") {
                    Task {
                        await viewModel.submitReport(spotId: spotId)
                    }
                }
                .disabled(!viewModel.canSubmit || viewModel.isSubmitting)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(viewModel.canSubmit && !viewModel.isSubmitting ? Color.blue : Color.gray)
                .cornerRadius(8)
            }
        }
    }
    
    private var errorAlertContent: some View {
        Group {
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
                    }
                )
                .presentationDetents([.medium, .large])
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
    
    // Helper function to get the current field name for validation
    private func getCurrentFieldName() -> String {
        switch viewModel.currentStep {
        case 0: return "surfSize"
        case 1: return "messiness"
        case 2: return "windDirection"
        case 3: return "windAmount"
        case 4: return "consistency"
        case 5: return "quality"
        default: return ""
        }
    }
}

struct OptionCard: View {
    let option: SurfReportOption
    let isSelected: Bool
    let onTap: () -> Void
    let hasError: Bool
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Icon based on option type
                Image(systemName: option.iconName)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : (hasError ? .red : .blue))
                
                Text(option.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : (hasError ? .red : .primary))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 100)
            .padding()
            .background(isSelected ? Color.blue : (hasError ? Color.red.opacity(0.1) : Color.gray.opacity(0.1)))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : (hasError ? Color.red : Color.gray.opacity(0.3)), lineWidth: hasError ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    SurfReportSubmissionView(spotId: "test", spotName: "Test Spot")
}
