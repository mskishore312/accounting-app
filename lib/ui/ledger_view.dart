import 'dart:collection'; // For HashSet
import 'package:flutter/material.dart';
import 'package:accounting_app/data/storage_service.dart';
import 'package:accounting_app/ui/payment_voucher.dart';
import 'package:accounting_app/ui/receipt_voucher.dart';
import 'package:accounting_app/ui/journal_voucher.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:provider/provider.dart';
import 'package:accounting_app/services/period_service.dart';
import 'package:accounting_app/services/pdf_service.dart';

class LedgerView extends StatefulWidget {
  final Map<String, dynamic> ledger;
  final List<Map<String, dynamic>> initialEntries;

  const LedgerView({
    Key? key,
    required this.ledger,
    required this.initialEntries,
  }) : super(key: key);

  @override
  State<LedgerView> createState() => _LedgerViewState();
}

class _LedgerViewState extends State<LedgerView> {
  late List<Map<String, dynamic>> _entries;
  bool _isLoading = false;

  // Calculation variables
  double openingBalance = 0.0;
  double totalDebit = 0.0;
  double totalCredit = 0.0;
  double closingBalance = 0.0;
  List<Map<String, dynamic>> processedEntries = [];

  // Selection state for entries
  bool _isSelectionMode = false;
  final Set<int> _selectedVoucherIds = HashSet<int>();

  // Date range filtering
  DateTime? startDate;
  DateTime? endDate;
  String? booksBeginningDate;
  DateTime? booksBeginningDateDt;

  // Search and filter state
  bool _showNarration = false;
  String? _searchTypeOfInfo;
  // For Date search
  DateTime? _searchDate;
  // For Particulars/Narration search
  String? _searchHaving; // 'Contains' or 'Equal to'
  String? _searchValue;
  // For Voucher Type search
  String? _searchVoucherType;
  // For Amount search
  String? _searchAmountMode; // 'Exact', 'Range', 'Greater than', 'Less than'
  double? _searchAmountValue;
  double? _searchAmountFrom;
  double? _searchAmountTo;

  List<Map<String, dynamic>> _filteredEntries = [];

  // Column widths - wider to show full content
  double dateWidth = 110;
  double particularsWidth = 150; // Wide enough for particulars text
  double debitWidth = 100;
  double creditWidth = 100;
  // Start the running balance column equal to debit/credit width;
  // it will grow dynamically if larger numbers are present.
  double balanceWidth = 120;

  // Compute total table width dynamically
  double get totalTableWidth => dateWidth + particularsWidth + debitWidth + creditWidth + balanceWidth;

  // Two controllers (top table and bottom summary) so horizontal scrolling can be synchronized
  // and attached to separate ScrollViews without causing "attached to multiple scroll views" errors.
  final ScrollController _topHorizontalController = ScrollController();
  final ScrollController _bottomHorizontalController = ScrollController();
  // Flags to avoid circular updates while syncing scroll positions.
  bool _isSyncingTop = false;
  bool _isSyncingBottom = false;

  @override
  void initState() {
    super.initState();
    _entries = List<Map<String, dynamic>>.from(widget.initialEntries);

    // Sync horizontal scroll positions between top table and bottom summary.
    _topHorizontalController.addListener(() {
      if (_isSyncingTop) return;
      if (!_topHorizontalController.hasClients) return;
      final pos = _topHorizontalController.position.pixels;
      if (_bottomHorizontalController.hasClients) {
        _isSyncingBottom = true;
        _bottomHorizontalController.jumpTo(pos);
        _isSyncingBottom = false;
      }
    });
    _bottomHorizontalController.addListener(() {
      if (_isSyncingBottom) return;
      if (!_bottomHorizontalController.hasClients) return;
      final pos = _bottomHorizontalController.position.pixels;
      if (_topHorizontalController.hasClients) {
        _isSyncingTop = true;
        _topHorizontalController.jumpTo(pos);
        _isSyncingTop = false;
      }
    });

    // Ensure booksBeginningDate is loaded BEFORE first calculation so user-declared OB is honored
    Future.microtask(() async {
      await _loadBooksBeginningDate();
      _calculateBalances();
    });
  }

  Future<void> _loadBooksBeginningDate() async {
    try {
      final company = await StorageService.getSelectedCompany();
      if (!mounted) return;
      final raw = company != null ? company['books_from'] as String? : null;
      DateTime? parsed;
      if (raw != null && raw.isNotEmpty) {
        // Try to parse common formats: YYYY-MM-DD or DD/MM/YYYY or YYYY/MM/DD
        try {
          parsed = DateTime.parse(raw); // handles YYYY-MM-DD
        } catch (_) {
          try {
            final parts = raw.split('/');
            if (parts.length == 3) {
              // assume DD/MM/YYYY
              parsed = DateTime(
                int.parse(parts[2]),
                int.parse(parts[1]),
                int.parse(parts[0]),
              );
            } else {
              // try YYYY/MM/DD
              final parts2 = raw.split('/');
              if (parts2.length == 3) {
                parsed = DateTime(
                  int.parse(parts2[0]),
                  int.parse(parts2[1]),
                  int.parse(parts2[2]),
                );
              }
            }
          } catch (_) {
            parsed = null;
          }
        }
      }
      setState(() {
        booksBeginningDate = raw;
        booksBeginningDateDt = parsed;
      });
    } catch (e) {
      debugPrint('Error loading books beginning date: $e');
    }
  }

  @override
  void dispose() {
    _topHorizontalController.dispose();
    _bottomHorizontalController.dispose();
    super.dispose();
  }

  // Format a DateTime to YYYY-MM-DD
  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  // Determine default Dr/Cr behavior based on group (same logic as in ledger creation)
  bool _isDebitGroup(String group) {
    // Asset groups - Dr. by default
    const assetGroups = [
      'Bank Accounts',
      'Cash-in-hand',
      'Current Assets',
      'Deposits (Assets)',
      'Fixed Assets',
      'Investments',
      'Loans & Advances (Asset)',
      'Misc. Expenses (ASSET)',
      'Stock-in-hand',
      'Sundry Debtors'
    ];

    // Liability and Capital groups - Cr. by default
    const liabilityGroups = [
      'Bank OD A/c',
      'Capital Account',
      'Current Liabilities',
      'Duties & Taxes',
      'Loans (Liability)',
      'Provisions',
      'Reserves & Surplus',
      'Secured Loans',
      'Sundry Creditors',
      'Unsecured Loans'
    ];

    // Revenue groups - Cr. by default
    const revenueGroups = [
      'Direct Incomes',
      'Indirect Income',
      'Sales Accounts'
    ];

    // Expense groups - Dr. by default
    const expenseGroups = [
      'Direct Expenses',
      'Indirect Expenses',
      'Purchase Accounts'
    ];

    if (assetGroups.contains(group) || expenseGroups.contains(group)) return true;
    if (liabilityGroups.contains(group) || revenueGroups.contains(group)) return false;
    // Default to Dr if unknown
    return true;
  }

  void _calculateBalances() {
    // Determine effective start/end of the reporting period
    final periodService = PeriodService();
    // Use view-local date range if set; otherwise fallback to PeriodService; initialize defaults if needed.
    DateTime? effStart = startDate ?? periodService.startDate;
    DateTime? effEnd = endDate ?? periodService.endDate;
    if (effStart == null || effEnd == null) {
      periodService.initializeDefaultPeriod();
      effStart = effStart ?? periodService.startDate;
      effEnd = effEnd ?? periodService.endDate;
    }

    // String boundaries for efficient lexicographic comparison (YYYY-MM-DD)
    final String reportStartDate =
        effStart != null ? _fmt(effStart) : (booksBeginningDate ?? '2023-04-01');
    final String reportEndDate = effEnd != null ? _fmt(effEnd) : '2099-12-31';

    final double initialLedgerBalance =
        (widget.ledger['balance'] as num?)?.toDouble() ?? 0.0;
    final String classification = (widget.ledger['classification'] as String?) ?? '';

    final sortedEntries = List<Map<String, dynamic>>.from(_entries);
    sortedEntries.sort((a, b) {
      final dateA = a['voucher_date'] as String? ?? '';
      final dateB = b['voucher_date'] as String? ?? '';
      int dateComparison = dateA.compareTo(dateB);
      if (dateComparison != 0) return dateComparison;
      final idA = a['voucher_id'] as int? ?? 0;
      final idB = b['voucher_id'] as int? ?? 0;
      return idA.compareTo(idB);
    });

    // Determine effective books beginning date
    String? effectiveBooksBeginning;
    if (booksBeginningDateDt != null) {
      effectiveBooksBeginning = _fmt(booksBeginningDateDt!);
    } else if (booksBeginningDate != null && booksBeginningDate!.isNotEmpty) {
      effectiveBooksBeginning = booksBeginningDate;
    }

    // Always start with user-provided opening balance (from books beginning)
    // and then add all transactions between books beginning and report start
    double dynamicOpeningBalance = 0.0;
    final bool isDebitDefault = _isDebitGroup(classification);

    // Start with user-provided balance (applies sign based on group)
    dynamicOpeningBalance = isDebitDefault ? initialLedgerBalance : -initialLedgerBalance;

    double periodTotalDebit = 0.0;
    double periodTotalCredit = 0.0;
    List<Map<String, dynamic>> periodEntries = [];
    double currentRunningBalance = 0.0;
    bool firstPeriodEntry = true;

    try {
      for (final entry in sortedEntries) {
        final entryDate = entry['voucher_date'] as String? ?? '';
        final double debitAmount = (entry['debit'] as num?)?.toDouble() ?? 0.0;
        final double creditAmount = (entry['credit'] as num?)?.toDouble() ?? 0.0;

        if (entryDate.isEmpty) {
          continue;
        }

        // Accumulate ALL transactions before report start date into opening balance
        if (entryDate.compareTo(reportStartDate) < 0) {
          dynamicOpeningBalance += debitAmount;
          dynamicOpeningBalance -= creditAmount;
          continue;
        }

        // Include in the period only if within [start, end]
        if (entryDate.compareTo(reportStartDate) >= 0 && entryDate.compareTo(reportEndDate) <= 0) {
          if (firstPeriodEntry) {
            currentRunningBalance = dynamicOpeningBalance;
            firstPeriodEntry = false;
          }
          currentRunningBalance += debitAmount;
          currentRunningBalance -= creditAmount;
          periodTotalDebit += debitAmount;
          periodTotalCredit += creditAmount;

          final entryCopy = Map<String, dynamic>.from(entry);
          entryCopy['running_balance'] = currentRunningBalance;
          entryCopy['debit_amount'] = debitAmount;
          entryCopy['credit_amount'] = creditAmount;
          periodEntries.add(entryCopy);
        }
      }
      if (firstPeriodEntry) {
        // No entries in range; closing equals opening
        currentRunningBalance = dynamicOpeningBalance;
      }
    } catch (e, st) {
      debugPrint('Error processing ledger entries: $e\n$st');
      // Recalculate from scratch on error
      dynamicOpeningBalance = isDebitDefault ? initialLedgerBalance : -initialLedgerBalance;
      periodEntries = [];
      periodTotalDebit = 0.0;
      periodTotalCredit = 0.0;
      currentRunningBalance = dynamicOpeningBalance;
    }

    if (mounted) {
      setState(() {
        openingBalance = dynamicOpeningBalance;
        processedEntries = periodEntries;
        totalDebit = periodTotalDebit;
        totalCredit = periodTotalCredit;
        closingBalance = currentRunningBalance;
      });
      // Debug logging
      debugPrint('=== Ledger Balance Calculation ===');
      debugPrint('Report Period: $reportStartDate to $reportEndDate');
      debugPrint('Books Beginning: $effectiveBooksBeginning');
      debugPrint('Initial Ledger Balance (from DB): $initialLedgerBalance');
      debugPrint('Classification: $classification');
      debugPrint('Is Debit Group: $isDebitDefault');
      debugPrint('Calculated Opening Balance: $dynamicOpeningBalance');
      debugPrint('Period Debit: $periodTotalDebit, Period Credit: $periodTotalCredit');
      debugPrint('Closing Balance: $currentRunningBalance');
      debugPrint('Number of entries in period: ${periodEntries.length}');
      // Adjust column widths based on content (running balances / totals)
      _updateDynamicWidths();
      // Apply search filter after balance calculation
      _applySearchFilter();
    }
  }

  // Adjust dynamic widths to fit numeric content (running balances / totals)
  void _updateDynamicWidths() {
    try {
      // Gather candidate strings that will appear in the balance column
      final List<String> candidates = [];
      // Running balances from entries
      for (final e in processedEntries) {
        final rb = e['running_balance'];
        if (rb != null) {
          try {
            final double val = (rb as num).toDouble();
            final s = '${val.abs().toStringAsFixed(2)}${val != 0 ? (val >= 0 ? " Dr" : " Cr") : ""}';
            candidates.add(s);
          } catch (_) {}
        }
      }
      // Totals and opening/closing balances
      candidates.add(openingBalance.abs().toStringAsFixed(2));
      candidates.add(totalDebit.toStringAsFixed(2));
      candidates.add(totalCredit.toStringAsFixed(2));
      candidates.add(closingBalance.abs().toStringAsFixed(2));
 
      // Determine maximum character length
      int maxLen = 0;
      for (final s in candidates) {
        if (s.length > maxLen) maxLen = s.length;
      }
 
      // Estimate pixel width needed: approximate char width for the font used.
      // This is approximate; gives enough room for larger numbers.
      final double charPx = 8.0;
      final double padding = 28.0; // left/right padding used in cells
      final double calculated = (maxLen * charPx) + padding;
 
      // Constrain to reasonable bounds - never shrink below debitWidth so alignment stays consistent
      final double minWidth = debitWidth;
      // Allow a larger max so very large numbers can expand the running balance column and be scrollable
      final double maxWidth = 400.0;
      final double newBalanceWidth = calculated.clamp(minWidth, maxWidth);
 
      // Update only if changed to avoid unnecessary rebuilds
      if ((newBalanceWidth - balanceWidth).abs() > 1.0) {
        setState(() {
          balanceWidth = newBalanceWidth;
        });
      }
    } catch (e) {
      // ignore any errors during width calculation
    }
  }
 
  // --- Selection Logic ---
  void _toggleSelection(int voucherId) {
    debugPrint("Toggling selection for voucher ID: $voucherId. Current selection mode: $_isSelectionMode");
    setState(() {
      if (_selectedVoucherIds.contains(voucherId)) {
        _selectedVoucherIds.remove(voucherId);
        if (_selectedVoucherIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedVoucherIds.add(voucherId);
        _isSelectionMode = true;
      }
    });
  }

  void _onDateRangeSelected(DateTime start, DateTime end) async {
    await _loadBooksBeginningDate(); // Ensure we have the latest books beginning date

    // Validate: start date should not be before books beginning date
    if (booksBeginningDateDt != null) {
      if (start.isBefore(booksBeginningDateDt!)) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Start date cannot be before books beginning date (${_fmt(booksBeginningDateDt!)})'),
              backgroundColor: Colors.red,
            ),
          );
        }
        return;
      }
    }

    // Update shared period so header text reflects the chosen range (and consistent across app)
    try {
      Provider.of<PeriodService>(context, listen: false).setPeriod(start, end);
    } catch (_) {}
    setState(() {
      startDate = start;
      endDate = end;
      _calculateBalances();
    });
  }

  void _showDateRangeDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Select Date Range'),
          contentPadding: EdgeInsets.zero,
          content: DateRangeSelector(
            initialStartDate: startDate,
            initialEndDate: endDate,
            showResetButton: true,
            onDateRangeSelected: (start, end) {
              _onDateRangeSelected(start, end);
              Navigator.of(dialogContext).pop();
            },
            onCancel: () => Navigator.of(dialogContext).pop(),
            onResetToDefault: () {
              try {
                Provider.of<PeriodService>(context, listen: false).resetToSessionDefault();
                final periodService = Provider.of<PeriodService>(context, listen: false);
                setState(() {
                  startDate = periodService.startDate;
                  endDate = periodService.endDate;
                  _calculateBalances();
                });
                Navigator.of(dialogContext).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Period reset to session default'),
                    duration: Duration(seconds: 2),
                  ),
                );
              } catch (e) {
                debugPrint('Error resetting to default: $e');
              }
            },
          ),
        );
      },
    );
  }

  void _cancelSelection() {
    setState(() {
      _isSelectionMode = false;
      _selectedVoucherIds.clear();
    });
  }
  // --- End Selection Logic ---

  // --- Deletion Logic ---
  Future<void> _deleteSelectedVouchers() async {
    if (_selectedVoucherIds.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Confirm Deletion (${_selectedVoucherIds.length})'),
        content: const Text('Delete selected vouchers? This cannot be undone.'),
        actions: [
          TextButton(child: const Text('Cancel'), onPressed: () => Navigator.of(dialogContext).pop(false)),
          TextButton(child: const Text('Delete', style: TextStyle(color: Colors.red)), onPressed: () => Navigator.of(dialogContext).pop(true)),
        ],
      ),
    );

    if (confirmed == true) {
      if (!mounted) return;
      setState(() { _isLoading = true; });

      try {
        final idsToDelete = _selectedVoucherIds.toList();
        await StorageService.deleteVouchers(idsToDelete);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${idsToDelete.length} vouchers deleted.')),
          );
          _cancelSelection();
          await _refreshEntries();
        }
      } catch (e) {
        debugPrint("Error deleting selected vouchers: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error deleting vouchers: ${e.toString()}')),
          );
          setState(() { _isLoading = false; });
        }
      }
    }
  }
  // --- End Deletion Logic ---

  void _navigateToVoucher(BuildContext context, Map<String, dynamic> entry) {
    if (_isSelectionMode) {
      _toggleSelection(entry['voucher_id'] as int);
      return;
    }

    final voucherId = entry['voucher_id'] as int?;
    final voucherType = entry['voucher_type'] as String?;
    if (voucherId == null || voucherType == null) return;

    Widget destinationScreen;
    if (voucherType.toLowerCase() == 'receipt') {
      destinationScreen = ReceiptVoucher(voucherId: voucherId);
    } else if (voucherType.toLowerCase() == 'payment') {
      destinationScreen = PaymentVoucher(voucherId: voucherId);
    } else {
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => destinationScreen))
        .then((_) => _refreshEntries());
  }

  Future<void> _refreshEntries() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _cancelSelection(); });
    try {
      final refreshedEntries = await StorageService.getLedgerReport(widget.ledger['id'] as int);
      if (mounted) {
        _entries = refreshedEntries;
        _calculateBalances();
      }
    } catch (e) {
      debugPrint("Error refreshing ledger entries: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error refreshing ledger: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) { setState(() { _isLoading = false; }); }
    }
  }

  // --- Dynamic AppBar Builder ---
  AppBar _buildAppBar() {
    if (_isSelectionMode) {
      return AppBar(
        elevation: 0,
        backgroundColor: Colors.teal[800],
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: _cancelSelection,
        ),
        title: Text('${_selectedVoucherIds.length} selected', style: const TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.white),
            onPressed: _deleteSelectedVouchers,
            tooltip: 'Delete Selected',
          ),
        ],
      );
    } else {
      return AppBar(
        elevation: 0,
        backgroundColor: const Color(0xFF2C5545),
        title: Text('Ledger: ${widget.ledger['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.arrow_back, color: Colors.white), onPressed: () => Navigator.pop(context)),
        actions: [
          IconButton(
            icon: const Icon(Icons.search, color: Colors.white),
            onPressed: _showSearchDialog,
            tooltip: 'Search',
          ),
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: _showOptionsMenu,
            tooltip: 'Options',
          ),
          IconButton(
            icon: const Icon(Icons.calendar_today, color: Colors.white),
            onPressed: () => _showDateRangeDialog(context),
            tooltip: 'Select Date Range',
          ),
        ],
      );
    }
  }
  // --- End AppBar Builder ---

  // --- Search Dialog ---
  void _showSearchDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Search Ledger Entries'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Type of Info', style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    DropdownButtonFormField<String>(
                      value: _searchTypeOfInfo,
                      decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      items: const [
                        DropdownMenuItem(value: 'Date', child: Text('Date')),
                        DropdownMenuItem(value: 'Particulars', child: Text('Particulars')),
                        DropdownMenuItem(value: 'Voucher Type', child: Text('Voucher Type')),
                        DropdownMenuItem(value: 'Debit Amount', child: Text('Debit Amount')),
                        DropdownMenuItem(value: 'Credit Amount', child: Text('Credit Amount')),
                        DropdownMenuItem(value: 'Narration', child: Text('Narration')),
                      ],
                      onChanged: (value) {
                        setDialogState(() {
                          _searchTypeOfInfo = value;
                          // Reset other search fields when type changes
                          _searchDate = null;
                          _searchHaving = null;
                          _searchValue = null;
                          _searchVoucherType = null;
                          _searchAmountMode = null;
                          _searchAmountValue = null;
                          _searchAmountFrom = null;
                          _searchAmountTo = null;
                        });
                      },
                      hint: const Text('Select Type'),
                    ),
                    const SizedBox(height: 16),
                    // Dynamic fields based on Type of Info selection
                    if (_searchTypeOfInfo == 'Date') ...[
                      const Text('Select Date', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      InkWell(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: _searchDate ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                          );
                          if (picked != null) {
                            setDialogState(() {
                              _searchDate = picked;
                            });
                          }
                        },
                        child: InputDecorator(
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          child: Text(
                            _searchDate != null
                                ? '${_searchDate!.day.toString().padLeft(2, '0')}/${_searchDate!.month.toString().padLeft(2, '0')}/${_searchDate!.year}'
                                : 'Tap to select date',
                            style: TextStyle(
                              color: _searchDate != null ? Colors.black : Colors.grey,
                            ),
                          ),
                        ),
                      ),
                    ] else if (_searchTypeOfInfo == 'Particulars' || _searchTypeOfInfo == 'Narration') ...[
                      const Text('Having', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _searchHaving,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Contains', child: Text('Contains')),
                          DropdownMenuItem(value: 'Equal to', child: Text('Equal to')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            _searchHaving = value;
                          });
                        },
                        hint: const Text('Select'),
                      ),
                      const SizedBox(height: 16),
                      const Text('Value', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      TextFormField(
                        initialValue: _searchValue,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          hintText: 'Enter value',
                        ),
                        onChanged: (value) {
                          _searchValue = value;
                        },
                      ),
                    ] else if (_searchTypeOfInfo == 'Voucher Type') ...[
                      const Text('Select Voucher Type', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _searchVoucherType,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Receipt', child: Text('Receipt')),
                          DropdownMenuItem(value: 'Payment', child: Text('Payment')),
                          DropdownMenuItem(value: 'Journal', child: Text('Journal')),
                          DropdownMenuItem(value: 'Contra', child: Text('Contra')),
                          DropdownMenuItem(value: 'Sales', child: Text('Sales')),
                          DropdownMenuItem(value: 'Purchase', child: Text('Purchase')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            _searchVoucherType = value;
                          });
                        },
                        hint: const Text('Select Type'),
                      ),
                    ] else if (_searchTypeOfInfo == 'Debit Amount' || _searchTypeOfInfo == 'Credit Amount') ...[
                      const Text('Mode', style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: _searchAmountMode,
                        decoration: const InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        items: const [
                          DropdownMenuItem(value: 'Exact', child: Text('Exact')),
                          DropdownMenuItem(value: 'Range', child: Text('Range')),
                          DropdownMenuItem(value: 'Greater than', child: Text('Greater than')),
                          DropdownMenuItem(value: 'Less than', child: Text('Less than')),
                        ],
                        onChanged: (value) {
                          setDialogState(() {
                            _searchAmountMode = value;
                            _searchAmountValue = null;
                            _searchAmountFrom = null;
                            _searchAmountTo = null;
                          });
                        },
                        hint: const Text('Select Mode'),
                      ),
                      const SizedBox(height: 16),
                      if (_searchAmountMode == 'Exact' || _searchAmountMode == 'Greater than' || _searchAmountMode == 'Less than') ...[
                        const Text('Value', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: _searchAmountValue?.toString(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            hintText: 'Enter amount',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _searchAmountValue = double.tryParse(value);
                          },
                        ),
                      ] else if (_searchAmountMode == 'Range') ...[
                        const Text('From', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: _searchAmountFrom?.toString(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            hintText: 'Enter from amount',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _searchAmountFrom = double.tryParse(value);
                          },
                        ),
                        const SizedBox(height: 16),
                        const Text('To', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        TextFormField(
                          initialValue: _searchAmountTo?.toString(),
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            hintText: 'Enter to amount',
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _searchAmountTo = double.tryParse(value);
                          },
                        ),
                      ],
                    ],
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    _applySearchFilter();
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Search filter applied')),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2C5545),
                  ),
                  child: const Text('Search', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }
  // --- End Search Dialog ---

  // --- Apply Search Filter ---
  void _applySearchFilter() {
    if (_searchTypeOfInfo == null) {
      // No search criteria, show all entries
      setState(() {
        _filteredEntries = List.from(processedEntries);
      });
      return;
    }

    List<Map<String, dynamic>> filtered = [];

    for (final entry in processedEntries) {
      bool matches = false;

      switch (_searchTypeOfInfo) {
        case 'Date':
          if (_searchDate != null) {
            final entryDate = entry['voucher_date'] as String?;
            if (entryDate != null) {
              final searchDateStr = _fmt(_searchDate!);
              matches = entryDate == searchDateStr;
            }
          }
          break;

        case 'Particulars':
          if (_searchHaving != null && _searchValue != null && _searchValue!.isNotEmpty) {
            final particulars = (entry['particulars'] as String? ?? '').toLowerCase();
            final searchVal = _searchValue!.toLowerCase();
            if (_searchHaving == 'Contains') {
              matches = particulars.contains(searchVal);
            } else if (_searchHaving == 'Equal to') {
              matches = particulars == searchVal;
            }
          }
          break;

        case 'Voucher Type':
          if (_searchVoucherType != null) {
            final voucherType = (entry['voucher_type'] as String? ?? '').toLowerCase();
            matches = voucherType == _searchVoucherType!.toLowerCase();
          }
          break;

        case 'Debit Amount':
          if (_searchAmountMode != null) {
            final debitAmount = (entry['debit'] as num?)?.toDouble() ?? 0.0;
            matches = _matchesAmountCriteria(debitAmount);
          }
          break;

        case 'Credit Amount':
          if (_searchAmountMode != null) {
            final creditAmount = (entry['credit'] as num?)?.toDouble() ?? 0.0;
            matches = _matchesAmountCriteria(creditAmount);
          }
          break;

        case 'Narration':
          if (_searchHaving != null && _searchValue != null && _searchValue!.isNotEmpty) {
            final narration = (entry['description'] as String? ?? '').toLowerCase(); // Changed from 'narration' to 'description'
            final searchVal = _searchValue!.toLowerCase();
            if (_searchHaving == 'Contains') {
              matches = narration.contains(searchVal);
            } else if (_searchHaving == 'Equal to') {
              matches = narration == searchVal;
            }
            // Auto-enable narration display when searching by narration
            if (!_showNarration) {
              _showNarration = true;
            }
          }
          break;
      }

      if (matches) {
        filtered.add(entry);
      }
    }

    setState(() {
      _filteredEntries = filtered;
    });
  }

  bool _matchesAmountCriteria(double amount) {
    switch (_searchAmountMode) {
      case 'Exact':
        return _searchAmountValue != null && amount == _searchAmountValue!;
      case 'Greater than':
        return _searchAmountValue != null && amount > _searchAmountValue!;
      case 'Less than':
        return _searchAmountValue != null && amount < _searchAmountValue!;
      case 'Range':
        return _searchAmountFrom != null &&
            _searchAmountTo != null &&
            amount >= _searchAmountFrom! &&
            amount <= _searchAmountTo!;
      default:
        return false;
    }
  }
  // --- End Apply Search Filter ---

  // --- Options Menu ---
  void _showOptionsMenu() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
              ListTile(
                leading: const Icon(Icons.add_circle, color: Color(0xFF2C5545)),
                title: const Text('Add New Voucher'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddVoucherDialog();
                },
              ),
              ListTile(
                leading: Icon(
                  _showNarration ? Icons.check_box : Icons.check_box_outline_blank,
                  color: const Color(0xFF2C5545),
                ),
                title: const Text('Report With Narration'),
                onTap: () {
                  Navigator.pop(context);
                  setState(() {
                    _showNarration = !_showNarration;
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(_showNarration
                          ? 'Narration column enabled'
                          : 'Narration column disabled'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF2C5545)),
                title: const Text('Export as PDF and Mail'),
                onTap: () {
                  Navigator.pop(context);
                  _exportPdfAndShare('email');
                },
              ),
              ListTile(
                leading: const Icon(Icons.table_chart, color: Color(0xFF2C5545)),
                title: const Text('Export as Excel Sheet'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.mail, color: Color(0xFF2C5545)),
                title: const Text('Export as Excel Sheet and Mail'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.sms, color: Color(0xFF2C5545)),
                title: const Text('Send SMS'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Coming soon')),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.chat, color: Color(0xFF2C5545)),
                title: const Text('Send WhatsApp'),
                onTap: () {
                  Navigator.pop(context);
                  _exportPdfAndShare('whatsapp');
                },
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf, color: Color(0xFF2C5545)),
                title: const Text('Export As PDF'),
                onTap: () {
                  Navigator.pop(context);
                  _exportPdfAndShare('general');
                },
              ),
            ],
          ),
        ),
        );
      },
    );
  }

  void _showAddVoucherDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add New Voucher', style: TextStyle(color: Color(0xFF2C5545))),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildVoucherTypeOption(context, 'Payment', const PaymentVoucher()),
              const SizedBox(height: 8),
              _buildVoucherTypeOption(context, 'Receipt', const ReceiptVoucher()),
              const SizedBox(height: 8),
              _buildVoucherTypeOption(context, 'Journal', const JournalVoucher()),
              const SizedBox(height: 8),
              _buildVoucherTypeOption(context, 'Contra', null), // TODO: Add Contra voucher
              const SizedBox(height: 8),
              _buildVoucherTypeOption(context, 'Sales', null), // TODO: Add Sales voucher
              const SizedBox(height: 8),
              _buildVoucherTypeOption(context, 'Purchase', null), // TODO: Add Purchase voucher
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildVoucherTypeOption(BuildContext context, String voucherType, Widget? destination) {
    return InkWell(
      onTap: () {
        Navigator.of(context).pop();
        if (destination != null) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => destination),
          ).then((_) => _refreshEntries());
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$voucherType voucher coming soon')),
          );
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: const Color(0xFF4C7380),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            const Icon(Icons.add_circle, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Text(
              voucherType,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _clearSearch() {
    setState(() {
      _searchTypeOfInfo = null;
      _searchDate = null;
      _searchHaving = null;
      _searchValue = null;
      _searchVoucherType = null;
      _searchAmountMode = null;
      _searchAmountValue = null;
      _searchAmountFrom = null;
      _searchAmountTo = null;
      _filteredEntries = List.from(processedEntries);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Search cleared')),
    );
  }

  // --- PDF Export and Share ---
  Future<void> _exportPdfAndShare(String shareType) async {
    try {
      setState(() {
        _isLoading = true;
      });

      // Get company name
      final company = await StorageService.getSelectedCompany();
      final companyName = company?['name'] as String? ?? 'Unknown Company';

      // Get ledger name
      final ledgerName = widget.ledger['name'] as String? ?? 'Unknown Ledger';

      // Get period text
      final periodService = Provider.of<PeriodService>(context, listen: false);
      final periodText = periodService.periodText;

      // Determine if opening/closing balances are debit or credit
      final bool isOpeningBalanceDebit = openingBalance >= 0;
      final bool isClosingBalanceDebit = closingBalance >= 0;

      // Get the entries to include in PDF (filtered or all)
      final entriesToExport = _searchTypeOfInfo != null ? _filteredEntries : processedEntries;

      // Generate PDF
      final pdfFile = await PdfService.generateLedgerPdf(
        companyName: companyName,
        ledgerName: ledgerName,
        periodText: periodText,
        openingBalance: openingBalance.abs(),
        isOpeningBalanceDebit: isOpeningBalanceDebit,
        entries: entriesToExport,
        closingBalance: closingBalance.abs(),
        isClosingBalanceDebit: isClosingBalanceDebit,
        totalDebit: totalDebit,
        totalCredit: totalCredit,
        showNarration: _showNarration,
      );

      setState(() {
        _isLoading = false;
      });

      // Share based on type
      if (shareType == 'email') {
        await PdfService.shareViaEmail(pdfFile, ledgerName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF ready to share via email')),
          );
        }
      } else if (shareType == 'whatsapp') {
        await PdfService.shareViaWhatsApp(pdfFile, ledgerName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF ready to share via WhatsApp')),
          );
        }
      } else {
        // General share
        await PdfService.shareViaEmail(pdfFile, ledgerName);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('PDF generated successfully')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }
  // --- End PDF Export and Share ---

  // --- End Options Menu ---

  @override
  Widget build(BuildContext context) {
    final bool isClosingBalanceDebit = closingBalance >= 0;
    final double absClosingBalance = closingBalance.abs();
    final bool isOpeningBalanceDebit = openingBalance >= 0;
    final double absOpeningBalance = openingBalance.abs();

    // Check if this is a cash/bank ledger for color coding
    final classification = (widget.ledger['classification'] as String? ?? '').toLowerCase();
    final isCashBank = classification.contains('cash') ||
        classification.contains('bank') ||
        classification == 'cash-in-hand' ||
        classification == 'bank accounts' ||
        classification == 'bank od a/c';

    // Determine color for closing balance (red if cash/bank and negative)
    final closingBalanceColor = isCashBank && closingBalance < 0
        ? Colors.red
        : const Color(0xFF2C5545);

    // Use the exact sum of column widths as table width for proper alignment
    final double tableWidth = totalTableWidth;

    // Bottom summary amounts split across columns
    final double obDebit = isOpeningBalanceDebit ? absOpeningBalance : 0.0;
    final double obCredit = !isOpeningBalanceDebit ? absOpeningBalance : 0.0;
    // Totals that align with the debit/credit columns should include the opening balance so the
    // "Current Total" row represents the actual column sums for the report (opening + period).
    final double displayTotalDebit = obDebit + totalDebit;
    final double displayTotalCredit = obCredit + totalCredit;
    // Use the already computed closingBalance for the UI to avoid divergence.
    final double uiClosing = closingBalance;

    return Scaffold(
      backgroundColor: const Color(0xFFE0F2E9),
      appBar: _buildAppBar(), // Use the dynamic AppBar
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Period display aligned with other report pages
                Consumer<PeriodService>(
                  builder: (context, periodService, child) {
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
                      color: const Color(0xFFE0F2E9),
                      child: Text(
                        'Curr. Period ${periodService.periodText}',
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF2C5545),
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                // Clear Search button - visible when search is active
                if (_searchTypeOfInfo != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    color: const Color(0xFFE0F2E9),
                    child: InkWell(
                      onTap: _clearSearch,
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFEBEE),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.red, width: 2),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.clear, color: Colors.red, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Clear Search Filter',
                              style: TextStyle(
                                color: Colors.red,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                // Table with Header and Body (horizontally scrollable together)
                Expanded(
                  child: processedEntries.isEmpty && openingBalance == 0
                      ? const Center(child: Text('No transactions found for this period.'))
                      : (_searchTypeOfInfo != null && _filteredEntries.isEmpty)
                          ? const Center(child: Text('No matching entries found.', style: TextStyle(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)))
                          : SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              controller: _topHorizontalController,
                              child: SizedBox(
                                width: tableWidth,
                                child: Column(
                                  children: [
                                    // Static Header Row
                                    _buildLedgerTableHeader(),
                                    // Table Body (vertically scrollable)
                                    Expanded(
                                      child: ListView.builder(
                                        itemCount: _searchTypeOfInfo != null ? _filteredEntries.length : processedEntries.length,
                                        itemBuilder: (context, index) {
                                          final entry = _searchTypeOfInfo != null ? _filteredEntries[index] : processedEntries[index];
                                          return _buildLedgerTableRow(entry);
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                ),

                // Bottom Summary: synchronized horizontal scrolling with table
                Container(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: Color(0xFF2C5545), width: 2)),
                    color: Color(0xFFC8E6D8),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    controller: _bottomHorizontalController,
                    child: SizedBox(
                      width: tableWidth,
                      child: Column(
                        children: [
                          // Opening Balance row
                          Row(
                            children: [
                              SizedBox(
                                width: dateWidth + particularsWidth - 60,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    'Opening Balance',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60 + debitWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    obDebit > 0 ? '${obDebit.toStringAsFixed(2)} Dr' : (absOpeningBalance == 0 ? '0.00' : ''),
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: creditWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    obCredit > 0 ? '${obCredit.toStringAsFixed(2)} Cr' : '',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(width: balanceWidth),
                            ],
                          ),
                          const Divider(color: Color(0xFF2C5545), height: 1, thickness: 1),
                          // Period Total row
                          Row(
                            children: [
                              SizedBox(
                                width: dateWidth + particularsWidth - 60,
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    'Period Total',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60 + debitWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    totalDebit > 0 ? totalDebit.toStringAsFixed(2) : '',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: creditWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    totalCredit > 0 ? totalCredit.toStringAsFixed(2) : '',
                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(width: balanceWidth),
                            ],
                          ),
                          const Divider(color: Color(0xFF2C5545), height: 1, thickness: 1),
                          // Closing Balance row
                          Row(
                            children: [
                              SizedBox(
                                width: dateWidth + particularsWidth - 60,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    'Closing Balance',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: closingBalanceColor),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: 60 + debitWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    isClosingBalanceDebit && absClosingBalance > 0 ? '${absClosingBalance.toStringAsFixed(2)} Dr' : '',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: closingBalanceColor),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(
                                width: creditWidth,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                                  child: Text(
                                    !isClosingBalanceDebit && absClosingBalance > 0 ? '${absClosingBalance.toStringAsFixed(2)} Cr' : '',
                                    style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: closingBalanceColor),
                                    textAlign: TextAlign.right,
                                  ),
                                ),
                              ),
                              SizedBox(width: balanceWidth),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  // Builds the fixed Table Header Row (now without Vch Type and Vch No)
  Widget _buildLedgerTableHeader() {
    // Column widths map
    final Map<int, TableColumnWidth> columnWidths = {
      0: FixedColumnWidth(dateWidth),
      1: FixedColumnWidth(particularsWidth),
      2: FixedColumnWidth(debitWidth),
      3: FixedColumnWidth(creditWidth),
      4: FixedColumnWidth(balanceWidth),
    };

    return Table(
      border: const TableBorder(
        top: BorderSide(color: Color(0xFF2C5545), width: 1),
        bottom: BorderSide(color: Color(0xFF2C5545), width: 1),
        left: BorderSide(color: Color(0xFF2C5545), width: 1),
        right: BorderSide(color: Color(0xFF2C5545), width: 1),
        verticalInside: BorderSide(color: Color(0xFF2C5545), width: 1),
      ),
      columnWidths: columnWidths,
      children: [
        TableRow(
          children: [
            _buildTableHeaderCell('Date'),
            _buildTableHeaderCell('Particulars'),
            _buildTableHeaderCell('Debit'),
            _buildTableHeaderCell('Credit'),
            _buildTableHeaderCell('Running Balance'),
          ],
        ),
      ],
    );
  }

  // Builds a single Data Table Row (no Vch Type / Vch No)
  Widget _buildLedgerTableRow(Map<String, dynamic> entry) {
    final voucherId = entry['voucher_id'] as int? ?? -1;
    final isSelected = _selectedVoucherIds.contains(voucherId);
    double debitAmount = entry['debit_amount'] as double? ?? 0.0;
    double creditAmount = entry['credit_amount'] as double? ?? 0.0;
    double runningBalance = entry['running_balance'] as double? ?? 0.0;
    String particulars = entry['particulars'] as String? ?? '';
    String narration = entry['description'] as String? ?? ''; // Changed from 'narration' to 'description'

    // Check if this is a cash/bank ledger
    final classification = (widget.ledger['classification'] as String? ?? '').toLowerCase();
    final isCashBank = classification.contains('cash') ||
        classification.contains('bank') ||
        classification == 'cash-in-hand' ||
        classification == 'bank accounts' ||
        classification == 'bank od a/c';

    // Column widths map for data rows
    final Map<int, TableColumnWidth> columnWidths = {
      0: FixedColumnWidth(dateWidth),
      1: FixedColumnWidth(particularsWidth),
      2: FixedColumnWidth(debitWidth),
      3: FixedColumnWidth(creditWidth),
      4: FixedColumnWidth(balanceWidth),
    };

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () {
        debugPrint("Tap detected. Selection mode: $_isSelectionMode");
        if (_isSelectionMode) {
          _toggleSelection(voucherId);
        } else {
          _navigateToVoucher(context, entry);
        }
      },
      onLongPress: () {
        debugPrint("Long press detected. Selection mode before: $_isSelectionMode");
        if (!_isSelectionMode) {
          setState(() {
            _isSelectionMode = true;
            _selectedVoucherIds.add(voucherId);
            debugPrint("Entered selection mode. Selected IDs: $_selectedVoucherIds");
          });
        } else {
          _toggleSelection(voucherId);
        }
      },
      child: Container(
        color: isSelected ? Colors.teal.withOpacity(0.3) : Colors.transparent,
        child: Table(
          border: const TableBorder(
            horizontalInside: BorderSide(color: Color(0xFF2C5545), width: 1),
            verticalInside: BorderSide(color: Color(0xFF2C5545), width: 1),
            left: BorderSide(color: Color(0xFF2C5545), width: 1),
            right: BorderSide(color: Color(0xFF2C5545), width: 1),
            bottom: BorderSide(color: Color(0xFF2C5545), width: 1),
          ),
          columnWidths: columnWidths,
          children: [
            TableRow(
              children: [
                _buildTableCell(_formatVoucherDate(entry['voucher_date'] as String?), TextAlign.center),
                _buildParticularsWithNarration(particulars, narration),
                _buildTableCell(debitAmount > 0 ? debitAmount.toStringAsFixed(2) : '', TextAlign.right),
                _buildTableCell(creditAmount > 0 ? creditAmount.toStringAsFixed(2) : '', TextAlign.right),
                _buildTableCellWithColor(
                  '${runningBalance.abs().toStringAsFixed(2)}${runningBalance != 0 ? (runningBalance >= 0 ? " Dr" : " Cr") : ""}',
                  TextAlign.right,
                  // Show red color if cash/bank and balance is negative
                  isCashBank && runningBalance < 0 ? Colors.red : const Color(0xFF1A3C30),
                ),
              ],
            )
          ],
        ),
      ),
    );
  }

  // Helper to build particulars cell with optional narration below
  Widget _buildParticularsWithNarration(String particulars, String narration) {
    // Debug logging
    if (_showNarration) {
      debugPrint('Show Narration: $_showNarration, Narration: "$narration", IsEmpty: ${narration.isEmpty}');
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            particulars,
            style: const TextStyle(
              fontSize: 13,
              color: Color(0xFF1A3C30),
              fontWeight: FontWeight.normal,
            ),
            textAlign: TextAlign.left,
          ),
          if (_showNarration && narration.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '($narration)',
              style: const TextStyle(
                fontSize: 11,
                color: Colors.black,
                fontStyle: FontStyle.italic,
              ),
              textAlign: TextAlign.left,
            ),
          ],
        ],
      ),
    );
  }

  // Helper for building table header cells
  Widget _buildTableHeaderCell(String text) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: Alignment.center,
      color: const Color(0xFFC8E6D8),
      child: Text(text,
          style: const TextStyle(
              fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis),
    );
  }

  // Helper for building table data cells
  Widget _buildTableCell(String text, TextAlign align,
      [FontWeight? fontWeight, bool ellipsis = true]) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : (align == TextAlign.center ? Alignment.center : Alignment.centerLeft),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 13, color: const Color(0xFF1A3C30), fontWeight: fontWeight ?? FontWeight.normal),
        textAlign: align,
        overflow: ellipsis ? TextOverflow.ellipsis : TextOverflow.visible,
        maxLines: ellipsis ? 1 : null,
      ),
    );
  }

  // Helper for building table data cells with custom color
  Widget _buildTableCellWithColor(String text, TextAlign align, Color color) {
    return Container(
      height: 40,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      alignment: align == TextAlign.right
          ? Alignment.centerRight
          : (align == TextAlign.center ? Alignment.center : Alignment.centerLeft),
      child: Text(
        text,
        style: TextStyle(
            fontSize: 13, color: color, fontWeight: FontWeight.normal),
        textAlign: align,
        overflow: TextOverflow.visible,
        maxLines: null,
      ),
    );
  }

  // Helper for building summary rows aligned with table columns
  Widget _buildAlignedSummaryRow(String label, double debit, double credit,
      {double? balanceAmount, String? balanceSuffix}) {
    final String displayDebit = debit > 0 ? debit.toStringAsFixed(2) : '';
    final String displayCredit = credit > 0 ? credit.toStringAsFixed(2) : '';
    final String displayBalance = balanceAmount != null
        ? '${balanceAmount.toStringAsFixed(2)}${balanceSuffix != null ? balanceSuffix : ''}'
        : '';

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          // Label spanning the first two columns' total width (date + particulars)
          SizedBox(
            width: dateWidth + particularsWidth,
            child: Text(
              label,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Debit column
          Container(
            width: debitWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              displayDebit,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
              textAlign: TextAlign.right,
            ),
          ),
          // Credit column
          Container(
            width: creditWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              displayCredit,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
              textAlign: TextAlign.right,
            ),
          ),
          // Balance column (for Closing Balance)
          Container(
            width: balanceWidth,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              displayBalance,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF2C5545)),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  // Helper to format date string
  String _formatVoucherDate(String? dateStr) {
    if (dateStr == null) return 'N/A';
    try {
      final parts = dateStr.split('-');
      if (parts.length == 3) {
        return '${parts[2]}/${parts[1]}/${parts[0]}';
      } // DD/MM/YYYY
      return dateStr;
    } catch (e) {
      return dateStr;
    }
  }
}
