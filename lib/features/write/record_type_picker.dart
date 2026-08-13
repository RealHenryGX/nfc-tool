import 'package:flutter/material.dart';

import '../../core/nfc/record_catalog.dart';
import '../../core/theme/stackntrace_tokens.dart';

/// Record kinds matching the given group filter + search query.
List<RecordKind> filterRecordKinds({required String groupFilter, required String query}) {
  return RecordCatalog.all.where((k) {
    final gOk = groupFilter == 'all' || k.group == groupFilter;
    final q = query.toLowerCase();
    final qOk = q.isEmpty ||
        k.label.toLowerCase().contains(q) ||
        k.id.toLowerCase().contains(q) ||
        (RecordCatalog.groupLabels[k.group] ?? '').toLowerCase().contains(q);
    return gOk && qOk;
  }).toList();
}

/// "Add NFC Record" type picker: search + group chips + grouped list.
///
/// Search/group-filter state is owned by the caller (survives the picker
/// being hidden while the form is shown, matching prior behavior).
class RecordTypePicker extends StatelessWidget {
  final ThemeData theme;
  final Brightness brightness;
  final TextEditingController searchController;
  final String groupFilter;
  final String query;
  final ValueChanged<String> onGroupFilterChanged;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onSelect;

  const RecordTypePicker({
    super.key,
    required this.theme,
    required this.brightness,
    required this.searchController,
    required this.groupFilter,
    required this.query,
    required this.onGroupFilterChanged,
    required this.onQueryChanged,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final accent = StackntraceTokens.accent(brightness);
    final kinds = filterRecordKinds(groupFilter: groupFilter, query: query);
    final groups = <String, List<RecordKind>>{};
    for (final k in kinds) {
      groups.putIfAbsent(k.group, () => []).add(k);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: searchController,
          decoration: const InputDecoration(
            hintText: 'Search record types…',
            prefixIcon: Icon(Icons.search),
          ),
          onChanged: onQueryChanged,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 40,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: const Text('All'),
                  selected: groupFilter == 'all',
                  onSelected: (_) => onGroupFilterChanged('all'),
                ),
              ),
              ...RecordCatalog.groups.map((g) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    label: Text(RecordCatalog.groupLabels[g] ?? g),
                    selected: groupFilter == g,
                    onSelected: (_) => onGroupFilterChanged(g),
                  ),
                );
              }),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: kinds.isEmpty
              ? Center(
                  child: Text(
                    'No matching types',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                )
              : ListView(
                  children: [
                    for (final entry in groups.entries) ...[
                      Padding(
                        padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                        child: Text(
                          (RecordCatalog.groupLabels[entry.key] ?? entry.key)
                              .toUpperCase(),
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: accent,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      ...entry.value.map((item) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Material(
                            color: StackntraceTokens.surface2(brightness),
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => onSelect(item.id),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: StackntraceTokens.accentSoft(
                                          brightness,
                                        ),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Icon(item.icon, color: accent),
                                    ),
                                    const SizedBox(width: 14),
                                    Expanded(
                                      child: Text(
                                        item.label,
                                        style: theme.textTheme.titleMedium
                                            ?.copyWith(
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      color: theme.colorScheme.onSurfaceVariant,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}
