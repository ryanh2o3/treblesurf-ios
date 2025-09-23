# Media Cleanup Backend Implementation

## Overview

The iOS app now tracks uploaded media and provides cleanup functionality for unused uploads. This prevents storage waste and reduces costs by automatically deleting media that was uploaded but never used in a surf report.

## Frontend Implementation

### What's Already Implemented:

- **Upload Tracking**: Tracks `uploadedImageKey`, `uploadedVideoKey`, and `uploadedVideoThumbnailKey`
- **Cleanup on Cancel**: Automatically cleans up unused media when user cancels the form
- **Cleanup on Success**: Clears tracking when submission is successful
- **Background Cleanup**: Runs cleanup in background without blocking UI

### Frontend Cleanup Logic:

```swift
// When user cancels form
Button("Cancel") {
    viewModel.cleanupUnusedUploads()
    dismiss()
}

// When submission succeeds
case .success(let response):
    // Clear tracking since media was used
    self.uploadedImageKey = nil
    self.uploadedVideoKey = nil
    self.uploadedVideoThumbnailKey = nil
```

## Required Backend Changes

### 1. New Endpoint: Delete Uploaded Media

**Endpoint:** `DELETE /api/deleteUploadedMedia?key={mediaKey}&type={mediaType}`

**Purpose:** Delete unused uploaded media from S3.

**Request:**

```
DELETE /api/deleteUploadedMedia?key=surf-reports/Ireland_Donegal_Ballyhiernan/2025-09-18T20:31:30Z_27ebc05e-625a-4c05-add5-5e6ef33f8b8e.mp4&type=video
```

**Response:**

```json
{
  "message": "Media deleted successfully"
}
```

### 2. Implementation Details

**Authentication:** Requires user authentication (session cookie + CSRF token)

**Parameters:**

- `key`: The S3 key of the media to delete
- `type`: Either "image" or "video"

**S3 Operations:**

- Delete the object from S3 bucket
- Handle both images and videos
- Handle video thumbnails (stored as images)

**Error Handling:**

- Return 404 if media key doesn't exist
- Return 403 if user doesn't have permission to delete the media
- Return 500 for server errors

### 3. Security Considerations

**Access Control:**

- Verify user has permission to delete the specific media
- Ensure media key belongs to the authenticated user
- Consider implementing ownership verification

**Validation:**

- Validate media key format
- Ensure type parameter is either "image" or "video"
- Sanitize input to prevent path traversal

### 4. Example Implementation (Node.js/Express)

```javascript
app.delete("/api/deleteUploadedMedia", authenticateUser, async (req, res) => {
  try {
    const { key, type } = req.query;

    // Validate parameters
    if (!key || !type) {
      return res.status(400).json({ error: "Missing required parameters" });
    }

    if (!["image", "video"].includes(type)) {
      return res.status(400).json({ error: "Invalid media type" });
    }

    // Verify user has access to this media
    const hasAccess = await verifyUserMediaAccess(req.user, key);
    if (!hasAccess) {
      return res.status(403).json({ error: "Access denied" });
    }

    // Delete from S3
    await s3
      .deleteObject({
        Bucket: process.env.S3_BUCKET_NAME,
        Key: key,
      })
      .promise();

    console.log(`🗑️ [CLEANUP] Deleted ${type}: ${key}`);

    res.json({ message: "Media deleted successfully" });
  } catch (error) {
    console.error("Error deleting media:", error);
    res.status(500).json({ error: "Failed to delete media" });
  }
});

async function verifyUserMediaAccess(user, mediaKey) {
  // Implementation depends on your access control system
  // Could check if media belongs to user's reports
  // or if it's within user's allowed time window
  return true; // Placeholder
}
```

### 5. Alternative: Backend Flag Approach

Instead of frontend cleanup, you could implement a backend flag system:

**Database Changes:**

```sql
ALTER TABLE uploaded_media ADD COLUMN confirmed BOOLEAN DEFAULT FALSE;
ALTER TABLE uploaded_media ADD COLUMN created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP;
```

**Backend Logic:**

- Set `confirmed = true` when media is used in a surf report
- Run a cron job to delete unconfirmed media older than 24-48 hours
- This approach is more robust and handles edge cases

**Cron Job Example:**

```javascript
// Run every hour
cron.schedule("0 * * * *", async () => {
  const cutoffTime = new Date(Date.now() - 24 * 60 * 60 * 1000); // 24 hours ago

  const unconfirmedMedia = await db.query(
    "SELECT * FROM uploaded_media WHERE confirmed = false AND created_at < ?",
    [cutoffTime]
  );

  for (const media of unconfirmedMedia) {
    try {
      await s3
        .deleteObject({
          Bucket: process.env.S3_BUCKET_NAME,
          Key: media.s3_key,
        })
        .promise();

      await db.query("DELETE FROM uploaded_media WHERE id = ?", [media.id]);
      console.log(`🗑️ [CLEANUP] Deleted unconfirmed media: ${media.s3_key}`);
    } catch (error) {
      console.error(
        `❌ [CLEANUP] Failed to delete media ${media.s3_key}:`,
        error
      );
    }
  }
});
```

## Benefits

### Frontend Cleanup Approach:

- **Immediate cleanup** when user cancels
- **No backend complexity** for tracking
- **User-controlled** cleanup timing

### Backend Flag Approach:

- **More robust** - handles all edge cases
- **Automatic cleanup** - no dependency on frontend
- **Better for costs** - guaranteed cleanup
- **Handles crashes** - cleanup happens even if app crashes

## Recommendation

I recommend the **Backend Flag Approach** because:

1. More reliable cleanup
2. Handles edge cases (app crashes, network issues)
3. Better cost control
4. Simpler frontend logic

The frontend cleanup can still be implemented as a **nice-to-have** for immediate cleanup, but the backend flag system should be the primary cleanup mechanism.

## Testing

Test the delete endpoint with:

```bash
curl -X DELETE "https://your-api.com/api/deleteUploadedMedia?key=test-key&type=image" \
  -H "Cookie: session_id=your-session-id" \
  -H "X-CSRF-Token: your-csrf-token"
```

Expected response:

```json
{
  "message": "Media deleted successfully"
}
```
