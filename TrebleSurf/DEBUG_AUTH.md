# Authentication Debug Guide

## Issues Identified

Based on the logs, the main problems are:

1. **Session validation failing** - Backend returning HTML instead of JSON
2. **Failed to extract session ID** - Cookie parsing not working properly
3. **Wrong endpoints** - App calling `/auth/validate` instead of `/api/auth/validate`

## Fixes Applied

### 1. Updated Endpoints
- Changed all authentication endpoints from `/auth/*` to `/api/auth/*`
- Updated `Endpoints.swift` to use correct API paths

### 2. Improved Cookie Extraction
- Enhanced `extractSessionId` method to handle complex cookie formats
- Added fallback parsing for different cookie structures
- Better error logging for debugging

### 3. Added HTML Response Detection
- Added checks for `Content-Type: text/html` headers
- Added checks for `<!DOCTYPE html>` in response body
- Better error messages when backend returns HTML instead of JSON

### 4. Enhanced Error Handling
- Added `Accept: application/json` headers to requests
- Better error messages for debugging
- Added endpoint accessibility testing

## Debugging Steps

### 1. Check Current Endpoint Configuration
```swift
AuthManager.shared.debugEndpointConfiguration()
```

### 2. Check Authentication State
```swift
AuthManager.shared.printAuthState()
```

### 3. Test Endpoint Accessibility
The debug method will test all authentication endpoints and report:
- ✅ Working endpoints (return JSON)
- ⚠️ Endpoints returning HTML (wrong configuration)
- ❌ Unreachable endpoints (server issues)

## Expected Behavior

After the fixes:

1. **Session validation** should call `/api/auth/validate` and receive JSON
2. **Cookie extraction** should properly parse session_id from Set-Cookie headers
3. **Error messages** should be more helpful and specific
4. **HTML responses** should be detected and reported as configuration errors

## Common Issues

### Backend Returns HTML Instead of JSON
- **Cause**: Wrong endpoint path or backend routing issue
- **Solution**: Ensure endpoints use `/api/auth/*` paths
- **Check**: Use `debugEndpointConfiguration()` to verify

### Session ID Not Extracted
- **Cause**: Complex cookie format or parsing logic issue
- **Solution**: Enhanced cookie parsing with fallback methods
- **Check**: Look for "Session ID extracted" in logs

### Authentication Failing
- **Cause**: Session validation endpoint not accessible
- **Solution**: Verify backend has `/api/auth/validate` endpoint
- **Check**: Use endpoint accessibility testing

## Testing

1. **Clean Build**: Clean and rebuild the project
2. **Test Authentication**: Try signing in again
3. **Check Logs**: Look for improved error messages
4. **Verify Endpoints**: Use debug methods to check configuration

## Next Steps

If issues persist:

1. Verify backend has the correct API endpoints
2. Check backend routing configuration
3. Ensure backend returns proper JSON responses
4. Test with Postman/curl to verify API behavior
