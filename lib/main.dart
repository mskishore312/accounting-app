import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:accounting_app/ui/gateway.dart';
import 'package:accounting_app/ui/options.dart';
import 'data/storage_service.dart';
import 'dart:io' show Platform;

import 'package:sqflite_common_ffi/sqflite_ffi.dart' if (dart.library.html) 'package:accounting_app/web_stub.dart';
import 'package:provider/provider.dart';
import 'package:accounting_app/services/period_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize database based on platform
  if (kIsWeb) {
    // Web platform doesn't support sqflite directly
    print('Running on web platform - database functionality will be limited');
  } else {
    try {
      // For desktop platforms, initialize FFI
      if (!Platform.isAndroid && !Platform.isIOS) {
        // Initialize FFI for desktop platforms
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      
      // Initialize database by making a simple call to force initialization
      await StorageService.getSelectedCompany();
      
      // Check and fix database schema for description field
      await StorageService.checkAndFixDatabaseSchema();
      
      // Don't run cleanup during startup as it might cause issues
      // The cleanup will run when accessing ledgers later
    } catch (e) {
      print('Error initializing database: $e');
    }
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