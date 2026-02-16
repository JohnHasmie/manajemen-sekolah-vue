# Claude Code Instructions

This file contains persistent instructions for Claude Code when working on this project.

## Project Overview

**Name:** Manajemen Sekolah (School Management System)
**Framework:** Flutter
**Platform:** Cross-platform (iOS, Android, macOS, Web)
**Architecture:** Feature-based with provider state management

## Design System

**IMPORTANT:** This project follows the **Kamil Edu Professional Design System**.

📖 **Full Design Guide:** [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md)

### Quick Reference

When working on any UI components or pages:

1. **Always read [`DESIGN_SYSTEM.md`](./DESIGN_SYSTEM.md) first** before making design changes
2. **Use the defined color palette** - No arbitrary colors
3. **Follow typography system** - Use `DashboardTypography` or defined text styles
4. **Apply spacing rules** - 4px grid system (8px, 12px, 16px, etc.)
5. **Use layered shadows** - Never single shadows, always 2+ layers
6. **Maintain consistency** - Reference dashboard implementation as example

### Design Principles
- Professional & Corporate aesthetic
- Kamil Edu blue palette (deep blues, not bright)
- Layered shadows for depth
- Glass morphism effects
- Smooth 300ms animations
- 16px w700 section headers
- Icon containers with borders

### Key Files
- `/lib/utils/color_utils.dart` - Color palette and helpers
- `/lib/utils/dashboard_typography.dart` - Typography system
- `/lib/widgets/dashboard/` - Reference component implementations
- `/lib/screen/dashboard.dart` - Complete redesigned dashboard example

## Code Standards

### File Organization
```
lib/
├── models/          # Data models
├── providers/       # State management
├── screen/          # Page screens
├── services/        # API and business logic
├── utils/           # Utilities (colors, typography, helpers)
└── widgets/         # Reusable UI components
    └── dashboard/   # Dashboard-specific widgets
```

### Naming Conventions
- Files: `snake_case.dart`
- Classes: `PascalCase`
- Variables/functions: `camelCase`
- Constants: `camelCase` (ColorUtils.slate900)
- Private members: `_leadingUnderscore`

### Widget Guidelines
1. **Extract reusable components** - Don't duplicate widget code
2. **Use const constructors** where possible
3. **Proper null safety** - Use `?`, `!`, and `??` appropriately
4. **Avoid deep nesting** - Extract methods/widgets if >3 levels
5. **StatelessWidget first** - Only use StatefulWidget when state needed

### Layout Best Practices
```dart
// ✅ Good - Using ListView.separated
ListView.separated(
  itemCount: items.length,
  separatorBuilder: (context, index) => SizedBox(height: 8),
  itemBuilder: (context, index) => ItemCard(item: items[index]),
)

// ❌ Avoid - Manual spacing
Column(
  children: items.map((item) =>
    Column(children: [ItemCard(item: item), SizedBox(height: 8)])
  ).toList(),
)
```

## Git Workflow

### Commit Messages
Follow conventional commits:
- `feat:` New features
- `fix:` Bug fixes
- `refactor:` Code restructuring
- `style:` UI/design changes
- `docs:` Documentation updates
- `chore:` Maintenance tasks

Example: `feat: Implement professional Kamil Edu dashboard redesign`

### Branches
- `main` - Production-ready code
- `luay1` - Current development branch (active)
- Feature branches: `feature/description`

## Environment Setup

### Required Files
- `.env` - Environment variables (API keys, URLs)
  - `API_BASE_URL_IOS` - iOS API endpoint
  - `LOG_API_KEY` - Logging API key

### API Configuration
- Development: `http://127.0.0.1:8000/api`
- Service: `lib/services/api_services.dart`

## Testing

### Before Committing
1. Build succeeds without errors
2. No deprecation warnings (use `withValues(alpha:)` not deprecated `.alpha`)
3. All routes navigate correctly
4. Responsive on different screen sizes
5. Design system compliance (check DESIGN_SYSTEM.md)

### Build Commands
```bash
# Run on macOS
flutter run -d macos

# Build release
flutter build macos --release

# Hot reload
r (when app is running)

# Clean build
flutter clean && flutter pub get
```

## Role-Based Features

The app serves three user roles:
1. **Admin** - Full system management
2. **Guru (Teacher)** - Teaching and grading
3. **Wali (Parent)** - Student monitoring

Each role has customized:
- Dashboard content
- Navigation menus
- Color themes
- Available features

## Common Patterns

### Navigation
```dart
Navigator.push(
  context,
  MaterialPageRoute(builder: (context) => TargetPage()),
);
```

### State Management (Provider)
```dart
// Reading state
final provider = Provider.of<MyProvider>(context);

// Watching for changes
Consumer<MyProvider>(
  builder: (context, provider, child) => /* Widget */,
)
```

### Localization
```dart
// Use AppLocalizations for all user-facing text
AppLocalizations.appTitle.tr
```

## Design System Application Example

### Before (Old Pattern)
```dart
Container(
  padding: EdgeInsets.all(10),
  decoration: BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
      BoxShadow(
        color: Colors.black12,
        blurRadius: 4,
      ),
    ],
  ),
)
```

### After (Kamil Edu Pattern)
```dart
Container(
  padding: EdgeInsets.all(12),
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
  ),
)
```

## Troubleshooting

### Common Issues

**API Connection Failed**
- Ensure backend is running on `127.0.0.1:8000`
- Check `.env` configuration
- Verify network permissions

**Build Warnings (macOS deployment target)**
- Expected warnings for Pods deployment targets
- Safe to ignore unless affecting functionality

**Deprecation: color.alpha**
- Use: `color.withValues(alpha: 0.5)`
- Not: `color.withOpacity(0.5)` or accessing `.alpha` directly

**Hot Reload Not Working**
- Try hot restart (R)
- If issues persist: `flutter clean && flutter run`

## Important Notes

1. **Never commit `.env` file** - Contains sensitive API keys
2. **Always use const constructors** when possible for performance
3. **Follow design system strictly** - Consistency is key
4. **Test all roles** - Admin, Teacher, Parent have different UIs
5. **Reference dashboard.dart** - Best example of Kamil Edu design implementation

## Documentation

- [DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md) - Complete design guidelines
- [README.md](./README.md) - Project setup and overview
- API Documentation - (Add link when available)

## Contact

For questions or issues related to:
- **Design System:** Reference DESIGN_SYSTEM.md
- **Code Patterns:** Check existing implementations
- **API Issues:** Contact backend team

---

**Last Updated:** 2026-02-16
**Design System Version:** 1.0
