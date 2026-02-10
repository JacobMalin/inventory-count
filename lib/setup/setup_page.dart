import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:inventory_count/setup/export_setup_page.dart';
import 'package:inventory_count/setup/shelf_setup_page.dart';
import 'package:provider/provider.dart';

class SetupPage extends StatelessWidget {
  final Profile selectedProfile;

  const SetupPage(this.selectedProfile, {super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: TabBarView(
              children: [
                ShelfSetupPage(selectedProfile),
                ExportSetupPage(selectedProfile),
              ],
            ),
            bottomNavigationBar: Row(
              children: [
                const Expanded(
                  child: TabBar(
                    tabs: [
                      Tab(text: 'Areas'),
                      Tab(text: 'Export Order'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
