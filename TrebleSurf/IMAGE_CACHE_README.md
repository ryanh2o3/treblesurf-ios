# Image Cache System

## Overview

The Image Cache System provides long-term caching for both spot images and surf report images. Since these images have unique keys and never change, they can be cached for extended periods (30 days) to improve user experience and reduce API calls.

## Features

- **Long-term caching**: Images are cached for 30 days since they never change
- **Dual storage**: Both memory and disk caching for optimal performance
- **Automatic cleanup**: Expired cache entries are automatically removed
- **Memory pressure handling**: Automatically reduces memory usage when needed
- **App lifecycle management**: Handles background/foreground transitions gracefully
- **Statistics and debugging**: Comprehensive cache information and export capabilities

## Architecture

### Core Components

1. **ImageCacheService**: Singleton service managing all image caching operations
2. **DataStore integration**: Seamless integration with existing data fetching methods
3. **ViewModels**: Updated to use cached images when available

### Cache Keys

- **Spot images**: `spot_{spotId}` (e.g., `spot_Ireland#Donegal#Ballymastocker`)
- **Surf report images**: `report_{imageKey}` (e.g., `report_abc123`)

## Usage

### Basic Image Caching

The system automatically caches images when they're fetched. No additional code is required for basic usage.

### Manual Cache Management

```swift
// Get cached image
ImageCacheService.shared.getCachedSpotImage(for: spotId) { image in
    if let image = image {
        // Use cached image
    } else {
        // Fetch from API
    }
}

// Cache an image manually
if let imageData = image.pngData() {
    ImageCacheService.shared.cacheSpotImage(imageData, for: spotId)
}

// Check if image is cached
let isCached = ImageCacheService.shared.hasCachedImage(for: "spot_\(spotId)")
```

### Cache Statistics

```swift
// Get basic stats
let stats = dataStore.getImageCacheStats()
print("Total images: \(stats.totalImages)")
print("Memory usage: \(stats.memoryUsage)")
print("Disk usage: \(stats.diskUsage)")

// Get detailed stats by type
let detailedStats = dataStore.getDetailedImageCacheStats()
print("Spot images: \(detailedStats.spotImages)")
print("Report images: \(detailedStats.reportImages)")

// Export full cache information
let cacheInfo = dataStore.exportImageCacheInfo()
print(cacheInfo)
```

### Cache Management

```swift
// Clear specific spot image cache
dataStore.clearImageCache(for: spotId)

// Clear all image caches
dataStore.clearImageCache()

// Refresh specific spot image
dataStore.refreshSpotImage(for: spotId) { image in
    // Use refreshed image
}

// Refresh all image caches
dataStore.refreshAllImageCaches()

// Test the cache system
dataStore.testImageCache()
```

## Integration Points

### DataStore

The `DataStore.fetchSpotImage()` method has been updated to:

1. First check the dedicated image cache
2. Fall back to existing regionSpotsCache
3. Fetch from API if not cached
4. Automatically cache new images

### ViewModels

Both `LiveSpotViewModel` and `HomeViewModel` have been updated to:

1. Check the image cache before making API calls
2. Cache images when they're fetched
3. Provide seamless fallback to API calls

### Automatic Preloading

The system automatically preloads images when:

- Fetching region spots
- Fetching individual spot data
- Fetching surf reports

## Performance Benefits

1. **Reduced API calls**: Images are served from cache when available
2. **Faster loading**: Cached images load instantly
3. **Better user experience**: No waiting for image downloads
4. **Offline capability**: Images remain available even without network
5. **Memory efficiency**: Smart memory management with disk persistence

## Memory Management

- **Memory pressure handling**: Automatically reduces memory usage when needed
- **LRU eviction**: Keeps most recently used images in memory
- **Disk persistence**: All images are safely stored on disk
- **Automatic cleanup**: Expired entries are removed automatically

## App Lifecycle

- **Background**: Cache is saved to disk and cleaned up
- **Foreground**: Cache is reloaded from disk
- **Memory warning**: Memory cache is reduced to essential images
- **Termination**: All cache data is safely persisted

## Debugging

### Cache Testing

```swift
// Test the entire cache system
dataStore.testImageCache()
```

### Cache Information

```swift
// Get comprehensive cache information
let cacheInfo = dataStore.exportImageCacheInfo()
print(cacheInfo)
```

### Logging

The system provides detailed logging for:

- Cache hits and misses
- Memory pressure events
- App lifecycle transitions
- Cache cleanup operations

## Configuration

### Cache Duration

Images are cached for 30 days by default. This can be modified in `CachedImageData.isExpired`:

```swift
var isExpired: Bool {
    // Cache images for 30 days since they never change
    let cacheExpirationInterval: TimeInterval = 30 * 24 * 60 * 60
    return Date().timeIntervalSince(timestamp) > cacheExpirationInterval
}
```

### Memory Limits

The system automatically manages memory usage:

- Keeps up to 10 most recent images in memory during normal operation
- Reduces to essential images during memory pressure
- All images remain available on disk

## Best Practices

1. **Let the system handle caching automatically** - no manual intervention needed
2. **Use cache statistics for monitoring** - helps identify performance issues
3. **Clear cache when needed** - useful for debugging or forcing refresh
4. **Monitor memory usage** - the system handles this automatically
5. **Test cache functionality** - use the built-in test methods

## Troubleshooting

### Common Issues

1. **Images not loading**: Check if cache is cleared or expired
2. **High memory usage**: System automatically handles memory pressure
3. **Cache not persisting**: Verify disk permissions and storage space

### Debug Commands

```swift
// Check cache status
let stats = dataStore.getImageCacheStats()
print(stats)

// Test cache functionality
dataStore.testImageCache()

// Clear cache if needed
dataStore.clearImageCache()

// Export cache information
let info = dataStore.exportImageCacheInfo()
print(info)
```

## Future Enhancements

1. **Image compression**: Automatic image optimization
2. **Network preloading**: Proactive image downloading
3. **Cache warming**: Pre-populate cache with frequently accessed images
4. **Analytics**: Track cache hit rates and performance metrics
5. **Cloud sync**: Share cache across devices (if needed)
