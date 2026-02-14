import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/area_model.dart';
import 'export_setup_page.dart';
import 'shelf_setup_page.dart';

class SetupPage extends StatelessWidget {
  const SetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return const DefaultTabController(
          length: 2,
          child: Scaffold(
            body: TabBarView(children: [ShelfSetupPage(), ExportSetupPage()]),
            bottomNavigationBar: Row(
              children: [
                Expanded(
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
