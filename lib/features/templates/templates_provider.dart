import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../models/tag_template.dart';
import '../../models/ndef_record.dart';
import '../../core/storage/storage_service.dart';
import '../../core/nfc/preset_library.dart';

class TemplatesNotifier extends Notifier<List<TagTemplate>> {
  @override
  List<TagTemplate> build() {
    final all = StorageService.getTemplates();
    final kept = _uniqueByName(all);
    if (kept.length < all.length) {
      Future.microtask(() => _purgeIds(
            all.map((t) => t.id).toSet().difference(kept.map((t) => t.id).toSet()),
          ));
    }
    return kept;
  }

  /// Keep the first entry for each case-insensitive name.
  static List<TagTemplate> _uniqueByName(List<TagTemplate> list) {
    final seen = <String>{};
    final kept = <TagTemplate>[];
    for (final t in list) {
      final key = t.name.trim().toLowerCase();
      if (!seen.add(key)) continue;
      kept.add(t);
    }
    return kept;
  }

  Future<void> _purgeIds(Set<String> ids) async {
    for (final id in ids) {
      await StorageService.deleteTemplate(id);
    }
  }

  Future<void> loadPresets() async {
    final existingNames = {
      for (final t in state) t.name.trim().toLowerCase(),
    };
    for (final p in PresetLibrary.all()) {
      if (state.any((t) => t.id == p.id)) continue;
      if (existingNames.contains(p.name.trim().toLowerCase())) continue;
      await StorageService.saveTemplate(p);
      existingNames.add(p.name.trim().toLowerCase());
    }
    state = _uniqueByName(StorageService.getTemplates());
  }

  Future<void> addTemplate(String name, List<dynamic> records) async {
    final newTemplate = TagTemplate(
      id: const Uuid().v4(),
      name: name,
      records: records.map((e) => e as NdefRecordModel).toList(),
      createdAt: DateTime.now(),
    );
    await StorageService.saveTemplate(newTemplate);
    state = [...state, newTemplate];
  }

  Future<void> saveTemplate(TagTemplate template) async {
    await StorageService.saveTemplate(template);
    state = [
      for (final t in state)
        if (t.id == template.id) template else t
    ];
  }

  Future<void> deleteTemplate(String id) async {
    await StorageService.deleteTemplate(id);
    state = state.where((t) => t.id != id).toList();
  }

  Future<void> duplicateTemplate(TagTemplate template) async {
    final copy = TagTemplate(
      id: const Uuid().v4(),
      name: '${template.name} (Copy)',
      records: template.records,
      createdAt: DateTime.now(),
    );
    await StorageService.saveTemplate(copy);
    state = [...state, copy];
  }

  String exportToJson() {
    final list = state.map((e) => e.toJson()).toList();
    return jsonEncode(list);
  }

  Future<bool> importFromJson(String jsonStr) async {
    try {
      final decoded = jsonDecode(jsonStr);
      if (decoded is List) {
        final imported = decoded
            .map((e) => TagTemplate.fromJson(Map<String, dynamic>.from(e as Map)))
            .toList();
        final existingIds = {for (final t in state) t.id};
        final existingNames = {
          for (final t in state) t.name.trim().toLowerCase(),
        };
        for (final t in imported) {
          if (existingIds.contains(t.id)) continue;
          final nameKey = t.name.trim().toLowerCase();
          if (existingNames.contains(nameKey)) continue;
          await StorageService.saveTemplate(t);
          existingIds.add(t.id);
          existingNames.add(nameKey);
        }
        state = _uniqueByName(StorageService.getTemplates());
        return true;
      }
      return false;
    } catch (_) {
      return false;
    }
  }

  Future<void> clearAll() async {
    await StorageService.clearTemplates();
    state = [];
  }
}

final templatesProvider = NotifierProvider<TemplatesNotifier, List<TagTemplate>>(() {
  return TemplatesNotifier();
});
