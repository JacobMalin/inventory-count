import 'package:flutter/material.dart';

import 'supabase_counts_page.dart';
import 'window_model.dart';

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

      home: const Scaffold(body: SupabaseCountsPage()),
    );
  }
}
