# Video View URL Backend Implementation

## Overview

The iOS app now uses presigned URLs to view videos instead of fetching raw video data. This approach is more efficient and secure for video playback.

## Required Backend Changes

### 1. New Endpoint: Generate Video View URL

**Endpoint:** `GET /api/generateVideoViewURL?key={videoKey}`

**Purpose:** Generate a presigned URL for viewing a video stored in S3.

**Request:**

```
GET /api/generateVideoViewURL?key=surf-reports/Ireland_Donegal_Ballyhiernan/2025-09-18T20:31:30Z_27ebc05e-625a-4c05-add5-5e6ef33f8b8e.mp4
```

**Response:**

```json
{
  "viewURL": "https://your-s3-bucket.s3.amazonaws.com/surf-reports/Ireland_Donegal_Ballyhiernan/2025-09-18T20:31:30Z_27ebc05e-625a-4c05-add5-5e6ef33f8b8e.mp4?AWSAccessKeyId=...&Signature=...&Expires=...",
  "expiresAt": "2025-09-18T21:31:30Z"
}
```

### 2. Implementation Details

**Authentication:** Requires user authentication (session cookie + CSRF token)

**S3 Configuration:**

- Generate presigned URL with appropriate expiration time (e.g., 1 hour)
- Use GET method for video viewing
- Ensure proper CORS headers for video streaming

**Error Handling:**

- Return 404 if video key doesn't exist
- Return 403 if user doesn't have permission to view the video
- Return 500 for server errors

### 3. Security Considerations

**Access Control:**

- Verify user has permission to view the specific surf report
- Ensure video key belongs to a report the user can access
- Consider implementing report ownership or sharing permissions

**URL Expiration:**

- Set reasonable expiration time (1-2 hours)
- Include expiration timestamp in response for client-side validation

### 4. Example Implementation (Node.js/Express)

```javascript
app.get("/api/generateVideoViewURL", authenticateUser, async (req, res) => {
  try {
    const { key } = req.query;

    // Verify user has access to this video
    const report = await getSurfReportByVideoKey(key);
    if (!report || !canUserViewReport(req.user, report)) {
      return res.status(403).json({ error: "Access denied" });
    }

    // Generate presigned URL
    const viewURL = await s3.getSignedUrl("getObject", {
      Bucket: process.env.S3_BUCKET_NAME,
      Key: key,
      Expires: 3600, // 1 hour
    });

    const expiresAt = new Date(Date.now() + 3600 * 1000).toISOString();

    res.json({
      viewURL,
      expiresAt,
    });
  } catch (error) {
    console.error("Error generating video view URL:", error);
    res.status(500).json({ error: "Failed to generate video view URL" });
  }
});
```

### 5. Frontend Integration

The iOS app will:

1. Call `/api/generateVideoViewURL?key={videoKey}` when user taps play button
2. Receive presigned URL and expiration time
3. Use `AVPlayer` to stream video directly from S3
4. Handle URL expiration gracefully

### 6. Benefits

**Performance:**

- No need to download entire video file
- Streaming playback starts immediately
- Reduced server bandwidth usage

**Security:**

- URLs expire automatically
- No raw video data in API responses
- Better access control

**Scalability:**

- S3 handles video delivery
- Reduced server load
- Better CDN integration potential

## Migration Notes

- The existing `/api/getReportVideo` endpoint can be deprecated
- All video viewing should use the new presigned URL approach
- Consider implementing video thumbnail generation for better UX
- Ensure proper CORS configuration for video streaming

## Testing

Test the endpoint with:

```bash
curl -X GET "https://your-api.com/api/generateVideoViewURL?key=test-video-key" \
  -H "Cookie: session_id=your-session-id" \
  -H "X-CSRF-Token: your-csrf-token"
```

Expected response:

```json
{
  "viewURL": "https://s3.amazonaws.com/...",
  "expiresAt": "2025-09-18T21:31:30Z"
}
```
