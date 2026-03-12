import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/area_model.dart';
import 'export_setup_page.dart';
import 'shelf_setup_page.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  final GlobalKey<State<ShelfSetupPage>> _shelfSetupPageKey =
      GlobalKey<State<ShelfSetupPage>>();

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return DefaultTabController(
          length: 2,
          child: Scaffold(
            body: TabBarView(
              children: [
                ShelfSetupPage(key: _shelfSetupPageKey),
                const ExportSetupPage(),
              ],
            ),
            bottomNavigationBar: Row(
              children: [
                Expanded(
                  child: TabBar(
                    tabs: const [
                      Tab(text: 'Areas'),
                      Tab(text: 'Export Order'),
                    ],
                    onTap: (index) {
                      if (index == 0) {
                        final State<ShelfSetupPage>? state =
                            _shelfSetupPageKey.currentState;
                        if (state != null) {
                          (state as dynamic).reset();
                        }
                      }
                    },
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
