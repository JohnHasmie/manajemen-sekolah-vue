# 🎨 Design System Guide - Kamil Edu Professional Style

**Last Updated:** 2026-02-16
**Reference:** Kamil Edu Dashboard Design
**Applied To:** Dashboard redesign (complete)

This document outlines the complete design system used for the professional dashboard redesign. Use these patterns and rules when redesigning other pages to maintain visual consistency.

---

## 📐 Design Principles

### 1. **Professional & Corporate**
- Clean, minimal interface with purposeful elements
- Corporate blue palette (deep blues, not bright)
- Subtle, layered shadows for depth
- Consistent spacing and breathing room

### 2. **Visual Hierarchy**
- Clear distinction between sections
- Prominent headers (16px w700)
- Progressive disclosure (expandable categories)
- Icon + text combinations for scannability

### 3. **Modern UI/UX**
- Glass morphism effects (subtle transparency)
- Decorative elements (circles, gradients)
- Smooth animations (300ms standard)
- Layered shadows (never single shadow)

---

## 🎨 Color Palette

### Primary Colors
```dart
// Deep Professional Blue
ColorUtils.kamilPrimary = Color(0xFF143068)

// Vibrant Teal Accent
ColorUtils.kamilAccent = Color(0xFF21AFE6)

// Light Backgrounds
ColorUtils.kamilPrimaryLight = Color(0xFFE8EEF7)
ColorUtils.kamilAccentLight = Color(0xFFE6F7FD)
```

### Corporate Blues
```dart
ColorUtils.corporateBlue900 = Color(0xFF1E3A8A)  // Darkest (headings)
ColorUtils.corporateBlue700 = Color(0xFF1D4ED8)  // Primary actions
ColorUtils.corporateBlue600 = Color(0xFF2563EB)  // Interactive
ColorUtils.corporateBlue500 = Color(0xFF3B82F6)  // Hover states
ColorUtils.corporateBlue100 = Color(0xFFDBEAFE)  // Light backgrounds
```

### Neutral Grays (Slate Scale)
```dart
ColorUtils.slate900 = Color(0xFF0F172A)  // Primary text
ColorUtils.slate700 = Color(0xFF334155)  // Secondary text
ColorUtils.slate600 = Color(0xFF475569)  // Tertiary text
ColorUtils.slate500 = Color(0xFF64748B)  // Disabled text
ColorUtils.slate400 = Color(0xFF94A3B8)  // Icons, dividers
ColorUtils.slate300 = Color(0xFFCBD5E1)  // Borders
ColorUtils.slate200 = Color(0xFFE2E8F0)  // Light borders
ColorUtils.slate50 = Color(0xFFF8FAFC)   // Page background
```

### Semantic Colors
```dart
ColorUtils.success600 = Color(0xFF059669)  // Green
ColorUtils.warning600 = Color(0xFFD97706)  // Orange
ColorUtils.error600 = Color(0xFFDC2626)    // Red
ColorUtils.info600 = Color(0xFF0891B2)     // Cyan
```

### Usage Rules
- **Primary text:** Always `slate900`
- **Secondary text:** `slate600` or `slate700`
- **Borders:** `slate200` (light) or `slate300` (prominent)
- **Backgrounds:** White or `slate50`
- **Interactive elements:** `corporateBlue600` or role-based colors
- **Badges/notifications:** `error600` with white text

---

## ✍️ Typography System

### Font Weights
```dart
FontWeight.w400  // Regular (body text)
FontWeight.w500  // Medium (labels, captions)
FontWeight.w600  // Semi-bold (subtitles)
FontWeight.w700  // Bold (headers, titles)
FontWeight.w800  // Extra-bold (hero values)
```

### Text Styles

#### Headers
```dart
// Main page title (24px, w700, slate900)
DashboardTypography.heading1()

// Section headers (20px, w600, slate900)
DashboardTypography.heading2()

// Sub-section headers (18px, w600, slate900)
DashboardTypography.heading3()

// Section titles - STANDARD for all sections (16px, w700, slate900)
TextStyle(
  fontSize: 16,
  fontWeight: FontWeight.w700,
  color: ColorUtils.slate900,
)
```

#### Body Text
```dart
// Primary body (14px, w400, slate700)
DashboardTypography.body()

// Bold body (14px, w600, slate900)
DashboardTypography.bodyBold()

// Subtitles (14px, w500, slate600)
DashboardTypography.subtitle()
```

#### Small Text
```dart
// Captions (12px, w400, slate500)
DashboardTypography.caption()

// Bold captions (12px, w600, slate700)
DashboardTypography.captionBold()

// Labels (10px, w500, slate600, letterSpacing: 0.5)
DashboardTypography.label()
```

#### Specialized
```dart
// Category titles (12px, w700, letterSpacing: 0.8)
DashboardTypography.categoryTitle()

// Menu card titles (14px, w700, letterSpacing: -0.1)
TextStyle(
  fontSize: 14,
  fontWeight: FontWeight.w700,
  color: ColorUtils.slate900,
  letterSpacing: -0.1,
)

// Stat values (20px, w800, letterSpacing: -0.3)
TextStyle(
  fontSize: 20,
  fontWeight: FontWeight.w800,
  color: ColorUtils.slate900,
  letterSpacing: -0.3,
)
```

### Typography Rules
1. **Letter spacing:**
   - Tight (-0.3 to -0.1) for large/bold text
   - Normal (0) for body text
   - Wide (0.5-0.8) for small caps/labels
2. **Line height:**
   - Tight (1.1) for numbers/values
   - Normal (1.3-1.4) for body text
   - Relaxed (1.5) for long paragraphs
3. **Max lines:**
   - Titles: 1-2 lines with ellipsis
   - Body: 2-3 lines in cards
   - Full text in detail views

---

## 📏 Spacing System

### Base Unit: 4px Grid
All spacing should follow a 4px grid system.

### Common Spacing Values
```dart
// Micro spacing
4px   // Minimal gap between related items
6px   // Tight vertical spacing
8px   // Standard small gap

// Standard spacing
10px  // Horizontal spacing in containers
12px  // Standard horizontal padding
14px  // Component internal padding
16px  // Large padding, section margins

// Macro spacing
20px  // Large section padding
24px  // Bottom page padding
32px  // Major section separators
```

### Component-Specific Spacing

#### Container Padding
```dart
// Hero section
EdgeInsets.fromLTRB(12, 8, 12, 0)

// Quick Actions section
EdgeInsets.fromLTRB(12, 12, 12, 8)

// Today's Overview section
EdgeInsets.fromLTRB(12, 6, 12, 6)

// Menu section header
EdgeInsets.fromLTRB(12, 12, 12, 10)

// Menu items container
EdgeInsets.symmetric(horizontal: 16)

// Bottom padding
EdgeInsets.only(bottom: 24)
```

#### Card Padding
```dart
// Overview cards: 12px all sides
padding: EdgeInsets.all(12)

// Menu item cards: 12px symmetric
padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12)

// Quick action buttons: No padding (icon-only)

// Category headers: 12px horizontal, 10px vertical
padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10)
```

#### Gaps & Spacing
```dart
// Between section title and content: 12px
SizedBox(height: 12)

// Between cards in grid: 8px
crossAxisSpacing: 8,
mainAxisSpacing: 8,

// Between list items: 8px
separatorBuilder: (context, index) => SizedBox(height: 8)

// Between icon and text: 10-12px
SizedBox(width: 12)

// Between category sections: 12px bottom margin
margin: EdgeInsets.only(bottom: 12)
```

---

## 🎭 Shadow System

### Philosophy
Always use **layered shadows** (2-3 shadows) for depth, never a single shadow.

### Shadow Patterns

#### Standard Card Shadow
```dart
boxShadow: [
  BoxShadow(
    color: accentColor.withValues(alpha: 0.08),
    blurRadius: 12,
    offset: Offset(0, 3),
  ),
  BoxShadow(
    color: ColorUtils.slate900.withValues(alpha: 0.06),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
]
```

#### Enhanced Card Shadow (Overview Cards)
```dart
boxShadow: [
  BoxShadow(
    color: accentColor.withValues(alpha: 0.12),
    blurRadius: 16,
    offset: Offset(0, 4),
  ),
  BoxShadow(
    color: ColorUtils.slate900.withValues(alpha: 0.06),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
]
```

#### Small Element Shadow (Quick Actions)
```dart
boxShadow: [
  BoxShadow(
    color: ColorUtils.slate900.withValues(alpha: 0.06),
    blurRadius: 8,
    offset: Offset(0, 2),
  ),
]
```

#### Badge Shadow
```dart
boxShadow: [
  BoxShadow(
    color: ColorUtils.error600.withValues(alpha: 0.3),
    blurRadius: 4,
    offset: Offset(0, 2),
  ),
]
```

#### Hero Section Shadow
```dart
boxShadow: [
  BoxShadow(
    color: primaryColor.withValues(alpha: 0.3),
    blurRadius: 16,
    offset: Offset(0, 6),
  ),
]
```

### Shadow Rules
1. **Top shadow:** Always color-tinted (accent/primary color)
2. **Bottom shadow:** Always neutral (slate900)
3. **Opacity range:** 0.06-0.12 for colored, 0.04-0.08 for neutral
4. **Blur radius:** 8-16px (larger for more prominent elements)
5. **Offset:** Always positive Y (0, 2) to (0, 6)

---

## 🔲 Border Radius

### Standard Values
```dart
// Small elements (icons, badges)
borderRadius: BorderRadius.circular(8-10)

// Medium containers (icon containers)
borderRadius: BorderRadius.circular(12)

// Cards (menu items, overview cards)
borderRadius: BorderRadius.circular(14-16)

// Large containers (hero section, categories)
borderRadius: BorderRadius.circular(16-20)

// Circular (badges, decorative elements)
shape: BoxShape.circle
```

### Rules
- **Consistent corners:** All corners same radius (no mixed)
- **Scale with size:** Larger elements → larger radius
- **Maximum:** 20px for rectangular elements
- **Buttons/Icons:** 10-12px for professional look

---

## 🎯 Component Patterns

### 1. Hero Section

#### Structure
```dart
Container(
  margin: EdgeInsets.fromLTRB(12, 8, 12, 0),
  decoration: BoxDecoration(
    gradient: ColorUtils.heroGradient(primaryColor: primaryColor),
    borderRadius: BorderRadius.circular(20),
    boxShadow: [/* Hero shadow */],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: Stack(
      children: [
        // Decorative circles
        // Main content
      ],
    ),
  ),
)
```

#### Decorative Circles
```dart
// Large circle - top right
Positioned(
  top: -40,
  right: -30,
  child: Container(
    width: 140,
    height: 140,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.08),
    ),
  ),
)

// Medium circle - bottom left
Positioned(
  bottom: -25,
  left: 15,
  child: Container(
    width: 70,
    height: 70,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.06),
    ),
  ),
)

// Small accent dot
Positioned(
  top: 20,
  right: 70,
  child: Container(
    width: 6,
    height: 6,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: Colors.white.withValues(alpha: 0.3),
    ),
  ),
)
```

#### Gradient
```dart
static LinearGradient heroGradient({required Color primaryColor}) {
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      primaryColor,
      _adjustColor(primaryColor, 0.15),
      _adjustColor(primaryColor, 0.35),
    ],
    stops: [0.0, 0.5, 1.4],
  );
}
```

### 2. Section Headers

#### Standard Pattern
```dart
Text(
  'Section Title',
  style: TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: ColorUtils.slate900,
  ),
)
```

#### With Spacing
```dart
Padding(
  padding: EdgeInsets.fromLTRB(12, 12, 12, 10),
  child: Text(/* Section header */),
)
```

### 3. Quick Action Buttons

#### Icon Container (54×54px)
```dart
Container(
  width: 54,
  height: 54,
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.1),
    borderRadius: BorderRadius.circular(16),
    border: Border.all(
      color: ColorUtils.slate200,
      width: 1,
    ),
    boxShadow: [/* Small shadow */],
  ),
  child: Icon(icon, color: color, size: 22),
)
```

#### Badge on Icon
```dart
Positioned(
  right: -4,
  top: -4,
  child: Container(
    padding: EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: ColorUtils.error600,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 2),
    ),
    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
    child: Text(
      badgeCount > 9 ? '9+' : badgeCount.toString(),
      style: TextStyle(
        color: Colors.white,
        fontSize: 7,
        fontWeight: FontWeight.bold,
      ),
      textAlign: TextAlign.center,
    ),
  ),
)
```

### 4. Overview Cards

#### Card Structure
```dart
Container(
  padding: EdgeInsets.all(12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(16),
    border: Border.all(color: ColorUtils.slate200, width: 1),
    boxShadow: [/* Enhanced card shadow */],
  ),
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      // Icon + Value row
      Row(
        children: [
          // Icon container (36×36px)
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: accentColor.withValues(alpha: 0.15),
                width: 1,
              ),
            ),
            child: Icon(icon, size: 18, color: accentColor),
          ),
          SizedBox(width: 10),
          // Value + Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: /* 20px w800 */),
                SizedBox(height: 2),
                Text(title, style: /* 11px w600 */),
              ],
            ),
          ),
        ],
      ),
      SizedBox(height: 8),
      Text(subtitle, style: /* 10px w500 */),
    ],
  ),
)
```

### 5. Menu Item Cards

#### Card Structure (66px height)
```dart
Container(
  height: 66,
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(14),
    border: Border.all(color: ColorUtils.slate200, width: 1),
    boxShadow: [/* Standard card shadow */],
  ),
  child: Row(
    children: [
      // Icon container (44×44px)
      Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: effectivePrimaryColor.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: effectivePrimaryColor.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Icon(icon, size: 24, color: effectivePrimaryColor),
      ),
      SizedBox(width: 12),
      // Title + Badge
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: ColorUtils.slate900,
            letterSpacing: -0.1,
          ),
        ),
      ),
      // Arrow
      Icon(Icons.chevron_right, size: 20, color: ColorUtils.slate400),
    ],
  ),
)
```

### 6. Category Sections

#### Header
```dart
Container(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
  decoration: ColorUtils.categoryHeaderDecoration(
    accentColor: accentColor,
    isExpanded: isExpanded,
  ),
  child: Row(
    children: [
      Icon(icon, size: 18, color: accentColor),
      SizedBox(width: 10),
      Expanded(
        child: Text(
          title,
          style: DashboardTypography.categoryTitle(color: accentColor),
        ),
      ),
      RotationTransition(/* Expand/collapse arrow */),
    ],
  ),
)
```

#### Content List
```dart
ListView.separated(
  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
  shrinkWrap: true,
  physics: NeverScrollableScrollPhysics(),
  itemCount: items.length,
  separatorBuilder: (context, index) => SizedBox(height: 8),
  itemBuilder: (context, index) => MenuItemCard(/* ... */),
)
```

---

## 🎬 Animation Guidelines

### Standard Durations
```dart
Duration(milliseconds: 300)  // Standard (category expand, size changes)
Duration(milliseconds: 250)  // Quick (hover, press effects)
Duration(milliseconds: 400)  // Slow (page transitions)
```

### Standard Curves
```dart
Curves.easeInOut  // Default for most animations
Curves.easeOut    // For appearing elements
Curves.easeIn     // For disappearing elements
```

### Staggered Animations
```dart
// Delay per item in list
final delay = index * 50;  // 50ms per item

TweenAnimationBuilder<double>(
  duration: Duration(milliseconds: 300 + delay),
  tween: Tween(begin: 0.0, end: 1.0),
  curve: Curves.easeOut,
  builder: (context, value, child) {
    return Opacity(
      opacity: value,
      child: Transform.translate(
        offset: Offset(0, 20 * (1 - value)),
        child: child,
      ),
    );
  },
  child: /* Your widget */,
)
```

---

## 📱 Grid & Layout

### Grid Specifications

#### 2-Column Grid (Overview Cards)
```dart
GridView.count(
  shrinkWrap: true,
  physics: NeverScrollableScrollPhysics(),
  crossAxisCount: 2,
  crossAxisSpacing: 8,
  mainAxisSpacing: 8,
  childAspectRatio: 1.4,
  children: cards,
)
```

#### Horizontal Scroll (Quick Actions)
```dart
SizedBox(
  height: 85,
  child: ListView.separated(
    scrollDirection: Axis.horizontal,
    padding: EdgeInsets.symmetric(horizontal: 12),
    itemCount: actions.length,
    separatorBuilder: (context, index) => SizedBox(width: 10),
    itemBuilder: (context, index) => QuickActionButton(/* ... */),
  ),
)
```

#### Single Column List (Menu Items)
```dart
ListView.separated(
  shrinkWrap: true,
  physics: NeverScrollableScrollPhysics(),
  itemCount: items.length,
  separatorBuilder: (context, index) => SizedBox(height: 8),
  itemBuilder: (context, index) => MenuItemCard(/* ... */),
)
```

---

## ✅ Design Checklist

When redesigning a page, verify:

### Visual Consistency
- [ ] Colors follow the Kamil Edu palette
- [ ] All text uses defined typography styles
- [ ] Spacing follows the 4px grid system
- [ ] All cards have layered shadows
- [ ] Border radius is consistent (14-16px for cards)

### Component Quality
- [ ] Icon containers have borders and backgrounds
- [ ] Badges have shadows and proper styling
- [ ] Section headers are 16px w700
- [ ] Cards have proper padding (12px)
- [ ] Gap between items is 8px

### Interactive Elements
- [ ] All tappable elements have InkWell with borderRadius
- [ ] Touch targets are at least 44×44px
- [ ] Animations are 300ms with Curves.easeInOut
- [ ] Disabled states have reduced opacity

### Accessibility
- [ ] Color contrast meets WCAG AA (4.5:1 for text)
- [ ] Text is readable at minimum size (10px)
- [ ] Icons have semantic labels
- [ ] Focus indicators are visible

### Performance
- [ ] Lists use ListView.builder for efficiency
- [ ] Grids use shrinkWrap: true with NeverScrollableScrollPhysics
- [ ] Images are properly sized
- [ ] No unnecessary rebuilds

---

## 🔄 Before & After Comparison

### Dashboard Redesign (Reference Implementation)

#### Before
- Simple 2-column grid of menu cards
- Basic statistics cards with single shadow
- Flat color backgrounds
- 14px section headers
- Minimal spacing (dense layout)

#### After
- Categorized expandable navigation
- Enhanced statistics with gradients and glass morphism
- Decorative circles and vibrant gradients in hero section
- 16px w700 section headers
- Professional spacing with breathing room
- Layered shadows throughout
- Icon containers with borders
- Enhanced badges with shadows

### Key Improvements
1. **Visual Hierarchy:** Clear sections with prominent headers
2. **Professional Styling:** Corporate color palette, layered shadows
3. **Better UX:** Categorized navigation, quick actions, today's overview
4. **Modern Design:** Glass morphism, decorative elements, smooth animations
5. **Consistency:** Unified spacing, typography, and component styling

---

## 📚 Code Snippets Library

### Color Usage
```dart
// Primary text
color: ColorUtils.slate900

// Secondary text
color: ColorUtils.slate600

// Light borders
border: Border.all(color: ColorUtils.slate200, width: 1)

// Icon background
color: primaryColor.withValues(alpha: 0.12)

// Badge background
color: ColorUtils.error600
```

### Common Patterns
```dart
// Standard card decoration
decoration: BoxDecoration(
  color: Colors.white,
  borderRadius: BorderRadius.circular(14),
  border: Border.all(color: ColorUtils.slate200, width: 1),
  boxShadow: [
    BoxShadow(
      color: accentColor.withValues(alpha: 0.08),
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
    BoxShadow(
      color: ColorUtils.slate900.withValues(alpha: 0.06),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ],
)

// Icon container
Container(
  width: 44,
  height: 44,
  decoration: BoxDecoration(
    color: color.withValues(alpha: 0.12),
    borderRadius: BorderRadius.circular(12),
    border: Border.all(
      color: color.withValues(alpha: 0.15),
      width: 1,
    ),
  ),
  child: Icon(icon, size: 24, color: color),
)

// Glass morphism effect
Container(
  decoration: BoxDecoration(
    color: Colors.white.withValues(alpha: 0.15),
    borderRadius: BorderRadius.circular(10),
    border: Border.all(
      color: Colors.white.withValues(alpha: 0.2),
      width: 1,
    ),
  ),
)
```

---

## 🎯 Next Steps

### Pages to Redesign Using This System
1. **Login/Auth pages** - Apply hero gradient, professional forms
2. **Student/Teacher lists** - Use menu card pattern for list items
3. **Detail pages** - Overview card pattern for stats, clean layouts
4. **Forms** - Professional input styling, consistent spacing
5. **Settings** - Category sections for organized options

### When Applying to New Pages
1. **Read this guide first**
2. **Identify page sections** (hero, stats, lists, actions)
3. **Choose appropriate patterns** from this guide
4. **Apply color palette** consistently
5. **Use typography system** for all text
6. **Follow spacing rules** strictly
7. **Add layered shadows** to all cards
8. **Test on multiple screen sizes**
9. **Verify checklist** before finalizing

---

## 📞 Support

For questions about this design system or when creating new patterns:
1. Reference this guide for existing patterns
2. Check dashboard implementation for examples
3. Follow the established principles
4. Maintain consistency with existing components

**Design System Version:** 1.0
**Compatible with:** Flutter 3.x
**Maintained by:** Development Team
