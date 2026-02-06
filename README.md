# TrebleSurf

TrebleSurf is an iOS application for surf forecasting and reporting. It provides real-time conditions, swell predictions, and user-submitted surf reports.

# CI/CD

Connected to Xcode Cloud for CI/CD, auto deploys to testflight on push to main right now.

## Features

- **Conditions**: Real-time data including wave height, wind speed, and water temperature.
- **Forecasting**: Dual-model system using standard meteorological data and AI-based swell predictions.
- **Surf Reports**: Users can upload reports with photos and videos to share current conditions.
- **Weather Buoys**: Direct integration with meteorological buoys for raw marine data.
- **Charts**: Interactive visualization of historical and forecast buoy data.

## Tech Stack

- **Language**: Swift 6
- **UI Framework**: SwiftUI
- **Architecture**: MVVM with Dependency Injection
- **Authentication**: Google Sign-In
- **Networking**: async/await with custom APIClient
- **Validation**: On-device image validation using Vision Framework

## Project Structure

```text
TrebleSurf/
├── App/                    # Entry point and configuration
├── Features/               # UI and logic by feature (Home, Map, Spots, Buoys)
├── Models/                 # Data entities
├── Networking/             # API communication layer
├── Services/               # Core business logic (Auth, SpotService, etc.)
├── Stores/                 # State containers (DataStore, LocationStore)
└── Utilities/              # Configuration and helpers
```

## Requirements

- Xcode 15.0+
- iOS 17.0+

## Local Development

The application is configured to switch endpoints based on the build configuration:

- **Debug (Simulator)**: Connects to `http://localhost:8080` (requires local backend).
- **Release / Device**: Connects to `https://treblesurf.com`.

### Setup

1. Clone the repository.
2. Open `TrebleSurf.xcodeproj`.
3. Verify your `Info.plist` contains the necessary Google Sign-In credentials.
4. Run on a Simulator or Device.

## License

This project is open-source under the **GNU Affero General Public License v3.0 (AGPLv3)**. See the [LICENSE](LICENSE) file for details.
