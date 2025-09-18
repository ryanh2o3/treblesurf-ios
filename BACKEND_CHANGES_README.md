# Backend Changes Required for iOS ML Validation and Video Support

This document outlines the changes needed in the Treble Surf backend to support iOS machine learning validation and video uploads for surf reports.

## Overview

The iOS app now uses the Vision framework for client-side image validation and supports video uploads. The backend needs to be updated to:

1. Support a new endpoint that accepts iOS-validated surf reports
2. Add video upload support with S3 presigned URLs
3. Maintain backward compatibility with existing image validation for non-iOS clients
4. Update database schema to store video keys
5. Add video retrieval endpoints

## New API Endpoints

### 1. Submit Surf Report with iOS Validation

**Endpoint:** `POST /api/submitSurfReportWithIOSValidation`

**Authentication:** Required (JWT token)

**Description:** Submit a surf report that has been validated using iOS Vision framework. This endpoint bypasses server-side image validation.

**Request Body:**

```json
{
  "country": "Ireland",
  "region": "Donegal",
  "spot": "Bundoran",
  "surfSize": "chest-shoulder",
  "windAmount": "light",
  "windDirection": "offshore",
  "consistency": "consistent",
  "quality": "good",
  "messiness": "clean",
  "imageKey": "surf-reports/Ireland_Donegal_Bundoran/2024-01-15T14:30:00Z_user-uuid.jpg",
  "videoKey": "surf-reports/Ireland_Donegal_Bundoran/2024-01-15T14:30:00Z_user-uuid.mp4",
  "iosValidated": true,
  "date": "2024-01-15 14:30:00"
}
```

**Response:**

```json
{
  "message": "Report submitted successfully"
}
```

**Key Changes:**

- `iosValidated: true` flag indicates client-side validation was performed
- `videoKey` field for video S3 key (optional)
- No server-side image validation when `iosValidated` is true
- Both `imageKey` and `videoKey` can be present (user can upload both)

### 2. Generate Video Upload URL

**Endpoint:** `GET /api/generateVideoUploadURL`

**Authentication:** Required (JWT token)

**Description:** Generate a presigned URL for uploading a video to S3.

**Query Parameters:**

- `country` (required): Country name
- `region` (required): Region name
- `spot` (required): Surf spot name

**Response:**

```json
{
  "uploadUrl": "https://s3.amazonaws.com/bucket/surf-reports/...",
  "videoKey": "surf-reports/Ireland_Donegal_Bundoran/2024-01-15T14:30:00Z_user-uuid.mp4",
  "expiresAt": "2024-01-15T14:45:00Z"
}
```

### 3. Get Report Video

**Endpoint:** `GET /api/getReportVideo`

**Authentication:** Required (JWT token)

**Description:** Retrieve a video associated with a surf report.

**Query Parameters:**

- `key` (required): S3 video key

**Response:**

```json
{
  "videoData": "base64-encoded-video-data",
  "contentType": "video/mp4"
}
```

## Database Schema Changes

### DynamoDB Table: SurfReports

**New Attributes:**

- `VideoKey` (String, optional): S3 key for associated video
- `MediaType` (String, optional): "image", "video", or "both" to indicate what media is attached

**Updated Primary Key Structure:**

- Partition Key: `country_region_spot` (unchanged)
- Sort Key: `dateReported` (unchanged)

**Example Item:**

```json
{
  "country_region_spot": "Ireland_Donegal_Bundoran",
  "dateReported": "2024-01-15T14:30:00Z_user-uuid",
  "SurfSize": "chest-shoulder",
  "WindAmount": "light",
  "WindDirection": "offshore",
  "Consistency": "consistent",
  "Quality": "good",
  "Messiness": "clean",
  "Reporter": "John Doe",
  "Time": "2024-01-15T14:30:00Z",
  "reportedBy": "user-uuid",
  "ImageKey": "surf-reports/Ireland_Donegal_Bundoran/2024-01-15T14:30:00Z_user-uuid.jpg",
  "VideoKey": "surf-reports/Ireland_Donegal_Bundoran/2024-01-15T14:30:00Z_user-uuid.mp4",
  "MediaType": "both",
  "IOSValidated": true
}
```

## S3 Storage Structure

**Updated Bucket Structure:**

```
treblesurf-images/
└── surf-reports/
    └── {country_region_spot}/
        ├── {timestamp}_{user-uuid}.jpg    # Images
        └── {timestamp}_{user-uuid}.mp4    # Videos
```

**Video Storage Guidelines:**

- Maximum file size: 100MB per video
- Supported formats: MP4, MOV, AVI
- Presigned URL expiry: 15 minutes
- Content-Type: video/mp4

## Backend Implementation Changes

### 1. New Data Models

```go
type ReportWithIOSValidation struct {
    Country       string `json:"country"`
    Region        string `json:"region"`
    Spot          string `json:"spot"`
    SurfSize      string `json:"surfSize"`
    WindAmount    string `json:"windAmount"`
    WindDirection string `json:"windDirection"`
    Consistency   string `json:"consistency"`
    Quality       string `json:"quality"`
    Messiness     string `json:"messiness"`
    ImageKey      string `json:"imageKey,omitempty"`
    VideoKey      string `json:"videoKey,omitempty"`
    IOSValidated  bool   `json:"iosValidated"`
    Date          string `json:"date"`
}

type VideoUploadResponse struct {
    UploadUrl  string `json:"uploadUrl"`
    VideoKey   string `json:"videoKey"`
    ExpiresAt  string `json:"expiresAt"`
}

type VideoResponse struct {
    VideoData   string `json:"videoData"`
    ContentType string `json:"contentType"`
}
```

### 2. Updated Service Logic

**Image Validation Logic:**

```go
func (s *ReportService) validateImage(imageData []byte, iosValidated bool) (bool, error) {
    // Skip validation if iOS validated
    if iosValidated {
        return true, nil
    }

    // Use existing AWS Rekognition validation for non-iOS clients
    return s.validateImageWithRekognition(imageData)
}
```

**Video Upload Logic:**

```go
func (s *ReportService) generateVideoUploadURL(country, region, spot string) (*VideoUploadResponse, error) {
    // Generate S3 key for video
    timestamp := time.Now().UTC().Format("2006-01-02T15:04:05Z")
    userUUID := getUserUUID() // Get from JWT token
    videoKey := fmt.Sprintf("surf-reports/%s_%s_%s/%s_%s.mp4",
        country, region, spot, timestamp, userUUID)

    // Generate presigned URL for video upload
    uploadURL, err := s.s3Client.PresignedPutObject(videoKey, 15*time.Minute)
    if err != nil {
        return nil, err
    }

    return &VideoUploadResponse{
        UploadUrl: uploadURL,
        VideoKey:  videoKey,
        ExpiresAt: time.Now().Add(15 * time.Minute).Format(time.RFC3339),
    }, nil
}
```

### 3. Updated Report Storage

```go
func (s *ReportService) storeReportWithIOSValidation(report *ReportWithIOSValidation) error {
    // Determine media type
    mediaType := "none"
    if report.ImageKey != "" && report.VideoKey != "" {
        mediaType = "both"
    } else if report.ImageKey != "" {
        mediaType = "image"
    } else if report.VideoKey != "" {
        mediaType = "video"
    }

    // Store in DynamoDB
    item := map[string]interface{}{
        "country_region_spot": fmt.Sprintf("%s_%s_%s", report.Country, report.Region, report.Spot),
        "dateReported":        fmt.Sprintf("%s_%s", report.Date, getUserUUID()),
        "SurfSize":           report.SurfSize,
        "WindAmount":         report.WindAmount,
        "WindDirection":      report.WindDirection,
        "Consistency":        report.Consistency,
        "Quality":            report.Quality,
        "Messiness":          report.Messiness,
        "Reporter":           getUserName(),
        "Time":               report.Date,
        "reportedBy":         getUserUUID(),
        "ImageKey":           report.ImageKey,
        "VideoKey":           report.VideoKey,
        "MediaType":          mediaType,
        "IOSValidated":       report.IOSValidated,
    }

    return s.dynamoDB.PutItem(item)
}
```

## Backward Compatibility

### Maintaining Existing Functionality

1. **Legacy Endpoints:** Keep existing `/api/submitSurfReport` and `/api/submitSurfReportWithS3Image` endpoints unchanged
2. **Image Validation:** Continue using AWS Rekognition for non-iOS clients
3. **Database Queries:** Update existing queries to handle optional `VideoKey` field
4. **API Responses:** Include `VideoKey` in existing surf report responses (as optional field)

### Client Detection

```go
func isIOSClient(userAgent string) bool {
    return strings.Contains(strings.ToLower(userAgent), "ios") ||
           strings.Contains(strings.ToLower(userAgent), "iphone") ||
           strings.Contains(strings.ToLower(userAgent), "ipad")
}
```

## Error Handling

### New Error Types

```go
var (
    ErrVideoUploadFailed     = errors.New("video upload failed")
    ErrVideoRetrievalFailed  = errors.New("failed to retrieve video")
    ErrInvalidVideoFormat    = errors.New("invalid video format")
    ErrVideoTooLarge         = errors.New("video file too large")
    ErrIOSValidationRequired = errors.New("iOS validation required for this endpoint")
)
```

### Error Response Format

```json
{
  "error": "Video upload failed",
  "message": "The video file could not be uploaded to S3",
  "help": "Please try uploading a smaller video file or check your internet connection."
}
```

## Security Considerations

1. **Video File Validation:** Validate video file types and sizes on upload
2. **S3 Security:** Use presigned URLs with appropriate expiry times
3. **Rate Limiting:** Implement rate limiting for video uploads (larger files)
4. **Content Scanning:** Consider adding virus scanning for video files
5. **Access Control:** Ensure only authenticated users can upload/retrieve videos

## Performance Considerations

1. **Video Compression:** Consider server-side video compression for large files
2. **CDN Integration:** Use CloudFront for video delivery
3. **Thumbnail Generation:** Generate video thumbnails for preview
4. **Progressive Upload:** Support chunked uploads for large videos
5. **Caching:** Cache video metadata and thumbnails

## Monitoring and Logging

### New Metrics to Track

- Video upload success/failure rates
- Video file sizes and formats
- iOS vs non-iOS client usage
- Video retrieval frequency
- S3 storage costs for videos

### Logging Updates

```go
log.Info("Video upload initiated",
    "userID", userID,
    "videoKey", videoKey,
    "fileSize", fileSize,
    "contentType", contentType)

log.Info("Surf report submitted with iOS validation",
    "userID", userID,
    "spot", spot,
    "hasImage", imageKey != "",
    "hasVideo", videoKey != "",
    "iosValidated", true)
```

## Testing Strategy

### Unit Tests

- Test iOS validation bypass logic
- Test video upload URL generation
- Test database schema updates
- Test error handling for video operations

### Integration Tests

- Test end-to-end video upload flow
- Test mixed image/video reports
- Test backward compatibility with existing clients
- Test S3 integration for videos

### Load Testing

- Test video upload performance
- Test concurrent video uploads
- Test large file handling
- Test S3 bandwidth limits

## Migration Strategy

### Phase 1: Backend Updates

1. Deploy new endpoints alongside existing ones
2. Update database schema (add optional fields)
3. Deploy video upload functionality
4. Test with iOS app in development

### Phase 2: iOS App Deployment

1. Deploy iOS app with new functionality
2. Monitor usage and error rates
3. Collect feedback on video upload experience

### Phase 3: Cleanup (Optional)

1. Consider deprecating old image validation endpoints
2. Optimize video storage and delivery
3. Add advanced video features (thumbnails, compression)

## Configuration Changes

### Environment Variables

```bash
# Video upload settings
MAX_VIDEO_SIZE_MB=100
VIDEO_UPLOAD_TIMEOUT=300
SUPPORTED_VIDEO_FORMATS=mp4,mov,avi

# S3 video settings
S3_VIDEO_BUCKET=treblesurf-videos
S3_VIDEO_PREFIX=surf-reports

# Feature flags
ENABLE_VIDEO_UPLOADS=true
ENABLE_IOS_VALIDATION_BYPASS=true
```

### S3 Bucket Configuration

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": { "AWS": "arn:aws:iam::ACCOUNT:user/treblesurf-app" },
      "Action": ["s3:PutObject", "s3:GetObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::treblesurf-videos/surf-reports/*"
    }
  ]
}
```

## Conclusion

These changes enable the iOS app to use client-side machine learning validation while maintaining full backward compatibility with existing web and Android clients. The video upload functionality provides users with richer surf reporting capabilities while maintaining the same security and performance standards as the existing image upload system.

The implementation should be done incrementally, with thorough testing at each phase to ensure a smooth transition and maintain the reliability of the existing surf reporting system.
