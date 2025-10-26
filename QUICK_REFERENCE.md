# Loading Animations - Quick Reference Guide

## 🎯 Quick Component Reference

### Skeleton Cards (Pre-built)

#### List Card (Buoys, Spots, etc.)

```swift
SkeletonListCard()
```

**Use for**: Vertical lists with icon, title, subtitle, and metadata

#### Report Card

```swift
SkeletonReportCard()
```

**Use for**: Horizontal scrolling report cards (160x180)

#### Buoy Card

```swift
SkeletonBuoyCard()
```

**Use for**: Grid layout buoy data cards

#### Current Conditions Card

```swift
SkeletonCurrentConditions()
    .padding(.horizontal)
```

**Use for**: Large prominent condition displays

### Basic Skeleton Elements

#### Generic Shape

```swift
SkeletonShape(cornerRadius: 12)
    .frame(width: 200, height: 100)
```

#### Circle

```swift
SkeletonCircle()
    .frame(width: 60, height: 60)
```

#### Line/Text

```swift
SkeletonLine(height: 16, width: 120)
```

### Loading Indicators

#### Glass Spinner with Message

```swift
GlassLoadingIndicator("Loading data...")
```

#### Error Alert

```swift
GlassErrorAlert(
    title: "Error",
    message: "Something went wrong"
) {
    // Retry action
    viewModel.retry()
}
```

## 🔧 Common Patterns

### Pattern 1: Basic Loading State

```swift
if viewModel.isLoading {
    SkeletonListCard()
} else {
    ActualContent()
}
```

### Pattern 2: Loading with Animation

```swift
if viewModel.isLoading {
    SkeletonListCard()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
} else {
    ActualContent()
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
}
.animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
```

### Pattern 3: Multiple Skeletons

```swift
if viewModel.isLoading {
    ForEach(0..<3, id: \.self) { _ in
        SkeletonListCard()
    }
}
```

### Pattern 4: Loading + Empty + Content

```swift
if viewModel.isLoading {
    // Loading state
    SkeletonListCard()
} else if viewModel.items.isEmpty {
    // Empty state
    VStack(spacing: 12) {
        Image(systemName: "exclamationmark.circle")
            .font(.system(size: 48))
            .foregroundColor(.secondary)
        Text("No items found")
            .font(.headline)
            .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
} else {
    // Content
    ForEach(viewModel.items) { item in
        ItemCard(item: item)
    }
}
```

### Pattern 5: Pull-to-Refresh

```swift
ScrollView {
    LazyVStack(spacing: 16) {
        if viewModel.isRefreshing {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonListCard()
            }
        } else {
            ForEach(viewModel.items) { item in
                ItemCard(item: item)
            }
        }
    }
}
.refreshable {
    await viewModel.refresh()
}
```

## 📱 View-Specific Examples

### BuoysView Style

```swift
private var buoyListView: some View {
    ScrollView {
        LazyVStack(spacing: 16) {
            if viewModel.isRefreshing {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonListCard()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else if viewModel.buoys.isEmpty {
                emptyStateView
            } else {
                ForEach(viewModel.buoys) { buoy in
                    BuoyCard(buoy: buoy)
                        .transition(.opacity.combined(with: .scale(scale: 0.95)))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.isRefreshing)
    }
    .refreshable {
        await viewModel.refreshBuoys()
    }
}
```

### HomeView Style (Horizontal Scroll)

```swift
ScrollView(.horizontal, showsIndicators: false) {
    HStack(alignment: .top, spacing: 15) {
        if viewModel.isLoadingReports {
            ForEach(0..<3, id: \.self) { _ in
                SkeletonReportCard()
            }
        } else {
            ForEach(viewModel.reports) { report in
                ReportCard(report: report)
            }
        }
    }
    .padding(.horizontal)
}
```

### MapView Style

```swift
if viewModel.isLoading {
    VStack {
        GlassLoadingIndicator("Loading map data...")
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    .padding(.top, 100)
    .animation(.easeInOut(duration: 0.3), value: viewModel.isLoading)
}
```

## 🎨 Custom Skeleton Builder

### Building a Custom Skeleton

```swift
struct CustomSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            // Icon
            SkeletonCircle()
                .frame(width: 40, height: 40)

            // Content
            VStack(alignment: .leading, spacing: 6) {
                SkeletonLine(height: 16, width: 180)
                SkeletonLine(height: 14, width: 120)

                HStack(spacing: 8) {
                    SkeletonLine(height: 12, width: 60)
                    SkeletonLine(height: 12, width: 60)
                }
            }

            Spacer()

            // Action indicator
            SkeletonShape(cornerRadius: 4)
                .frame(width: 8, height: 14)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.quaternary, lineWidth: 0.5)
                )
        )
    }
}
```

## 📊 Grid Layouts

### 2-Column Grid

```swift
LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 16) {
    if viewModel.isLoading {
        ForEach(0..<2, id: \.self) { _ in
            SkeletonBuoyCard()
        }
    } else {
        ForEach(viewModel.items) { item in
            ItemCard(item: item)
        }
    }
}
```

## 🎭 Animation Timing

### Standard Timings

```swift
// Quick transitions (most common)
.animation(.easeInOut(duration: 0.3), value: isLoading)

// Slower, more dramatic
.animation(.easeInOut(duration: 0.5), value: isLoading)

// Instant (no animation)
.animation(nil, value: isLoading)
```

### Transition Styles

```swift
// Fade only
.transition(.opacity)

// Fade + Scale (recommended)
.transition(.opacity.combined(with: .scale(scale: 0.95)))

// Slide + Fade
.transition(.slide.combined(with: .opacity))

// Move
.transition(.move(edge: .leading))
```

## 🎯 Empty State Template

```swift
var emptyStateView: some View {
    VStack(spacing: 12) {
        Image(systemName: "icon.name")
            .font(.system(size: 48))
            .foregroundColor(.secondary)

        Text("Main Message")
            .font(.headline)
            .foregroundColor(.secondary)

        Text("Helpful hint")
            .font(.caption)
            .foregroundColor(.tertiary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 60)
    .background(
        RoundedRectangle(cornerRadius: 16)
            .fill(.ultraThinMaterial)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(.quaternary, lineWidth: 0.5)
            )
    )
}
```

## 🔄 ViewModel Pattern

```swift
@MainActor
class MyViewModel: ObservableObject {
    @Published var items: [Item] = []
    @Published var isLoading: Bool = false

    func loadData() async {
        isLoading = true
        defer { isLoading = false }

        do {
            items = try await fetchItems()
        } catch {
            print("Error: \(error)")
        }
    }
}
```

## 📝 Checklist for New Views

When adding loading states to a new view:

- [ ] Add `@Published var isLoading: Bool = false` to ViewModel
- [ ] Set `isLoading = true` at start of fetch
- [ ] Set `isLoading = false` in defer or completion
- [ ] Choose appropriate skeleton component
- [ ] Add loading state condition
- [ ] Add empty state condition
- [ ] Add content state condition
- [ ] Add transitions to all states
- [ ] Add animation with value tracking
- [ ] Test loading → content flow
- [ ] Test loading → empty flow
- [ ] Test pull-to-refresh (if applicable)

## 🚀 Performance Tips

1. **Use Lazy Loading**: `LazyVStack` and `LazyVGrid` for lists
2. **Limit Skeleton Count**: Show 3-4 items max
3. **Reuse Components**: Don't create custom skeletons unless needed
4. **Track Specific Values**: `.animation(.., value: specificProperty)`
5. **Avoid Nested Animations**: One animation per hierarchy level

## 🎨 SF Symbols for Empty States

Common icons for different scenarios:

- No data: `exclamationmark.circle`, `tray`
- No network: `wifi.slash`, `antenna.radiowaves.left.and.right.slash`
- No results: `magnifyingglass`, `doc.text.magnifyingglass`
- No location: `location.slash`, `mappin.slash`
- No buoys: `water.waves.slash`
- No reports: `doc.text`, `doc.plaintext`
- No spots: `mappin.slash`, `map`

## ✅ Validation

Your implementation is correct if:

1. ✅ Skeleton appears immediately when loading starts
2. ✅ Content fades in smoothly when data arrives
3. ✅ Empty state shows when no data available
4. ✅ No visual "pop" or jarring transitions
5. ✅ Pull-to-refresh shows skeletons
6. ✅ No linter errors
7. ✅ Follows liquid glass aesthetic

---

**Need help?** Check `LOADING_ANIMATIONS.md` for detailed documentation or `IMPLEMENTATION_SUMMARY.md` for examples from the existing implementation.
