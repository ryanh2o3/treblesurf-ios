
// SpotForecastView.swift
import SwiftUI
import Charts

struct SpotForecastView: View {
    @StateObject private var viewModel = SpotForecastViewModel()
    let spotId: String
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Forecast period selector
                Picker("Forecast Period", selection: $viewModel.selectedPeriod) {
                    Text("Today").tag(ForecastPeriod.today)
                    Text("Tomorrow").tag(ForecastPeriod.tomorrow)
                    Text("Week").tag(ForecastPeriod.week)
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)
                
                // Wave height chart
                VStack(alignment: .leading) {
                    Text("Wave Height").font(.headline)
                    
                    Chart {
                        ForEach(viewModel.forecastData) { point in
                            LineMark(
                                x: .value("Time", point.time),
                                y: .value("Height", point.waveHeight)
                            )
                            .foregroundStyle(Color.blue)
                            
                            PointMark(
                                x: .value("Time", point.time),
                                y: .value("Height", point.waveHeight)
                            )
                            .foregroundStyle(Color.blue)
                        }
                    }
                    .frame(height: 200)
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // Wind forecast
                VStack(alignment: .leading) {
                    Text("Wind").font(.headline)
                    
                    ForEach(viewModel.windForecast) { hourly in
                        HStack {
                            Text(hourly.time)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .rotationEffect(.degrees(Double(hourly.direction)))
                            Text("\(hourly.speed) kts")
                                .frame(width: 60, alignment: .trailing)
                            Text(hourly.description)
                                .frame(width: 80, alignment: .trailing)
                        }
                        .padding(.vertical, 4)
                        Divider()
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 2)
                .padding(.horizontal)
                
                // Tide chart
                TideChartView(tideData: viewModel.tideData)
                    .frame(height: 180)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .shadow(radius: 2)
                    .padding(.horizontal)
            }
            .padding(.bottom, 20)
        }
        .task {
            await viewModel.loadForecastData(spotId: spotId)
        }
    }
}

class SpotForecastViewModel: ObservableObject {
    @Published var selectedPeriod: ForecastPeriod = .today
    @Published var forecastData: [ForecastPoint] = []
    @Published var windForecast: [WindForecast] = []
    @Published var tideData: [TidePoint] = []
    
    func loadForecastData(spotId: String) async {
        // Fetch forecast data for the specified spot
    }
}

enum ForecastPeriod {
    case today, tomorrow, week
}

struct ForecastPoint: Identifiable {
    let id = UUID()
    let time: Date
    let waveHeight: Double
    let period: Double
    let direction: Int
}

struct WindForecast: Identifiable {
    let id: UUID
    let time: String
    let speed: Int
    let direction: Int
    let description: String
}

struct TidePoint: Identifiable {
    let id: UUID
    let time: Date
    let height: Double
    let isHighTide: Bool
}

struct TideChartView: View {
    let tideData: [TidePoint]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Tide").font(.headline)
            
            Chart {
                ForEach(tideData) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Height", point.height)
                    )
                    .foregroundStyle(Color.green)
                    
                    if point.isHighTide {
                        PointMark(
                            x: .value("Time", point.time),
                            y: .value("Height", point.height)
                        )
                        .foregroundStyle(Color.green)
                        .annotation {
                            Text("\(point.height, specifier: "%.1f")m")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    SpotForecastView(spotId: "example_spot_id")
        
}
