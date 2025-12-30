import 'package:flutter/material.dart';
import 'package:inventory_count/setup/export_setup_page.dart';
import 'package:inventory_count/setup/shelf_setup_page.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        body: const TabBarView(children: [ShelfSetupPage(), ExportSetupPage()]),
        bottomNavigationBar: const TabBar(
          tabs: [
            Tab(text: 'Areas'),
            Tab(text: 'Export Order'),
          ],
        ),
      ),
    );
  }
}
