import 'package:flutter/material.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:provider/provider.dart';

class DatePicker extends StatelessWidget {
  const DatePicker({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<CountModel>(
      builder: (context, countModel, child) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              onPressed: countModel.decrementDate,
            ),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    countModel.date,
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    spacing: 8.0,
                    children: [
                      TextButton.icon(
                        onPressed: countModel.selectedProfile == null
                            ? null
                            : () => countModel.selectedProfile = null,
                        icon: Icon(
                          countModel.selectedProfile?.icon ?? Icons.person,
                          color: countModel.selectedProfile?.color,
                          size: 16,
                        ),
                        label: Text(
                          countModel.selectedProfile?.name ?? 'Select Profile',
                        ),
                        style: TextButton.styleFrom(
                          foregroundColor: countModel.selectedProfile?.color,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      if (!countModel.isToday)
                        TextButton.icon(
                          onPressed: countModel.goToToday,
                          icon: const Icon(Icons.today, size: 16),
                          label: const Text('Today'),
                          style: TextButton.styleFrom(
                            foregroundColor: const Color.fromARGB(
                              255,
                              221,
                              206,
                              39,
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              onPressed: countModel.incrementDate,
            ),
          ],
        );
      },
    );
  }
}
