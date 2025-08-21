# iOS Authentication Implementation

## Overview

This document describes the iOS authentication implementation for TrebleSurf, which integrates with the Go backend's session-based authentication system.

## Architecture

### Session-Based Authentication

- **No JWT tokens**: The app uses session-based authentication instead of JWT tokens
- **Session cookies**: Authentication is maintained via session cookies sent with each request
- **CSRF protection**: All POST requests include CSRF tokens for security

### Key Components

#### 1. AuthManager (`Services/Auth/AuthManager.swift`)

- Manages user authentication state
- Handles Google Sign-In integration
- Stores session ID and CSRF token in Keychain
- Provides session validation and logout functionality

#### 2. AuthModels (`Services/Auth/AuthModels.swift`)

- `User`: Represents authenticated user data
- `AuthResponse`: Response from Google authentication
- `ValidateResponse`: Response from session validation
- `SessionInfo`: Information about user sessions

#### 3. APIClient (`Networking/ApiClient.swift`)

- Handles all HTTP requests to the backend
- Automatically includes session cookies and CSRF tokens
- Provides methods for authenticated and unauthenticated requests

#### 4. SignInView (`UI/Auth/SignInView.swift`)

- Google Sign-In interface for physical devices
- Development mode sign-in for iOS Simulator
- Handles authentication flow and error states

## Authentication Flow

### 1. Google Sign-In (Physical Device)

```
User taps Google Sign-In → Google OAuth → Backend validation → Session creation → App authenticated
```

### 2. Development Mode (Simulator)

```
User enters email → Development session created → App authenticated (bypasses Google OAuth)
```

### 3. Session Management

```
App launch → Check existing session → Validate with backend → Maintain or redirect to sign-in
```

## Backend Integration

### Required Endpoints

- `POST /api/auth/google` - Google OAuth authentication
- `GET /api/auth/validate` - Session validation
- `POST /api/auth/logout` - User logout
- `GET /api/auth/sessions` - List user sessions
- `DELETE /api/auth/sessions/{sessionId}` - Terminate specific session

### Request Headers

- **Session Cookie**: `Cookie: session_id={sessionId}`
- **CSRF Token**: `X-CSRF-Token: {csrfToken}` (for POST/PUT/DELETE requests)

## Security Features

### CSRF Protection

- CSRF tokens are generated for each session
- Required for all state-changing requests (POST, PUT, DELETE)
- Tokens are refreshed periodically

### Session Security

- Sessions expire after 30 days
- TTL enabled on DynamoDB for automatic cleanup
- User agent and IP tracking for session monitoring

### Keychain Storage

- Sensitive data (session ID, CSRF token) stored in iOS Keychain
- Secure storage that persists across app launches
- Automatically cleared on logout

## Development & Testing

### Simulator Support

- Google Sign-In disabled in iOS Simulator
- Development mode allows testing without Google OAuth
- Mock user data for development purposes

### Debug Features

- `AuthManager.printAuthState()` for debugging
- Comprehensive logging throughout authentication flow
- Error handling with user-friendly messages

## Usage Examples

### Making Authenticated Requests

```swift
// Simple GET request
APIClient.shared.makeAuthenticatedRequest(to: "/api/spots") { (result: Result<[Spot], Error>) in
    switch result {
    case .success(let spots):
        // Handle spots data
    case .failure(let error):
        // Handle error
    }
}

// POST request with CSRF protection
let body = try JSONEncoder().encode(surfReport)
APIClient.shared.postRequest(to: "/api/surf-reports", body: body) { (result: Result<SurfReport, Error>) in
    // Handle response
}
```

### Checking Authentication Status

```swift
if AuthManager.shared.isAuthenticated {
    // User is logged in
    let user = AuthManager.shared.currentUser
} else {
    // User needs to sign in
}
```

### Logging Out

```swift
AuthManager.shared.logout { success in
    if success {
        // User logged out, redirect to sign-in
    }
}
```

## Configuration

### Environment Variables

- **Development**: `http://localhost:8080`
- **Production**: `https://treblesurf.com`

### Google Sign-In

- Configured in `Info.plist`
- Client IDs for both web and iOS
- URL scheme handling for OAuth callback

## Troubleshooting

### Common Issues

1. **Session Expired**

   - App automatically redirects to sign-in
   - Check backend session TTL settings

2. **CSRF Token Mismatch**

   - Tokens are automatically refreshed
   - Ensure proper header inclusion

3. **Simulator Authentication**
   - Use development mode sign-in
   - Check console for authentication state

### Debug Commands

```swift
// Print current authentication state
AuthManager.shared.printAuthState()

// Validate session manually
AuthManager.shared.validateSession { success, user in
    print("Session valid: \(success)")
}
```

## Future Enhancements

- Biometric authentication support
- Offline authentication caching
- Multi-factor authentication
- Session analytics and monitoring
- Automatic session refresh
