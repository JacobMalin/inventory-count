import 'package:flutter/material.dart';
import 'package:inventory_count/companion/window_model.dart';
import 'package:inventory_count/companion/supabase_counts_page.dart';

class CompanionApp extends StatelessWidget {
  const CompanionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color.fromARGB(255, 18, 75, 99),
          brightness: Brightness.dark,
        ),
        useMaterial3: true,
      ),
      builder: (context, child) => WindowSetupWatcher(child!),
      home: Scaffold(body: SupabaseCountsPage()),
    );
  }
}
