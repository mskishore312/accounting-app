import 'package:flutter/material.dart';

const Color kStatementGreen = Color(0xFF2C5545);
const Color kStatementBg = Color(0xFFDCEEE3);
const Color kStatementAltBg = Color(0xFFE8F4EC);

/// A single line in a financial statement.
class StatementRow {
  final String label;
  final double? amount;

  /// Group heading (e.g. "Capital Account") — rendered bold.
  final bool isGroup;

  /// Ledger line under a group — rendered indented and lighter.
  final bool isIndented;

  const StatementRow(
    this.label,
    this.amount, {
    this.isGroup = false,
    this.isIndented = false,
  });
}

/// Classic two-column (T) financial statement, styled like the app's
/// green report screens: Particulars/Amount on each side with a totals
/// row that spans both.
class TFormatTable extends StatelessWidget {
  const TFormatTable({
    super.key,
    required this.leftRows,
    required this.rightRows,
    required this.leftTotal,
    required this.rightTotal,
    this.leftTotalLabel = 'Total',
    this.rightTotalLabel = 'Total',
    this.minimumRows = 8,
    this.title,
    this.minSideWidth = 300,
  });

  final List<StatementRow> leftRows;
  final List<StatementRow> rightRows;
  final double leftTotal;
  final double rightTotal;
  final String leftTotalLabel;
  final String rightTotalLabel;

  /// Keeps both sides the same height so the table reads like paper.
  final int minimumRows;

  /// Optional heading bar above the table (e.g. "TRADING ACCOUNT").
  final String? title;

  /// Each side keeps at least this width; on a narrow phone the table
  /// scrolls sideways rather than squeezing the columns.
  final double minSideWidth;

  static String formatAmount(double value) {
    final negative = value < 0;
    final text = value.abs().toStringAsFixed(2);
    // Indian grouping: last three digits, then pairs.
    final parts = text.split('.');
    var digits = parts[0];
    String grouped;
    if (digits.length <= 3) {
      grouped = digits;
    } else {
      final last3 = digits.substring(digits.length - 3);
      var rest = digits.substring(0, digits.length - 3);
      final buffer = <String>[];
      while (rest.length > 2) {
        buffer.insert(0, rest.substring(rest.length - 2));
        rest = rest.substring(0, rest.length - 2);
      }
      if (rest.isNotEmpty) buffer.insert(0, rest);
      grouped = '${buffer.join(',')},$last3';
    }
    final result = '$grouped.${parts[1]}';
    return negative ? '($result)' : result;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final needed = minSideWidth * 2 + 1;
        final width = available.isFinite && available > needed ? available : needed;
        final table = SizedBox(width: width, child: _table());
        if (available.isFinite && width <= available) {
          return _withTitle(table);
        }
        return _withTitle(
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: table,
          ),
        );
      },
    );
  }

  Widget _withTitle(Widget child) {
    if (title == null) return child;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          color: kStatementGreen,
          child: Text(
            title!,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ),
        child,
      ],
    );
  }

  Widget _table() {
    final rowCount = [
      leftRows.length,
      rightRows.length,
      minimumRows,
    ].reduce((a, b) => a > b ? a : b);

    return Container(
      decoration: BoxDecoration(
        color: kStatementBg,
        border: Border.all(color: kStatementGreen),
      ),
      child: Column(
        children: [
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _side(leftRows, rowCount)),
                Container(width: 1, color: kStatementGreen),
                Expanded(child: _side(rightRows, rowCount)),
              ],
            ),
          ),
          Container(height: 1, color: kStatementGreen),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _totalRow(leftTotalLabel, leftTotal)),
                Container(width: 1, color: kStatementGreen),
                Expanded(child: _totalRow(rightTotalLabel, rightTotal)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _side(List<StatementRow> rows, int rowCount) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _headerRow(),
        for (var i = 0; i < rowCount; i++)
          i < rows.length ? _dataRow(rows[i]) : _emptyRow(),
      ],
    );
  }

  Widget _headerRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: kStatementGreen)),
      ),
      child: const Row(
        children: [
          Expanded(
            child: Text(
              'Particulars',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: kStatementGreen,
              ),
            ),
          ),
          Text(
            'Amount',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: kStatementGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _dataRow(StatementRow row) {
    final style = TextStyle(
      fontSize: 14,
      fontWeight: row.isGroup ? FontWeight.bold : FontWeight.normal,
      color: kStatementGreen,
    );
    return Container(
      padding: EdgeInsets.only(
        left: row.isIndented ? 20 : 8,
        right: 8,
        top: 6,
        bottom: 6,
      ),
      child: Row(
        children: [
          Expanded(child: Text(row.label, style: style)),
          if (row.amount != null)
            Text(formatAmount(row.amount!), style: style),
        ],
      ),
    );
  }

  Widget _emptyRow() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 6, horizontal: 8),
        child: Text(' ', style: TextStyle(fontSize: 14)),
      );

  Widget _totalRow(String label, double amount) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
      color: kStatementAltBg,
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: kStatementGreen,
              ),
            ),
          ),
          Text(
            formatAmount(amount),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: kStatementGreen,
            ),
          ),
        ],
      ),
    );
  }
}

/// Vertical (Schedule III) statement section: a numbered heading with
/// its line items and a section total.
class ScheduleIIISection extends StatelessWidget {
  const ScheduleIIISection({
    super.key,
    required this.title,
    required this.rows,
    this.total,
    this.totalLabel,
  });

  final String title;
  final List<StatementRow> rows;
  final double? total;
  final String? totalLabel;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: kStatementBg,
        border: Border.all(color: kStatementGreen),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            color: kStatementGreen,
            child: Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
          for (final row in rows)
            Padding(
              padding: EdgeInsets.only(
                left: row.isIndented ? 26 : 10,
                right: 10,
                top: 6,
                bottom: 6,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      row.label,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            row.isGroup ? FontWeight.bold : FontWeight.normal,
                        color: kStatementGreen,
                      ),
                    ),
                  ),
                  if (row.amount != null)
                    Text(
                      TFormatTable.formatAmount(row.amount!),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight:
                            row.isGroup ? FontWeight.bold : FontWeight.normal,
                        color: kStatementGreen,
                      ),
                    ),
                ],
              ),
            ),
          if (total != null) ...[
            Container(height: 1, color: kStatementGreen),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              color: kStatementAltBg,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      totalLabel ?? 'Total',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: kStatementGreen,
                      ),
                    ),
                  ),
                  Text(
                    TFormatTable.formatAmount(total!),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: kStatementGreen,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

enum StatementFormat { tFormat, scheduleIII }

/// Segmented selector for the statement layout, styled like the
/// Condensed/Detailed view toggle.
class StatementFormatToggle extends StatelessWidget {
  const StatementFormatToggle({
    super.key,
    required this.format,
    required this.onChanged,
  });

  final StatementFormat format;
  final ValueChanged<StatementFormat> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      color: const Color(0xFFD5EADF),
      child: Row(
        children: [
          const Icon(Icons.description_outlined,
              size: 20, color: kStatementGreen),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Format',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: kStatementGreen,
              ),
            ),
          ),
          ChoiceChip(
            label: const Text('T Format'),
            selected: format == StatementFormat.tFormat,
            onSelected: (_) => onChanged(StatementFormat.tFormat),
            selectedColor: kStatementGreen,
            labelStyle: TextStyle(
              color: format == StatementFormat.tFormat
                  ? Colors.white
                  : kStatementGreen,
            ),
          ),
          const SizedBox(width: 8),
          ChoiceChip(
            label: const Text('Schedule III'),
            selected: format == StatementFormat.scheduleIII,
            onSelected: (_) => onChanged(StatementFormat.scheduleIII),
            selectedColor: kStatementGreen,
            labelStyle: TextStyle(
              color: format == StatementFormat.scheduleIII
                  ? Colors.white
                  : kStatementGreen,
            ),
          ),
        ],
      ),
    );
  }
}
