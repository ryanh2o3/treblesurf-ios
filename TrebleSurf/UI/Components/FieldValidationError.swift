import SwiftUI

struct FieldValidationError: View {
    let errorMessage: String
    let fieldName: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
                .font(.caption)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("\(fieldName.capitalized) Error")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.red.opacity(0.1))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
}

#Preview {
    VStack(spacing: 16) {
        FieldValidationError(
            errorMessage: "Please select a valid surf size from the options provided.",
            fieldName: "surfSize"
        )
        
        FieldValidationError(
            errorMessage: "Wind direction must be one of: glassy, offshore, cross, onshore",
            fieldName: "windDirection"
        )
    }
    .padding()
}
