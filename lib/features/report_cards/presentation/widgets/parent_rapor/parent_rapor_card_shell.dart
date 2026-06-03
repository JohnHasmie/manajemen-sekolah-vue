import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ParentRaporCardShell extends StatelessWidget {
  const ParentRaporCardShell({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: padding ?? const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(16)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
        boxShadow: ColorUtils.corporateShadow(elevation: 1.0),
      ),
      child: child,
    );
  }
}
