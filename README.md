# TrebleSurf

A comprehensive iOS surf forecasting and reporting application built with SwiftUI, featuring real-time surf conditions, AI-powered swell predictions, and community-driven surf reports.

## 🌊 Overview

TrebleSurf is a modern iOS application designed for surfers to access accurate surf forecasts, view real-time conditions, and share surf reports with the community. The app combines traditional meteorological data with cutting-edge AI predictions to provide the most comprehensive surf forecasting experience.

## ✨ Key Features

### 🏠 Home Dashboard

- **Current Conditions**: Real-time surf conditions for popular spots
- **Recent Reports**: Community-submitted surf reports with photos and videos
- **Weather Buoys**: Live data from meteorological buoys
- **Quick Access**: Fast navigation to all app features

### 🗺️ Interactive Map

- **Spot Discovery**: Explore surf spots with detailed information
- **Live Conditions**: Real-time wave height, wind, and temperature data
- **AI Predictions**: Purple indicators for AI-powered swell predictions
- **Traditional Forecasts**: Blue indicators for standard meteorological forecasts

### 📊 Surf Spots

- **Detailed Spot Information**: Comprehensive data for each surf location
- **Dual Forecast System**: Toggle between traditional and AI predictions
- **Live Conditions**: Real-time data from weather stations and buoys
- **Historical Data**: Access to past conditions and trends

### 🌊 Weather Buoys

- **Real-time Data**: Live wave height, period, direction, and water temperature
- **Interactive Charts**: Visual representation of buoy data over time
- **Multiple Locations**: Data from various meteorological stations
- **Detailed Analytics**: Comprehensive buoy information and trends

### 📱 Surf Reports

- **Community Reports**: Submit and view surf reports from fellow surfers
- **Photo & Video Support**: Upload images and videos with reports
- **iOS ML Validation**: Client-side image validation using Vision framework
- **Detailed Conditions**: Report wave size, quality, wind, and consistency

### ⚙️ Settings & Customization

- **Dark Mode Support**: Light, dark, and system theme options
- **AI Prediction Toggle**: Enable/disable AI-powered swell predictions
- **User Preferences**: Customizable app experience
- **Account Management**: Google Sign-In integration

## 🛠️ Technical Stack

### Frontend (iOS)

- **SwiftUI**: Modern declarative UI framework
- **iOS 17+**: Latest iOS features and capabilities
- **Google Sign-In**: Authentication integration
- **Vision Framework**: Machine learning for image validation
- **AVKit**: Video playback and processing
- **Charts**: Data visualization for buoy information

### Backend Integration

- **RESTful API**: Comprehensive backend API integration
- **Session-based Authentication**: Secure user authentication
- **S3 Integration**: Cloud storage for images and videos
- **WebSocket Support**: Real-time data updates
- **CSRF Protection**: Security measures for API requests

### Key Dependencies

- **GoogleSignIn**: Google authentication
- **GoogleSignInSwift**: Swift wrapper for Google Sign-In
- **Swift Package Manager**: Dependency management

## 🏗️ Architecture

### MVVM Pattern

The app follows the Model-View-ViewModel (MVVM) architecture pattern:

- **Models**: Data structures and API response models
- **Views**: SwiftUI views and UI components
- **ViewModels**: Business logic and data management
- **Services**: Network services and data processing
- **Stores**: Centralized state management

### Core Components

#### Services

- **AuthManager**: User authentication and session management
- **ApiClient**: HTTP client for backend communication
- **SwellPredictionService**: AI prediction data management
- **ImageCacheService**: Image caching and optimization
- **BuoyCacheService**: Weather buoy data caching

#### Stores

- **DataStore**: Centralized data management
- **SettingsStore**: User preferences and theme management
- **LocationStore**: Location services and permissions

#### Utilities

- **NetworkManager**: Network connectivity monitoring
- **APIErrorHandler**: Centralized error handling
- **Extensions**: Swift extensions for enhanced functionality

## 📱 App Structure

```
TrebleSurf/
├── App/                    # App configuration and lifecycle
├── Core/                   # Core layout and navigation
├── Features/               # Feature-specific views and components
│   ├── Home/              # Home dashboard
│   ├── Map/               # Interactive map view
│   ├── Spots/             # Surf spots management
│   ├── Buoys/             # Weather buoy data
│   ├── SurfReport/        # Surf reporting system
│   └── Settings/          # App settings and preferences
├── Models/                # Data models and API responses
├── Networking/            # API client and endpoints
├── Services/              # Business logic services
├── Stores/                # State management
├── UI/                    # Reusable UI components
├── Utilities/             # Helper functions and extensions
└── ViewModels/            # View models for MVVM pattern
```

## 🚀 Getting Started

### Prerequisites

- **Xcode 15+**: Latest Xcode version
- **iOS 17+**: Target iOS version
- **macOS**: Development environment
- **Apple Developer Account**: For device testing and App Store deployment

### Installation

1. **Clone the repository**

   ```bash
   git clone https://github.com/yourusername/TrebleSurf.git
   cd TrebleSurf
   ```

2. **Open in Xcode**

   ```bash
   open TrebleSurf.xcodeproj
   ```

3. **Configure Google Sign-In**

   - Add your Google Sign-In configuration to `Info.plist`
   - Update the Google Sign-In client ID

4. **Build and Run**
   - Select your target device or simulator
   - Build and run the project (⌘+R)

### Development Setup

The app automatically detects the development environment:

- **Simulator**: Uses `http://localhost:8080` for development
- **Physical Device**: Uses `https://treblesurf.com` for production

For local development:

1. Start your backend server on port 8080
2. Run the app in the iOS Simulator
3. The app will automatically connect to your local server

## 🔧 Configuration

### Environment Variables

The app uses different configurations based on the build environment:

- **Development**: Local server integration with mock data fallbacks
- **Production**: Full backend integration with live data

### API Endpoints

Key API endpoints include:

- Authentication: `/api/auth/*`
- Surf Spots: `/api/spots`, `/api/forecast`
- Buoys: `/api/regionBuoys`, `/api/getMultipleBuoyData`
- Surf Reports: `/api/getTodaySpotReports`, `/api/submitSurfReport`
- Swell Predictions: `/api/swellPrediction`

## 🎨 UI/UX Features

### Liquid Glass Design

- **Ultra-thin Material**: Modern glassmorphism effects
- **Transparent Elements**: Sophisticated visual hierarchy
- **Smooth Animations**: Fluid transitions and interactions

### Dark Mode Support

- **Three Theme Modes**: Light, Dark, and System
- **Persistent Settings**: Theme preferences saved across sessions
- **Smooth Transitions**: Animated theme switching

### Responsive Design

- **Adaptive Layout**: Optimized for all iOS device sizes
- **Safe Area Support**: Proper handling of device notches and home indicators
- **Accessibility**: VoiceOver and accessibility features

## 📊 Data Management

### Caching Strategy

- **Image Caching**: Efficient image storage and retrieval
- **Video Caching**: Local video storage with automatic cleanup
- **API Response Caching**: Reduced network requests
- **Offline Support**: Graceful degradation when offline

### Real-time Updates

- **Pull-to-Refresh**: Manual data refresh
- **Automatic Updates**: Background data synchronization
- **WebSocket Integration**: Real-time data streaming

## 🔐 Security Features

### Authentication

- **Google Sign-In**: Secure OAuth integration
- **Session Management**: Secure session handling
- **Keychain Storage**: Secure credential storage
- **CSRF Protection**: Cross-site request forgery prevention

### Data Protection

- **Image Validation**: Client-side ML validation
- **Secure Uploads**: Presigned URL uploads to S3
- **Data Encryption**: Secure data transmission

## 🧪 Testing

### Test Structure

- **Unit Tests**: Core functionality testing
- **UI Tests**: User interface testing
- **Integration Tests**: API integration testing

### Running Tests

```bash
# Run all tests
⌘+U

# Run specific test suite
# Use Xcode test navigator
```

## 📈 Performance Optimization

### Image Optimization

- **Lazy Loading**: Images loaded on demand
- **Compression**: Optimized image sizes
- **Caching**: Efficient image storage

### Memory Management

- **Automatic Cleanup**: Old cached data removal
- **Efficient Loading**: Minimal memory footprint
- **Background Processing**: Non-blocking operations

## 🚀 Deployment

### App Store Deployment

1. **Archive Build**: Create release build in Xcode
2. **Upload to App Store Connect**: Use Xcode or Application Loader
3. **App Store Review**: Submit for Apple review
4. **Release**: Publish to App Store

### Version Management

- **Semantic Versioning**: Clear version numbering
- **Release Notes**: Detailed changelog
- **Feature Flags**: Gradual feature rollouts

## 🤝 Contributing

### Development Workflow

1. **Fork Repository**: Create your own fork
2. **Create Branch**: Feature or bugfix branch
3. **Make Changes**: Implement your changes
4. **Test Thoroughly**: Ensure all tests pass
5. **Submit PR**: Create pull request with description

### Code Standards

- **Swift Style Guide**: Follow Apple's Swift style guide
- **Documentation**: Document public APIs
- **Testing**: Include tests for new features
- **Code Review**: All changes require review

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- **Surf Community**: For feedback and feature requests
- **Open Source Libraries**: For the amazing tools and frameworks
- **Apple**: For the excellent development tools and platforms
- **Contributors**: Everyone who has contributed to the project

## 📞 Support

### Getting Help

- **Issues**: Report bugs and request features on GitHub
- **Discussions**: Community discussions and Q&A
- **Documentation**: Comprehensive documentation in the project

### Contact

- **Email**: support@treblesurf.com
- **Website**: https://treblesurf.com
- **Social Media**: Follow us for updates and community

---

**Made with ❤️ for the surf community**

_TrebleSurf - Your ultimate surf forecasting companion_
