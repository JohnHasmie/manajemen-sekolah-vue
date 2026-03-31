// Unit tests for DashboardTypography factory methods.
// Each method returns a TextStyle — we verify font sizes, weights, and that
// optional color overrides work correctly.  No widgets are rendered.
// Like testing a Laravel helper that returns configuration arrays.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:manajemensekolah/core/utils/dashboard_typography.dart';

void main() {
  group('DashboardTypography heading styles', () {
    test('heading1 returns 24px bold style', () {
      final style = DashboardTypography.heading1();
      expect(style.fontSize, 24);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('heading2 returns 20px semibold style', () {
      final style = DashboardTypography.heading2();
      expect(style.fontSize, 20);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('heading3 returns 18px semibold style', () {
      final style = DashboardTypography.heading3();
      expect(style.fontSize, 18);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('heading1 uses supplied color override', () {
      const override = Colors.red;
      final style = DashboardTypography.heading1(color: override);
      expect(style.color, override);
    });
  });

  group('DashboardTypography body styles', () {
    test('subtitle returns 14px medium weight', () {
      final style = DashboardTypography.subtitle();
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w500);
    });

    test('body returns 14px regular weight', () {
      final style = DashboardTypography.body();
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w400);
    });

    test('bodyBold returns 14px semibold weight', () {
      final style = DashboardTypography.bodyBold();
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('body uses supplied color override', () {
      const override = Colors.blue;
      final style = DashboardTypography.body(color: override);
      expect(style.color, override);
    });
  });

  group('DashboardTypography small/caption styles', () {
    test('caption returns 12px regular weight', () {
      final style = DashboardTypography.caption();
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w400);
    });

    test('captionBold returns 12px semibold weight', () {
      final style = DashboardTypography.captionBold();
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('label returns 10px with letter spacing', () {
      final style = DashboardTypography.label();
      expect(style.fontSize, 10);
      expect(style.letterSpacing, greaterThan(0));
    });
  });

  group('DashboardTypography specialised stat styles', () {
    test('statValue returns 28px bold — biggest text in the hierarchy', () {
      final style = DashboardTypography.statValue();
      expect(style.fontSize, 28);
      expect(style.fontWeight, FontWeight.w700);
    });

    test('statTitle returns 13px medium weight', () {
      final style = DashboardTypography.statTitle();
      expect(style.fontSize, 13);
      expect(style.fontWeight, FontWeight.w500);
    });

    test('statSubtitle returns 11px regular weight', () {
      final style = DashboardTypography.statSubtitle();
      expect(style.fontSize, 11);
      expect(style.fontWeight, FontWeight.w400);
    });

    test('trendText accepts a color and uses it directly (no default)', () {
      const override = Colors.green;
      final style = DashboardTypography.trendText(color: override);
      expect(style.color, override);
    });

    test('trendText without color argument has null color (caller sets it)', () {
      final style = DashboardTypography.trendText();
      expect(style.color, isNull);
    });

    test('menuTitle returns 14px semibold', () {
      final style = DashboardTypography.menuTitle();
      expect(style.fontSize, 14);
      expect(style.fontWeight, FontWeight.w600);
    });

    test('categoryTitle returns 12px bold with positive letter spacing', () {
      final style = DashboardTypography.categoryTitle();
      expect(style.fontSize, 12);
      expect(style.fontWeight, FontWeight.w700);
      expect(style.letterSpacing, greaterThan(0));
    });
  });
}
