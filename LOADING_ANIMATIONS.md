# Loading Animations & Skeleton System

## Overview

This document describes the comprehensive loading animation and skeleton system implemented across the TrebleSurf app, following iOS 26 Liquid Glass design patterns and Swift best practices.

## Design Philosophy

The loading system follows these key principles:

1. **Consistency**: All loading states use the same design language
2. **Performance**: Animations are optimized using SwiftUI best practices
3. **Accessibility**: Loading states are descriptive and meaningful
4. **Liquid Glass Aesthetic**: Uses `.ultraThinMaterial` with subtle borders and shimmer effects
5. **Smooth Transitions**: All state changes include appropriate animations

## Core Components

### 1. Shimmer Effect (`LiquidGlassComponents.swift`)

The shimmer effect provides a smooth, animated gradient that sweeps across skeleton elements:

```swift
.shimmer(duration: 1.5, bounce: false)
```

**Features:**

- Customizable duration
- Optional bounce effect
- Linear gradient with opacity variations
- Infinite repeat animation

### 2. Skeleton Shapes

#### SkeletonShape

Generic rounded rectangle skeleton with shimmer effect.

```swift
SkeletonShape(cornerRadius: 8)
```

#### SkeletonCircle

Circular skeleton element for avatars and icons.

```swift
SkeletonCircle()
    .frame(width: 60, height: 60)
```

#### SkeletonLine

Line-based skeleton for text placeholders.

```swift
SkeletonLine(height: 12, width: 150, cornerRadius: 6)
```

### 3. Specialized Skeleton Cards

#### SkeletonListCard

Full card skeleton for list items (buoys, spots, etc.)

**Use case:**

- BuoysView list items
- SpotsView list items
- Any vertical scrolling list

**Visual structure:**

- Circular icon placeholder (60x60)
- Title line (150px width)
- Subtitle line (100px width)
- Two metadata lines (60px each)
- Chevron indicator

#### SkeletonReportCard

Horizontal card skeleton for surf reports.

**Use case:**

- HomeView recent reports section
- Horizontal scrolling report lists

**Visual structure:**

- Media area (160x100)
- Title line
- Metadata lines with separator
- Secondary information

#### SkeletonBuoyCard

Grid-based skeleton for weather buoy cards.

**Use case:**

- HomeView weather buoys section
- Grid layouts displaying buoy data

**Visual structure:**

- Header with icon and name
- 2x2 grid of data points
- Each cell has value and label placeholders

#### SkeletonCurrentConditions

Large card skeleton for current conditions display.

**Use case:**

- HomeView current conditions section
- Prominent data displays

**Visual structure:**

- Header line
- Three-column data layout
- Summary text line

### 4. Enhanced Loading Indicators

#### GlassLoadingIndicator

Animated circular progress indicator with message.

**Features:**

- Custom circular animation
- Liquid glass background
- Configurable message
- Scales appropriately for context

**Usage:**

```swift
GlassLoadingIndicator("Loading map data...")
```

#### GlassErrorAlert

Error state with retry functionality.

**Features:**

- Icon, title, and message display
- Retry button with glass styling
- Consistent error presentation

**Usage:**

```swift
GlassErrorAlert(
    title: "Error",
    message: "Something went wrong"
) {
    // Retry action
}
```

## Implementation Across Views

### BuoysView

**Loading States:**

- Initial load: Shows 3 `SkeletonListCard` instances
- Empty state: Custom glass card with icon and message
- Refresh: Animated skeleton cards

**Animations:**

- Opacity + scale transition (0.95)
- 0.3s ease-in-out timing
- Tracks `isRefreshing` state

**Code Pattern:**

```swift
if viewModel.isRefreshing {
    ForEach(0..<3, id: \.self) { _ in
        SkeletonListCard()
    }
    .transition(.opacity.combined(with: .scale(scale: 0.95)))
}
```

### HomeView

**Loading States:**

1. **Current Conditions**: `SkeletonCurrentConditions`
2. **Recent Reports**: 3 `SkeletonReportCard` instances in horizontal scroll
3. **Weather Buoys**: 2 `SkeletonBuoyCard` instances in grid

**ViewModel Updates:**

- Added `isLoadingReports` property
- Added `isLoadingBuoys` property
- Proper state management in fetch methods

**Empty States:**

- Reports: "No recent reports" with icon
- Buoys: "No buoy data available" with icon

### SpotsView

**Loading States:**

- Initial load: Shows 4 `SkeletonListCard` instances
- Empty state: Custom glass card with map icon
- Pull-to-refresh support

**Features:**

- Smooth animations on count changes
- Consistent with BuoysView pattern

### MapView

**Loading States:**

- Map data loading: `GlassLoadingIndicator`
- Error state: `GlassErrorAlert` with retry

**Improvements:**

- Replaced basic `ProgressView` with enhanced glass loader
- Added smooth transitions and animations
- Better error handling UI

### BuoyDetailView

**Loading States:**

1. **Current Readings**: 6-cell skeleton grid
2. **Wave Chart**: Custom chart skeleton with axes
3. **Empty States**: Meaningful icons and messages

**Features:**

- Per-section skeleton loaders
- Smooth transitions when data loads
- iOS version compatibility handling

### SpotDetailView

**Loading States:**

- Refresh indicator: Custom animated spinner

**Features:**

- Compact inline spinner
- Matches liquid glass aesthetic
- Smooth rotation animation

## Animation Guidelines

### Timing

- **Standard Duration**: 0.3s for most transitions
- **Shimmer Duration**: 1.5s for skeleton animations
- **Spinner Duration**: 1.0s for loading indicators

### Easing

- **Standard**: `.easeInOut` for most transitions
- **Continuous**: `.linear` for infinite animations

### Scale Effects

- **Subtle Scale**: 0.95 for appearing/disappearing elements
- Prevents jarring pop-in effects

### Transition Combinations

```swift
.transition(.opacity.combined(with: .scale(scale: 0.95)))
```

## Best Practices

### 1. Always Include Loading States

Every view that fetches data should have:

- Loading skeleton
- Loaded content
- Empty state
- Error state (where applicable)

### 2. Match Skeleton to Content

Skeleton layouts should closely match the actual content structure:

- Same spacing
- Same card sizes
- Same visual hierarchy

### 3. Use Appropriate Skeleton Count

Show a realistic number of skeleton items:

- 3-4 for full-screen lists
- 2-3 for grid layouts
- 1 for single prominent items

### 4. Transition Management

```swift
// Track loading state
.animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)

// Apply transitions
.transition(.opacity.combined(with: .scale(scale: 0.95)))
```

### 5. Empty State Design

Empty states should:

- Use SF Symbols icons
- Provide clear messaging
- Match liquid glass aesthetic
- Include actionable hints (e.g., "Pull to refresh")

## Performance Considerations

### Lazy Loading

Use `LazyVStack` and `LazyVGrid` for skeleton lists:

```swift
LazyVStack(spacing: 16) {
    ForEach(0..<3, id: \.self) { _ in
        SkeletonListCard()
    }
}
```

### Animation Optimization

- Shimmer animations use `onAppear` trigger
- Minimal redraw with `GeometryReader`
- Efficient gradient calculations

### State Management

- Use `@Published` properties for loading states
- Update on main thread with `@MainActor`
- Proper cleanup in Combine subscriptions

## Accessibility

### VoiceOver Support

Loading states are announced appropriately:

- "Loading..." messages are read
- Empty states provide clear information
- Error messages are descriptive

### Reduced Motion

The system respects user preferences:

- Animations can be disabled system-wide
- Core functionality remains accessible

## Testing

### Visual Testing

1. **Initial Load**: Verify skeletons appear immediately
2. **Transition**: Check smooth fade-in when data arrives
3. **Empty State**: Confirm appropriate messaging
4. **Error State**: Verify error handling UI
5. **Pull to Refresh**: Test loading indicators during refresh

### State Testing

- Fast network: Verify skeleton briefly visible
- Slow network: Verify skeleton persists appropriately
- No data: Verify empty state displays
- Error: Verify error UI with retry option

## Future Enhancements

### Potential Additions

1. **Staggered Animations**: Cards appear with slight delay
2. **Pulse Animation**: Alternative to shimmer for some contexts
3. **Progress Indicators**: Show actual progress for known durations
4. **Smart Preloading**: Predictive skeleton display

### Customization Options

- Theme-aware skeleton colors
- Adjustable animation speeds
- Custom skeleton templates per view

## Migration Guide

### Adding Loading States to New Views

1. **Import Components**:

```swift
import SwiftUI
// LiquidGlassComponents are automatically available
```

2. **Add Loading State**:

```swift
@Published var isLoading: Bool = true
```

3. **Implement Skeleton**:

```swift
if isLoading {
    SkeletonListCard()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
} else {
    // Actual content
}
```

4. **Add Animation**:

```swift
.animation(.easeInOut(duration: 0.3), value: isLoading)
```

## Summary

This comprehensive loading animation system provides:

- ✅ Consistent user experience across the app
- ✅ Professional, polished appearance
- ✅ iOS 26 liquid glass aesthetic compliance
- ✅ Swift best practices implementation
- ✅ Accessible and performant
- ✅ Easy to maintain and extend

The system is now implemented across all major views: BuoysView, HomeView, SpotsView, MapView, BuoyDetailView, and SpotDetailView.
