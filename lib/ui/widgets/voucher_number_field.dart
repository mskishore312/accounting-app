import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';

class VoucherNumberField extends StatefulWidget {
  final TextEditingController controller;
  final String voucherType;
  final String label;
  final bool autoGenerate;

  const VoucherNumberField({
    Key? key,
    required this.controller,
    required this.voucherType,
    this.label = 'Voucher No',
    this.autoGenerate = true,
  }) : super(key: key);

  @override
  State<VoucherNumberField> createState() => _VoucherNumberFieldState();
}

class _VoucherNumberFieldState extends State<VoucherNumberField> {
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    if (widget.autoGenerate && widget.controller.text.isEmpty) {
      _generateVoucherNumber();
    }
  }

  Future<void> _generateVoucherNumber() async {
    if (_isGenerating) return;
    
    setState(() => _isGenerating = true);
    
    try {
      final company = await StorageService.getSelectedCompany();
      if (company == null) return;

      // Get the next voucher number based on existing vouchers
      final vouchers = await StorageService.getVouchers(company['id'], widget.voucherType);
      
      // Generate next number based on existing vouchers
      int nextNumber = 1;
      if (vouchers.isNotEmpty) {
        // Find the highest number
        int maxNumber = 0;
        for (var voucher in vouchers) {
          final voucherNo = voucher['voucher_number'] as String?;
          if (voucherNo != null) {
            // Extract number from voucher number (handle formats like "RV001", "001", etc.)
            final numberMatch = RegExp(r'(\d+)').firstMatch(voucherNo);
            if (numberMatch != null) {
              final number = int.tryParse(numberMatch.group(1)!) ?? 0;
              if (number > maxNumber) {
                maxNumber = number;
              }
            }
          }
        }
        nextNumber = maxNumber + 1;
      }

      // Format the voucher number based on type
      String prefix = '';
      switch (widget.voucherType.toLowerCase()) {
        case 'receipt':
          prefix = 'RV';
          break;
        case 'payment':
          prefix = 'PV';
          break;
        case 'journal':
          prefix = 'JV';
          break;
        default:
          prefix = 'V';
      }

      final formattedNumber = '$prefix${nextNumber.toString().padLeft(3, '0')}';
      
      if (mounted) {
        widget.controller.text = formattedNumber;
      }
    } catch (e) {
      // If auto-generation fails, use a simple number
      widget.controller.text = '001';
    } finally {
      if (mounted) {
        setState(() => _isGenerating = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${widget.label} *:',
            style: const TextStyle(
              color: Color(0xFF2C5545),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: widget.controller,
                decoration: InputDecoration(
                  hintText: 'Enter ${widget.label.toLowerCase()}',
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2C5545)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0x802C5545)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                    borderSide: const BorderSide(color: Color(0xFF2C5545), width: 2),
                  ),
                ),
                validator: (value) => value?.isEmpty == true ? 'Required' : null,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(
                color: const Color(0xFF4C7380),
                borderRadius: BorderRadius.circular(8),
              ),
              child: IconButton(
                onPressed: _isGenerating ? null : _generateVoucherNumber,
                icon: _isGenerating 
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                    : const Icon(
                        Icons.refresh,
                        color: Colors.white,
                        size: 20,
                      ),
                tooltip: 'Generate voucher number',
              ),
            ),
          ],
        ),
      ],
    );
  }
}
