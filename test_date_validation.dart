import 'package:flutter/material.dart';
import 'package:accounting_app/ui/widgets/date_range_selector.dart';
import 'package:accounting_app/data/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize database
  await StorageService().database;
  
  // Create a test company with books beginning date
  final db = await StorageService().database;
  await db.insert('Companies', {
    'name': 'Test Company',
    'financial_year_from': '2023-04-01',
    'books_from': '2023-04-01', // Books beginning date
  });
  
  runApp(const TestApp());
}

class TestApp extends StatelessWidget {
  const TestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Date Validation Test',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const TestScreen(),
    );
  }
}

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  State<TestScreen> createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  DateTime? selectedStartDate;
  DateTime? selectedEndDate;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Date Validation Test'),
        backgroundColor: const Color(0xFF2C5545),
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text(
              'Books Beginning Date: 01/04/2023\nTry selecting a start date before this date.',
              style: TextStyle(fontSize: 16),
              textAlign: TextAlign.center,
            ),
          ),
          DateRangeSelector(
            initialStartDate: selectedStartDate,
            initialEndDate: selectedEndDate,
            onDateRangeSelected: (start, end) {
              setState(() {
                selectedStartDate = start;
                selectedEndDate = end;
              });
            },
          ),
          if (selectedStartDate != null && selectedEndDate != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Selected Period: ${_formatDate(selectedStartDate!)} to ${_formatDate(selectedEndDate!)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
