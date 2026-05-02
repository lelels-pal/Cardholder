# Light Mode Conversion Plan for CardiKeep Dashboard

## Overview
Convert the entire CardiKeep application from dark mode to light mode, ensuring consistent styling across all screens and widgets.

## Current Dark Mode Implementation

### Color Palette (lib/constants.dart)
- **Background**: `0xFF0F172A` (Dark Blue)
- **Card Background**: `0xFF1E293B` (Slightly lighter blue)
- **Primary**: `0xFF10B981` (Green)
- **Text Primary**: `Colors.white`
- **Text Secondary**: `Colors.grey`

### Theme Configuration (lib/main.dart)
- `brightness: Brightness.dark`
- `scaffoldBackgroundColor: AppColors.background`
- `primaryColor: AppColors.primary`

### Map Tile Layer (lib/screens/home_screen.dart)
- Dark map tiles: `https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png`

---

## Proposed Light Mode Color Palette

### New Colors for lib/constants.dart
```dart
class AppColors {
  // Light Mode Colors
  static const Color background = Color(0xFFF8FAFC);      // Light gray/white
  static const Color cardBackground = Color(0xFFFFFFFF);  // Pure white
  static const Color primary = Color(0xFF10B981);         // Keep green (brand color)
  static const Color textPrimary = Color(0xFF1E293B);     // Dark blue/gray
  static const Color textSecondary = Color(0xFF64748B);   // Medium gray
  
  // Additional light mode colors
  static const Color border = Color(0xFFE2E8F0);          // Light border
  static const Color shadow = Color(0x1A000000);          // Subtle shadow
}
```

---

## Files to Modify

### 1. lib/constants.dart
**Changes:**
- Update `background` from dark blue to light gray
- Update `cardBackground` from dark blue to white
- Update `textPrimary` from white to dark blue/gray
- Update `textSecondary` from grey to medium gray
- Add new `border` and `shadow` colors for light mode

### 2. lib/main.dart
**Changes:**
- Change `brightness: Brightness.dark` to `brightness: Brightness.light`
- Update `scaffoldBackgroundColor` to use new light background
- Add `colorScheme` for better Material 3 support

### 3. lib/screens/home_screen.dart (Dashboard)
**Changes:**
- Update all `Colors.white` references to `AppColors.textPrimary`
- Update all `Colors.grey` references to `AppColors.textSecondary`
- Update map tile layer from dark to light: `https://{s}.basemaps.cartocdn.com/light_all/{z}/{x}/{y}{r}.png`
- Update `ColorFilter.matrix` for light mode map appearance
- Update container borders and shadows for light mode
- Update switch colors for light mode visibility

**Specific sections to update:**
- Anti-Loss Mode Header (lines 318-394)
- Debug Info (lines 396-413)
- Map Area container (lines 416-594)
- Status Cards Row (lines 597-725)
- Navigate Button (lines 728-755)
- Alarm and GPS Status Row (lines 758-889)

### 4. lib/screens/settings_screen.dart
**Changes:**
- Update title text color from `Colors.white` to `AppColors.textPrimary`
- Update subtitle text color from `Colors.grey` to `AppColors.textSecondary`
- Update profile card border from `Colors.white.withValues(alpha: 0.05)` to `AppColors.border`
- Update divider color from `Colors.white10` to `AppColors.border`
- Update info row label color from `Colors.grey[400]` to `AppColors.textSecondary`
- Update info row value color from `Colors.white` to `AppColors.textPrimary`

### 5. lib/screens/login_screen.dart
**Changes:**
- Update background color reference
- Update text field text color from `AppColors.textPrimary` (white) to dark
- Update label style color
- Update border colors for light mode
- Update fill color for text fields

### 6. lib/screens/signup_screen.dart
**Changes:**
- Same as login_screen.dart
- Update back button icon color

### 7. lib/widgets/status_card.dart
**Changes:**
- Update title text color from `Colors.grey` to `AppColors.textSecondary`
- Update value text color from `Colors.white` to `AppColors.textPrimary`
- Update icon container background from `AppColors.background` to light variant

### 8. lib/widgets/history_item.dart
**Changes:**
- Update title text color from `Colors.white` to `AppColors.textPrimary`
- Update address text color from `Colors.grey[400]` to `AppColors.textSecondary`
- Update date text color from `Colors.grey[600]` to `AppColors.textSecondary`
- Update border color from `Colors.white.withValues(alpha: 0.05)` to `AppColors.border`
- Update icon container background from `AppColors.background` to light variant

### 9. lib/screens/tracking_screen.dart
**Changes:**
- Update map tile layer to light mode
- Update button colors for better visibility on light background
- Update any hardcoded colors

### 10. lib/screens/scan_screen.dart
**Changes:**
- Minimal changes needed (uses AppBar theme)
- Verify AppBar colors work with light mode

---

## Implementation Strategy

### Phase 1: Core Color System
1. Update `lib/constants.dart` with new light mode palette
2. Update `lib/main.dart` theme configuration

### Phase 2: Dashboard (Home Screen)
3. Update `lib/screens/home_screen.dart` - This is the primary focus
   - Update map tile layer
   - Update all text colors
   - Update container backgrounds and borders
   - Update switch and button colors

### Phase 3: Other Screens
4. Update `lib/screens/settings_screen.dart`
5. Update `lib/screens/login_screen.dart`
6. Update `lib/screens/signup_screen.dart`
7. Update `lib/screens/tracking_screen.dart`
8. Update `lib/screens/scan_screen.dart`

### Phase 4: Widgets
9. Update `lib/widgets/status_card.dart`
10. Update `lib/widgets/history_item.dart`

### Phase 5: Testing & Refinement
11. Test all screens for visual consistency
12. Adjust colors as needed for readability
13. Ensure proper contrast ratios for accessibility

---

## Key Considerations

### Contrast & Accessibility
- Ensure text has sufficient contrast against backgrounds (WCAG AA standard)
- Primary green color should remain visible on light backgrounds
- Interactive elements (buttons, switches) should be clearly distinguishable

### Map Integration
- Switch from dark map tiles to light map tiles
- Adjust `ColorFilter.matrix` values for light mode
- Ensure markers and circles remain visible on light map

### Brand Consistency
- Keep the primary green color (`0xFF10B981`) as the brand accent
- Maintain visual hierarchy with appropriate gray shades
- Ensure cards and containers have subtle shadows for depth

### State Indicators
- Battery level colors (green/red) should remain the same
- GPS status colors should remain the same
- Alarm state (red gradient) should remain the same

---

## Testing Checklist

- [ ] Dashboard loads with light background
- [ ] Map displays with light tiles
- [ ] All text is readable with proper contrast
- [ ] Cards have visible borders and subtle shadows
- [ ] Buttons and switches are clearly visible
- [ ] Status indicators (battery, GPS, signal) are visible
- [ ] Navigation bar works with light theme
- [ ] Settings screen displays correctly
- [ ] Login/Signup screens display correctly
- [ ] Tracking screen map is visible
- [ ] Scan screen works properly
- [ ] No dark mode artifacts remain

---

## Estimated Changes Summary

| File | Lines Changed | Complexity |
|------|---------------|------------|
| lib/constants.dart | ~10 lines | Low |
| lib/main.dart | ~5 lines | Low |
| lib/screens/home_screen.dart | ~150 lines | High |
| lib/screens/settings_screen.dart | ~20 lines | Medium |
| lib/screens/login_screen.dart | ~30 lines | Medium |
| lib/screens/signup_screen.dart | ~30 lines | Medium |
| lib/widgets/status_card.dart | ~10 lines | Low |
| lib/widgets/history_item.dart | ~15 lines | Low |
| lib/screens/tracking_screen.dart | ~20 lines | Medium |
| lib/screens/scan_screen.dart | ~5 lines | Low |

**Total Estimated Changes: ~295 lines**

---

## Notes

- The primary green color (`0xFF10B981`) will be retained as it's the brand color
- All `Colors.white` references will be replaced with appropriate dark text colors
- All `Colors.grey` references will be replaced with medium gray shades
- Map tile layer will be switched from `dark_all` to `light_all`
- Container backgrounds will change from dark blue to white with subtle borders
- Shadows will be added for depth in light mode
