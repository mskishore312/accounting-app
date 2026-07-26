import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:accounting_app/data/storage_service.dart';

/// Registers: monthly voucher registers per voucher type, Tally-style.
class Registers extends StatelessWidget {
  const Registers({Key? key}) : super(key: key);

  static const List<String> _voucherTypes = [
    'Receipt',
    'Payment',
    'Journal',
    'Contra',
    'Sales',
    'Purchase',
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Registers',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _voucherTypes
              .map(
                (type) => Container(
                  height: 48,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: const BoxDecoration(
                    color: Color(0xFF4C7380),
                    borderRadius: BorderRadius.all(Radius.circular(8)),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              MonthlyRegister(voucherType: type),
                        ),
                      ),
                      child: Center(
                        child: Text(
                          '$type Register',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w500,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

/// Month-wise summary of vouchers of one type.
class MonthlyRegister extends StatefulWidget {
  final String voucherType;

  const MonthlyRegister({Key? key, required this.voucherType})
      : super(key: key);

  @override
  State<MonthlyRegister> createState() => _MonthlyRegisterState();
}

class _MonthlyRegisterState extends State<MonthlyRegister> {
  List<Map<String, dynamic>> _months = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final vouchers =
          await StorageService.getVouchers(null, widget.voucherType);
      final byMonth = <String, List<Map<String, dynamic>>>{};
      for (final voucher in vouchers) {
        final date = voucher['voucher_date'] as String? ?? '';
        if (date.length < 7) continue;
        byMonth.putIfAbsent(date.substring(0, 7), () => []).add(voucher);
      }
      final months = byMonth.entries.map((entry) {
        final total = entry.value.fold<double>(
            0.0, (sum, v) => sum + ((v['total'] as num?)?.toDouble() ?? 0.0));
        return <String, dynamic>{
          'month': entry.key,
          'vouchers': entry.value,
          'count': entry.value.length,
          'total': total,
        };
      }).toList()
        ..sort(
            (a, b) => (a['month'] as String).compareTo(b['month'] as String));
      if (!mounted) return;
      setState(() {
        _months = months;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading register: $e')),
        );
      }
    }
  }

  String _monthLabel(String yearMonth) {
    final parts = yearMonth.split('-');
    if (parts.length != 2) return yearMonth;
    final year = int.tryParse(parts[0]);
    final month = int.tryParse(parts[1]);
    if (year == null || month == null) return yearMonth;
    return DateFormat('MMMM yyyy').format(DateTime(year, month));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '${widget.voucherType} Register',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _months.isEmpty
              ? Center(
                  child: Text(
                    'No ${widget.voucherType.toLowerCase()} vouchers recorded.',
                    style: const TextStyle(
                        fontSize: 16, color: Color(0xFF2C5545)),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: _months.length,
                  separatorBuilder: (context, index) =>
                      const Divider(color: Color(0xFF2C5545), height: 1),
                  itemBuilder: (context, index) {
                    final month = _months[index];
                    return InkWell(
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => _MonthVouchers(
                            voucherType: widget.voucherType,
                            monthLabel: _monthLabel(month['month'] as String),
                            vouchers: (month['vouchers'] as List)
                                .cast<Map<String, dynamic>>(),
                          ),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 16, horizontal: 24),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _monthLabel(month['month'] as String),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF2C5545),
                                    ),
                                  ),
                                  Text(
                                    '${month['count']} voucher${month['count'] == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF4C7380),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              (month['total'] as double).toStringAsFixed(2),
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF2C5545),
                              ),
                            ),
                            const Icon(Icons.chevron_right,
                                color: Color(0xFF4C7380)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

class _MonthVouchers extends StatelessWidget {
  final String voucherType;
  final String monthLabel;
  final List<Map<String, dynamic>> vouchers;

  const _MonthVouchers({
    required this.voucherType,
    required this.monthLabel,
    required this.vouchers,
  });

  String _formatDate(String isoDate) {
    try {
      return DateFormat('dd/MM/yyyy').format(DateTime.parse(isoDate));
    } catch (_) {
      return isoDate;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          '$voucherType — $monthLabel',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: vouchers.length,
        separatorBuilder: (context, index) =>
            const Divider(color: Color(0xFF2C5545), height: 1),
        itemBuilder: (context, index) {
          final voucher = vouchers[index];
          return Padding(
            padding:
                const EdgeInsets.symmetric(vertical: 16, horizontal: 24),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'No. ${voucher['voucher_number'] ?? '-'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF2C5545),
                        ),
                      ),
                      Text(
                        _formatDate(voucher['voucher_date'] as String? ?? ''),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF4C7380),
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  ((voucher['total'] as num?)?.toDouble() ?? 0.0)
                      .toStringAsFixed(2),
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF2C5545),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
