import 'package:flutter/material.dart';

class LedgerSelector extends StatelessWidget {
  final List<Map<String, dynamic>> ledgers;
  final String? selectedLedgerId;
  final Function(String?) onLedgerChanged;
  final String label;
  final bool isRequired;

  const LedgerSelector({
    Key? key,
    required this.ledgers,
    required this.selectedLedgerId,
    required this.onLedgerChanged,
    this.label = 'Ledger',
    this.isRequired = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '$label${isRequired ? ' *' : ''}:',
            style: const TextStyle(
              color: Color(0xFF2C5545),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: const Color(0x802C5545)),
            borderRadius: BorderRadius.circular(8),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedLedgerId,
              hint: Text(
                'Select $label',
                style: const TextStyle(
                  color: Color(0x802C5545),
                  fontSize: 16,
                ),
              ),
              isExpanded: true,
              icon: const Icon(
                Icons.arrow_drop_down,
                color: Color(0xFF2C5545),
              ),
              style: const TextStyle(
                color: Color(0xFF2C5545),
                fontSize: 16,
              ),
              items: ledgers.map((ledger) {
                return DropdownMenuItem<String>(
                  value: ledger['id'].toString(),
                  child: Text(
                    ledger['name'] as String,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              }).toList(),
              onChanged: onLedgerChanged,
            ),
          ),
        ),
      ],
    );
  }
}
