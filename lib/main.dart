import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'screens/login_page.dart';

import 'services/local_database.dart';
import 'services/sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await LocalDatabase.instance.database;
  
  await LocalDatabase.instance.clearPendingAttendance();

  SyncService.instance.startListening();

  await Supabase.initialize(
    url: 'https://uwqcldejliwkfatxgkmp.supabase.co',
    publishableKey: 'sb_publishable_Be1uxqY6p4BTI2c-QOcF2w_EDiyu-co',
  );

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Employee Attendance',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
        ),
        useMaterial3: true,
      ),
      home: const LoginPage(),
    );
  }
}

