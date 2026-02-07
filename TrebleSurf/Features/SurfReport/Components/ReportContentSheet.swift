//
//  ReportContentSheet.swift
//  TrebleSurf
//
//  Sheet for reporting inappropriate content
//

import SwiftUI

struct ReportContentSheet: View {
    let surfReportId: String
    let onSubmit: (ReportReason, String?) async -> Bool
    
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasSeenGuidelines") private var hasSeenGuidelines = false
    
    @State private var selectedReason: ReportReason = .inappropriate
    @State private var description: String = ""
    @State private var isSubmitting = false
    @State private var showSuccess = false
    @State private var showError = false
    @State private var showGuidelinesAlert = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Form {
                    // Reason Section
                    Section {
                        Picker("Reason", selection: $selectedReason) {
                            ForEach(ReportReason.allCases, id: \.self) { reason in
                                Label {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(reason.rawValue)
                                            .font(.body)
                                        Text(reason.description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                } icon: {
                                    Image(systemName: reason.icon)
                                }
                                .tag(reason)
                            }
                        }
                        .pickerStyle(.navigationLink)
                    } header: {
                        Text("Why are you reporting this?")
                    }
                    
                    // Description Section
                    Section {
                        TextEditor(text: $description)
                            .frame(minHeight: 100)
                            .disabled(isSubmitting)
                    } header: {
                        Text("Additional Details (Optional)")
                    } footer: {
                        Text("Provide any additional context that might help us review this report.")
                    }
                    
                    // Guidelines Link
                    Section {
                        NavigationLink {
                            CommunityGuidelinesView()
                        } label: {
                            HStack {
                                Image(systemName: "doc.text.fill")
                                    .foregroundColor(.blue)
                                Text("Community Guidelines")
                                    .font(.subheadline)
                            }
                        }
                    }
                    
                    // Submit Button
                    Section {
                        Button {
                            submitReport()
                        } label: {
                            HStack {
                                Spacer()
                                if isSubmitting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle())
                                } else {
                                    Text("Submit Report")
                                        .fontWeight(.semibold)
                                }
                                Spacer()
                            }
                        }
                        .disabled(isSubmitting)
                    }
                }
                
                // Success Overlay
                if showSuccess {
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("Report Submitted")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Thank you for helping keep TrebleSurf safe")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(40)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(.ultraThinMaterial)
                    )
                    .shadow(radius: 20)
                }
            }
            .navigationTitle("Report Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isSubmitting)
                }
            }
            .alert("Community Guidelines", isPresented: $showGuidelinesAlert) {
                Button("I Understand") {
                    hasSeenGuidelines = true
                }
            } message: {
                Text("Please review our community guidelines before reporting content. Reports are reviewed by our team and false reports may result in account restrictions.")
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text("Failed to submit report. Please try again.")
            }
            .onAppear {
                if !hasSeenGuidelines {
                    showGuidelinesAlert = true
                }
            }
        }
    }
    
    private func submitReport() {
        isSubmitting = true
        
        Task {
            let success = await onSubmit(selectedReason, description.isEmpty ? nil : description)
            
            await MainActor.run {
                isSubmitting = false
                
                if success {
                    showSuccess = true
                    // Dismiss after showing success
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                        dismiss()
                    }
                } else {
                    showError = true
                }
            }
        }
    }
}

#Preview {
    ReportContentSheet(surfReportId: "test-report-id") { reason, description in
        // Simulate API call
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        return true
    }
}
