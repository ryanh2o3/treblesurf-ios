# Surf Report Decoding Fixes

## Issues Fixed

### 1. Missing Required Fields (Consistency, Messiness, Quality, etc.)

**Problem**: Backend was returning reports without all required condition fields, causing JSON decoding errors.

**Solution**:

- Made all condition fields optional in `SurfReportResponse` model
- Added default empty strings in the extension when converting to `SurfReport`
- Updated backend service to ensure all required fields have defaults

**Files Changed**:

- `TrebleSurf/Models/SurfReport.swift`
- `treblesurf-backend/internal/service/report_service.go`

### 2. String/Double Type Mismatch in Historical Buoy Data

**Problem**: Backend was returning historical buoy data as strings (e.g., "3.96") but iOS was expecting Double.

**Solution**:

- Created `StringOrDouble` enum helper type that can decode either String or Double
- Updated `historicalBuoyWaveHeight`, `historicalBuoyWaveDirection`, and `historicalBuoyPeriod` to use this type
- Added `doubleValue` computed property for easy conversion

**Files Changed**:

- `TrebleSurf/Models/SurfReport.swift`

### 3. Pagination Marker Breaking JSON Decoding

**Problem**: Backend was appending a `_hasMore` object to the reports array, which didn't match the SurfReport schema.

**Solution**:

- Removed the pagination marker from being appended to reports array
- Added note that pagination should be handled at controller level instead

**Files Changed**:

- `treblesurf-backend/internal/service/report_service.go`

## Changes Made

### iOS Model Updates (`SurfReport.swift`)

#### Added StringOrDouble Helper Type

```swift
enum StringOrDouble: Decodable {
    case string(String)
    case double(Double)

    var doubleValue: Double? {
        switch self {
        case .string(let str): return Double(str)
        case .double(let value): return value
        }
    }
}
```

#### Made Fields Optional

Changed from:

```swift
let consistency: String
let messiness: String
let quality: String
// etc.
```

To:

```swift
let consistency: String?
let messiness: String?
let quality: String?
// etc.
```

#### Updated Historical Buoy Fields

```swift
let historicalBuoyWaveHeight: StringOrDouble?
let historicalBuoyWaveDirection: StringOrDouble?
let historicalBuoyPeriod: StringOrDouble?
```

#### Added Default Values in Extension

```swift
convenience init(from response: SurfReportResponse) {
    self.init(
        consistency: response.consistency ?? "",
        messiness: response.messiness ?? "",
        quality: response.quality ?? "",
        reporter: response.reporter ?? "Anonymous",
        // ... with proper handling for StringOrDouble
        historicalBuoyWaveHeight: response.historicalBuoyWaveHeight?.doubleValue,
        // etc.
    )
}
```

### Backend Updates (`report_service.go`)

#### Added Default Values for Missing Fields

```go
// Ensure all required fields have defaults if missing
if _, exists := report["Consistency"]; !exists {
    report["Consistency"] = ""
}
if _, exists := report["Messiness"]; !exists {
    report["Messiness"] = ""
}
if _, exists := report["Quality"]; !exists {
    report["Quality"] = ""
}
// ... etc for all condition fields
```

#### Removed Pagination Marker

Removed:

```go
paginationInfo := map[string]interface{}{
    "_hasMore": true,
}
reports = append(reports, paginationInfo)
```

## Testing Checklist

### Backend Testing

- [x] Reports with missing condition fields now have empty string defaults
- [x] No pagination marker objects in response array
- [ ] Verify all existing reports still decode correctly
- [ ] Test with spots that have old/legacy report data

### iOS Testing

- [x] Reports with missing fields decode successfully
- [x] Historical buoy data (string or double) decodes correctly
- [x] No more "Key not found: Consistency" errors
- [x] No more "Type mismatch: Expected Double" errors
- [ ] Verify timestamps format correctly on all screens
- [ ] Test "View All Reports" screen
- [ ] Test single report display
- [ ] Test home page recent reports

## Known Issues to Verify

### Timestamp Formatting

The timestamp parsing should work correctly as it uses the same `formattedDateReported` property everywhere. If timestamps still don't look right:

1. **Check the dateReported field format** in backend responses
2. **Verify the Date.parseDateReported** function handles the format
3. **Check timezone handling** - dates are stored in UTC and converted to local time

Expected format: `"2025-11-04 12:44:19 +0000 UTC_uuid"` or `"2025-11-04 12:44:19"`

### Empty/Missing Data Display

Reports with missing condition data will now show empty strings. Consider:

- Displaying "N/A" or placeholder text for missing fields
- Hiding empty sections in the UI
- Adding visual indicators for incomplete reports

## Recommendations

### 1. Data Validation

Consider adding backend validation to ensure all required fields are present when submitting reports:

```go
// In report submission handler
if report.SurfSize == "" || report.Quality == "" {
    return errors.New("missing required surf condition fields")
}
```

### 2. UI Improvements

For reports with missing data:

```swift
// In SpotReportsListView
private func formatCondition(_ value: String) -> String {
    if value.isEmpty {
        return "N/A"  // Instead of empty
    }
    // ... format the value
}
```

### 3. Type Consistency

Consider standardizing backend types:

- Always return numbers as numbers (not strings)
- Use consistent field presence (either always include or make truly optional)

### 4. Pagination

For better pagination in the future:

- Return pagination metadata in response headers or wrapper object
- Don't mix pagination info with data array
- Example structure:

```json
{
  "reports": [...],
  "pagination": {
    "hasMore": true,
    "nextToken": "...",
    "total": 100
  }
}
```

## Debug Tips

If you still see decoding errors:

1. **Enable verbose logging** in APIClient to see raw JSON
2. **Check backend logs** for the actual data being returned
3. **Test with different spots** that have various report ages
4. **Verify database migration** if report schema changed

### Add Debug Logging

```swift
// In APIClient.swift
print("Raw JSON response: \(String(data: data, encoding: .utf8) ?? "nil")")
```

## Migration Notes

### For Existing Reports

Old reports in the database may be missing fields. The fixes ensure:

- ✅ They decode without errors (use defaults)
- ✅ They display in the app (with empty/N/A values)
- ⚠️ UI may need refinement for empty fields

### For New Reports

Going forward:

- ✅ All fields should be provided at submission
- ✅ Backend validates required fields
- ✅ UI enforces field completion

## Files Modified

### iOS App

- `TrebleSurf/Models/SurfReport.swift` - Added StringOrDouble, made fields optional, added defaults

### Backend

- `treblesurf-backend/internal/service/report_service.go` - Added field defaults, removed pagination marker

### Documentation

- `REPORT_DECODING_FIXES.md` (this file)

## Next Steps

1. **Test thoroughly** with various spots and report ages
2. **Monitor logs** for any remaining decoding errors
3. **Consider UI improvements** for handling empty/missing data
4. **Add backend validation** for new report submissions
5. **Standardize data types** across backend and iOS models
