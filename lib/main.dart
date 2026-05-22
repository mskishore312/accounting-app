import 'package:flutter/material.dart';
import 'package:accounting_app/ui/gateway.dart';
import 'package:accounting_app/ui/options.dart';
import 'data/storage_service.dart';

// Platform DB init — web_stub wires sqflite_common_ffi_web; native_stub handles mobile/desktop
import 'package:accounting_app/native_stub.dart' if (dart.library.html) 'package:accounting_app/web_stub.dart';
import 'package:provider/provider.dart';
import 'package:accounting_app/services/period_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database (web: wasm FFI; mobile: auto; desktop: sqflite_ffi)
  await initDatabase();
  try {
    await StorageService.getSelectedCompany();
    await StorageService.checkAndFixDatabaseSchema();
  } catch (e) {
    print('DB init error: \$e');
  }

  // Initialize the period service
  PeriodService().initializeDefaultPeriod();
  
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => PeriodService(),
      child: MaterialApp(
        title: 'Accounting App',
        theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2C5545),
          primary: const Color(0xFF2C5545),
          secondary: const Color(0xFF4C7380),
        ),
        scaffoldBackgroundColor: const Color(0xFFE0F2E9),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2C5545),
            foregroundColor: Colors.white,
          ),
        ),
      ),
      debugShowCheckedModeBanner: false,
      home: const AppRouter(),
      ),
    );
  }
}

class AppRouter extends StatefulWidget {
  const AppRouter({Key? key}) : super(key: key);

  @override
  State<AppRouter> createState() => _AppRouterState();
}

class _AppRouterState extends State<AppRouter> {
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Map<String, dynamic>?>(
      future: StorageService.getSelectedCompany(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(),
            ),
          );
        }
        
        if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text('Error: ${snapshot.error}'),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {}); // Rebuild to retry
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        
        // If there's a selected company, go to Options; otherwise go to Gateway
        final selectedCompany = snapshot.data;
        if (selectedCompany != null && selectedCompany.isNotEmpty) {
          return const Options();
        } else {
          return const Gateway();
        }
      },
    );
  }
}