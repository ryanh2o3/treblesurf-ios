//
//  CommunityGuidelinesView.swift
//  TrebleSurf
//
//  Display community guidelines for content moderation
//

import SwiftUI

struct CommunityGuidelinesView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                VStack(alignment: .leading, spacing: 8) {
                    Text("Community Guidelines")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    
                    Text("Help us keep TrebleSurf a positive space for the surf community")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.bottom, 8)
                
                // What to Post
                GuidelineSection(
                    title: "✅ What to Post",
                    icon: "checkmark.circle.fill",
                    iconColor: .green,
                    items: [
                        "Surf-related photos and videos",
                        "Accurate surf condition reports",
                        "Respectful comments and feedback",
                        "Helpful tips for fellow surfers"
                    ]
                )
                
                // What Not to Post
                GuidelineSection(
                    title: "❌ What Not to Post",
                    icon: "xmark.circle.fill",
                    iconColor: .red,
                    items: [
                        "Nudity or sexually explicit content",
                        "Hate speech or harassment",
                        "Spam or advertising",
                        "Content unrelated to surfing",
                        "False or misleading information"
                    ]
                )
                
                // Reporting
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "flag.fill")
                            .foregroundColor(.orange)
                        Text("Reporting Content")
                            .font(.headline)
                    }
                    
                    Text("If you see content that violates these guidelines, please report it using the report button. Our team reviews all reports and takes appropriate action.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(12)
                
                // Consequences
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                        Text("Consequences")
                            .font(.headline)
                    }
                    
                    Text("Violations of these guidelines may result in content removal and account suspension. Repeated violations may lead to permanent bans.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                
                // Contact
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "envelope.fill")
                            .foregroundColor(.blue)
                        Text("Questions?")
                            .font(.headline)
                    }
                    
                    Text("If you have questions about these guidelines, contact us at support@treblesurf.com")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
            .padding()
        }
        .navigationTitle("Community Guidelines")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct GuidelineSection: View {
    let title: String
    let icon: String
    let iconColor: Color
    let items: [String]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(iconColor)
                Text(title)
                    .font(.headline)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                            .foregroundColor(.secondary)
                        Text(item)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(iconColor.opacity(0.1))
        .cornerRadius(12)
    }
}

#Preview {
    NavigationStack {
        CommunityGuidelinesView()
    }
}
