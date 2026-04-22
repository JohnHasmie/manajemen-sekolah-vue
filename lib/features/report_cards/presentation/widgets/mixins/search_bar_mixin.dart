import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

/// Mixin for building the search input section.
mixin SearchBarMixin {
  /// Abstract setter to update search query (provided by State).
  set searchQuery(String value);

  /// Abstract getter for build context (provided by State).
  BuildContext get context;

  /// Build the search bar for filtering students.
  Widget buildSearchBar() {
    final accentColor = ColorUtils.getRoleColor('guru');

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        onChanged: (v) {
          searchQuery = v;
        },
        style: const TextStyle(fontSize: 13),
        decoration: InputDecoration(
          hintText: 'Cari siswa...',
          hintStyle: TextStyle(color: ColorUtils.slate400, fontSize: 13),
          prefixIcon: Icon(Icons.search, size: 18, color: ColorUtils.slate400),
          isDense: true,
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ColorUtils.slate200),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: ColorUtils.slate200),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: accentColor, width: 1.5),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
        ),
      ),
    );
  }
}
