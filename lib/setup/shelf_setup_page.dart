import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:inventory_count/setup/area_page.dart';
import 'package:inventory_count/setup/item_page.dart';
import 'package:inventory_count/setup/setup_tiles.dart';
import 'package:inventory_count/setup/shelf_page.dart';
import 'package:provider/provider.dart';

class ShelfSetupPage extends StatefulWidget {
  final Profile selectedProfile;

  const ShelfSetupPage(this.selectedProfile, {super.key});

  @override
  State<ShelfSetupPage> createState() => _ShelfSetupPageState();
}

class _ShelfSetupPageState extends State<ShelfSetupPage> {
  var selectedOrder = <int>[];

  void select(int index) {
    setState(() {
      selectedOrder.add(index);
    });
  }

  void deselect() {
    setState(() {
      selectedOrder.removeLast();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        switch (selectedOrder.length) {
          case 0:
            return AreasPage(
              select: select,
              selectedProfile: widget.selectedProfile,
            );
          case 1:
            return AreaPage(
              select: select,
              deselect: deselect,
              selectedOrder: selectedOrder,
              selectedProfile: widget.selectedProfile,
            );
          default:
            dynamic shelfOrItem = areaModel.getShelfOrItem(
              selectedOrder,
              widget.selectedProfile,
            );

            if (shelfOrItem is Shelf) {
              return ShelfPage(
                select: select,
                deselect: deselect,
                shelf: shelfOrItem,
                selectedOrder: selectedOrder,
                selectedProfile: widget.selectedProfile,
              );
            } else {
              return ItemPage(
                deselect: deselect,
                item: shelfOrItem,
                selectedOrder: selectedOrder,
                selectedProfile: widget.selectedProfile,
              );
            }
        }
      },
    );
  }
}

class AreasPage extends StatelessWidget {
  const AreasPage({
    super.key,
    required this.select,
    required this.selectedProfile,
  });

  final void Function(int) select;
  final Profile selectedProfile;

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Scaffold(
          appBar: AppBar(
            title: Text(
              'Areas',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            centerTitle: true,
            scrolledUnderElevation: 0,
            backgroundColor: Theme.of(context).colorScheme.surface,
          ),
          body: AreaList(select: select, selectedProfile: selectedProfile),
        );
      },
    );
  }
}

class AreaList extends StatefulWidget {
  const AreaList({
    super.key,
    required this.select,
    required this.selectedProfile,
  });

  final void Function(int) select;
  final Profile selectedProfile;

  @override
  State<AreaList> createState() => _AreaListState();
}

class _AreaListState extends State<AreaList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() async {
    await Future.delayed(const Duration(milliseconds: 100));
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
      // Scroll again in case the extent changed during animation
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<AreaModel>(
      builder: (context, areaModel, child) {
        return Column(
          children: [
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Area'),
              tileColor: Theme.of(context).colorScheme.surface,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Enter Area Name'),
                    content: TextField(
                      autofocus: true,
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          areaModel.addArea(
                            Area(value),
                            widget.selectedProfile,
                          );
                          Navigator.pop(context);
                          _scrollToBottom();
                        }
                      },
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Text('Cancel'),
                      ),
                    ],
                  ),
                );
              },
            ),
            Expanded(
              child: Overlay(
                initialEntries: [
                  OverlayEntry(
                    builder: (context) => Material(
                      child: ReorderableListView(
                        scrollController: _scrollController,
                        key: const PageStorageKey('areaListView'),
                        children: <AreaTile>[
                          for (
                            int index = 0;
                            index <
                                areaModel.getNumAreas(widget.selectedProfile);
                            index += 1
                          )
                            AreaTile(
                              key: Key('$index'),
                              index: index,
                              select: widget.select,
                              selectedProfile: widget.selectedProfile,
                            ),
                        ],
                        onReorder: (int oldIndex, int newIndex) {
                          if (newIndex > oldIndex) {
                            newIndex -= 1;
                          }

                          areaModel.moveArea(
                            oldIndex,
                            newIndex,
                            widget.selectedProfile,
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
