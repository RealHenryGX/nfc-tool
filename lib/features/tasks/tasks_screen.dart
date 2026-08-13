import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'task_list_widgets.dart';
import 'tasks_actions.dart';
import 'tasks_filter_provider.dart';

class TasksScreen extends ConsumerWidget {
  const TasksScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final grouped = ref.watch(groupedTasksProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tasks')),
      body: Column(
        children: [
          const TaskSearchField(),
          const TaskCategoryChips(),
          Expanded(
            child: grouped.isEmpty
                ? Center(
                    child: Text(
                      'No matching tasks',
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                    ),
                  )
                : CustomScrollView(
                    slivers: [
                      for (final entry in grouped) ...[
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: TaskGroupHeaderDelegate(
                            title: taskGroupMeta(entry.key).$1,
                            icon: taskGroupMeta(entry.key).$2,
                            color: taskGroupMeta(entry.key).$3,
                            background: theme.scaffoldBackgroundColor,
                            extent: MediaQuery.textScalerOf(context)
                                .scale(40)
                                .clamp(40, 56)
                                .toDouble(),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                          sliver: SliverList.separated(
                            itemCount: entry.value.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 4),
                            itemBuilder: (context, i) {
                              final t = entry.value[i];
                              return TaskTile(
                                kind: t,
                                onTap: () =>
                                    ref.read(tasksActionsProvider).openTask(context, t),
                              );
                            },
                          ),
                        ),
                      ],
                      const SliverToBoxAdapter(child: SizedBox(height: 24)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
