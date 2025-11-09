# Spot Reports Scrolling Implementation

## Overview

This document describes the implementation of the feature to scroll through all reports for a given surf spot.

## Implementation Date

November 9, 2025

## Features Implemented

### Backend Changes

#### 1. New Service Method (`report_service.go`)

- **`GetSpotSurfReports`**: New method to retrieve all surf reports for a spot with pagination support
  - Parameters:
    - `countryName`, `regionName`, `spotName`: Spot location identifiers
    - `limit`: Maximum number of reports to return (0 for all)
    - `lastEvaluatedKey`: For pagination (currently simplified)
  - Returns: Array of reports with pagination metadata
  - Legacy method `GetTodaysSurfReports` now wraps this with limit of 1

#### 2. New Controller Endpoint (`report_controller.go`)

- **`GetAllSpotSurfReports`**: New controller endpoint at `/api/getAllSpotReports`
  - Query Parameters:
    - `country` (required): Country name
    - `region` (required): Region name
    - `spot` (required): Spot name
    - `limit` (optional): Number of reports to fetch (default: 50)
  - Returns: JSON array of surf reports
  - Authentication: Required (uses existing auth middleware)

#### 3. New Route (`router.go`)

- Added route: `authorized.GET("/getAllSpotReports", controller.GetAllSpotSurfReports)`
- Placed in the authorized routes section (requires authentication)

### iOS App Changes

#### 1. New Endpoint Constant (`Endpoints.swift`)

- Added: `static let allSpotReports = "/api/getAllSpotReports"`

#### 2. New API Client Method (`ApiClient.swift`)

- **`fetchAllSpotReports`**: New method to fetch all reports for a spot
  - Parameters:
    - `country`: Country name
    - `region`: Region name
    - `spot`: Spot name
    - `limit`: Number of reports to fetch (default: 50)
  - Returns: Array of `SurfReportResponse` objects
  - Includes logging for debugging

#### 3. New View (`SpotReportsListView.swift`)

- Full-screen scrollable view displaying all reports for a spot
- Features:
  - Pull-to-refresh support
  - Lazy loading with "Load More" button
  - Image and video support for each report
  - Empty state when no reports exist
  - Error handling with user-friendly messages
  - Navigation bar with "Done" button
- Report cards show:
  - Reporter name and formatted timestamp
  - Media (image or video with thumbnail)
  - All surf conditions (size, quality, wind, consistency, messiness)
  - Video playback via presigned URLs

#### 4. New ViewModel (`SpotReportsListViewModel.swift`)

- Manages state for the reports list view
- Features:
  - Pagination with configurable page size (20 reports per page)
  - Initial load and "load more" functionality
  - Pull-to-refresh support
  - Error handling with user-friendly messages
  - Automatic spot ID parsing (country/region/spot)
- Published properties:
  - `reports`: Array of loaded reports
  - `isLoading`: Loading state for initial load
  - `isLoadingMore`: Loading state for pagination
  - `hasMore`: Whether more reports are available
  - `errorMessage`: User-friendly error messages

#### 5. Updated LiveSpotView

- Added "View All" button next to "Recent Report" title
- Button opens `SpotReportsListView` in a sheet
- State variable: `@State private var showingAllReports = false`

## API Endpoint Documentation

### GET /api/getAllSpotReports

Retrieves all surf reports for a specific spot with optional pagination.

**Authentication**: Required

**Query Parameters**:

- `country` (string, required): Country name (e.g., "Ireland")
- `region` (string, required): Region name (e.g., "Donegal")
- `spot` (string, required): Spot name (e.g., "Tullan Strand")
- `limit` (integer, optional): Maximum number of reports to return (default: 50, 0 for all)

**Success Response (200 OK)**:

```json
[
  {
    "country_region_spot": "Ireland_Donegal_Tullan Strand",
    "dateReported": "2025-11-09 14:30:00_user-uuid",
    "SurfSize": "head-high",
    "Quality": "excellent",
    "WindAmount": "light",
    "WindDirection": "offshore",
    "Consistency": "consistent",
    "Messiness": "clean",
    "Reporter": "John Doe",
    "Time": "2025-11-09 14:30:00",
    "ImageKey": "surf-reports/Ireland_Donegal_Tullan_Strand/2025-11-09T14:30:00Z_uuid.jpg",
    "VideoKey": "",
    "MediaType": "image",
    "IOSValidated": true,
    "reportedBy": "user-uuid"
  }
]
```

**Error Responses**:

- `400 Bad Request`: Missing required parameters or invalid limit
- `401 Unauthorized`: Authentication token missing or invalid
- `500 Internal Server Error`: Database query failed

## User Experience Flow

1. **User navigates to a spot's Live view**

   - Sees most recent report in the "Recent Report" section
   - Notices "View All" button next to the section title

2. **User taps "View All"**

   - Full-screen sheet appears showing `SpotReportsListView`
   - Initial 20 reports load automatically
   - Loading indicator shown during fetch

3. **User scrolls through reports**

   - Each report shows complete information in a card format
   - Images load on demand as cards appear
   - Video reports show thumbnail with play button

4. **User reaches bottom**

   - If more reports exist, "Load More" button appears
   - Tapping loads next 20 reports
   - Process continues until all reports are loaded

5. **User can refresh**

   - Pull down to refresh reloads all reports from start
   - Useful for checking for new reports

6. **User taps image/video**

   - Images display in full size within the card
   - Videos play in full-screen video player via presigned URLs
   - Videos generate temporary view URLs on-demand

7. **User closes view**
   - Taps "Done" button to dismiss sheet
   - Returns to Live view

## Technical Details

### Pagination Strategy

- Simple page-based pagination for initial implementation
- Frontend fetches all reports up to current page on each "Load More"
- Default page size: 20 reports
- Backend supports pagination tokens (simplified for now)

### Performance Considerations

- Lazy loading of images (only loaded when report card appears)
- Videos use presigned URLs (no data stored in memory)
- Reports fetched in batches to reduce initial load time
- Pull-to-refresh clears and reloads all reports

### Error Handling

- Network errors show user-friendly messages
- Failed image loads show placeholder
- Video playback errors logged to console
- Automatic retry not implemented (user must manually refresh)

### Security

- All endpoints require authentication
- User email removed from report responses for privacy
- User UUID (reportedBy) included for ownership verification
- Video presigned URLs have 1-hour expiration
- Image keys validated before access

## Testing Checklist

### Backend Testing

- [ ] `/api/getAllSpotReports` returns reports for valid spot
- [ ] Endpoint respects limit parameter
- [ ] Endpoint returns 400 for missing parameters
- [ ] Endpoint returns 401 for unauthenticated requests
- [ ] Reports sorted by most recent first
- [ ] Pagination works correctly
- [ ] Legacy endpoint `/api/getTodaySpotReports` still works

### iOS App Testing

- [ ] "View All" button appears in Live view
- [ ] Tapping button opens reports list
- [ ] Reports load and display correctly
- [ ] Images load on demand
- [ ] Videos play via presigned URLs
- [ ] "Load More" button appears when more reports exist
- [ ] Pull-to-refresh reloads reports
- [ ] Empty state shows when no reports exist
- [ ] Error messages display for network failures
- [ ] "Done" button dismisses view
- [ ] Report timestamps format correctly
- [ ] Surf conditions display in readable format

### Integration Testing

- [ ] Multiple users can view same spot's reports
- [ ] New reports appear after refresh
- [ ] Reports from different dates show correctly
- [ ] Media (images/videos) load for all report types
- [ ] Legacy reports (without video) display correctly
- [ ] iOS-validated reports display correctly

## Future Enhancements

### Potential Improvements

1. **Advanced Pagination**

   - Implement proper pagination tokens
   - Infinite scroll instead of "Load More" button
   - Cache pagination state

2. **Filtering & Sorting**

   - Filter by date range
   - Filter by quality/conditions
   - Sort by different criteria (date, quality, etc.)

3. **Report Actions**

   - Like/react to reports
   - Comment on reports
   - Share reports
   - Report inappropriate content

4. **Performance**

   - Cache reports locally
   - Prefetch next page of reports
   - Image thumbnail generation
   - Video thumbnail generation

5. **Search**

   - Search reports by reporter
   - Search by conditions
   - Full-text search in comments (future feature)

6. **Analytics**
   - Track which reports users view most
   - Popular spots/times
   - User engagement metrics

## Files Modified/Created

### Backend

- `treblesurf-backend/internal/service/report_service.go` (modified)
- `treblesurf-backend/internal/controller/report_controller.go` (modified)
- `treblesurf-backend/internal/api/router.go` (modified)

### iOS App

- `TrebleSurf/Networking/Endpoints.swift` (modified)
- `TrebleSurf/Networking/ApiClient.swift` (modified)
- `TrebleSurf/Features/SurfReport/SpotReportsListView.swift` (created)
- `TrebleSurf/ViewModels/SpotReportsListViewModel.swift` (created)
- `TrebleSurf/Features/Spots/LiveSpot/LiveSpotView.swift` (modified)

### Documentation

- `SPOT_REPORTS_SCROLLING_IMPLEMENTATION.md` (this file, created)

## Troubleshooting

### Issue: Reports not loading

- Check network connectivity
- Verify authentication token is valid
- Check backend logs for errors
- Verify spot ID format is correct (Country#Region#Spot)

### Issue: Images not displaying

- Check image keys are valid
- Verify S3 bucket permissions
- Check presigned URL generation
- Verify image data is base64 encoded correctly

### Issue: Videos not playing

- Check video keys are valid
- Verify presigned URL generation works
- Check video URL expiration (1 hour)
- Verify video format is supported (MP4, MOV)

### Issue: "Load More" button not appearing

- Check if there are actually more reports
- Verify pagination logic in ViewModel
- Check backend pagination response

### Issue: Performance slow with many reports

- Check if pagination is working correctly
- Verify lazy loading of images
- Consider reducing page size if needed
- Check for memory leaks in video playback

## Notes

- This implementation provides a solid foundation for viewing all spot reports
- Pagination is simplified and can be enhanced for better performance
- All existing report submission functionality remains unchanged
- The feature integrates seamlessly with existing spot views
- No breaking changes to existing APIs or views
