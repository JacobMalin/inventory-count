import 'package:flutter/material.dart';
import 'package:inventory_count/models/area_model.dart';
import 'package:inventory_count/models/count_model.dart';
import 'package:inventory_count/models/hive.dart';
import 'package:provider/provider.dart';
import 'package:dropdown_search/dropdown_search.dart';

class SelectProfile extends StatefulWidget {
  const SelectProfile({super.key});

  @override
  State<SelectProfile> createState() => _SelectProfileState();
}

class _SelectProfileState extends State<SelectProfile> {
  final TextEditingController _newProfileController = TextEditingController();
  Profile? _baseProfile;

  @override
  void dispose() {
    _newProfileController.dispose();
    super.dispose();
  }

  void _createProfile(
    AreaModel areaModel,
    CountModel countModel,
    Profile? baseProfile,
  ) {
    final name = _newProfileController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a profile name'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final currentProfiles = areaModel.profiles;
    final nameLower = name.toLowerCase();
    final hasDuplicate = currentProfiles.keys.any(
      (profile) => profile.name.toLowerCase() == nameLower,
    );
    if (hasDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile already exists'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    final newProfile = Profile(name);
    if (!currentProfiles.containsKey(newProfile)) {
      // Copy areas from base profile if one is selected
      if (baseProfile != null && currentProfiles.containsKey(baseProfile)) {
        final baseAreas = currentProfiles[baseProfile] ?? <Area>[];
        currentProfiles[newProfile] = List<Area>.from(baseAreas);
      } else {
        currentProfiles[newProfile] = <Area>[];
      }
      areaModel.profiles = currentProfiles;
    }

    countModel.selectedProfile = newProfile;
    _newProfileController.clear();
    _baseProfile = null;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile ${newProfile.name} created'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showCreateProfileDialog(
    AreaModel areaModel,
    CountModel countModel,
  ) async {
    _newProfileController.clear();
    _baseProfile = null;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          final profileList = areaModel.profiles.keys.toList();

          return AlertDialog(
            title: const Text('Add new profile'),
            contentPadding: const EdgeInsets.only(
              left: 24,
              right: 24,
              top: 8,
              bottom: 20,
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _newProfileController,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Profile name'),
                  onSubmitted: (_) {
                    Navigator.of(dialogContext).pop();
                    _createProfile(areaModel, countModel, _baseProfile);
                  },
                ),
                if (profileList.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  DropdownSearch<Profile?>(
                    items: (f, cs) => [null, ...profileList],
                    selectedItem: _baseProfile,
                    itemAsString: (Profile? profile) =>
                        profile?.name ?? 'None (start empty)',
                    decoratorProps: const DropDownDecoratorProps(
                      decoration: InputDecoration(
                        hintText: "Base on existing profile",
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                    ),
                    popupProps: PopupProps.menu(
                      fit: FlexFit.loose,
                      constraints: const BoxConstraints(maxHeight: 400),
                      showSearchBox: profileList.length > 5,
                      searchFieldProps: const TextFieldProps(
                        decoration: InputDecoration(
                          hintText: 'Search profiles...',
                          prefixIcon: Icon(Icons.search),
                        ),
                      ),
                    ),
                    compareFn: (item1, item2) => item1 == item2,
                    onSelected: (value) {
                      setState(() {
                        _baseProfile = value;
                      });
                    },
                  ),
                ],
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop();
                  _createProfile(areaModel, countModel, _baseProfile);
                },
                child: const Text('Create'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showProfileMenu(
    Profile profile,
    AreaModel areaModel,
    CountModel countModel,
  ) async {
    await showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (bottomSheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.update),
              title: const Text('Update from profile'),
              onTap: () {
                Navigator.of(bottomSheetContext).pop();
                _showUpdateFromProfileDialog(profile, areaModel, countModel);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit),
              title: const Text('Rename profile'),
              onTap: () {
                Navigator.of(bottomSheetContext).pop();
                _showRenameProfileDialog(profile, areaModel, countModel);
              },
            ),
            ListTile(
              leading: Icon(
                Icons.delete,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Delete profile',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () {
                Navigator.of(bottomSheetContext).pop();
                _showDeleteProfileDialog(profile, areaModel, countModel);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRenameProfileDialog(
    Profile profile,
    AreaModel areaModel,
    CountModel countModel,
  ) async {
    final TextEditingController renameController = TextEditingController(
      text: profile.name,
    );

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Rename profile'),
          content: TextField(
            controller: renameController,
            autofocus: true,
            decoration: const InputDecoration(labelText: 'Profile name'),
            onSubmitted: (_) {
              Navigator.of(dialogContext).pop();
              _renameProfile(
                profile,
                renameController.text,
                areaModel,
                countModel,
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _renameProfile(
                  profile,
                  renameController.text,
                  areaModel,
                  countModel,
                );
              },
              child: const Text('Rename'),
            ),
          ],
        );
      },
    );

    renameController.dispose();
  }

  void _renameProfile(
    Profile profile,
    String newName,
    AreaModel areaModel,
    CountModel countModel,
  ) {
    final trimmedName = newName.trim();
    if (trimmedName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please enter a profile name'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    if (trimmedName.toLowerCase() == profile.name.toLowerCase()) {
      return; // No change
    }

    final currentProfiles = areaModel.profiles;
    final nameLower = trimmedName.toLowerCase();
    final hasDuplicate = currentProfiles.keys.any(
      (p) => p.name.toLowerCase() == nameLower && p != profile,
    );

    if (hasDuplicate) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile already exists'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    // Create new profile with new name and transfer data
    final areas = currentProfiles.remove(profile) ?? <Area>[];
    final newProfile = Profile(trimmedName);
    currentProfiles[newProfile] = areas;
    areaModel.profiles = currentProfiles;

    // Update selected profile if it was the one being renamed
    if (countModel.selectedProfile == profile) {
      countModel.selectedProfile = newProfile;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Profile renamed to "$trimmedName"'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showUpdateFromProfileDialog(
    Profile targetProfile,
    AreaModel areaModel,
    CountModel countModel,
  ) async {
    Profile? sourceProfile;
    final profileList = areaModel.profiles.keys
        .where((p) => p != targetProfile)
        .toList();

    if (profileList.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('No other profiles available'),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
      return;
    }

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: Text('Update "${targetProfile.name}"'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Copy data from:',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 12),
                DropdownSearch<Profile?>(
                  items: (f, cs) => profileList,
                  selectedItem: sourceProfile,
                  itemAsString: (Profile? profile) => profile?.name ?? '',
                  decoratorProps: const DropDownDecoratorProps(
                    decoration: InputDecoration(
                      hintText: "Select profile",
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                    ),
                  ),
                  popupProps: PopupProps.menu(
                    fit: FlexFit.loose,
                    constraints: const BoxConstraints(maxHeight: 400),
                    showSearchBox: profileList.length > 5,
                    searchFieldProps: const TextFieldProps(
                      decoration: InputDecoration(
                        hintText: 'Search profiles...',
                        prefixIcon: Icon(Icons.search),
                      ),
                    ),
                  ),
                  compareFn: (item1, item2) => item1 == item2,
                  onSelected: (value) {
                    setState(() {
                      sourceProfile = value;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Text(
                  'This will replace all areas and items in "${targetProfile.name}" with data from the selected profile.',
                  style: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: sourceProfile == null
                    ? null
                    : () {
                        Navigator.of(dialogContext).pop();
                        _updateProfile(
                          targetProfile,
                          sourceProfile!,
                          areaModel,
                        );
                      },
                child: const Text('Update'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _updateProfile(
    Profile targetProfile,
    Profile sourceProfile,
    AreaModel areaModel,
  ) {
    final currentProfiles = areaModel.profiles;
    final sourceAreas = currentProfiles[sourceProfile] ?? <Area>[];
    currentProfiles[targetProfile] = List<Area>.from(sourceAreas);
    areaModel.profiles = currentProfiles;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '"${targetProfile.name}" updated from "${sourceProfile.name}"',
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  Future<void> _showDeleteProfileDialog(
    Profile profile,
    AreaModel areaModel,
    CountModel countModel,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete profile'),
        content: Text(
          'Are you sure you want to delete "${profile.name}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final currentProfiles = areaModel.profiles;
      currentProfiles.remove(profile);
      areaModel.profiles = currentProfiles;

      if (countModel.selectedProfile == profile) {
        countModel.selectedProfile = null;
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${profile.name}" deleted'),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 360),
          child: Consumer2<AreaModel, CountModel>(
            builder: (context, areaModel, countModel, child) {
              final profileList = areaModel.profiles.keys.toList();

              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Inventory Count',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Pick a profile to start counting items.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  GridView.builder(
                    shrinkWrap: true,
                    itemCount: profileList.length + 1,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 3,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 1,
                        ),
                    itemBuilder: (context, index) {
                      if (index == profileList.length) {
                        return _ProfileTile(
                          label: 'Add profile',
                          icon: Icons.add,
                          onTap: () =>
                              _showCreateProfileDialog(areaModel, countModel),
                        );
                      }

                      final profile = profileList[index];
                      return _ProfileTile(
                        label: profile.name,
                        icon: profile.icon,
                        iconColor: profile.color,
                        onTap: () {
                          countModel.selectedProfile = profile;
                        },
                        onLongPress: () {
                          _showProfileMenu(profile, areaModel, countModel);
                        },
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  const _ProfileTile({
    required this.label,
    required this.icon,
    required this.onTap,
    this.iconColor,
    this.onLongPress,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveColor = iconColor ?? colorScheme.primary;
    final dulledColor1 = Color.lerp(effectiveColor, colorScheme.surface, 0.80)!;
    final dulledColor2 = Color.lerp(effectiveColor, colorScheme.surface, 0.85)!;

    return Material(
      elevation: 3,
      borderRadius: BorderRadius.circular(20),
      child: Ink(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [dulledColor1, dulledColor2],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          onSecondaryTap: onLongPress,
          borderRadius: BorderRadius.circular(20),
          splashColor: effectiveColor.withAlpha(51),
          highlightColor: effectiveColor.withAlpha(26),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: effectiveColor, size: 36),
                const SizedBox(height: 8),
                Text(
                  label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: effectiveColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
