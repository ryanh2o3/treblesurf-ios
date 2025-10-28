# TrebleSurf Codebase Refactoring Plan

## 🔴 Critical Issues

### 1. Singleton Overuse & Tight Coupling

**Problem:** Almost every service uses the singleton pattern (`.shared`), creating tight coupling and making testing nearly impossible.

**Affected Components:**

- `AuthManager.shared`
- `DataStore.shared`
- `SettingsStore.shared`
- `APIClient.shared`
- `BuoyCacheService.shared`
- `ImageCacheService.shared`
- `WeatherBuoyService.shared`

**Impact:**

- Cannot inject mock dependencies for testing
- Difficult to isolate components
- Global mutable state
- Hidden dependencies

**Fix:** Implement proper dependency injection through constructor injection and use `AppDependencies` container consistently.

---

### 2. Broken SwiftUI Lifecycle with @StateObject

**Problem:** ViewModels are directly instantiated in views, breaking SwiftUI's lifecycle management.

**Impact:**

- ViewModels recreated unnecessarily
- Lost state on view recreation
- Memory leaks potential
- Unpredictable behavior

**Fix:** Use `@StateObject` with properly injected dependencies via environment objects or constructor parameters.

---

### 3. Inconsistent Async Patterns

**Problem:** Mixing completion handlers with async/await creates confusion and technical debt.

**Examples:**

- `APIClient` uses completion handlers everywhere
- ViewModels use async/await
- Excessive wrapping in `Task { @MainActor in }`

**Fix:**

- Convert all `APIClient` methods to async/await
- Remove completion handler wrappers
- Use structured concurrency throughout

---

## 🟡 Major Issues

### 4. Massive View Files

**Problem:** Views are too large and contain business logic.

**Examples:**

- `HomeView.swift`: 927 lines
- `BuoysView.swift`: 239 lines (better but still large)
- Multiple concerns in single files

**Fix:** Break into smaller, focused components:

- Separate view components
- Extract subviews
- Move business logic to ViewModels
- Create reusable UI components

---

### 5. Massive APIClient File

**Problem:** `APIClient.swift` is 931 lines with multiple responsibilities.

**Fix:** Break into protocol-based services:

- `SpotService`
- `BuoyService`
- `ForecastService`
- `WeatherService`
- `AuthService`

---

### 6. Inconsistent Error Handling

**Problem:** Errors are handled inconsistently throughout the codebase.

**Issues:**

- Different error types in different layers
- Inconsistent user feedback
- No centralized error logging
- Mixed error propagation strategies

**Fix:** Create a centralized error handling system with:

- Unified error types
- Consistent user messaging
- Centralized logging
- Standardized error recovery

---

### 7. Model Organization Issues

**Problem:** Models defined in wrong places.

**Issues:**

- Models scattered across different files
- Inconsistent naming conventions
- Mixed concerns (API responses vs domain models)

**Fix:**

- Move all models to the `Models` folder
- Separate API response models from domain models
- Ensure consistent structure and naming

---

### 8. Unused Dependency Container

**Problem:** `AppDependencies` exists but isn't used consistently.

**Fix:**

- Fully implement dependency injection using `AppDependencies`
- Remove singleton pattern usage
- Inject dependencies through environment or constructors

---

## 🟢 Medium Priority Issues

### 9. Memory Management Concerns

**Problem:** Inconsistent use of `[weak self]` in closures.

**Fix:** Always use `[weak self]` in async closures or document why it's not needed.

---

### 10. Concurrency Annotations

**Problem:** Mixing `@MainActor`, `nonisolated`, and `nonisolated(unsafe)` inconsistently.

**Fix:** Use proper Swift 6 concurrency:

- Mark ViewModels with `@MainActor`
- Use `@MainActor` on UI-updating methods
- Properly isolate background work
- Remove `nonisolated(unsafe)` unless absolutely necessary

---

### 11. Hardcoded Values

**Problem:** Magic strings and values scattered throughout.

**Examples:**

- API endpoints
- Configuration values
- Color values
- String literals

**Fix:** Use configuration or constants files with proper organization.

---

### 12. Cache Management Complexity

**Problem:** Multiple overlapping cache systems with manual management.

**Issues:**

- `BuoyCacheService`
- `ImageCacheService`
- Manual cache invalidation
- No unified strategy

**Fix:** Create a unified caching layer with:

- Generic cache protocol
- Automatic expiration
- Memory management
- Unified invalidation strategy

---

## 📋 Recommended Action Plan

### Phase 1: Foundation (Week 1-2)

- [ ] Convert `APIClient` to async/await
- [ ] Establish proper dependency injection pattern
- [ ] Create centralized error handling
- [ ] Set up proper environment configuration

### Phase 2: Architecture (Week 3-4)

- [ ] Remove singleton dependencies from ViewModels
- [ ] Properly inject ViewModels into Views
- [ ] Break up large files into focused components
- [ ] Implement protocol-based service architecture

### Phase 3: Refinement (Week 5-6)

- [ ] Consolidate cache implementations
- [ ] Add comprehensive error handling
- [ ] Add unit tests for critical paths
- [ ] Document architecture decisions
- [ ] Clean up concurrency annotations
- [ ] Remove hardcoded values

---

## 🎯 Success Metrics

- [ ] All services use dependency injection instead of singletons
- [ ] No view file exceeds 300 lines
- [ ] All async operations use async/await (no completion handlers)
- [ ] 80%+ test coverage for business logic
- [ ] Centralized error handling with consistent UX
- [ ] All concurrency properly annotated for Swift 6
- [ ] Zero `nonisolated(unsafe)` usages

---

## 📚 Additional Notes

- Prioritize backwards compatibility where possible
- Consider incremental migration strategy
- Document all architectural decisions
- Create migration guides for team members
- Set up linting rules to prevent regression
