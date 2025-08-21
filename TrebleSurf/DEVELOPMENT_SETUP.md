# Development Setup Guide

## Environment Configuration

The TrebleSurf app automatically detects whether it's running in development or production mode and adjusts its behavior accordingly.

### Development Mode (Simulator)

- **Base URL**: `http://localhost:8080`
- **Session Validation**: Uses local session data when server is unavailable
- **Mock Data**: Provides mock responses for authenticated endpoints when server is down
- **Error Handling**: Graceful fallbacks for connection issues

### Production Mode (Device)

- **Base URL**: `https://treblesurf.com`
- **Session Validation**: Full server-side validation required
- **Mock Data**: Not available
- **Error Handling**: Standard error handling with user feedback

## Running the Development Server

To test the full functionality in development mode:

1. **Start your local development server** on port 8080
2. **Run the app in the iOS Simulator**
3. **The app will automatically connect to localhost:8080**

## Development Server Not Available

When the development server is not running:

- **Non-authenticated requests** (spots, buoys) will fail gracefully
- **Authenticated requests** (surf reports) will receive mock data
- **Session validation** will use local session data
- **Clear error messages** will indicate the server is unavailable

## Testing Authentication

In development mode without a server:

1. **Sign in with Google** (this will work as it goes to production)
2. **Session validation** will use local data
3. **Surf report requests** will receive mock data
4. **Other features** will show appropriate error messages

## Switching Between Environments

- **Simulator**: Always uses development mode
- **Physical Device**: Always uses production mode
- **No manual configuration required**

## Troubleshooting

### Connection Refused Errors

- Ensure your development server is running on port 8080
- Check that the server is accessible from the simulator
- Verify firewall settings if using a remote development machine

### Session Validation Issues

- Clear app data and re-authenticate
- Check that the development server has proper session handling
- Verify CSRF token and session cookie extraction

### Mock Data Not Working

- Ensure you're running in the simulator
- Check that the endpoint supports mock data
- Verify the data model matches the expected structure

## Adding New Endpoints

When adding new API endpoints:

1. **Update the `Endpoints.swift` file**
2. **Add mock data support** in `provideMockData()` if needed
3. **Update the development mode handler** in `handleDevelopmentMode()`
4. **Test both with and without** the development server

## Best Practices

- **Always test in both environments** before releasing
- **Use meaningful error messages** for development mode
- **Provide fallback behavior** when possible
- **Log important state changes** for debugging
- **Handle network errors gracefully** in all scenarios
