# Surf Report Submission API Documentation

## Overview

This document describes the surf report submission API endpoints and data formats used by the TrebleSurf iOS app for submitting quick surf reports.

## Endpoints

### 1. Submit Surf Report (Legacy)

- **Endpoint**: `POST /api/submitSurfReport`
- **Description**: Submit a surf report with base64 encoded image data
- **Content-Type**: `application/json`

### 2. Submit Surf Report with S3 Image

- **Endpoint**: `POST /api/submitSurfReportWithS3Image`
- **Description**: Submit a surf report with S3 image key reference
- **Content-Type**: `application/json`

### 3. Generate Image Upload URL

- **Endpoint**: `GET /api/generateImageUploadURL`
- **Description**: Generate presigned URL for S3 image upload
- **Query Parameters**: `country`, `region`, `spot`

## Request Format

### Common Fields

Both endpoints accept the following JSON structure:

```json
{
  "country": "string",
  "region": "string",
  "spot": "string",
  "surfSize": "string",
  "messiness": "string",
  "windDirection": "string",
  "windAmount": "string",
  "consistency": "string",
  "quality": "string",
  "date": "string",
  "imageKey": "string",
  "imageData": "string" // Only for legacy endpoint
}
```

### Field Descriptions

| Field           | Type   | Required | Description                        | Example                              |
| --------------- | ------ | -------- | ---------------------------------- | ------------------------------------ |
| `country`       | string | Yes      | Country name                       | "Ireland"                            |
| `region`        | string | Yes      | Region/state name                  | "Donegal"                            |
| `spot`          | string | Yes      | Surf spot name                     | "Ballymastocker"                     |
| `surfSize`      | string | Yes      | Wave size category                 | "head-high"                          |
| `messiness`     | string | Yes      | Wave messiness level               | "clean"                              |
| `windDirection` | string | Yes      | Wind direction                     | "offshore"                           |
| `windAmount`    | string | Yes      | Wind strength                      | "light"                              |
| `consistency`   | string | Yes      | Wave consistency                   | "consistent"                         |
| `quality`       | string | Yes      | Wave quality rating                | "good"                               |
| `date`          | string | Yes      | Report timestamp                   | "2025-01-19 14:30:00"                |
| `imageKey`      | string | No       | S3 image key (S3 endpoint only)    | "reports/2025/01/19/abc123.jpg"      |
| `imageData`     | string | No       | Base64 encoded image (legacy only) | "data:image/jpeg;base64,/9j/4AAQ..." |

## Field Value Options

### Surf Size (`surfSize`)

| Value             | Display Name      | Description |
| ----------------- | ----------------- | ----------- |
| `flat`            | Flat              | No waves    |
| `knee-waist`      | Knee to Waist     | 1-3 feet    |
| `chest-shoulder`  | Chest to Shoulder | 3-4 feet    |
| `head-high`       | Head High         | 4-6 feet    |
| `overhead`        | Overhead          | 6-8 feet    |
| `double-overhead` | Double Overhead   | 8+ feet     |

### Messiness (`messiness`)

| Value         | Display Name | Description                  |
| ------------- | ------------ | ---------------------------- |
| `clean`       | Clean        | Smooth, clean waves          |
| `slight-chop` | Slight Chop  | Minor surface disturbance    |
| `choppy`      | Choppy       | Moderate surface disturbance |
| `messy`       | Messy        | Heavy surface disturbance    |

### Wind Direction (`windDirection`)

| Value         | Display Name | Description                    |
| ------------- | ------------ | ------------------------------ |
| `onshore`     | Onshore      | Wind blowing from sea to land  |
| `offshore`    | Offshore     | Wind blowing from land to sea  |
| `cross-shore` | Cross Shore  | Wind blowing parallel to shore |
| `no-wind`     | No Wind      | Calm conditions                |

### Wind Amount (`windAmount`)

| Value         | Display Name | Description |
| ------------- | ------------ | ----------- |
| `light`       | Light        | 0-10 mph    |
| `moderate`    | Moderate     | 10-20 mph   |
| `strong`      | Strong       | 20-30 mph   |
| `very-strong` | Very Strong  | 30+ mph     |

### Consistency (`consistency`)

| Value          | Display Name | Description                  |
| -------------- | ------------ | ---------------------------- |
| `setty`        | Setty        | Waves come in regular sets   |
| `consistent`   | Consistent   | Steady wave activity         |
| `inconsistent` | Inconsistent | Irregular wave activity      |
| `sporadic`     | Sporadic     | Very irregular wave activity |

### Quality (`quality`)

| Value       | Display Name | Description               |
| ----------- | ------------ | ------------------------- |
| `mushy`     | Mushy        | Soft, slow-breaking waves |
| `average`   | Average      | Standard wave quality     |
| `okay`      | Okay         | Decent wave quality       |
| `good`      | Good         | High-quality waves        |
| `excellent` | Excellent    | Perfect wave conditions   |

## Date Format

- **Format**: `yyyy-MM-dd HH:mm:ss`
- **Example**: `2025-01-19 14:30:00`
- **Timezone**: UTC (handled by backend)

## Image Handling

### S3 Upload Process (Recommended)

1. Client calls `GET /api/generateImageUploadURL?country=X&region=Y&spot=Z`
2. Backend returns presigned URL and image key
3. Client uploads image directly to S3 using presigned URL
4. Client submits report with `imageKey` field

### Legacy Base64 Process

1. Client compresses image to <1MB
2. Client encodes image as base64 string
3. Client submits report with `imageData` field

## Response Format

### Success Response

```json
{
  "message": "Surf report submitted successfully",
  "success": true,
  "report_id": "uuid-string"
}
```

### Error Response

```json
{
  "error": "Error Type",
  "message": "Human-readable error message",
  "help": "Additional help text for user"
}
```

## Error Types

### Validation Errors

- `Missing required fields` - One or more required fields are missing
- `Invalid surf size` - Invalid surfSize value
- `Invalid wind amount` - Invalid windAmount value
- `Invalid wind direction` - Invalid windDirection value
- `Invalid consistency` - Invalid consistency value
- `Invalid quality` - Invalid quality value
- `Invalid messiness` - Invalid messiness value

### Image Errors

- `Image validation failed` - Image failed validation checks
- `Image not surf-related` - Image doesn't contain surf-related content
- `Image analysis failed` - Could not analyze image content
- `Image upload failed` - Failed to upload image to S3
- `Invalid image data` - Invalid image format or data
- `Image retrieval failed` - Could not retrieve image from S3

### System Errors

- `Authentication required` - User not authenticated
- `User information error` - User data validation failed
- `Invalid request format` - Malformed request data
- `Failed to generate upload URL` - S3 URL generation failed
- `Failed to retrieve reports` - Database query failed

## Authentication

- Requires valid session cookie
- Requires CSRF token for POST requests
- CSRF token can be refreshed via `GET /api/auth/csrf`

## Rate Limiting

- Standard rate limiting applies
- Image uploads may have additional limits

## Example Requests

### Complete S3 Report Submission

```json
{
  "country": "Ireland",
  "region": "Donegal",
  "spot": "Ballymastocker",
  "surfSize": "head-high",
  "messiness": "clean",
  "windDirection": "offshore",
  "windAmount": "light",
  "consistency": "consistent",
  "quality": "good",
  "date": "2025-01-19 14:30:00",
  "imageKey": "reports/2025/01/19/ireland_donegal_ballymastocker_20250119_143000_abc123.jpg"
}
```

### Legacy Report Submission (No Image)

```json
{
  "country": "Ireland",
  "region": "Donegal",
  "spot": "Ballymastocker",
  "surfSize": "knee-waist",
  "messiness": "slight-chop",
  "windDirection": "no-wind",
  "windAmount": "light",
  "consistency": "setty",
  "quality": "average",
  "date": "2025-01-19 14:30:00",
  "imageData": ""
}
```

## Notes

- All field values are case-sensitive and must match exactly
- Empty strings are acceptable for optional fields
- Image compression is handled client-side (target <1MB)
- Timestamps are extracted from image EXIF data when available
- User can manually override timestamp if needed
