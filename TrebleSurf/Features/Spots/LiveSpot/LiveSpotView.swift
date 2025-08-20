// LiveSpotView.swift
import SwiftUI

struct LiveSpotView: View {
    @EnvironmentObject var dataStore: DataStore
    var spotId: String
    @State private var spotImage: Image? = nil

    var body: some View {
        VStack {
            ScrollView {
                // Current conditions card uses the data from dataStore
                CurrentConditionsCard(spotImage: spotImage)
                
                // Other cards and UI elements
                // ...
            }
        }
        .onAppear {
            // Trigger data fetch when view appears
            print("Spot fetching: \(spotId)")
            dataStore.fetchConditions(for: spotId) { success in
                if !success {
                    // Handle error if needed
                    print("Failed to fetch conditions for spot: \(spotId)")
                }
            }
            // Fetch spot image
//                        dataStore.fetchSpotImage(for: spotId) { image in
//                            self.spotImage = image
//                        }
        }
    }
}
