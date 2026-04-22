import 'package:flutter/material.dart';

import 'tools/calculator_tool_page.dart';
import 'tools/notes_tool_page.dart';
import 'tools/restock_tool_page.dart';

class ToolsPage extends StatefulWidget {
  const ToolsPage({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  State<ToolsPage> createState() => _ToolsPageState();
}

class _ToolsPageState extends State<ToolsPage> {
  Future<void> _openRestockHelper() async {
    await ToolsPage.navigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(builder: (_) => const RestockToolPage()),
    );
  }
  // Use static navigatorKey for global access

  Future<void> _openNotes() async {
    await ToolsPage.navigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(builder: (_) => const NotesToolPage()),
    );
  }

  Future<void> _openCalculator() async {
    await ToolsPage.navigatorKey.currentState?.push<void>(
      MaterialPageRoute<void>(builder: (_) => const CalculatorToolPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return NavigatorPopHandler(
      onPopWithResult: (result) async {
        await ToolsPage.navigatorKey.currentState?.maybePop();
      },
      child: Navigator(
        key: ToolsPage.navigatorKey,
        onGenerateRoute: (_) {
          return MaterialPageRoute<void>(
            builder: (_) => _ToolsHomeView(
              openNotes: _openNotes,
              openCalculator: _openCalculator,
              restockHelper: _openRestockHelper,
            ),
          );
        },
      ),
    );
  }
}

class _ToolsHomeView extends StatelessWidget {
  const _ToolsHomeView({
    required VoidCallback openNotes,
    required VoidCallback openCalculator,
    required VoidCallback restockHelper,
  }) : _openNotes = openNotes,
       _openCalculator = openCalculator,
       _openRestockHelper = restockHelper;

  final VoidCallback _openNotes;
  final VoidCallback _openCalculator;
  final VoidCallback _openRestockHelper;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          title: Text(
            'Tools',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          floating: true,
          snap: true,
        ),
        SliverPadding(
          padding: const EdgeInsets.all(16),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              ToolCard(
                icon: Icons.calculate,
                title: 'Calculator',
                description:
                    'Quick calculations for quantities and adjustments',
                onTap: _openCalculator,
              ),
              const SizedBox(height: 12),
              ToolCard(
                icon: Icons.inventory_2,
                title: 'Restock Helper',
                description: 'Write restock numbers for easy reference',
                onTap: _openRestockHelper,
              ),
              const SizedBox(height: 12),
              ToolCard(
                icon: Icons.note_add,
                title: 'Notes',
                description: 'Add quick notes during inventory counting',
                onTap: _openNotes,
              ),
            ]),
          ),
        ),
      ],
    );
  }
}

class ToolCard extends StatelessWidget {
  const ToolCard({
    required IconData icon,
    required String title,
    required String description,
    required void Function() onTap,
    super.key,
  }) : _onTap = onTap,
       _description = description,
       _title = title,
       _icon = icon;

  final IconData _icon;
  final String _title;
  final String _description;
  final VoidCallback _onTap;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: _onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  _icon,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _title,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _description,
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_ios,
                size: 16,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
