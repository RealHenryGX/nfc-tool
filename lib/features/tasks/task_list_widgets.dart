import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tasks/task_catalog.dart';
import 'tasks_filter_provider.dart';

const _groupMeta = <String, (String, IconData, Color)>{
  'connectivity': ('Connectivity', Icons.wifi, Color(0xFF2563EB)),
  'sound': ('Sound & Media', Icons.volume_up, Color(0xFF7C3AED)),
  'display': ('Display', Icons.brightness_6, Color(0xFFF59E0B)),
  'apps': ('Apps & System', Icons.apps, Color(0xFFEA580C)),
  'input': ('Input & Speech', Icons.keyboard, Color(0xFF059669)),
  'files': ('Files', Icons.folder, Color(0xFF0D9488)),
  'comms': ('Communications', Icons.call, Color(0xFF16A34A)),
  'maps': ('Maps & Location', Icons.map, Color(0xFFDC2626)),
  'logic': ('Logic & Variables', Icons.account_tree, Color(0xFF6366F1)),
  'misc': ('Misc', Icons.more_horiz, Color(0xFF64748B)),
};

/// (title, icon, color) metadata for a task category group.
(String, IconData, Color) taskGroupMeta(String group) =>
    _groupMeta[group] ?? (group, Icons.bolt, const Color(0xFF6366F1));

String taskGroupTitle(String group) {
  if (group == 'all') return 'All';
  return taskGroupMeta(group).$1;
}

/// Search box bound to [tasksFilterProvider].
class TaskSearchField extends ConsumerWidget {
  const TaskSearchField({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: TextField(
        decoration: const InputDecoration(
          prefixIcon: Icon(Icons.search),
          hintText: 'Search tasks…',
        ),
        onChanged: (v) => ref.read(tasksFilterProvider.notifier).setQuery(v),
      ),
    );
  }
}

/// Horizontal category chip row bound to [tasksFilterProvider].
class TaskCategoryChips extends ConsumerWidget {
  const TaskCategoryChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final selectedGroup = ref.watch(tasksFilterProvider).group;
    final groups = ['all', ...TaskCatalog.groups];

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: groups.map((g) {
          final selected = selectedGroup == g;
          final color = g == 'all' ? theme.colorScheme.primary : taskGroupMeta(g).$3;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              avatar: Icon(
                g == 'all' ? Icons.grid_view : taskGroupMeta(g).$2,
                size: 16,
                color: selected ? color : null,
              ),
              label: Text(taskGroupTitle(g)),
              selected: selected,
              onSelected: (_) => ref.read(tasksFilterProvider.notifier).selectGroup(g),
              selectedColor: color.withValues(alpha: 0.18),
              checkmarkColor: color,
            ),
          );
        }).toList(),
      ),
    );
  }
}

/// Sticky section header for a task category group.
class TaskGroupHeaderDelegate extends SliverPersistentHeaderDelegate {
  final String title;
  final IconData icon;
  final Color color;
  final Color background;
  final double extent;

  TaskGroupHeaderDelegate({
    required this.title,
    required this.icon,
    required this.color,
    required this.background,
    required this.extent,
  });

  @override
  double get minExtent => extent;
  @override
  double get maxExtent => extent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      color: background,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 1.05,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant TaskGroupHeaderDelegate oldDelegate) =>
      title != oldDelegate.title ||
      color != oldDelegate.color ||
      background != oldDelegate.background ||
      extent != oldDelegate.extent;
}

/// A single task row in the catalog list.
class TaskTile extends StatelessWidget {
  final TaskKind kind;
  final VoidCallback onTap;

  const TaskTile({super.key, required this.kind, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final meta = taskGroupMeta(kind.group);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: meta.$3.withValues(alpha: 0.15),
          child: Icon(
            kind.rootRecommended ? Icons.warning_amber_rounded : meta.$2,
            color: kind.rootRecommended ? theme.colorScheme.tertiary : meta.$3,
            size: 20,
          ),
        ),
        title: Text(
          kind.label,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          kind.description,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(Icons.add_circle_outline, color: meta.$3),
        onTap: onTap,
      ),
    );
  }
}
