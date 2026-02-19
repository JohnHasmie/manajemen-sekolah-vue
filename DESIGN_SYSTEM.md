# 🎨 Design System Guide - Kamil Edu Professional Style

**Last Updated:** 2026-02-19
**Version:** 2.10
**Reference:** Kamil Edu Dashboard Design
**Applied To:** Dashboard, Student Management, Teacher Management, Class Management, Subject Management, Teaching Schedule Management, Grade (Nilai) Page, Admin Announcement, Admin Class Activity, Admin Presence Report, Admin RPP, Finance, Class Finance Report, User Profile (Settings), School Settings, Notification List, Teacher Teaching Schedule, Teacher Presence (Absensi Guru), Teacher Learning Materials (Materi Pembelajaran), Teacher RPP (Guru RPP), Wali Murid Announcement, Wali Murid Presence

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

### 7. Gradient Header (Detail Pages)

#### Usage
Use this header pattern for detail/management pages (e.g., Kelola Data, Kelola Jadwal) to provide a professional gradient header with back button, title, and subtitle.

#### Structure
```dart
Widget _buildGradientHeader(BuildContext context) {
  return Container(
    width: double.infinity,
    padding: EdgeInsets.only(
      top: MediaQuery.of(context).padding.top + 16,
      left: 16,
      right: 16,
      bottom: 16,
    ),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          ColorUtils.corporateBlue600,
          ColorUtils.corporateBlue600.withValues(alpha: 0.8),
        ],
      ),
      boxShadow: [
        BoxShadow(
          color: ColorUtils.corporateBlue600.withValues(alpha: 0.3),
          blurRadius: 8,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Row(
      children: [
        // Back button
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.arrow_back,
              color: Colors.white,
              size: 20,
            ),
          ),
        ),
        SizedBox(width: 12),
        // Title and subtitle
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Page Title',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: 2),
              Text(
                'Page description or subtitle',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        // Optional: Action button (e.g., toggle view)
        // GestureDetector(
        //   onTap: () { /* action */ },
        //   child: Container(
        //     width: 40,
        //     height: 40,
        //     decoration: BoxDecoration(
        //       color: Colors.white.withValues(alpha: 0.2),
        //       borderRadius: BorderRadius.circular(10),
        //     ),
        //     child: Icon(Icons.action, color: Colors.white, size: 20),
        //   ),
        // ),
      ],
    ),
  );
}
```

#### Layout Pattern
```dart
Scaffold(
  backgroundColor: ColorUtils.slate50,
  body: Column(
    children: [
      // Gradient header
      _buildGradientHeader(context),

      // Content area
      Expanded(
        child: ListView(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            // Your content here (MenuItemCard, etc.)
          ],
        ),
      ),
    ],
  ),
)
```

#### Specifications
- **Back button:** 40×40px with semi-transparent background (alpha: 0.2)
- **Title:** 20px, bold, white
- **Subtitle:** 14px, white with 90% opacity
- **Gradient:** Role-specific color to lighter variant (alpha: 0.8)
- **Shadow:** Role color with 30% opacity, 8px blur, (0,2) offset
- **Spacing:** 12px between back button and title
- **Border radius:** 10px for buttons

#### Color Variations by Role
```dart
// Admin
ColorUtils.corporateBlue600

// Teacher
Color(0xFF16A34A) // Green

// Parent
Color(0xFF9333EA) // Purple
```

#### Notes
- Always include MediaQuery padding for safe area
- Back button should use Navigator.pop(context)
- Gradient provides depth and professionalism
- Semi-transparent buttons blend well with gradient
- Subtitle is optional but recommended for context

### 8. Compact Management List Card

#### Usage
Use for data management screens (students, teachers, employees) where lists need to display key info in a compact, scannable format.

#### Structure
```dart
Container(
  margin: EdgeInsets.symmetric(vertical: 5, horizontal: 16),
  child: Material(
    child: InkWell(
      onTap: () => _showDetailPopup(item),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: ColorUtils.slate200, width: 1),
          boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
        ),
        child: Row(
          children: [
            // 1. Colored initial avatar
            CircleAvatar(
              radius: 22,
              backgroundColor: avatarColor.withValues(alpha: 0.15),
              child: Text(
                name[0].toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: avatarColor,
                ),
              ),
            ),
            SizedBox(width: 12),
            // 2. Name + info tags
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  SizedBox(height: 4),
                  Row(children: [
                    _buildInfoTag(Icons.school_outlined, classLabel),
                    SizedBox(width: 6),
                    _buildInfoTag(Icons.person_outline, secondaryLabel),
                  ]),
                ],
              ),
            ),
            SizedBox(width: 8),
            // 3. Status chip + action buttons
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Active status chip
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: ColorUtils.success600.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: ColorUtils.success600.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Container(
                      width: 5, height: 5,
                      decoration: BoxDecoration(
                        color: ColorUtils.success600,
                        shape: BoxShape.circle,
                      ),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Active',
                      style: TextStyle(
                        color: ColorUtils.success600,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ]),
                ),
                SizedBox(height: 8),
                // Edit + Delete buttons
                Row(children: [
                  InkWell(
                    onTap: onEdit,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.edit_outlined, size: 16, color: ColorUtils.corporateBlue600),
                    ),
                  ),
                  SizedBox(width: 6),
                  InkWell(
                    onTap: onDelete,
                    child: Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: ColorUtils.error600.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(Icons.delete_outline, size: 16, color: ColorUtils.error600),
                    ),
                  ),
                ]),
              ],
            ),
          ],
        ),
      ),
    ),
  ),
)
```

#### Info Tag Helper (`_buildInfoTag`)
```dart
Widget _buildInfoTag(IconData icon, String text) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 3),
    decoration: BoxDecoration(
      color: ColorUtils.slate50,
      borderRadius: BorderRadius.circular(6),
      border: Border.all(color: ColorUtils.slate200),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: ColorUtils.slate600),
      SizedBox(width: 3),
      Text(
        text,
        style: TextStyle(
          fontSize: 11,
          color: ColorUtils.slate700,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ]),
  );
}
```

#### Info Tag Layout: Horizontal vs Vertical
When all tags contain **short text** (class name, gender, 1-2 words), use a horizontal `Row`:
```dart
Row(children: [
  _buildInfoTag(Icons.school_outlined, classLabel),
  SizedBox(width: 6),
  _buildInfoTag(Icons.person_outline, genderLabel),
])
```

When any tag may contain **long text** (email, full name, address), stack vertically in a `Column`:
```dart
Column(
  crossAxisAlignment: CrossAxisAlignment.start,
  children: [
    _buildInfoTag(Icons.class_outlined, classLabel),  // short: first
    SizedBox(height: 4),
    _buildInfoTag(Icons.email_outlined, email),       // long: last
  ],
)
```

> ⚠️ **Never wrap `_buildInfoTag` in `Flexible` inside a `Column`** — `Flexible` in an unbounded-height Column causes a `RenderFlex` crash. The `Expanded` parent already constrains the Column's width, so the text's `overflow: ellipsis` handles truncation automatically.

#### Avatar Color Coding
```dart
// In list: use index for consistent color rotation
final avatarColor = ColorUtils.getColorForIndex(index);

// In detail popup (no index): use name hash for consistent per-record color
final nameHash = name.codeUnits.fold(0, (sum, c) => sum + c);
final avatarColor = ColorUtils.getColorForIndex(nameHash);
```

#### Specifications
- **Card border radius:** 14px
- **Card padding:** 12px horizontal, 12px vertical
- **Card margin:** 5px vertical, 16px horizontal
- **Avatar radius:** 22px (44×44px touch target)
- **Info tag font:** 11px w500
- **Status dot:** 5×5px circle
- **Action icon size:** 16px inside 6px-padded container
- **Shadow:** `ColorUtils.corporateShadow(elevation: 1.0)`

---

### 9. Form Dialog (Add/Edit)

#### Usage
Use for add/edit dialogs that collect structured data. Preferred over full-screen forms for compact data sets (≤10 fields).

#### Structure
```dart
showDialog(
  context: context,
  builder: (context) => Dialog(
    backgroundColor: Colors.white,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // --- Gradient Header ---
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20),
                topRight: Radius.circular(20),
              ),
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Icon(isEdit ? Icons.edit_rounded : Icons.add_rounded, color: Colors.white, size: 22),
                ),
                SizedBox(width: 14),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isEdit ? 'Edit Record' : 'Add Record',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 2),
                      Text(isEdit ? 'Update record information' : 'Fill in record information',
                        style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                // X close button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // --- Form Fields ---
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              children: [
                _buildFormTextField(/* ... */),
                SizedBox(height: 12),
                _buildFormDropdown(/* ... */),
                // ... more fields
              ],
            ),
          ),

          // --- Footer Buttons ---
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ColorUtils.slate100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel',
                      style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.corporateBlue600,
                      padding: EdgeInsets.symmetric(vertical: 13),
                      elevation: 2,
                      shadowColor: ColorUtils.corporateBlue600.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isEdit ? 'Update' : 'Save',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
```

#### Form Field Helper (`_buildFormTextField`)
```dart
Widget _buildFormTextField({
  required TextEditingController controller,
  required String label,
  required IconData icon,
  TextInputType? keyboardType,
  int maxLines = 1,
  String? hintText,
  VoidCallback? onTap,
  bool readOnly = false,
}) {
  return Container(
    decoration: BoxDecoration(
      color: ColorUtils.slate50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ColorUtils.slate200),
    ),
    child: TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
        hintText: hintText,
        hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
        prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
        border: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      ),
      style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      keyboardType: keyboardType,
      maxLines: maxLines,
      onTap: onTap,
      readOnly: readOnly,
    ),
  );
}
```

#### Form Dropdown Helper (`_buildFormDropdown`)
```dart
Widget _buildFormDropdown({
  required String? value,
  required String label,
  required IconData icon,
  required List<DropdownMenuItem<String>> items,
  required Function(String?) onChanged,
}) {
  return Container(
    decoration: BoxDecoration(
      color: ColorUtils.slate50,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: ColorUtils.slate200),
    ),
    child: DropdownButtonFormField<String>(
      initialValue: value,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: ColorUtils.slate500, fontSize: 13),
        prefixIcon: Icon(icon, color: ColorUtils.corporateBlue600, size: 18),
        border: InputBorder.none,
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ColorUtils.corporateBlue600, width: 1.5),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 12),
      ),
      items: items,
      onChanged: onChanged,
      style: TextStyle(fontSize: 14, color: ColorUtils.slate800),
      dropdownColor: Colors.white,
      borderRadius: BorderRadius.circular(12),
      icon: Icon(Icons.keyboard_arrow_down_rounded, color: ColorUtils.slate500),
    ),
  );
}
```

#### Specifications
- **Dialog border radius:** 20px
- **Header padding:** `fromLTRB(20, 20, 12, 20)` (right is 12 to fit close button)
- **Icon container:** 44×44px, 12px border radius, `white.withValues(alpha: 0.2)` bg with 0.3 border
- **Close button:** 32×32px circle, `white.withValues(alpha: 0.2)` bg
- **Field container bg:** `ColorUtils.slate50` with `slate200` border
- **Field focused border:** 1.5px `corporateBlue600`
- **Footer top divider:** `slate100`
- **Cancel button:** `slate300` border, `slate700` text, 13px vertical padding
- **Save button:** `corporateBlue600` bg, `w600` text, elevation 2 with `corporateBlue600` shadow

---

### 10. Detail Popup

#### Usage
Use for read-only detail views triggered by tapping a list card. Shows comprehensive record information in a scrollable dialog.

#### Structure
```dart
showDialog(
  context: context,
  builder: (context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: FutureBuilder(
      future: apiService.getById(id),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return SizedBox(height: 200, child: Center(child: CircularProgressIndicator()));
        }
        final details = snapshot.hasData ? snapshot.data : localData;

        return SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // --- Colored Avatar Header ---
              Builder(builder: (context) {
                final nameHash = name.codeUnits.fold(0, (sum, c) => sum + c);
                final avatarColor = ColorUtils.getColorForIndex(nameHash);
                return Container(
                  width: double.infinity,
                  padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(/* role gradient */),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          // Colored avatar with white border
                          Container(
                            width: 72, height: 72,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: avatarColor,
                              border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: Offset(0, 4))],
                            ),
                            child: Center(
                              child: Text(initial, style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white)),
                            ),
                          ),
                          SizedBox(height: 12),
                          Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white), textAlign: TextAlign.center),
                          SizedBox(height: 6),
                          // Badge chips row (NIS, class, etc.)
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildHeaderBadge(Icons.badge_outlined, 'NIS: $nis'),
                              if (className.isNotEmpty) ...[
                                SizedBox(width: 8),
                                _buildHeaderBadge(Icons.school_outlined, className),
                              ],
                            ],
                          ),
                        ],
                      ),
                      // X close button top-right
                      Positioned(
                        top: 0, right: 0,
                        child: GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 32, height: 32,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),

              // --- Content ---
              Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildDetailItem(icon: Icons.school, label: 'Class', value: className),
                    _buildDetailItem(icon: Icons.cake, label: 'Birth Date', value: birthDate),
                    // ...

                    // --- Section Header ---
                    SizedBox(height: 16),
                    _buildDetailSectionHeader(Icons.history_rounded, 'Section Title'),
                    SizedBox(height: 12),

                    // --- More detail items ---
                    _buildDetailItem(/* ... */),

                    // --- Footer Buttons ---
                    SizedBox(height: 20),
                    Container(
                      padding: EdgeInsets.only(top: 12),
                      decoration: BoxDecoration(border: Border(top: BorderSide(color: ColorUtils.slate100))),
                      child: Row(children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.pop(context),
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.symmetric(vertical: 13),
                              side: BorderSide(color: ColorUtils.slate300),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: Text('Close', style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600, fontSize: 14)),
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () { Navigator.pop(context); openEditDialog(); },
                            icon: Icon(Icons.edit_rounded, size: 16, color: Colors.white),
                            label: Text('Edit', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: ColorUtils.corporateBlue600,
                              padding: EdgeInsets.symmetric(vertical: 13),
                              elevation: 2,
                              shadowColor: ColorUtils.corporateBlue600.withValues(alpha: 0.4),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    ),
  ),
);
```

#### Header Badge Helper
```dart
Widget _buildHeaderBadge(IconData icon, String text) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.2),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
    ),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: Colors.white),
      SizedBox(width: 4),
      Text(text, style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w500)),
    ]),
  );
}
```

#### Section Header Helper
```dart
Widget _buildDetailSectionHeader(IconData icon, String title) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    decoration: BoxDecoration(
      color: ColorUtils.slate50,
      borderRadius: BorderRadius.circular(8),
      border: Border(left: BorderSide(color: ColorUtils.corporateBlue600, width: 3)),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: ColorUtils.corporateBlue600),
      SizedBox(width: 8),
      Text(
        title,
        style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: ColorUtils.slate800, letterSpacing: 0.3),
      ),
    ]),
  );
}
```

#### Detail Item Helper (`_buildDetailItem`)
```dart
Widget _buildDetailItem({
  required IconData icon,
  required String label,
  required String value,
  bool isMultiline = false,
}) {
  return Container(
    margin: EdgeInsets.only(bottom: 10),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: ColorUtils.slate50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ColorUtils.slate100),
    ),
    child: Row(
      crossAxisAlignment: isMultiline ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ColorUtils.corporateBlue600.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, size: 18, color: ColorUtils.corporateBlue600),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: ColorUtils.slate500, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
            SizedBox(height: 3),
            Text(value,
              style: TextStyle(fontSize: 14, color: ColorUtils.slate800, fontWeight: FontWeight.w600),
              maxLines: isMultiline ? 3 : 1,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ],
    ),
  );
}
```

#### Specifications
- **Dialog border radius:** 20px
- **Avatar size:** 72×72px with 3px white border and shadow
- **Avatar color:** `ColorUtils.getColorForIndex(name.codeUnits.fold(0, (sum, c) => sum + c))`
- **Badge chips:** pill shape, `white.withValues(alpha: 0.2)` bg, 20px border radius
- **Section header:** `slate50` bg, 3px `corporateBlue600` left border, 8px border radius
- **Detail item bg:** `slate50` with `slate100` border, 10px border radius
- **Detail icon container:** 36×36px, `corporateBlue600 * 0.1` bg with `* 0.15` border
- **Label:** 11px, `slate500`, w500, letterSpacing 0.3
- **Value:** 14px, `slate800`, w600
- **Footer divider:** `slate100`
- **Close button:** 32×32px circle at `Positioned(top: 0, right: 0)`
- **Edit button:** `ElevatedButton.icon` with edit icon, `corporateBlue600` bg

---

### 11. Filter Bottom Sheet

#### Usage
Use for filtering lists with multiple filter categories. Slides up from the bottom with organized sections.

#### Structure
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => Container(
    height: MediaQuery.of(context).size.height * 0.75,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(24),
        topRight: Radius.circular(24),
      ),
    ),
    child: Column(
      children: [
        // --- Gradient Header ---
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ColorUtils.corporateBlue600, ColorUtils.corporateBlue600.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(children: [
                Icon(Icons.filter_list_rounded, color: Colors.white, size: 22),
                SizedBox(width: 12),
                Text('Filter', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
              ]),
              TextButton(
                onPressed: onReset,
                child: Text('Reset', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),

        // --- Scrollable Filter Sections ---
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterSectionHeader(Icons.class_outlined, 'By Class'),
                SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: items.map((item) => FilterChip(
                    label: Text(item.name),
                    selected: selectedItems.contains(item.id),
                    onSelected: (selected) => onToggle(item.id),
                    backgroundColor: Colors.white,
                    selectedColor: ColorUtils.corporateBlue600.withValues(alpha: 0.15),
                    checkmarkColor: ColorUtils.corporateBlue600,
                    labelStyle: TextStyle(
                      color: selectedItems.contains(item.id) ? ColorUtils.corporateBlue600 : ColorUtils.slate700,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: selectedItems.contains(item.id) ? ColorUtils.corporateBlue600 : ColorUtils.slate300,
                      width: 1,
                    ),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  )).toList(),
                ),
              ],
            ),
          ),
        ),

        // --- Footer Buttons ---
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: ColorUtils.slate200)),
            boxShadow: [BoxShadow(color: ColorUtils.slate900.withValues(alpha: 0.05), blurRadius: 8, offset: Offset(0, -2))],
          ),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 14),
                  side: BorderSide(color: ColorUtils.slate300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel', style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: onApply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.corporateBlue600,
                  padding: EdgeInsets.symmetric(vertical: 14),
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Apply Filter', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ],
    ),
  ),
);
```

#### Filter Section Header Helper
```dart
Widget _buildFilterSectionHeader(IconData icon, String title) {
  return Row(children: [
    Icon(icon, size: 16, color: ColorUtils.slate600),
    SizedBox(width: 8),
    Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate800)),
  ]);
}
```

#### Specifications
- **Sheet height:** 75% of screen height
- **Sheet border radius (top):** 24px
- **Header padding:** 20px all sides
- **Header gradient:** `corporateBlue600` → `corporateBlue600.withValues(alpha: 0.8)`
- **FilterChip border radius:** 10px, horizontal padding 12px, vertical 8px
- **Selected chip bg:** `corporateBlue600.withValues(alpha: 0.15)`
- **Section header icon size:** 16px, `slate600`
- **Footer shadow:** upward, `slate900 * 0.05`, 8px blur, `(0, -2)` offset
- **Footer padding:** 20px all sides
- **Apply button:** `corporateBlue600` fill with elevation 2

---

### 12. Full-Screen Detail Page

#### Usage
Use for detail pages that require more space than a popup allows — e.g., teacher profiles with subjects, class lists, and contact info. Navigated to via route (not showDialog). Complements Pattern #10 (Detail Popup) for data-rich entities.

#### Structure
```dart
Scaffold(
  backgroundColor: ColorUtils.slate50,
  body: Column(
    children: [
      // --- Pattern #7 Gradient Header ---
      _buildGradientHeader(context),

      // --- Scrollable Content ---
      Expanded(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(16),
          child: Column(
            children: [
              // Profile header card
              _buildProfileCard(details),
              SizedBox(height: 16),

              // Section cards
              _buildSectionCard(
                icon: Icons.info_outline,
                title: 'Personal Information',
                children: [
                  _buildInfoRow(Icons.badge, 'NIP', nip),
                  _buildInfoRow(Icons.email, 'Email', email),
                  // ...
                ],
              ),
              SizedBox(height: 16),

              // Back button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.arrow_back, size: 18, color: ColorUtils.slate700),
                  label: Text('Back', style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    padding: EdgeInsets.symmetric(vertical: 13),
                    side: BorderSide(color: ColorUtils.slate300),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              SizedBox(height: 24),
            ],
          ),
        ),
      ),
    ],
  ),
)
```

#### Profile Card
```dart
Widget _buildProfileCard(Map<String, dynamic> details) {
  final name = details['name'] ?? '';
  final nameHash = name.codeUnits.fold(0, (sum, c) => sum + c);
  final avatarColor = ColorUtils.getColorForIndex(nameHash);

  return Container(
    width: double.infinity,
    padding: EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [ColorUtils.corporateBlue600, ColorUtils.corporateBlue600.withValues(alpha: 0.8)],
      ),
      borderRadius: BorderRadius.circular(16),
      boxShadow: ColorUtils.corporateShadow(elevation: 2.0),
    ),
    child: Column(
      children: [
        // Avatar with white border
        Container(
          width: 72, height: 72,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: avatarColor,
            border: Border.all(color: Colors.white.withValues(alpha: 0.4), width: 3),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: Offset(0, 4))],
          ),
          child: Center(
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : '?',
              style: TextStyle(fontSize: 30, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ),
        SizedBox(height: 12),
        Text(name, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        SizedBox(height: 4),
        Text(details['role'] ?? '', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.85))),
        SizedBox(height: 10),
        // Badge chips row
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeaderBadge(Icons.badge_outlined, details['nip'] ?? ''),
            if ((details['homeroom_class'] ?? '') != '') ...[
              SizedBox(width: 8),
              _buildHeaderBadge(Icons.school_outlined, details['homeroom_class']),
            ],
          ],
        ),
      ],
    ),
  );
}
```

#### Section Card
```dart
Widget _buildSectionCard({required IconData icon, required String title, required List<Widget> children}) {
  return Container(
    width: double.infinity,
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: ColorUtils.slate200),
      boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with left border accent
        _buildSectionHeader(icon, title),
        Divider(height: 1, color: ColorUtils.slate100),
        Padding(
          padding: EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ],
    ),
  );
}
```

#### Section Header Helper
```dart
Widget _buildSectionHeader(IconData icon, String title) {
  return Container(
    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    decoration: BoxDecoration(
      color: ColorUtils.slate50,
      borderRadius: BorderRadius.only(
        topLeft: Radius.circular(16),
        topRight: Radius.circular(16),
      ),
      border: Border(left: BorderSide(color: ColorUtils.corporateBlue600, width: 3)),
    ),
    child: Row(children: [
      Icon(icon, size: 16, color: ColorUtils.corporateBlue600),
      SizedBox(width: 8),
      Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: ColorUtils.slate800)),
    ]),
  );
}
```

#### Info Row Helper (`_buildInfoRow`)
```dart
Widget _buildInfoRow(IconData icon, String label, String value) {
  return Container(
    margin: EdgeInsets.only(bottom: 10),
    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
    decoration: BoxDecoration(
      color: ColorUtils.slate50,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: ColorUtils.slate100),
    ),
    child: Row(
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            color: ColorUtils.corporateBlue600.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: ColorUtils.corporateBlue600.withValues(alpha: 0.15)),
          ),
          child: Icon(icon, size: 18, color: ColorUtils.corporateBlue600),
        ),
        SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label, style: TextStyle(fontSize: 11, color: ColorUtils.slate500, fontWeight: FontWeight.w500, letterSpacing: 0.3)),
            SizedBox(height: 3),
            Text(value,
              style: TextStyle(fontSize: 14, color: ColorUtils.slate800, fontWeight: FontWeight.w600),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ]),
        ),
      ],
    ),
  );
}
```

#### Specifications
- **Scaffold bg:** `ColorUtils.slate50`
- **Header:** Pattern #7 gradient (same as management screens)
- **Profile card:** same avatar specs as Pattern #10 (72px, name-hash color, 3px white border)
- **Profile card gradient:** `corporateBlue600` → `corporateBlue600 * 0.8`, 16px border radius
- **Section card:** white, `slate200` border, `corporateShadow(1.0)`, 16px border radius
- **Section header accent:** 3px `corporateBlue600` left border, `slate50` bg
- **Info row:** identical to `_buildDetailItem` in Pattern #10
- **Back button:** full-width `OutlinedButton.icon`, `slate300` border, 12px border radius
- **Back button bottom padding:** 24px below

#### When to Use vs Pattern #10
| Pattern #10 (Popup) | Pattern #12 (Full Screen) |
|---|---|
| Few fields (≤8) | Many fields (>8) |
| Quick reference | Deep inspection |
| Triggered from any screen | Has its own route |
| Overlay dismissable | Back-navigable |
| No list data | Can show lists (subjects, classes) |

### 13. Add/Edit Form Bottom Sheet

#### Usage
Use for add/edit forms in management screens. Slides up from the bottom at 92% screen height — preferred over center dialogs (Pattern #9) when the form has many fields, uses dropdowns, or needs keyboard-aware scrolling.

Applied to: Student Management, Teacher Management, Class Management, Subject Management.

#### Key Differences from Pattern #9 (Form Dialog)
| | Pattern #9 (Dialog) | Pattern #13 (Bottom Sheet) |
|---|---|---|
| Trigger | `showDialog` | `showModalBottomSheet` |
| Presentation | Centered overlay | Slides from bottom |
| Height | Intrinsic (min content) | 92% screen height |
| Form body | `Padding(Column)` | `Expanded(SingleChildScrollView(...))` |
| Header radius | 20px | 24px (matches outer container) |
| Keyboard | Dialog auto-adjusts | Requires `Padding(viewInsets.bottom)` |
| Ideal for | ≤ 6 simple fields | Many fields / dropdowns / long forms |

#### Structure
```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => Padding(
    // Lift sheet above keyboard
    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
    child: Container(
      height: MediaQuery.of(context).size.height * 0.92,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          // --- Gradient Header ---
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(20, 20, 12, 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [primaryColor, primaryColor.withValues(alpha: 0.8)],
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(24),  // must match outer container
                topRight: Radius.circular(24),
              ),
            ),
            child: Row(
              children: [
                // Icon container
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                  ),
                  child: Icon(isEdit ? Icons.edit_rounded : Icons.add_rounded,
                      color: Colors.white, size: 22),
                ),
                SizedBox(width: 14),
                // Title + subtitle
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(isEdit ? 'Edit Record' : 'Add Record',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                      SizedBox(height: 2),
                      Text(isEdit ? 'Update record information' : 'Fill in record information',
                          style: TextStyle(fontSize: 12, color: Colors.white.withValues(alpha: 0.8))),
                    ],
                  ),
                ),
                // X close button (32×32 circle)
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.close_rounded, color: Colors.white, size: 18),
                  ),
                ),
              ],
            ),
          ),

          // --- Scrollable Form Body ---
          // NOTE: Use Expanded + SingleChildScrollView (not Padding + Column)
          // This is the critical structural difference from Pattern #9.
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFormTextField(/* field 1 */),
                  SizedBox(height: 12),
                  _buildFormDropdown(/* field 2 */),
                  SizedBox(height: 12),
                  // ... more fields
                ],
              ),
            ),
          ),

          // --- Footer Buttons ---
          Container(
            padding: EdgeInsets.fromLTRB(16, 8, 16, 16),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: ColorUtils.slate100)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 13),
                      side: BorderSide(color: ColorUtils.slate300),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text('Cancel',
                        style: TextStyle(color: ColorUtils.slate700, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: onSave,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorUtils.corporateBlue600,
                      padding: EdgeInsets.symmetric(vertical: 13),
                      elevation: 2,
                      shadowColor: ColorUtils.corporateBlue600.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text(isEdit ? 'Update' : 'Save',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 14)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  ),
);
```

#### Stateful Dropdowns Inside Bottom Sheet
When the form contains dropdowns that need local state (e.g., selected class, selected teacher), wrap the sheet body in `StatefulBuilder` to enable `setState` without rebuilding the entire screen:

```dart
showModalBottomSheet(
  context: context,
  isScrollControlled: true,
  backgroundColor: Colors.transparent,
  builder: (context) => StatefulBuilder(
    builder: (context, setModalState) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        // ... same structure
        // Use setModalState(() { ... }) instead of setState(() { ... })
      ),
    ),
  ),
);
```

If the bottom sheet also needs Provider/Consumer data (e.g., for loading dropdown items), wrap `StatefulBuilder` inside `Consumer`, or vice versa depending on which is the outer builder:
```dart
builder: (context) => Consumer<MyProvider>(
  builder: (context, provider, _) => StatefulBuilder(
    builder: (context, setModalState) => Padding(/* ... */),
  ),
),
```

#### Critical Bracket Rule
When converting from Pattern #9 (dialog) to Pattern #13 (bottom sheet), the form body changes from:
```dart
// Pattern #9: 2 closing brackets after last field
Padding(
  padding: EdgeInsets.all(20),
  child: Column(
    children: [/* fields */],
  ),  // ← closes Column
),   // ← closes Padding
```
to:
```dart
// Pattern #13: 3 closing brackets after last field
Expanded(
  child: SingleChildScrollView(
    padding: EdgeInsets.all(20),
    child: Column(
      children: [/* fields */],
    ),  // ← closes Column
  ),   // ← closes SingleChildScrollView
),    // ← closes Expanded   ← THIS EXTRA BRACKET IS REQUIRED
```
Missing this third bracket causes `"Expected to find ')'"` and `"Too many positional arguments"` errors in the footer section.

#### Specifications
- **`showModalBottomSheet` params:** `isScrollControlled: true`, `backgroundColor: Colors.transparent`
- **Outer padding:** `EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom)` — keyboard-aware
- **Sheet height:** `MediaQuery.of(context).size.height * 0.92`
- **Sheet border radius (top):** 24px
- **Header border radius:** must match sheet — 24px (not 20px)
- **Header icon container:** 44×44px, 12px radius, `white * 0.2` bg + `white * 0.3` border
- **Close button:** 32×32px circle, `white * 0.2` bg
- **Form body:** `Expanded(SingleChildScrollView(...))` — never bare `Padding(Column(...))`
- **Field spacing:** 12px `SizedBox` between fields
- **Footer divider:** `slate100` top border
- **Footer padding:** `fromLTRB(16, 8, 16, 16)`
- **Cancel button:** `slate300` border, `slate700` text, 13px vertical padding
- **Save button:** `corporateBlue600` bg, elevation 2, 13px vertical padding

---

### 14. Danger / Confirm Dialog

#### Usage
Use for destructive actions (delete, reset, irreversible operations) that require explicit user confirmation. Replaces generic `AlertDialog` with a styled `Dialog` that communicates severity through a red gradient header.

#### Structure
```dart
showDialog(
  context: context,
  builder: (context) => Dialog(
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // --- Red gradient header ---
        Container(
          width: double.infinity,
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [ColorUtils.error600, ColorUtils.error600.withValues(alpha: 0.8)],
            ),
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Row(children: [
            Icon(Icons.delete_outline, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Delete Record?',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ),
          ]),
        ),
        // --- Descriptive message ---
        Padding(
          padding: EdgeInsets.all(20),
          child: Text(
            'Are you sure you want to delete this record? This action cannot be undone.',
            style: TextStyle(color: ColorUtils.slate700, fontSize: 14),
          ),
        ),
        // --- Cancel + Confirm buttons ---
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Row(children: [
            Expanded(
              child: OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: ColorUtils.slate300),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Cancel',
                    style: TextStyle(color: ColorUtils.slate600, fontWeight: FontWeight.w600)),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  onConfirm();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorUtils.error600,
                  padding: EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text('Delete',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ),
          ]),
        ),
      ],
    ),
  ),
);
```

#### Color Variations
```dart
// Delete (default) — red
colors: [ColorUtils.error600, ColorUtils.error600.withValues(alpha: 0.8)]
icon: Icons.delete_outline

// Warning / Reset — orange
colors: [ColorUtils.warning600, ColorUtils.warning600.withValues(alpha: 0.8)]
icon: Icons.warning_amber_rounded

// Logout / Exit — slate
colors: [ColorUtils.slate700, ColorUtils.slate700.withValues(alpha: 0.8)]
icon: Icons.logout_rounded
```

#### Specifications
- **Dialog border radius:** 20px
- **Header padding:** 20px all sides
- **Header gradient:** semantic color to `* 0.8` (error, warning, or slate)
- **Header icon size:** 24px, white
- **Title:** 18px bold white
- **Message padding:** 20px all sides, `slate700`, 14px
- **Footer padding:** `fromLTRB(20, 0, 20, 20)`
- **Cancel:** `slate300` border, `slate600` text, 12px vertical padding
- **Confirm:** semantic color fill, white text, 12px vertical padding
- **Button border radius:** 12px
- **No X close button** — user must explicitly choose Cancel or Confirm

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
1. **Management/Detail pages** - Use gradient header pattern (Pattern #7), MenuItemCard for lists
   - Example: Student Management, Teacher Management, Class Management, Subject Management
2. **Login/Auth pages** - Apply hero gradient, professional forms
3. **List screens** - Use MenuItemCard pattern for list items, gradient header
4. **Dashboard-like pages** - Overview card pattern for stats, clean layouts
5. **Forms** - Professional input styling, consistent spacing, gradient header
6. **Settings** - Category sections for organized options, gradient header

### Already Redesigned (Reference Examples)
✅ **Dashboard** - Complete Kamil Edu design with hero, quick actions, overview cards, categorized menu
✅ **Kelola Data (Admin Data Management)** - Gradient header + MenuItemCard list
✅ **Student Management** - Gradient header (#7), compact list cards (#8), add/edit form bottom sheet (#13), detail popup (#10), filter sheet (#11)
✅ **Teacher Management** - Gradient header (#7), compact list cards (#8) with vertical info stacking, add/edit form bottom sheet (#13), filter sheet (#11), full-screen detail (#12)
✅ **Class Management** - Gradient header (#7), compact list cards (#8) with `_buildInfoTag`, add/edit form bottom sheet (#13) with grade/teacher dropdowns + StatefulBuilder inside Consumer, filter sheet (#11), detail popup (#10)
✅ **Subject Management** - Gradient header (#7), compact list cards (#8) with CircleAvatar + `_buildInfoTag` + `_buildCircleActionButton`, add/edit form bottom sheet (#13) with Autocomplete + SwitchListTile, filter sheet (#11) with 4 sections; SubjectClassManagementPage with modern class assignment cards
✅ **Teaching Schedule Management** - Gradient header (#7), compact list cards (#8) with colored icon container + `_buildInfoTag` (class/day/time) + `_buildCircleActionButton`, add/edit form bottom sheet (#13, via ScheduleFormDialog component), detail dialog (#10), filter sheet (#11), table view with styled info bar + SfDataGrid card
✅ **Admin Announcement** - Full redesign (v1.8 final):
  - **Header** (#7): `_getCardGradient()` fixed to `[primaryColor, primaryColor.withValues(alpha:0.85)]` — solid admin-blue, no purple bleed; search bar + filter button with active dot indicator; active filter chips (`visualDensity: compact`, white text on gradient); clear-all button uses `ColorUtils.error600`
  - **List cards** (#8): compact horizontal `Row` layout — 44×44 colored icon container (accentColor for priority) on left, title + 2-line content preview + `_buildInfoTag` chips in middle, icon-only action buttons (`edit`/`delete` 28×28 squares) on right column; unread dot above action buttons; no tall info rows
  - **`_buildInfoTag`**: reusable pill chip `px:6 py:3` with icon(10) + text(10), optional `tagColor` for priority/orange variant; matches Pattern #8 chip from student/teacher management
  - **Filter sheet** (#11): 75% height, gradient header, Priority/Target/Status FilterChip sections with `ColorUtils.slate*` colors; Cancel + Apply footer
  - **Add/Edit form** (#13): `showModalBottomSheet(isScrollControlled: true)`, 92% height, gradient header + subtitle + X close, `Expanded(SingleChildScrollView(Column))` form body, slate-styled `_buildDialogTextField` / `_buildPrioritasDropdown` / `_buildRoleTargetDropdown` / `_buildDateField` helpers, `_buildFilePicker` with `ColorUtils.slate*` throughout
  - **Delete dialog** (#14): inline Pattern #14 red gradient danger dialog — no `ConfirmationDialog` import
  - **Snackbars**: `ColorUtils.success600` / `ColorUtils.error600` replacing `Colors.green` / `Colors.red`
  - **Zero raw colors**: `Colors.grey`, `withOpacity`, `Color(0xFF...)`, `Colors.red/green` fully eliminated
✅ **Admin Class Activity** - Full redesign (v1.9 final):
  - **Header** (#7): Dynamic 3-state title — `_buildTeacherList` shows "Aktivitas Kelas" + subtitle; `_buildSubjectList` shows selected teacher name as title; `_buildActivityList` shows subject name as title; `_getCardGradient()` = `[primaryColor, primaryColor.withValues(alpha:0.85)]` solid admin-blue; 40×40 semi-transparent back button; icon badge (right) toggles per state; embedded `_buildSearchBar`
  - **Teacher cards** (#8): `CircleAvatar(radius:22)` colored via `ColorUtils.getColorForIndex(index)`, teacher name + NIP + `_buildInfoTag` chips (email, NIP label), slate100 40×40 chevron container on right
  - **Subject cards** (#8): 44×44 colored icon container `getColorForIndex(index)` with `Icons.menu_book_rounded`, subject name + hint "Tap untuk lihat aktivitas", slate100 chevron right
  - **Activity cards** (#8): 44×44 icon container — `corporateBlue600` for `tugas` type, `success600` for `materi` type; title + "subject • class" preview text; `_buildInfoTag` chips for date, type (colored tagColor), target role
  - **`_buildInfoTag`**: Pill chip `px:6 py:3`, icon(10) + text(10), optional `tagColor` for semantic type coloring — same pattern as Announcement and Student Management
  - **Detail dialog** (#10): `showDialog > Dialog(borderRadius:20)` with gradient header `Row` — 44×44 icon container + title+subtitle column, scrollable `_buildDetailItem` rows (36×36 icon container, label slate500, value slate800), `OutlinedButton` close footer with `ColorUtils.slate300/700`
  - **`_buildDetailItem`**: 36×36 icon container `primaryColor.withValues(alpha:0.1)`, `ColorUtils.slate500` label, `ColorUtils.slate800` value
  - **Error snackbar**: `ColorUtils.error600` replacing `Colors.red`
  - **Scaffold**: `ColorUtils.slate50` background replacing `Color(0xFFF8F9FA)`
  - **Zero raw colors**: `Colors.grey`, `withOpacity`, `Colors.orange/purple/green/red`, left accent strips fully eliminated

✅ **Admin RPP** - Full redesign (v2.1 final):
  - **Header** (#7): `AdminRppScreen` — `_getCardGradient()` fixed to `[primaryColor, primaryColor.withValues(alpha:0.85)]`; 40×40 back button with `Colors.white.withValues(alpha:0.2)` bg; dynamic title ("Pilih Guru" / "RPP - TeacherName"); popup menu (40×40 semi-transparent); search bar with `Colors.white.withValues(alpha:0.9)` bg; filter button with active dot indicator (`error600`)
  - **RPP cards** (`_buildRppCard`, #8): `AnimatedBuilder > Material > InkWell > Container(corporateShadow(1.5), slate200 border)` — 44×44 colored icon container `getColorForIndex(index)` + `Icons.description_rounded`; title (slate900 w700) + subject (slate500); status badge chip (statusColor alpha + border); `Divider(slate100)`; `Wrap(_buildInfoTag(class), _buildInfoTag(teacher))`; `_buildCircleActionButton(detail:primary, edit:warning600)`; no accent strip or decorative circle
  - **Teacher cards** (`_buildTeacherCard`, #8): `CircleAvatar(radius:22)` with `getColorForIndex(index)` + 0.15 alpha bg; name (slate900 w700) + NIP (slate500); slate100 36×36 chevron container on right; `corporateShadow(elevation:1.0)` + slate200 border
  - **`_buildInfoTag`**: Pill chip `px:6 py:3`, icon(10)+text(10), optional `tagColor` — matches design system standard
  - **`_buildCircleActionButton`**: 36×36 rounded square, `color.withValues(alpha:0.1)` bg + `color.withValues(alpha:0.25)` border
  - **Filter sheet** (#11): Gradient header `LinearGradient([primaryColor, primaryColor.withValues(alpha:0.85)])` with `Icon(tune_rounded) + Text` and white Reset button; status section header `Row(Icon(swap_horiz_rounded), Text(slate900))`; Cancel+Apply footer with `slate200` top border + shadow
  - **`_buildStatusChip`**: `selectedColor: primaryColor.withValues(alpha:0.2)`, `labelStyle: isSelected?primaryColor:slate600`, `side: isSelected?primaryColor:slate300`
  - **`RppAdminDetailPage`**: AppBar replaced with Pattern #7 inline gradient header (back button, "Detail RPP" + judul subtitle, `PopupMenuButton` 40×40 semi-transparent); `body: Column([header, Expanded(SingleChildScrollView(...))])`; status card uses outline badge with dot indicator (statusColor alpha); `_buildDetailItem` (slate600 label, slate800 value); `_buildContentSection` (slate700 title, slate50 bg, slate200 border); content cards use `corporateShadow(1.0)` + `slate200` border + `BorderRadius.circular(14)`
  - **Both `_getStatusColor()`**: `success600/warning600/error600/info600/slate400`; `_getStatusLabel`/`_getStatusLabelDetail` helpers
  - **Zero raw colors**: All `Colors.grey`, `withOpacity()`, `Colors.red/green/blue/orange`, accent strips, decorative circles eliminated

✅ **Admin Presence Report** - Full redesign (v2.0 final):
  - **Header** (#7): Both `AdminPresenceReportScreen` and `AdminAbsensiDetailPage` — `_getCardGradient()` fixed to `[primaryColor, primaryColor.withValues(alpha:0.85)]`; `AdminAbsensiDetailPage` AppBar replaced with inline Pattern #7 gradient header (back button, title/subject/date, edit/check/popup actions); old "Header Info Card" Container removed
  - **Filter sheet** (#11): Gradient header with Icon+Title; section headers using `Row(Icon+Text)` with `ColorUtils.slate700`; FilterChips with `Colors.white` background + `selectedColor: primaryColor.withValues(alpha:0.2)` + `checkmarkColor: primaryColor`; Cancel + Apply footer with border+shadow, `BorderRadius.circular(12)` buttons
  - **Class list** (`_buildClassList`, #8): `Material > InkWell > Container` — `corporateShadow(elevation:1.0)`, 44×44 colored icon container with `getColorForIndex(index)`, class name + grade `_buildInfoTag`, slate100 chevron container on right
  - **Summary cards** (`_buildSummaryCard`, #8): Clean white card with `corporateShadow(elevation:1.5)`, slate200 border, 44×44 book icon container, attendance `_buildInfoTag` chips (present/absent/total), `LinearProgressIndicator` with `success600`/`warning600`/`error600` based on percentage, detail button; no accent strip or decorative circle
  - **`_buildInfoTag`**: Reusable pill chip `px:6 py:3`, icon(10)+text(10), optional `tagColor` — same pattern as Announcement/Class Activity
  - **Student cards** (`_buildStudentCard`, AdminAbsensiDetailPage): `CircleAvatar(radius:22)` with `getColorForIndex(index)` + 0.15 alpha bg, name + NIS row, status badge chip, edit-mode quick-status buttons; no Stack/Positioned, no accent strip
  - **Stat cards** (`_buildStatCard`): Flat style `color.withValues(alpha:0.1)` background + `color.withValues(alpha:0.2)` border, 36×36 circle icon, count text in `color`, label text in `color.withValues(alpha:0.8)`; uses `success600`/`warning600`/`error600`/`info600`/`Color(0xFF7C3AED)` for semantic meaning
  - **Delete dialog** (#14): Pattern #14 danger dialog with `error600` gradient header, Cancel + Delete buttons
  - **AttendanceDataSource**: `CircleAvatar` uses `corporateBlue600`; grid cell borders use `slate200`; `_getStatusColor`/`_getStatusTextColor` use `success600`/`warning600`/`info600`/`error600`
  - **Snackbars**: `success600`/`warning600`/`error600` replacing raw green/orange/red
  - **Scaffold**: `slate50` background
  - **Zero raw colors**: All `Colors.grey`, `withOpacity()`, `Colors.red/green/blue/orange/purple` fully eliminated

✅ **Grade (Nilai) Page** - Four classes redesigned:
  - `GradePage`: Gradient header (#7) with search embedded, class/subject selection cards (#8) with color-coded avatar + `_buildInfoTag`
  - `GradeBookPage`: Gradient header (#7) with inline export + filter action buttons (40×40 semi-transparent), filter bottom sheet (#11) with toggle chips, styled assessment detail dialog (#10), danger confirm dialog (#14) for delete
  - `GradeInputForm`: Gradient header (#7) showing student name as subtitle, info summary card with `_buildDetailItem` rows, Pattern #9 styled form fields (`slate50` bg + `slate200` border + role-color focus ring)
  - `GradeInputFormNew`: Gradient header (#7), same styled configuration panel and form fields; progress counter badge using `success600`/`slate` semantic colors

✅ **Teacher Teaching Schedule** (`lib/screen/guru/teaching_schedule.dart`) - Full color & component redesign (v2.5):
  - **Scaffold**: `Color(0xFFF8F9FA)` → `ColorUtils.slate50`
  - **Gradient header** (#7): `_getCardGradient()` uses `withValues(alpha: 0.8)` instead of deprecated `withOpacity`; search bar hint `slate400`, prefix icon `slate500`; filter button 40×40 `Colors.white.withValues(alpha: 0.2)` bg; active-filter dot 8×8 `error600` with white border `1.5px`
  - **Filter chips** (active, horizontal ListView): pill style `Colors.white.withValues(alpha: 0.2)` bg + `0.3` border; "Hapus Semua" button `error600.withValues(alpha: 0.2)` bg + `0.3` border
  - **Count bar**: `slate500` text (was `Colors.grey[600]`); current view label in `_getPrimaryColor()`
  - **`_buildJadwalCard`** - Structural redesign:
    - Old: `Stack` with `Positioned(left strip)` + `Positioned(decorative circle)` + `Padding`
    - New: `ClipRRect > IntrinsicHeight > Row` — 5px wide left accent strip `Container(color: dayColor)` + `Expanded(Padding(...))`
    - Shadow: `BoxShadow(Colors.grey.withOpacity(0.3))` → `ColorUtils.corporateShadow(elevation: 1.5)`
    - Border: added `Border.all(color: ColorUtils.slate200)` for definition
    - Subject text: `Colors.black` → `ColorUtils.slate900 w700`; academic year text `slate500`
    - Day badge: `color: dayColor.withValues(alpha: 0.12)`, border `0.3`, radius `10`, text `w700 fontSize:13`
    - Icon containers: 32×32 → **36×36**, `borderRadius: 8`, added `border: Border.all(alpha: 0.15)`
    - Class/time/session info labels: `slate500`; values `slate900 w600`
    - Action buttons: `OutlinedButton` Materi — `borderRadius: 10`, `elevation: 0`, `backgroundColor: primary.withValues(alpha:0.05)`, border `primary.withValues(alpha:0.6) w:1.5`; `ElevatedButton` Aktivitas — `borderRadius: 10`, `elevation: 0`, `shadowColor: transparent`; both use `Icons.*_rounded` variants + `fontSize:12 w600`
  - **`_buildTableView`**: All `Colors.grey.*` borders → `ColorUtils.slate*`; table cell fill `dayColor.withValues(alpha:0.1)` + border `0.3`; legend container `slate50` bg + `slate200` border; `_buildTimeForSession` fallback text `slate400`
  - **`_showErrorSnackBar`**: `Colors.red.shade400` → `ColorUtils.error600` + `SnackBarBehavior.floating`
  - **`_dayColorMap`**: Hardcoded hex colors retained for day-specific semantic meaning (not semantic color system)
  - **Zero raw colors**: All `withOpacity`, `Colors.grey.*`, `Colors.black`, `Colors.red` fully eliminated

✅ **Notification List** (`lib/screen/common/notification_list.dart`) - Full redesign (v2.4):
  - **AppBar**: Gradient `corporateBlue600` with `flexibleSpace LinearGradient`; white title + dynamic subtitle `"$unreadCount belum dibaca"` (visible only when > 0); "Tandai semua dibaca" action button only rendered when `_hasUnread` — 36×36 frosted glass container (`Colors.white.withValues(alpha:0.2)`, `BorderRadius.circular(10)`) with `Icons.done_all_rounded`
  - **`_buildNotificationCard`** (#8): `Dismissible > GestureDetector > Container` — `corporateShadow(elevation: isRead ? 0.5 : 1.2)`; border `isRead ? slate200 w:1.0 : color.withValues(alpha:0.35) w:1.5`; `ClipRRect(borderRadius:14) > IntrinsicHeight > Row` — **left accent bar** 4px wide with type color (only on unread), then `Expanded(Padding)` with icon + text content
  - **Icon container**: 44×44, `color.withValues(alpha:0.12)` bg + `color.withValues(alpha:0.2)` border, type-colored icon 22px; read cards use `ColorUtils.slate400` as color
  - **Unread dot indicator**: 8×8 circle in top-right of title row, only on unread cards; title is `w700 slate900` (unread) vs `w500 slate600` (read)
  - **Body preview**: `maxLines:2 overflow:ellipsis`, `slate600` unread / `slate400` read
  - **Timestamp row**: `Icons.access_time_rounded` size:11 + relative text — "Baru saja" / "N menit lalu" / "N jam lalu" / "N hari lalu" / full date; color `slate400`
  - **Dismissible background**: `error600` bg + `BorderRadius.circular(14)` + `Icons.delete_rounded` + "Hapus" label — styled dismiss target
  - **`_getColor(type)`**: Semantic mapping — `bill/tagihan → success600`, `announcement/pengumuman → corporateBlue600`, `class_activity/activity → warning600`, `reminder_teaching → Color(0xFF7C3AED)`, `grade/nilai/exam_score → Color(0xFF0D9488)`, default `→ slate500`
  - **`_getIcon(type)`**: Rounded icon variants — `receipt_long_rounded`, `campaign_rounded`, `assignment_rounded`, `class_rounded`, `grade_rounded`, `notifications_rounded`
  - **`_showDetailDialog`** (#10): `Dialog(borderRadius:20, clipBehavior:Clip.antiAlias)` — gradient header `[color, color.withValues(alpha:0.8)]` with 44×44 frosted icon + title + timestamp subtitle; body text `slate700 height:1.6`; footer `slate100` top border + full-width `ElevatedButton` colored to match type
  - **Empty state**: `ListView(children:[SizedBox(120), Center(Column(...))])` — 80×80 circle container `corporateBlue600.withValues(alpha:0.1)` + `notifications_off_rounded` icon; "Tidak Ada Notifikasi" heading `slate800 w700`; "Semua notifikasi akan muncul di sini." subtitle `slate500`
  - **`_isUnread` helper**: Handles both `bool` and `int` (0/1) `is_read` field — centralizes read-state logic used by `_unreadCount`, `_hasUnread`, and card rendering
  - **Loading**: `CircularProgressIndicator(color: corporateBlue600)`; `RefreshIndicator(color: corporateBlue600)`
  - **Scaffold**: `slate50` background
  - **Zero raw colors**: All `Colors.grey`, `Colors.blue`, `Colors.red`, `withOpacity()` fully eliminated; `kDebugMode` guards on all `print()` calls

✅ **Teacher Presence (Absensi Guru)** (`lib/screen/guru/presence_teacher.dart`) - Full redesign aligned with Admin Presence Report (v2.5):
  - **Header** (#7): `PresencePage` — `_getCardGradient()` with `[primaryColor, primaryColor.withValues(alpha:0.85)]`; 40×40 semi-transparent back/filter buttons; dynamic title; search bar with `Colors.white.withValues(alpha:0.9)` bg
  - **Class list** (`_buildInlineClassList`, #8): `AnimatedBuilder` with staggered `FadeTransition + Transform.translate` using `Interval((index*0.1).clamp(0.0,0.8), 1.0, curve: Curves.easeOut)`; 40×40 icon container `borderRadius:10` + `alpha:0.15` bg; name `w700`; plain `Icon(arrow_forward_ios)` chevron; `corporateShadow(elevation:1.0)` + `slate200` border
  - **Summary cards** (`_buildSummaryCard`, #8): `AnimatedBuilder` with staggered animation; `corporateShadow(elevation:1.5)` + `slate200` border + `borderRadius:16`; 40×40 icon container `borderRadius:10` + `alpha:0.15`; inline class+lesson text; `_buildInfoTag` row for Present/Absent/Total counts; `LinearProgressIndicator(minHeight:6, borderRadius:4)` with `success600`/`warning600`/`error600` based on percentage; circle delete button
  - **`_buildInfoTag`**: Pill chip `px:6 py:3`, icon(10)+text(10), alpha `0.1` bg + `0.2` border — aligned with admin pattern
  - **Filter sheet** (#11): Gradient header with Icon+Title; section headers using `Row(Icon(size:16, slate700) + Text(w600, fontSize:14, slate900))` with `padding top:24`; `FilterChip` widgets for date range, subject, day, lesson hour sections — `selectedColor: primaryColor.withValues(alpha:0.2)`, `checkmarkColor: primaryColor`, `labelStyle` toggling between `primaryColor/bold` and `slate600/normal`; Cancel + Apply footer with `slate200` top border + shadow
  - **Edit bottom sheet** (#13): Existing pattern preserved
  - **`TeacherAbsensiDetailPage` header** (#7): Inline gradient header with close/back toggle (close when editing, back when viewing); dynamic title ("Edit Kehadiran" / "Detail Kehadiran"); date+lesson hour info row at bottom; `fontSize:18`
  - **Student cards** (`_buildStudentCard`, detail page): Flat `Container` with `corporateShadow(elevation:1.0)` + `borderRadius:14` + `slate200` border; `CircleAvatar(radius:22)` with `getColorForIndex(index)` + `0.15` alpha bg; name `fontSize:15 w700 slate900`; status badge `px:10 py:5`; quick-status buttons when editing — no Stack/accent strip
  - **`_buildQuickStatusButton`**: 36×36 circle, `isSelected ? color : color.withValues(alpha:0.1)` bg, `Border.all(color:color, width:1.5)`, text `bold fontSize:12`, white/color text toggle
  - **Stat cards** (`_buildStatCard`, detail page): Flat `color.withValues(alpha:0.1)` bg + `color.withValues(alpha:0.2)` border; 36×36 circle icon `color.withValues(alpha:0.15)`; count `w800` in `color`; label `color.withValues(alpha:0.8)`; height `120`, padding `h:16`; conditional Permission/Sick cards
  - **`_getStatusColor`**: `success600` (Hadir) / `info600` (Sakit) / `warning600` (Izin) / `error600` (Alpha) / `Color(0xFF7C3AED)` (Terlambat)
  - **`_buildInfoChip`** (detail page): Alpha `0.1` bg + `0.2` border — aligned with admin
  - **Animations**: `TickerProviderStateMixin` for dual controllers (`TabController` + `_listAnimationController`); animation triggered on `_loadInitialData` and `_loadAbsensiSummary`
  - **Zero raw colors**: All `Colors.grey`, `Colors.green`, `Colors.blue`, `Colors.orange`, `Colors.red`, `Colors.purple`, `withOpacity()` fully eliminated

✅ **Teacher Learning Materials (Materi Pembelajaran)** (`lib/screen/guru/materi_screen.dart`) - Full redesign (v2.6):
  - **`MateriPage` header** (#7): `_getCardGradient()` with `[primaryColor, primaryColor.withValues(alpha:0.85)]`; 40×40 semi-transparent back/generate/refresh buttons (`Colors.white.withValues(alpha:0.2)`, `borderRadius:10`); title + subtitle; rounded icon variants (`auto_awesome_rounded`, `refresh_rounded`)
  - **Filter section**: `primaryColor.withValues(alpha:0.08)` info bar with `0.15` border + 32×32 icon container; pill badge `primaryColor.withValues(alpha:0.15)` for checked count; full-width Generate RPP button `success600` + `borderRadius:12` + `elevation:0`; bottom border `slate200`
  - **Dropdowns** (`_buildKelasDropdown`, `_buildMataPelajaranDropdown`): `slate50` bg + `slate200` border + `borderRadius:10`; labels `slate600 w600 fontSize:12`; icons `slate500`; text `slate800 fontSize:14`; `arrow_drop_down` in `slate500`
  - **Material cards** (`_buildMateriList`, #8): `Material > InkWell > Container` — `corporateShadow(elevation:1.5)` + `slate200` border + `borderRadius:14`; 44×44 colored number container `getColorForIndex(index).withValues(alpha:0.15)` bg + `0.25` border + `borderRadius:10`; title `w700 fontSize:15 slate900`; subtitle `slate500 fontSize:13`; 32×32 expand/collapse container `slate100` bg; no Stack/accent strip/decorative circle
  - **Sub-chapter list** (`_buildSubBabList`): Custom `Row` replacing `ListTile`; 36×36 colored number containers `alpha:0.12` bg + `0.2` border + `borderRadius:8`; text `w600 fontSize:14 slate800`; `arrow_forward_ios_rounded` chevron `slate400 size:14`; `Material > InkWell` for tap
  - **`_getCheckboxColor`**: Helper method — `info600` (used/blue), `Color(0xFF8B5CF6)` (generated/purple), `success600` (checked/green); applies to both bab and sub-bab checkboxes
  - **Search results**: `slate500` text color
  - **`SubBabDetailPage` header** (#7): Same gradient pattern; custom done/undone toggle button (pill with `check_circle_rounded`/`circle_outlined` icon + text, `alpha:0.3/0.15` bg toggle); sub-bab info card with 32×32 icon container `alpha:0.2` bg + `borderRadius:8`, `borderRadius:10` card with `alpha:0.15` bg + `0.2` border
  - **Content cards** (`_buildContentList`, #8): Flat card `corporateShadow(elevation:1.0)` + `slate200` border + `borderRadius:14`; 44×44 colored number container `alpha:0.15` bg + `0.25` border; title `w700 fontSize:15 slate900`; description `slate600 fontSize:13 height:1.5`; no colored left side panel
  - **Scaffold**: `ColorUtils.slate50` background (both pages)
  - **`_dayColorMap`**: Hardcoded hex colors retained for day-specific semantic meaning (same as Teaching Schedule)
  - **Zero raw colors**: All `Colors.grey`, `Colors.blue`, `Colors.black12`, `withOpacity()` fully eliminated

✅ **Teacher RPP (Guru RPP)** (`lib/screen/guru/rpp_screen.dart`) - Full redesign (v2.7):
  - **`RppScreen` header** (#7): `_getCardGradient()` with `[primaryColor, primaryColor.withValues(alpha:0.85)]`; 40×40 semi-transparent back/refresh buttons (`Colors.white.withValues(alpha:0.2)`, `borderRadius:10`); title + subtitle; search bar with `Colors.white.withValues(alpha:0.9)` bg; filter button with active dot indicator (`error600`); active filter chips pill style `Colors.white.withValues(alpha:0.2)` bg + `0.5` border with clear button
  - **RPP cards** (`_buildRppCard`, #8): `AnimatedBuilder` with staggered `FadeTransition + Transform.translate` using `Interval((index*0.1).clamp(0.0,0.9), 1.0, curve: Curves.easeOut)`; `Material > InkWell > Container` — `corporateShadow(elevation:1.5)` + `slate200` border + `borderRadius:16`; 44×44 colored icon container `getColorForIndex(index).withValues(alpha:0.15)` bg + `Icons.description_rounded`; title `slate900 w700 fontSize:15` + subject `slate500 fontSize:12`; status badge chip `statusColor.withValues(alpha:0.1)` bg + `0.3` border + `fontSize:10 w600`; `Divider(slate100)`; `Wrap(_buildInfoTag(class))`; `_buildCircleActionButton` row (detail:primary, edit:warning600, delete:error600); no Stack/accent strip/decorative circle
  - **`_buildInfoTag`**: Pill chip `px:6 py:3`, icon(10)+text(10), optional `tagColor`, alpha `0.1` bg + `0.2` border — matches design system standard
  - **`_buildCircleActionButton`**: 36×36 rounded square, `color.withValues(alpha:0.1)` bg + `color.withValues(alpha:0.25)` border + `borderRadius:10`
  - **Filter sheet** (#11): Gradient header `LinearGradient([primaryColor, primaryColor.withValues(alpha:0.85)])` with `Icon(tune_rounded) + Text` and white Reset button; status section header `Row(Icon(swap_horiz_rounded, size:18, slate700), Text(slate900 w700))` with spacing 12; `_buildStatusChip` using `ChoiceChip` — `selectedColor: primaryColor.withValues(alpha:0.2)`, `labelStyle` toggling between `primaryColor/bold` and `slate600/normal`, `side: isSelected?primaryColor:slate300`; Cancel + Apply footer with `slate200` top border + shadow
  - **Add/Edit form** (#13): `showModalBottomSheet(isScrollControlled: true)`, 92% height, gradient header (44×44 icon container `white*0.2` bg + `white*0.3` border + edit/add icon, title 18px bold + subtitle 12px `white*0.8`, 32×32 circle close button `white*0.2`); `Expanded(SingleChildScrollView(Column))` form body; slate-styled `_buildDialogTextField` (Container `slate50` bg + `slate200` border + `borderRadius:12`, `TextFormField` with `labelText` + `corporateBlue600` prefix icons size:18, `InputBorder.none` + `focusedBorder: corporateBlue600 w:1.5` + `errorBorder: error600`) / `_buildDialogDropdown` (same container + `DropdownButtonFormField` with `initialValue`); semester & academic year as separate fields; file upload section (`slate50` bg container + 40×40 icon indicator + view button `info600` + choose button `primaryColor`); footer `fromLTRB(16,8,16,16)` — Cancel `OutlinedButton(slate300 side, slate700 text, w600)` + Save `ElevatedButton(corporateBlue600 bg, elevation:2, shadowColor:corporateBlue600*0.4)` with loading spinner
  - **`RppDetailPage`** (#12-style): Inline gradient header (#7) with back button + "Detail RPP" title + judul subtitle; `body: Column([header, Expanded(SingleChildScrollView(...))])` with 3 content cards — title+status card (outline badge with 6×6 dot indicator, `statusColor.withValues(alpha:0.1)` bg + `0.3` border), info card (`_buildDetailItem` with `slate500` label + `slate900` value), file card (44×44 `info600` icon container + file name + download icon); all cards use `corporateShadow(elevation:1.0)` + `slate200` border + `borderRadius:14`
  - **Delete dialog**: Inline `AlertDialog` with `error600` bg `ElevatedButton` + `borderRadius:10`
  - **Snackbars**: `success600` / `error600` replacing raw green/red
  - **Empty state**: 72×72 container `slate100` bg + `borderRadius:20` + `Icons.description_outlined` `slate400`; title `slate700 w600 fontSize:16`; subtitle `slate500 fontSize:13`
  - **Error state**: Same 72×72 container with `error600.withValues(alpha:0.1)` bg; retry `ElevatedButton` with `primaryColor` bg
  - **`_getStatusColor`**: `success600` (Approved) / `warning600` (Pending) / `error600` (Rejected) / `info600` (Draft) / `slate400` (default)
  - **Scaffold**: `Color(0xFFF8F9FA)` for list screen, `ColorUtils.slate50` for detail page
  - **Zero raw colors**: All `Colors.grey`, `Colors.red/green/blue/orange/black`, `withOpacity()` fully eliminated; only pre-existing `print()` statements remain (guarded by `kDebugMode` where applicable)

✅ **Wali Murid Announcement** (`lib/screen/walimurid/announcement_screen.dart`) - Full redesign (v2.9):
  - **Header** (#7): `_getCardGradient()` with `[primaryColor, primaryColor.withValues(alpha:0.85)]`; 40×40 semi-transparent back/announcement buttons (`Colors.white.withValues(alpha:0.2)`, `borderRadius:10`); title + subtitle; search bar with `Colors.white.withValues(alpha:0.9)` bg, `ColorUtils.slate400` hint/prefix icon, `ColorUtils.slate900` text
  - **Announcement cards** (`_buildAnnouncementCard`, #8): `Material > InkWell > Container` — `corporateShadow(elevation:1.0)` + `slate200` border + `borderRadius:14`; 44×44 colored icon container `accentColor.withValues(alpha:0.1)` bg + `accentColor.withValues(alpha:0.25)` border — `campaign_rounded` for important, `announcement_outlined` for normal; title `slate900 w700 fontSize:14` + content preview `slate600 fontSize:12 height:1.4`; `Wrap(_buildInfoTag)` chips for time, creator, target, importance; unread dot 8×8 `error600` circle; `accentColor = isImportant ? warning600 : primaryColor`; no Stack/accent strip/decorative circle
  - **`_buildInfoTag`**: Pill chip `px:6 py:3`, icon(10)+text(10), optional `tagColor`, alpha `0.08` bg + `0.3` border — matches admin announcement pattern exactly
  - **Detail dialog** (#10): Gradient header with 40×40 icon container `white*0.2`; priority badge using `warning600.withValues(alpha:0.1)` bg + `0.4` border (replacing raw `Colors.orange`); content `slate800` fontSize:16 height:1.6; attachment section `slate50` bg + `slate200` border + icon container `white` bg `slate200` border; metadata section `slate50` bg with `_buildDetailRow`; close button `ElevatedButton` with `primaryColor` bg
  - **`_buildDetailRow`**: Icon(16) `_getPrimaryColor()` + label `slate500` fontSize:12 + value `slate800 w600` fontSize:14
  - **Snackbars**: `ColorUtils.error600` replacing raw `Colors.red`
  - **Scaffold**: `ColorUtils.slate50` replacing raw `Color(0xFFF8F9FA)`
  - **Search bar**: `ColorUtils.slate400` hints/icons replacing raw `Colors.grey`, `ColorUtils.slate900` text replacing `Colors.black87`
  - **Zero raw colors**: All `Colors.grey.shade*`, `Colors.black`, `Colors.black87`, `Colors.red`, `Colors.orange`, `withOpacity()` fully eliminated
  - **Note**: Read-only screen (no add/edit/delete features) — matched to admin announcement card/detail patterns without admin-only features (filter sheet, FAB, form dialog, delete dialog, pagination)

✅ **Wali Murid Presence** (`lib/screen/walimurid/presence_parent.dart`) - Full redesign (v2.10):
  - **Header** (#7): `_getCardGradient()` with `[primaryColor, primaryColor.withValues(alpha:0.85)]`; flat bottom (no border radius); 40×40 semi-transparent back button (`Colors.white.withValues(alpha:0.2)`, `borderRadius:10`); title + subtitle; search bar with `Colors.white.withValues(alpha:0.9)` bg, `ColorUtils.slate400` hint/prefix icon, `ColorUtils.slate900` text; filter button with `error600` active dot indicator (8×8); filter chips `Colors.white.withValues(alpha:0.2)` bg + `0.5` border with close icon
  - **`_getPrimaryColor()`**: `ColorUtils.getRoleColor('wali')` replacing hardcoded `Color(0xFF9333EA)`
  - **`_getStatusColor()`**: Semantic mapping — hadir→`success600`, terlambat→`corporateBlue600`, izin→`info600`, sakit→`warning600`, alpha→`error600`, default→`slate400`
  - **`_getStatusIcon()`**: Status-specific outlined icons — hadir→`check_circle_outline`, terlambat→`schedule`, izin→`event_busy_outlined`, sakit→`local_hospital_outlined`, alpha→`cancel_outlined`, default→`help_outline`
  - **Attendance cards** (`_buildAbsensiItem`, #8): `Material > InkWell > Container` — `corporateShadow(elevation:1.0)` + `slate200` border + `borderRadius:14`; 50×50 date container `primaryColor.withValues(alpha:0.1)` bg + `0.2` border + `borderRadius:12` displaying day number (`primaryColor w800 fontSize:18`) + month abbrev (`primaryColor.withValues(alpha:0.7) fontSize:10`); subject name `slate900 w700 fontSize:14` + day name `slate500 fontSize:12`; `Wrap(_buildInfoTag)` chips for full date, lesson hour, status (with `_getStatusIcon` + `_getStatusColor`); 8×8 unread dot `error600`; no Stack/accent strip/decorative circle
  - **`_buildInfoTag`**: Pill chip `px:6 py:3`, icon(10)+text(10), optional `tagColor`, alpha `0.08` bg + `0.3` border — matches design system standard
  - **Monthly summary** (`_buildMonthlySummary`): `corporateShadow(elevation:1.0)` + `slate200` border + `borderRadius:14`; header row with `slate900 w700 fontSize:15` title + attendance rate badge (`primaryColor.withValues(alpha:0.1)` bg + `0.3` border); stat items via `_buildStatItem` with `statusColor.withValues(alpha:0.1)` bg circle (28×28) + count `slate900 w700` + label `slate500 fontSize:11`; `_getStatusColor` applied to each stat category
  - **Student info card**: `corporateShadow(elevation:1.0)` + `slate200` border + `borderRadius:14`; 48×48 `CircleAvatar` with `primaryColor.withValues(alpha:0.15)` bg + `primaryColor` border + initial letter `primaryColor w700 fontSize:18`; name `slate900 w700 fontSize:15` + class info `slate600 fontSize:13`
  - **Empty state**: 72×72 container `slate100` bg + `borderRadius:20` + `Icons.assignment_outlined` `slate400`; title `slate700 w600 fontSize:16`; subtitle `slate500 fontSize:13`
  - **Loading state**: `CircularProgressIndicator` with `primaryColor`, text `slate600 fontSize:14`
  - **Snackbars**: `ColorUtils.error600` replacing raw `Colors.red`
  - **Scaffold**: `ColorUtils.slate50` replacing raw `Color(0xFFF8F9FA)`
  - **Section title**: "Riwayat Absensi" with translation support, `ColorUtils.slate900 w700 fontSize:16`
  - **Zero raw colors**: All `Colors.grey.shade*`, `Colors.black`, `Colors.red`, `Colors.purple`, `Color(0xFF9333EA)`, `withOpacity()` fully eliminated
  - **Filter sheet** (#11): Replaced shared `FilterSheet` component with inline `StatefulBuilder`; gradient header `LinearGradient([primaryColor, primaryColor.withValues(alpha:0.8)])` with `borderRadius:24` top corners, 36×4 drag handle `white*0.5`, 36×36 icon container `white*0.2` bg + `borderRadius:10` + `Icons.filter_list`, title `fontSize:18 bold white`, white Reset `TextButton`; `_buildSectionHeader(title, icon)` — `Padding(top:24)` + `Row(Icon(16, slate700), Text(fontSize:14 w600 slate900))`; 2 sections (Month with `calendar_month_outlined`, Semester with `school_outlined`); `FilterChip` — `backgroundColor: Colors.white`, `selectedColor: primaryColor.withValues(alpha:0.2)`, `checkmarkColor: primaryColor`, label toggles `primaryColor/bold` ↔ `slate600/normal`; footer `fromLTRB(20,12,20,24)` with `slate200` top border — Cancel `OutlinedButton(slate300 side, slate700 text, borderRadius:12)` + Apply `ElevatedButton(primaryColor bg, white foreground, elevation:0, borderRadius:12, bold text)`
  - **Bug fix**: Added missing `languageProvider = context.read<LanguageProvider>()` declaration in `_buildMonthlySummary()`

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

**Design System Version:** 2.10
**Compatible with:** Flutter 3.x
**Maintained by:** Development Team
