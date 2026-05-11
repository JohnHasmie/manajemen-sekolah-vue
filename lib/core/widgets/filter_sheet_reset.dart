// Shared helpers for filter bottom-sheet behaviour.
//
// All filter sheets in the app share two recurring chores: handling the
// "Reset" button, and resolving the label of a picked item by id. The
// implementations have drifted across features over time and several of
// them shipped subtly broken — most commonly the Reset button that
// silently did nothing.
//
// This file centralises the contract so every new filter sheet starts
// from a working pattern instead of reinventing it.
//
// ─── BRAND FILTER RULE ────────────────────────────────────────────────
//
// Every filter sheet's class / subject / teacher / day / semester chip
// set MUST come from `ref.watch(filterRosterRiverpod)`. That provider
// is hydrated once at dashboard init from the role-aware
// `GET /filter-options` endpoint and cached for 6 hours. Filter sheets
// must NEVER derive chip options from:
//
//   • the page's currently-displayed list (`_groupedData`, paginated
//     lists), because that list is server-filtered — applying a filter
//     shrinks it to the picked value and the chip set collapses with it
//   • a per-screen "all classes" state field loaded independently of
//     `/filter-options`, because the two will drift (e.g. one includes
//     grade-authored classes, the other doesn't, and the filter shows
//     a different set than the screen surfaces)
//
// For the teacher mengajar ↔ wali kelas dichotomy use
// `FilterRosterProvider.classesForView(isHomeroomView: ...)` — the
// backend already partitions the roster for you.
//
// If a filter needs a narrower set than the global roster (e.g. "which
// subjects does this teacher use *for the currently-picked class*"),
// fetch that on demand from a dedicated endpoint such as
// `/teacher/{id}/subjects?class_id=X` — that's a different question
// than the global roster, not a violation of the rule.

import 'package:flutter/material.dart';

/// Shared filter-sheet helpers.
///
/// **Reset semantics** — when a teacher/parent taps "Reset" inside a
/// filter sheet, they mean: "remove all filters now, and let me see
/// the unfiltered data". That requires three steps in a fixed order:
///
///   1. Close the sheet.
///   2. Clear the outer screen's filter state.
///   3. Trigger a data reload.
///
/// Skipping any one of these leaves a broken user experience:
///
///   - No pop → the in-sheet chips visually clear but the sheet
///     stays open; if the user then taps Apply, the in-flight local
///     state (which the bare reset didn't touch) restores the filter
///     they just tried to clear.
///   - No outer-state clear → the chips outside the sheet (header
///     chip strip, active-filter row) keep showing the old filter
///     even after the sheet closes.
///   - No reload → the data list keeps whatever shape the previous
///     backend-filtered fetch returned, even though the filter
///     fields are now null.
///
/// `FilterSheetHelpers.reset` performs steps 1–3 in one call. Pass a
/// [commit] callback that does the outer-state clear plus reload
/// (typically `setState(() { filterX = null; ... }); loadData();`).
///
/// **Label tracking** — when a class/subject chip is tapped, the
/// in-sheet state usually tracks the id. But the header chip strip
/// outside the sheet wants to display the human-readable name. If
/// the onSelected handler forgets to also resolve and stash the
/// label, Apply commits `classId='abc'` alongside `className=null`
/// and the header chip stays stuck on its placeholder. Use
/// [labelForId] to resolve a label from any `[{id, name|nama|...}]`
/// list with one call.
class FilterSheetHelpers {
  FilterSheetHelpers._();

  /// Standard "Reset" handler for [AppFilterBottomSheet.onReset].
  ///
  /// Pops the sheet, then runs [commit]. The commit callback must
  /// clear the outer screen's filter fields **and** trigger a data
  /// reload — both inside a single `setState` is fine, or split
  /// across `setState` + `loadData()` calls.
  ///
  /// Safe to call when the sheet is no longer poppable — the helper
  /// guards on `Navigator.canPop` so a stray double-tap doesn't
  /// trigger an assertion.
  ///
  /// Example:
  ///
  /// ```dart
  /// showFilterSheet(
  ///   context: context,
  ///   onReset: () => FilterSheetHelpers.reset(context, () {
  ///     setState(() {
  ///       filterClassId = null;
  ///       filterSubjectId = null;
  ///     });
  ///     loadData();
  ///   }),
  ///   ...
  /// );
  /// ```
  static void reset(BuildContext context, VoidCallback commit) {
    if (Navigator.canPop(context)) {
      Navigator.pop(context);
    }
    commit();
  }

  /// Looks up the human-readable label of an entry in [items] whose
  /// `id` matches [id]. Walks [keys] in order and returns the first
  /// non-null value — defaults to `['name', 'nama']` to cover the
  /// snake- and camel-case variants the various backends emit.
  ///
  /// Returns `null` when [id] is null or no match is found, so it's
  /// safe to forward straight into a `tClassName = ...` assignment
  /// when the user has deselected.
  ///
  /// Example:
  ///
  /// ```dart
  /// onSelected: (id) {
  ///   setSS(() {
  ///     tClassId = id;
  ///     tClassName = FilterSheetHelpers.labelForId(
  ///       ref.read(filterRosterRiverpod).classes,
  ///       id,
  ///     );
  ///   });
  /// }
  /// ```
  static String? labelForId(
    Iterable<dynamic> items,
    String? id, {
    List<String> keys = const ['name', 'nama'],
  }) {
    if (id == null) return null;
    for (final item in items) {
      if (item is Map && item['id']?.toString() == id) {
        for (final k in keys) {
          final v = item[k];
          if (v != null) return v.toString();
        }
      }
    }
    return null;
  }
}
