import 'package:flutter/material.dart';

enum ReportViewMode { condensed, detailed }

class ReportViewToggle extends StatelessWidget {
  const ReportViewToggle({
    super.key,
    required this.mode,
    required this.onChanged,
  });

  final ReportViewMode mode;
  final ValueChanged<ReportViewMode> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFD5EADF),
      child: Row(
        children: [
          const Icon(Icons.tune, size: 20, color: Color(0xFF2C5545)),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'View',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Color(0xFF2C5545),
              ),
            ),
          ),
          ChoiceChip(
            label: const Text('Condensed'),
            selected: mode == ReportViewMode.condensed,
            onSelected: (_) => onChanged(ReportViewMode.condensed),
            selectedColor: const Color(0xFF2C5545),
            labelStyle: TextStyle(
              color: mode == ReportViewMode.condensed
                  ? Colors.white
                  : const Color(0xFF2C5545),
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Detailed'),
            selected: mode == ReportViewMode.detailed,
            onSelected: (_) => onChanged(ReportViewMode.detailed),
            selectedColor: const Color(0xFF2C5545),
            labelStyle: TextStyle(
              color: mode == ReportViewMode.detailed
                  ? Colors.white
                  : const Color(0xFF2C5545),
            ),
          ),
        ],
      ),
    );
  }
}
