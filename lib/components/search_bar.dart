// Simple search bar component with a text input and clear button.
//
// Like a basic Vue `<SearchInput>` component with `v-model` and a clear icon,
// or a Blade partial `@include('partials.search-bar')`.
// This is the simpler version; see EnhancedSearchBar for the version with filters.
import 'package:flutter/material.dart';

/// A simple search bar widget with an icon, text field, and clear button.
///
/// Like a Vue `<SearchBar>` component with props:
/// - [controller] - the text controller (like `v-model`)
/// - [hintText] - placeholder text (defaults to 'Cari...')
/// - [onChanged] - keystroke callback (like `@input`)
///
/// Simpler alternative to [EnhancedSearchBar] when no filter dropdown is needed.
class CustomSearchBar extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;

  const CustomSearchBar({
    super.key,
    required this.controller,
    this.hintText = 'Cari...',
    this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: Icon(Icons.search, color: Colors.grey.shade600),
          border: InputBorder.none,
          suffixIcon: controller.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 20),
                  onPressed: () {
                    controller.clear();
                    onChanged?.call('');
                  },
                )
              : null,
        ),
        onChanged: onChanged,
      ),
    );
  }
}