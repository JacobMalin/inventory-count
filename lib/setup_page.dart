import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:inventory_count/area.dart';

class SetupPage extends StatefulWidget {
  const SetupPage({super.key});

  @override
  State<SetupPage> createState() => _SetupPageState();
}

class _SetupPageState extends State<SetupPage> {
  var selectedArea = -1;

  void selectArea(int selectedArea) {
    setState(() {
      this.selectedArea = selectedArea;
    });
  }

  @override
  Widget build(BuildContext context) {
    return selectedArea != -1
        ? ShelvesPage(selectArea: selectArea, areaIndex: selectedArea)
        : AreasPage(selectArea: selectArea);
  }
}

class AreasPage extends StatelessWidget {
  const AreasPage({super.key, required this.selectArea});

  final void Function(int) selectArea;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Areas', style: Theme.of(context).textTheme.headlineLarge),
        centerTitle: true,
        toolbarHeight: 40,
      ),
      body: AreaList(selectArea: selectArea),
    );
  }
}

class AreaList extends StatelessWidget {
  const AreaList({super.key, required this.selectArea});

  final void Function(int) selectArea;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: Hive.box<Area>('areas').listenable(),
      builder: (context, box, child) {
        return Column(
          children: [
            ReorderableListView(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(horizontal: 40),
              children: <Widget>[
                for (int index = 0; index < box.length; index += 1)
                  ListTile(
                    key: Key('$index'),
                    tileColor: box.getAt(index)!.color,
                    title: Text(box.getAt(index)!.name),
                  ),
              ],
              onReorder: (int oldIndex, int newIndex) {
                if (oldIndex < newIndex) {
                  newIndex -= 1;
                }
                final Area item = box.getAt(oldIndex)!;
                box.deleteAt(oldIndex);
                box.putAt(newIndex, item);
              },
            ),
            ListTile(
              leading: const Icon(Icons.add),
              title: const Text('Add Area'),
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Enter Area Name'),
                    content: TextField(
                      autofocus: true,
                      onSubmitted: (value) {
                        if (value.isNotEmpty) {
                          box.add(Area(value));
                          Navigator.pop(context);
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
          ],
        );
      },
    );

    // @override
    // Widget build(BuildContext context) {
    //   return Padding(
    //     padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
    //     child: GridView.builder(
    //       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
    //         crossAxisCount: 3,
    //       ),
    //       itemCount: 15,
    //       itemBuilder: (context, index) {
    //         const double radius = 12;
    //         return ValueListenableBuilder(
    //           valueListenable: Hive.box('areas').listenable(),
    //           builder: (context, box, widget) {
    //             var isArea = box.containsKey(index);

    //             return Card(
    //               color: isArea ? null : Colors.transparent,
    //               shadowColor: isArea ? null : Colors.transparent,
    //               child: InkWell(
    //                 borderRadius: BorderRadius.circular(radius),
    //                 onTap: () {
    //                   if (isArea) {
    //                     selectArea(index);
    //                   } else {
    //                     showDialog(
    //                       context: context,
    //                       builder: (context) => AlertDialog(
    //                         title: const Text('Enter Area Name'),
    //                         content: TextField(
    //                           autofocus: true,
    //                           onSubmitted: (value) {
    //                             if (value.isNotEmpty) {
    //                               box.put(index, value);
    //                               Navigator.pop(context);
    //                             }
    //                           },
    //                         ),
    //                         actions: [
    //                           TextButton(
    //                             onPressed: () => Navigator.pop(context),
    //                             child: const Text('Cancel'),
    //                           ),
    //                         ],
    //                       ),
    //                     );
    //                   }
    //                 },
    //                 child: Padding(
    //                   padding: const EdgeInsets.all(12.0),
    //                   child: Column(
    //                     mainAxisAlignment: MainAxisAlignment.center,
    //                     children: isArea
    //                         ? [
    //                             Icon(
    //                               Icons.inventory,
    //                               size: 40,
    //                               color: Theme.of(context).colorScheme.primary,
    //                             ),
    //                             Text(
    //                               box.get(index),
    //                               style: Theme.of(
    //                                 context,
    //                               ).textTheme.bodyLarge!.copyWith(fontSize: 18),
    //                               textAlign: TextAlign.center,
    //                             ),
    //                           ]
    //                         : [
    //                             Icon(
    //                               Icons.add,
    //                               size: 40,
    //                               color: Theme.of(context).colorScheme.primary,
    //                             ),
    //                           ],
    //                   ),
    //                 ),
    //               ),
    //             );
    //           },
    //         );
    //       },
    //     ),
    //   );
  }
}

class ShelvesPage extends StatelessWidget {
  const ShelvesPage({
    super.key,
    required this.selectArea,
    required this.areaIndex,
  });

  final void Function(int) selectArea;
  final int areaIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: ValueListenableBuilder(
          valueListenable: Hive.box('areas').listenable(),
          builder: (context, box, widget) {
            return Text(
              box.get(areaIndex),
              style: Theme.of(context).textTheme.headlineLarge,
            );
          },
        ),
        centerTitle: true,
        toolbarHeight: 40,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new),
          onPressed: () => selectArea(-1),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 5.0),
        child: GridView.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
          ),
          itemCount: 15,
          itemBuilder: (context, index) {
            const double radius = 12;
            return ValueListenableBuilder(
              valueListenable: Hive.box('shelves').listenable(),
              builder: (context, box, widget) {
                var isShelf = box.containsKey(index);

                return Card(
                  color: isShelf ? null : Colors.transparent,
                  shadowColor: isShelf ? null : Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(radius),
                    onTap: () {
                      if (isShelf) {
                        selectArea(index);
                      } else {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Enter Shelf Name'),
                            content: TextField(
                              autofocus: true,
                              onSubmitted: (value) {
                                if (value.isNotEmpty) {
                                  box.put(index, value);
                                  Navigator.pop(context);
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
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: isShelf
                            ? [
                                Icon(
                                  Icons.inventory,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                Text(
                                  box.get(index),
                                  style: Theme.of(
                                    context,
                                  ).textTheme.bodyLarge!.copyWith(fontSize: 18),
                                  textAlign: TextAlign.center,
                                ),
                              ]
                            : [
                                Icon(
                                  Icons.add,
                                  size: 40,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                              ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}
