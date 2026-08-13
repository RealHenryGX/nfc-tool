import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tasks/task_catalog.dart';

/// Search query + selected category chip for the Tasks screen.
class TasksFilterState {
  final String query;
  final String group;

  const TasksFilterState({this.query = '', this.group = 'all'});

  TasksFilterState copyWith({String? query, String? group}) => TasksFilterState(
        query: query ?? this.query,
        group: group ?? this.group,
      );
}

class TasksFilterNotifier extends Notifier<TasksFilterState> {
  @override
  TasksFilterState build() => const TasksFilterState();

  void setQuery(String query) => state = state.copyWith(query: query);

  void selectGroup(String group) => state = state.copyWith(group: group);
}

final tasksFilterProvider =
    NotifierProvider<TasksFilterNotifier, TasksFilterState>(() {
  return TasksFilterNotifier();
});

/// Catalog entries matching the current search query and selected chip.
final filteredTasksProvider = Provider<List<TaskKind>>((ref) {
  final filter = ref.watch(tasksFilterProvider);
  final q = filter.query.toLowerCase();
  return TaskCatalog.all.where((t) {
    final gOk = filter.group == 'all' || t.group == filter.group;
    final qOk = q.isEmpty ||
        t.label.toLowerCase().contains(q) ||
        t.id.contains(q) ||
        t.description.toLowerCase().contains(q);
    return gOk && qOk;
  }).toList();
});

/// Filtered tasks grouped by category, preserving catalog order of first
/// appearance (matches the sticky-header section order on screen).
final groupedTasksProvider = Provider<List<MapEntry<String, List<TaskKind>>>>((ref) {
  final filtered = ref.watch(filteredTasksProvider);
  final sectionOrder = <String>[];
  final byGroup = <String, List<TaskKind>>{};
  for (final t in filtered) {
    byGroup.putIfAbsent(t.group, () {
      sectionOrder.add(t.group);
      return <TaskKind>[];
    }).add(t);
  }
  return [for (final g in sectionOrder) MapEntry(g, byGroup[g]!)];
});
