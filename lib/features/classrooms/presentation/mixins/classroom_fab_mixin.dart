import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart' hide Provider;
import 'package:manajemensekolah/features/classrooms/presentation/screens/admin_classroom_management_screen.dart';

/// Mixin for FAB (Floating Action Button) animation and state.
///
/// Manages the expandable FAB menu with animations. Assumes the State
/// class provides setState(), context, and TickerProvider.
mixin ClassroomFabMixin on ConsumerState<AdminClassManagementScreen> {
  // Abstract state fields
  bool get isFabOpen;
  set isFabOpen(bool value);

  AnimationController get fabAnimationController;
  Animation<double> get fabRotateAnimation;
  Animation<double> get fabScaleAnimation;

  GlobalKey get fabKey;

  bool get isMounted => mounted;

  /// Toggles the FAB menu open/closed.
  void toggleFabMenu() {
    setState(() {
      isFabOpen = !isFabOpen;
      if (isFabOpen) {
        fabAnimationController.forward();
      } else {
        fabAnimationController.reverse();
      }
    });
  }

  /// Closes the FAB menu.
  void closeFabMenu() {
    setState(() {
      isFabOpen = false;
      fabAnimationController.reverse();
    });
  }

  /// Called when "Create New Class" FAB is pressed.
  void onAddClassPressed() {
    closeFabMenu();
    onCreateNewClass();
  }

  /// Called when "Promote Class" FAB is pressed.
  void onPromoteClassPressed() {
    closeFabMenu();
    onPromoteClass();
  }

  /// Called by onAddClassPressed (hook for showing dialog).
  void onCreateNewClass();

  /// Called by onPromoteClassPressed (hook for showing wizard).
  void onPromoteClass();
}
