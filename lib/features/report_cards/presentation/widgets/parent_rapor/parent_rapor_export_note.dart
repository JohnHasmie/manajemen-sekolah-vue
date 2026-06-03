import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';

class ParentRaporExportNote extends StatelessWidget {
  const ParentRaporExportNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.all(Radius.circular(14)),
        border: Border.all(color: ColorUtils.slate200, width: 0.75),
      ),
      child: Text(
        'Rapor ini hanya tampilan ringkas. Untuk dokumen resmi sekolah, '
        'unduh PDF.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: ColorUtils.slate500,
          height: 1.5,
        ),
      ),
    );
  }
}
