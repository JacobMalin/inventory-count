import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:provider/provider.dart';

import '../models/area_model.dart';
import '../models/export_entry.dart';
import '../models/export_model.dart';

class ExportSetupPage extends StatefulWidget {
  const ExportSetupPage({super.key});

  @override
  State<ExportSetupPage> createState() => _ExportSetupPageState();
}

class _ExportSetupPageState extends State<ExportSetupPage> {
  final ScrollController _scrollController = ScrollController();
  bool _isAtBottom = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final bool isAtBottom =
          _scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 50;
      if (isAtBottom != _isAtBottom) {
        setState(() {
          _isAtBottom = isAtBottom;
        });
      }
    }
  }

  Future<void> _scrollToBottom() async {
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

  Future<void> _scrollToTop() async {
    if (_scrollController.hasClients) {
      await _scrollController.animateTo(
        0,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Overlay(
      initialEntries: [
        OverlayEntry(
          builder: (context) {
            return Consumer2<ExportModel, AreaModel>(
              builder: (context, exportModel, areaModel, child) {
                final List<ExportEntry> exportList = exportModel.exportList;
                return Scaffold(
                  appBar: AppBar(
                    title: Text(
                      'Export Order',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    centerTitle: true,
                    scrolledUnderElevation: 0,
                    backgroundColor: Theme.of(context).colorScheme.surface,
                  ),
                  body: exportList.isEmpty
                      ? const Center(child: Text('No items to export'))
                      : ExportListBody(
                          scrollController: _scrollController,
                          scrollToBottom: _scrollToBottom,
                        ),
                  floatingActionButton: exportList.isEmpty
                      ? null
                      : ScrollActionButton(
                          isAtBottom: _isAtBottom,
                          onScrollToTop: _scrollToTop,
                          onScrollToBottom: _scrollToBottom,
                        ),
                );
              },
            );
          },
        ),
      ],
    );
  }
}

Future<bool> _confirmDelete(
  BuildContext context, {
  required String type,
  required String name,
}) async {
  final bool? shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Delete $type'),
      content: Text('Are you sure you want to delete "$name"?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Delete'),
        ),
      ],
    ),
  );

  return shouldDelete ?? false;
}

class ScrollActionButton extends StatelessWidget {
  const ScrollActionButton({
    required bool isAtBottom,
    required void Function() onScrollToTop,
    required void Function() onScrollToBottom,
    super.key,
  }) : _onScrollToBottom = onScrollToBottom,
       _onScrollToTop = onScrollToTop,
       _isAtBottom = isAtBottom;

  final bool _isAtBottom;
  final VoidCallback _onScrollToTop;
  final VoidCallback _onScrollToBottom;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton.small(
      onPressed: _isAtBottom ? _onScrollToTop : _onScrollToBottom,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
      foregroundColor: Theme.of(context).colorScheme.onSurfaceVariant,
      elevation: 2,
      child: AnimatedRotation(
        duration: const Duration(milliseconds: 200),
        turns: _isAtBottom ? -0.5 : 0,
        child: const Icon(Icons.arrow_downward),
      ),
    );
  }
}

class ExportListBody extends StatelessWidget {
  const ExportListBody({
    required ScrollController scrollController,
    required Function() scrollToBottom,
    super.key,
  }) : _scrollController = scrollController,
       _scrollToBottom = scrollToBottom;

  final ScrollController _scrollController;
  final Function() _scrollToBottom;

  List<Widget> _buildExportTiles(
    List<ExportEntry> exportList,
    AreaModel areaModel,
  ) {
    var titleHidden = false;

    return exportList.indexed.map((record) {
      final (index, exportEntry) = record;

      if (exportEntry is ExportTitle) {
        titleHidden = exportEntry.isHidden;
      }

      return ExportTile(
        key: Key('$index'),
        exportEntry: exportEntry,
        index: index,
        titleHidden: titleHidden,
        paths: exportEntry is ExportItem
            ? areaModel.getPathsForItem(exportEntry.name).join('\n')
            : null,
      );
    }).toList();
  }

  Future<void> _showAddDialog({
    required BuildContext context,
    required String title,
    required String inputLabel,
    required ExportModel exportModel,
    required ExportEntry Function(String) createEntry,
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        final controller = TextEditingController();
        return AlertDialog(
          title: Text(title),
          content: TextField(
            controller: controller,
            autofocus: true,
            onSubmitted: (value) async {
              if (value.isNotEmpty) {
                await exportModel.add(createEntry(value));
                await _scrollToBottom();
                if (!context.mounted) return;
                Navigator.pop(context);
              }
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                if (controller.text.isNotEmpty) {
                  await exportModel.add(createEntry(controller.text));
                  await _scrollToBottom();
                  if (!context.mounted) return;
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer2<ExportModel, AreaModel>(
      builder: (context, exportModel, areaModel, child) {
        return Column(
          children: [
            Material(
              child: Row(
                children: [
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Add Title'),
                      onTap: () => _showAddDialog(
                        context: context,
                        title: 'Enter Title',
                        inputLabel: 'Title',
                        exportModel: exportModel,
                        createEntry: ExportTitle.new,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      leading: const Icon(Icons.add),
                      title: const Text('Add Item'),
                      onTap: () => _showAddDialog(
                        context: context,
                        title: 'Enter Name',
                        inputLabel: 'Name',
                        exportModel: exportModel,
                        createEntry: ExportItem.new,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView(
                scrollController: _scrollController,
                key: const PageStorageKey('exportListView'),
                onReorder: (oldIndex, newIndex) async {
                  if (newIndex > oldIndex) {
                    newIndex -= 1;
                  }
                  await exportModel.reorder(oldIndex, newIndex);
                },
                children: _buildExportTiles(exportModel.exportList, areaModel),
              ),
            ),
          ],
        );
      },
    );
  }
}

class ExportTile extends StatelessWidget {
  const ExportTile({
    required ExportEntry exportEntry,
    required int index,
    required bool titleHidden,
    String? paths,
    super.key,
  }) : _exportEntry = exportEntry,
       _index = index,
       _titleHidden = titleHidden,
       _paths = paths;

  final ExportEntry _exportEntry;
  final int _index;
  final bool _titleHidden;
  final String? _paths;

  Future<void> showRenameDialog({
    required BuildContext context,
    required String title,
    required String initialValue,
    required void Function(String) onChanged,
    required void Function(String) onSaved,
  }) {
    final controller = TextEditingController(text: initialValue);
    controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: controller.text.length,
    );
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          onChanged: onChanged,
          onSubmitted: (_) => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                onSaved(controller.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  List<Widget> actionPaneChildren({
    required BuildContext context,
    required ExportModel exportModel,
    required ExportEntry exportEntry,
    required String? paths,
    required int index,
    required bool titleHidden,
    required ColorScheme colorScheme,
  }) {
    final String entryType = switch (_exportEntry) {
      ExportTitle _ => 'Title',
      ExportItem _ =>
        _paths != null && _paths.isNotEmpty ? 'Item' : 'Placeholder',
      _ => 'Unknown',
    };

    return [
      SlidableAction(
        onPressed: (_) async {
          await exportModel.editEntry(_index, isHidden: !_exportEntry.isHidden);
        },
        backgroundColor: colorScheme.secondaryContainer,
        foregroundColor: colorScheme.onSecondaryContainer,
        icon: _exportEntry.isHidden ? Icons.visibility : Icons.visibility_off,
        label: _exportEntry.isHidden ? 'Show' : 'Hide',
      ),
      SlidableAction(
        onPressed: (_) async {
          await showRenameDialog(
            context: context,
            title: 'Rename $entryType',
            initialValue: _exportEntry.name,
            onChanged: (value) async {
              await exportModel.editEntry(_index, name: value);
            },
            onSaved: (value) async {
              await exportModel.editEntry(_index, name: value);
            },
          );
        },
        backgroundColor: colorScheme.surfaceContainerHighest,
        foregroundColor: colorScheme.onSurfaceVariant,
        icon: Icons.edit,
        label: 'Edit',
      ),
      SlidableAction(
        onPressed: (_) async {
          final bool shouldDelete = await _confirmDelete(
            context,
            type: entryType,
            name: _exportEntry.name,
          );
          if (shouldDelete) {
            await exportModel.removeAt(_index);
          }
        },
        backgroundColor: colorScheme.errorContainer,
        foregroundColor: colorScheme.onErrorContainer,
        icon: Icons.delete,
        label: 'Delete',
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final contentPadding = _exportEntry is ExportTitle
        ? const EdgeInsets.symmetric(horizontal: 16)
        : const EdgeInsets.only(left: 32, right: 16);

    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final Color? tileColor = switch (_exportEntry) {
      ExportTitle _ => null,
      ExportItem _ =>
        _paths != null && _paths.isNotEmpty
            ? colorScheme.surfaceContainerHighest
            : Colors.yellow.withAlpha(80),
      _ => null,
    };

    return Consumer<ExportModel>(
      builder: (context, exportModel, child) {
        return Material(
          child: Slidable(
            key: ValueKey(_exportEntry),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: actionPaneChildren(
                context: context,
                exportModel: exportModel,
                exportEntry: _exportEntry,
                paths: _paths,
                index: _index,
                titleHidden: _titleHidden,
                colorScheme: colorScheme,
              ),
            ),
            child: ListTile(
              contentPadding: contentPadding,
              tileColor: tileColor,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportEntry.isHidden)
                    Icon(
                      Icons.visibility_off,
                      color: Colors.red.withAlpha(160),
                      size: 20,
                    ),
                  const SizedBox(width: 8),
                  const Icon(Icons.drag_handle),
                ],
              ),
              onTap: () {},
              title: Text(
                _exportEntry.name,
                style: _exportEntry.isHidden || _titleHidden
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,

                        color: colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              subtitle: _paths != null && _paths.isNotEmpty
                  ? Text(_paths)
                  : null,
            ),
          ),
        );
      },
    );
  }
}
