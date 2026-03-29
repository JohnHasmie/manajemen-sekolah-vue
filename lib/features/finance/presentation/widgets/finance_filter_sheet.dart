import 'package:flutter/material.dart';
import 'package:manajemensekolah/core/utils/color_utils.dart';
import 'package:manajemensekolah/core/utils/language_utils.dart';
import 'package:manajemensekolah/core/constants/app_spacing.dart';

class FinanceFilterSheet extends StatelessWidget {
  final String? currentStatus;
  final String? currentPeriod;
  final LanguageProvider languageProvider;
  final Function(String?, String?) onApply;

  const FinanceFilterSheet({
    super.key,
    this.currentStatus,
    this.currentPeriod,
    required this.languageProvider,
    required this.onApply,
  });

  @override
  Widget build(BuildContext context) {
    String? selectedStatus = currentStatus;
    String? selectedPeriod = currentPeriod;

    return StatefulBuilder(
      builder: (context, setModalState) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(20),
              topRight: Radius.circular(20),
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    languageProvider.getTranslatedText({'en': 'Filter', 'id': 'Filter'}),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ColorUtils.slate900,
                    ),
                  ),
                  TextButton(
                    onPressed: () {
                      setModalState(() {
                        selectedStatus = null;
                        selectedPeriod = null;
                      });
                    },
                    child: Text(
                      languageProvider.getTranslatedText({'en': 'Reset', 'id': 'Reset'}),
                      style: TextStyle(color: ColorUtils.error600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                languageProvider.getTranslatedText({'en': 'Status', 'id': 'Status'}),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ColorUtils.slate700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  _FilterChip(
                    label: languageProvider.getTranslatedText({'en': 'Unpaid', 'id': 'Belum Bayar'}),
                    isSelected: selectedStatus == 'unpaid',
                    onSelected: (val) => setModalState(() => selectedStatus = val ? 'unpaid' : null),
                  ),
                  _FilterChip(
                    label: languageProvider.getTranslatedText({'en': 'Pending', 'id': 'Tertunda'}),
                    isSelected: selectedStatus == 'pending',
                    onSelected: (val) => setModalState(() => selectedStatus = val ? 'pending' : null),
                  ),
                  _FilterChip(
                    label: languageProvider.getTranslatedText({'en': 'Verified', 'id': 'Terverifikasi'}),
                    isSelected: selectedStatus == 'verified',
                    onSelected: (val) => setModalState(() => selectedStatus = val ? 'verified' : null),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xl),
              Text(
                languageProvider.getTranslatedText({'en': 'Period', 'id': 'Periode'}),
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: ColorUtils.slate700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: 8,
                children: [
                  _FilterChip(
                    label: languageProvider.getTranslatedText({'en': 'Monthly', 'id': 'Bulanan'}),
                    isSelected: selectedPeriod == 'bulanan',
                    onSelected: (val) => setModalState(() => selectedPeriod = val ? 'bulanan' : null),
                  ),
                  _FilterChip(
                    label: languageProvider.getTranslatedText({'en': 'Yearly', 'id': 'Tahunan'}),
                    isSelected: selectedPeriod == 'tahunan',
                    onSelected: (val) => setModalState(() => selectedPeriod = val ? 'tahunan' : null),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xxl),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: () {
                    onApply(selectedStatus, selectedPeriod);
                    Navigator.pop(context);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: ColorUtils.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    languageProvider.getTranslatedText({'en': 'Apply', 'id': 'Terapkan'}),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final Function(bool) onSelected;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: onSelected,
      selectedColor: ColorUtils.primary.withValues(alpha: 0.1),
      checkmarkColor: ColorUtils.primary,
      labelStyle: TextStyle(
        color: isSelected ? ColorUtils.primary : ColorUtils.slate600,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        fontSize: 12,
      ),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      side: BorderSide(
        color: isSelected ? ColorUtils.primary : ColorUtils.slate200,
      ),
    );
  }
}
