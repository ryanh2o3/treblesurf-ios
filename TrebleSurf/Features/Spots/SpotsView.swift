// SpotsView.swift
import SwiftUI

struct SpotsView: View {
    @EnvironmentObject var dataStore: DataStore
    @StateObject private var viewModel: SpotsViewModel = SpotsViewModel()
    @State private var selectedTab: String = "Live"
    @State private var isLoggedIn: Bool = false
    @State private var showLogin: Bool = false
    @State private var selectedRegion: String = "Donegal"
        @State private var selectedSpot: String = ""
        
        let regionOptions = ["Donegal"]
    var dynamicSpotId: String {
            "Ireland#\(selectedRegion)#\(selectedSpot)"
        }

    var body: some View {
        NavigationView {
            
            VStack(spacing: 0) {
                // Top Buttons
                HStack {
                    Button(action: { selectedTab = "Live" }) {
                        Text("Live")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .background(selectedTab == "Live" ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                    Button(action: { selectedTab = "Forecast" }) {
                        Text("Forecast")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 2)
                            .background(selectedTab == "Forecast" ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(20)
                    }
                }
                .padding()
                
                // Region Dropdown
                HStack {
                    Picker("Region", selection: $selectedRegion) {
                        ForEach(regionOptions, id: \.self) { region in
                            Text(region).tag(region)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .cornerRadius(10)
                    
                    // Spot Dropdown
                    Picker("Spot", selection: $selectedSpot) {
                                                if viewModel.spotNames.isEmpty {
                                                    Text("Loading...").tag("")
                                                } else {
                                                    ForEach(viewModel.spotNames, id: \.self) { spot in
                                                        Text(spot).tag(spot)
                                                    }
                                                }
                                            }
                    .pickerStyle(MenuPickerStyle())
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3)
                    .cornerRadius(10)
                }
                
                // Display loading indicator if needed
                                    if viewModel.isLoading {
                                        ProgressView()
                                    }
            
                // Dynamic Content
                if selectedTab == "Live" {
                    if !selectedSpot.isEmpty {
                        LiveSpotView(spotId: dynamicSpotId)
                                    .id(dynamicSpotId)
                                            } else {
                                                Text("Select a spot to view conditions")
                                                    .padding()
                                            }
                } else {
                    if !selectedSpot.isEmpty {
                        SpotForecastView(spotId: dynamicSpotId).id(dynamicSpotId)
                    } else {
                        Text("Select a spot to view conditions")
                            .padding()
                    }
                }
                
            }
        }
            .onAppear {
                viewModel.setDataStore(dataStore)

                            // Load spots when the view appears
                            Task {
                                await viewModel.loadSpots()
                                if !viewModel.spotNames.isEmpty {
                                    selectedSpot = viewModel.spotNames[0]
                                }
                            }
                        }
        }
    }

#Preview {SpotsView()}
