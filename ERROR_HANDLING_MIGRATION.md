# Error Handling System - Migration Guide

## Overview

This guide documents the new centralized error handling system for TrebleSurf and provides migration instructions for updating existing code.

## New Architecture

### 1. Unified Error Type (`TrebleSurfError`)

**Location:** `TrebleSurf/Utilities/Errors/TrebleSurfError.swift`

All errors in the app now use a single, comprehensive error enum:

```swift
enum TrebleSurfError: TrebleSurfErrorProtocol {
    // Network Errors
    case noConnection
    case timeout
    case serverUnavailable

    // Authentication Errors
    case notAuthenticated
    case sessionExpired

    // API Errors
    case apiError(error: String, message: String, help: String)
    case decodingFailed(Error)

    // Validation Errors
    case missingRequiredField(field: String)
    case invalidFieldValue(field: String, reason: String)

    // Media Errors
    case imageNotSurfRelated
    case imageUploadFailed(reason: String)

    // ... and more
}
```

**Key Features:**

- Error codes for tracking (`NET_001`, `AUTH_002`, etc.)
- Category classification
- User-friendly messages
- Technical details for logging
- Recovery suggestions
- Automatic conversion from standard errors

### 2. Logging Infrastructure (`ErrorLogger`)

**Location:** `TrebleSurf/Utilities/Errors/ErrorLogger.swift`

Replaces all `print()` statements with structured logging:

```swift
logger.info("Loading data...", category: .api)
logger.warning("Cache miss", category: .cache)
logger.error("Request failed", category: .network)
logger.logError(trebleError, context: "Fetch spots")
```

**Features:**

- Log levels (debug, info, warning, error, critical)
- Category-based filtering
- OSLog integration
- Timestamp formatting
- Context tracking

### 3. Error Handler Service (`ErrorHandler`)

**Location:** `TrebleSurf/Utilities/Errors/ErrorHandler.swift`

Protocol-based error processing (no singletons):

```swift
let errorHandler = AppDependencies.shared.errorHandler
let trebleError = errorHandler.handle(error, context: "API call")
let presentation = errorHandler.handleForPresentation(error, context: "Submit form")
```

### 4. Error Presentation Layer

**Location:** `TrebleSurf/UI/Components/ErrorViews.swift`

SwiftUI components for displaying errors:

- `ErrorAlertModifier` - Alert with retry support
- `InlineErrorView` - Inline error messages
- `FieldErrorView` - Form field errors
- `ErrorBannerView` - Dismissible error banner
- `ErrorStateView` - Full-screen error state

### 5. Base ViewModel

**Location:** `TrebleSurf/ViewModels/BaseViewModel.swift`

Standard error handling for all ViewModels:

```swift
@MainActor
class MyViewModel: BaseViewModel {
    func loadData() {
        executeTask(context: "Load data") {
            // Your async code here
            // Errors are automatically handled
        }
    }
}
```

## Migration Instructions

### For ViewModels

#### Before:

```swift
@MainActor
class MyViewModel: ObservableObject {
    @Published var isLoading = false
    @Published var errorMessage: String?

    func loadData() {
        isLoading = true

        Task {
            do {
                // Fetch data
                print("Loading data...")
            } catch {
                print("Error: \(error)")
                errorMessage = error.localizedDescription
            }
            isLoading = false
        }
    }
}
```

#### After:

```swift
@MainActor
class MyViewModel: BaseViewModel {
    @Published var data: [MyData] = []

    func loadData() {
        executeTask(context: "Load data") {
            logger.info("Loading data...", category: .general)
            // Fetch data
            // Errors automatically handled and presented
        }
    }
}
```

### For API Calls

#### Before:

```swift
APIClient.shared.fetchSpots { result in
    switch result {
    case .success(let spots):
        print("✅ Loaded \(spots.count) spots")
        self.spots = spots
    case .failure(let error):
        print("❌ Error: \(error)")
        self.errorMessage = error.localizedDescription
    }
}
```

#### After:

```swift
executeTask(context: "Fetch spots") {
    let spots = try await withCheckedThrowingContinuation { continuation in
        APIClient.shared.fetchSpots { result in
            continuation.resume(with: result)
        }
    }

    self.spots = spots
    logger.info("Loaded \(spots.count) spots", category: .api)
}
```

### For Views

#### Before:

```swift
struct MyView: View {
    @StateObject private var viewModel = MyViewModel()

    var body: some View {
        VStack {
            // Content
        }
        .alert(item: $viewModel.errorMessage) { message in
            Alert(title: Text("Error"), message: Text(message))
        }
    }
}
```

#### After:

```swift
struct MyView: View {
    @StateObject private var viewModel = MyViewModel()

    var body: some View {
        VStack {
            // Content
        }
        .errorAlert(error: $viewModel.errorPresentation, onRetry: {
            viewModel.loadData()
        })
    }
}
```

### For Form Validation

#### Before:

```swift
@Published var fieldErrors: [String: String] = [:]

func validateForm() {
    fieldErrors.removeAll()

    if email.isEmpty {
        fieldErrors["email"] = "Email is required"
    }

    if password.isEmpty {
        fieldErrors["password"] = "Password is required"
    }
}
```

#### After:

```swift
func validateForm() throws {
    var errors: [String: String] = [:]

    if email.isEmpty {
        errors["email"] = "Email is required"
    }

    if password.isEmpty {
        errors["password"] = "Password is required"
    }

    if !errors.isEmpty {
        throw TrebleSurfError.validationFailed(fields: errors)
    }
}

// Usage
executeTask(context: "Submit form") {
    try validateForm()
    // Submit form
}
```

## Best Practices

### 1. Always Provide Context

```swift
// Good
executeTask(context: "Fetch user profile") { ... }

// Bad
executeTask { ... }
```

### 2. Use Appropriate Log Levels

```swift
logger.debug("Cache hit", category: .cache)  // Development info
logger.info("User logged in", category: .authentication)  // Important events
logger.warning("Slow response", category: .network)  // Potential issues
logger.error("Request failed", category: .api)  // Actual errors
logger.critical("Database corrupted", category: .dataProcessing)  // Critical failures
```

### 3. Use Specific Error Types

```swift
// Good
throw TrebleSurfError.missingRequiredField(field: "email")

// Less good
throw TrebleSurfError.unknown(error)
```

### 4. Handle Field Errors

```swift
TextField("Email", text: $email)
    .border(viewModel.hasFieldError("email") ? Color.red : Color.gray)

if let error = viewModel.fieldError(for: "email") {
    FieldErrorView(message: error)
}
```

### 5. Provide Retry Functionality

```swift
.errorAlert(error: $viewModel.errorPresentation, onRetry: {
    viewModel.retry { await loadData() }
})
```

## Deprecated Patterns

### ❌ Do NOT Use:

1. **Print statements for logging**

   ```swift
   print("Error: \(error)")  // ❌
   logger.error("Error occurred", category: .general)  // ✅
   ```

2. **Raw error strings**

   ```swift
   errorMessage = "Failed to load"  // ❌
   throw TrebleSurfError.apiError(...)  // ✅
   ```

3. **Singleton error handler**

   ```swift
   APIErrorHandler.shared.handleError()  // ❌
   errorHandler.handle(error)  // ✅
   ```

4. **Generic error messages**
   ```swift
   Alert(title: Text("Error"))  // ❌
   .errorAlert(error: $errorPresentation)  // ✅
   ```

## Testing

The new system includes mock implementations:

```swift
let mockLogger = MockErrorLogger()
let mockErrorHandler = ErrorHandler(logger: mockLogger)
let viewModel = MyViewModel(errorHandler: mockErrorHandler, logger: mockLogger)

// Test error handling
await viewModel.loadData()
XCTAssertEqual(mockLogger.errorEntries.count, 1)
```

## Migration Checklist

- [ ] Replace `print()` with `logger` calls
- [ ] Extend ViewModels from `BaseViewModel`
- [ ] Use `executeTask()` for async operations
- [ ] Replace custom error types with `TrebleSurfError`
- [ ] Update views to use `.errorAlert()` modifier
- [ ] Remove `APIErrorHandler.shared` usages
- [ ] Update form validation to use error types
- [ ] Add retry handlers where appropriate
- [ ] Test error presentation in UI

## Files to Update

### Priority 1 (Core)

- [x] TrebleSurfError.swift - Created new unified error system
- [x] ErrorLogger.swift - Created logging infrastructure
- [x] ErrorHandler.swift - Created error handling service
- [x] ErrorViews.swift - Created UI components
- [x] BaseViewModel.swift - Created base ViewModel
- [x] AppDependencies.swift - Added error handling infrastructure
- [x] MapViewModel.swift - Example migration (COMPLETED)

### Priority 2 (ViewModels)

- [ ] HomeViewModel.swift
- [ ] BuoysViewModel.swift
- [ ] SpotsViewModel.swift
- [ ] SpotForecastViewModel.swift
- [ ] LiveSpotViewModel.swift
- [ ] QuickPhotoReportViewModel.swift
- [ ] SurfReportSubmissionViewModel.swift
- [ ] SurfReportViewModel.swift

### Priority 3 (Services)

- [ ] APIClient.swift - Add proper logging throughout
- [ ] WeatherBuoyService.swift
- [ ] SurfReportService.swift
- [ ] DataStore.swift
- [ ] BuoyCacheService.swift

### Priority 4 (Cleanup)

- [ ] Delete old TrebleSurfError.swift (if different)
- [ ] Delete APIErrorHandler.swift
- [ ] Remove print statements across codebase
- [ ] Update EnhancedErrorAlert.swift to use new system

## Performance Considerations

1. **Logging in Production:**

   - Debug logs are disabled in production
   - Only info+ logs are sent to OSLog
   - No performance impact from disabled logs

2. **Error Conversion:**

   - Error conversion is lightweight
   - Minimal allocation overhead
   - Cached error descriptions

3. **Presentation:**
   - SwiftUI modifiers are efficient
   - Lazy error presentation creation
   - No blocking operations

## Support

For questions or issues with migration:

1. Check this guide first
2. Review the example migration in `MapViewModel.swift`
3. Look at `BaseViewModel.swift` for standard patterns
4. Refer to inline documentation in error handling files

## Success Metrics

After migration, the codebase should have:

- ✅ Zero print statements
- ✅ Consistent error handling across all ViewModels
- ✅ Unified error presentation in UI
- ✅ Proper logging with categories
- ✅ Testable error handling
- ✅ No singleton error handlers
- ✅ Clear error recovery paths
