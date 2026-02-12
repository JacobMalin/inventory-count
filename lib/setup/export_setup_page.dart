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
                      : Column(
                          children: [
                            Material(
                              child: Row(
                                children: [
                                  Expanded(
                                    child: ListTile(
                                      leading: const Icon(Icons.add),
                                      title: const Text('Add Title'),
                                      onTap: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (context) {
                                            final controller =
                                                TextEditingController();
                                            return AlertDialog(
                                              title: const Text('Enter Title'),
                                              content: TextField(
                                                controller: controller,
                                                autofocus: true,
                                                onSubmitted: (value) async {
                                                  if (value.isNotEmpty) {
                                                    await exportModel.add(
                                                      ExportTitle(value),
                                                    );
                                                    await _scrollToBottom();
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    Navigator.pop(context);
                                                  }
                                                },
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    if (controller
                                                        .text
                                                        .isNotEmpty) {
                                                      await exportModel.add(
                                                        ExportTitle(
                                                          controller.text,
                                                        ),
                                                      );
                                                      await _scrollToBottom();
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      Navigator.pop(context);
                                                    }
                                                  },
                                                  child: const Text('Add'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                  Expanded(
                                    child: ListTile(
                                      leading: const Icon(Icons.add),
                                      title: const Text('Add Item'),
                                      onTap: () async {
                                        await showDialog(
                                          context: context,
                                          builder: (context) {
                                            final controller =
                                                TextEditingController();
                                            return AlertDialog(
                                              title: const Text('Enter Name'),
                                              content: TextField(
                                                controller: controller,
                                                autofocus: true,
                                                onSubmitted: (value) async {
                                                  if (value.isNotEmpty) {
                                                    await exportModel.add(
                                                      ExportItem(value),
                                                    );
                                                    await _scrollToBottom();
                                                    if (!context.mounted) {
                                                      return;
                                                    }
                                                    Navigator.pop(context);
                                                  }
                                                },
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.pop(context),
                                                  child: const Text('Cancel'),
                                                ),
                                                TextButton(
                                                  onPressed: () async {
                                                    if (controller
                                                        .text
                                                        .isNotEmpty) {
                                                      await exportModel.add(
                                                        ExportItem(
                                                          controller.text,
                                                        ),
                                                      );
                                                      await _scrollToBottom();
                                                      if (!context.mounted) {
                                                        return;
                                                      }
                                                      Navigator.pop(context);
                                                    }
                                                  },
                                                  child: const Text('Add'),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Builder(
                              builder: (context) {
                                var titleHidden = false;
                                return Expanded(
                                  child: ReorderableListView(
                                    scrollController: _scrollController,
                                    key: const PageStorageKey('exportListView'),
                                    onReorder: (oldIndex, newIndex) async {
                                      if (newIndex > oldIndex) {
                                        newIndex -= 1;
                                      }
                                      await exportModel.reorder(
                                        oldIndex,
                                        newIndex,
                                      );
                                    },
                                    children: [
                                      for (
                                        int index = 0;
                                        index < exportList.length;
                                        index++
                                      )
                                        () {
                                          final ExportEntry exportEntry =
                                              exportList[index];
                                          if (exportEntry is ExportTitle) {
                                            titleHidden = exportEntry.isHidden;
                                          }
                                          return switch (exportEntry) {
                                            ExportTitle() => ExportTitleTile(
                                              key: Key('$index'),
                                              exportTitle: exportEntry,
                                              index: index,
                                            ),
                                            ExportItem() =>
                                              areaModel
                                                      .getPathsForItem(
                                                        exportEntry.name,
                                                      )
                                                      .isEmpty
                                                  ? ExportPlaceholderTile(
                                                      key: Key('$index'),
                                                      exportPlaceholder:
                                                          exportEntry,
                                                      index: index,
                                                      titleHidden: titleHidden,
                                                    )
                                                  : ExportItemTile(
                                                      key: Key('$index'),
                                                      exportItem: exportEntry,
                                                      index: index,
                                                      titleHidden: titleHidden,
                                                    ),
                                            _ => throw UnimplementedError(),
                                          };
                                        }(),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                  floatingActionButton: exportList.isEmpty
                      ? null
                      : FloatingActionButton.small(
                          onPressed: _isAtBottom
                              ? _scrollToTop
                              : _scrollToBottom,
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.surfaceContainer,
                          foregroundColor: Theme.of(
                            context,
                          ).colorScheme.onSurfaceVariant,
                          elevation: 2,
                          child: AnimatedRotation(
                            duration: const Duration(milliseconds: 200),
                            turns: _isAtBottom ? -0.5 : 0,
                            child: const Icon(Icons.arrow_downward),
                          ),
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
  required String title,
  required String content,
}) async {
  final bool? shouldDelete = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
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

Future<void> _showRenameDialog({
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

class ExportItemTile extends StatelessWidget {
  const ExportItemTile({
    required ExportItem exportItem,
    required int index,
    required bool titleHidden,
    super.key,
  }) : _titleHidden = titleHidden,
       _index = index,
       _exportItem = exportItem;

  final ExportItem _exportItem;
  final int _index;
  final bool _titleHidden;

  @override
  Widget build(BuildContext context) {
    return Consumer2<AreaModel, ExportModel>(
      builder: (context, areaModel, exportModel, child) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        return Material(
          child: Slidable(
            key: ValueKey(_exportItem),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) async {
                    await exportModel.editEntry(
                      _index,
                      isHidden: !_exportItem.isHidden,
                    );
                  },
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  icon: _exportItem.isHidden
                      ? Icons.visibility
                      : Icons.visibility_off,
                  label: _exportItem.isHidden ? 'Show' : 'Hide',
                ),
                SlidableAction(
                  onPressed: (_) async {
                    await _showRenameDialog(
                      context: context,
                      title: 'Rename Item',
                      initialValue: _exportItem.name,
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
                      title: 'Delete Item',
                      content:
                          'Are you sure you want to delete '
                          '"${_exportItem.name}"?',
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
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              tileColor: colorScheme.surfaceContainerHighest,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportItem.isHidden)
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
                _exportItem.name,
                style: _exportItem.isHidden || _titleHidden
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
              subtitle: areaModel.getPathsForItem(_exportItem.name).isNotEmpty
                  ? Text(areaModel.getPathsForItem(_exportItem.name).join('\n'))
                  : null,
            ),
          ),
        );
      },
    );
  }
}

class ExportPlaceholderTile extends StatelessWidget {
  const ExportPlaceholderTile({
    required ExportItem exportPlaceholder,
    required int index,
    required bool titleHidden,
    super.key,
  }) : _titleHidden = titleHidden,
       _index = index,
       _exportPlaceholder = exportPlaceholder;

  final ExportItem _exportPlaceholder;
  final int _index;
  final bool _titleHidden;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExportModel>(
      builder: (context, exportModel, child) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        return Material(
          child: Slidable(
            key: ValueKey(_exportPlaceholder),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) async {
                    await exportModel.editEntry(
                      _index,
                      isHidden: !_exportPlaceholder.isHidden,
                    );
                  },
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  icon: _exportPlaceholder.isHidden
                      ? Icons.visibility
                      : Icons.visibility_off,
                  label: _exportPlaceholder.isHidden ? 'Show' : 'Hide',
                ),
                SlidableAction(
                  onPressed: (_) async {
                    await _showRenameDialog(
                      context: context,
                      title: 'Rename Placeholder',
                      initialValue: _exportPlaceholder.name,
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
                      title: 'Delete Placeholder',
                      content:
                          'Are you sure you want to delete '
                          '"${_exportPlaceholder.name}"?',
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
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.only(left: 32, right: 16),
              tileColor: Colors.yellow.withValues(alpha: 0.3),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportPlaceholder.isHidden)
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
                _exportPlaceholder.name,
                style: _exportPlaceholder.isHidden || _titleHidden
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}

class ExportTitleTile extends StatelessWidget {
  const ExportTitleTile({
    required ExportTitle exportTitle,
    required int index,
    super.key,
  }) : _index = index,
       _exportTitle = exportTitle;

  final ExportTitle _exportTitle;
  final int _index;

  @override
  Widget build(BuildContext context) {
    return Consumer<ExportModel>(
      builder: (context, exportModel, child) {
        final ColorScheme colorScheme = Theme.of(context).colorScheme;
        return Material(
          child: Slidable(
            key: ValueKey(_exportTitle),
            endActionPane: ActionPane(
              motion: const DrawerMotion(),
              children: [
                SlidableAction(
                  onPressed: (_) async {
                    await exportModel.editEntry(
                      _index,
                      isHidden: !_exportTitle.isHidden,
                    );
                  },
                  backgroundColor: colorScheme.secondaryContainer,
                  foregroundColor: colorScheme.onSecondaryContainer,
                  icon: _exportTitle.isHidden
                      ? Icons.visibility
                      : Icons.visibility_off,
                  label: _exportTitle.isHidden ? 'Show' : 'Hide',
                ),
                SlidableAction(
                  onPressed: (_) async {
                    await _showRenameDialog(
                      context: context,
                      title: 'Rename Title',
                      initialValue: _exportTitle.name,
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
                      title: 'Delete Title',
                      content:
                          'Are you sure you want to delete '
                          '"${_exportTitle.name}"?',
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
              ],
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_exportTitle.isHidden)
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
                _exportTitle.name,
                style: _exportTitle.isHidden
                    ? TextStyle(
                        decoration: TextDecoration.lineThrough,
                        color: colorScheme.onSurfaceVariant,
                      )
                    : null,
              ),
            ),
          ),
        );
      },
    );
  }
}
