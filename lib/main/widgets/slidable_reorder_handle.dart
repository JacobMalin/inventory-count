import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:material_ui/material_ui.dart';

class SlidableReorderHandle extends StatelessWidget {
  const SlidableReorderHandle({
    required this.index,
    this.hideWhenSlidableOpen = true,
    super.key,
  });

  final int index;
  final bool hideWhenSlidableOpen;

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = switch (Theme.of(context).platform) {
      TargetPlatform.linux ||
      TargetPlatform.macOS ||
      TargetPlatform.windows => true,
      _ => false,
    };
    if (!isDesktop) {
      return const SizedBox.shrink();
    }

    final SlidableController controller = Slidable.of(context)!;

    return AnimatedBuilder(
      animation: controller.animation,
      builder: (context, child) {
        if (hideWhenSlidableOpen && controller.animation.value > 0) {
          return const SizedBox.shrink();
        }
        return ReorderableDragStartListener(index: index, child: child!);
      },
      child: const Icon(Icons.drag_handle),
    );
  }
}
