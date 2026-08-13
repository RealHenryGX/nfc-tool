import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/widgets/app_ui.dart';
import '../../models/history.dart';
import 'history_provider.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key});

  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _searchQuery = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _exportHistory() async {
    final csvString = ref.read(historyProvider.notifier).exportToCsv();
    if (csvString.isEmpty) return;

    try {
      await shareAppTempFile(
        fileName: 'nfc_history.csv',
        contents: csvString,
        mimeType: 'text/csv',
        subject: 'NFC Toolbox History Log',
      );
    } catch (e) {
      if (mounted) {
        showAppSnack(context, 'Export failed: $e', isError: true);
      }
    }
  }

  void _clearAllHistory() async {
    final confirm = await confirmAppAction(
      context,
      title: 'Clear History?',
      message:
          'This will permanently delete all read/write history logs. Proceed?',
      confirmLabel: 'Clear All',
      destructive: true,
    );

    if (confirm) {
      await ref.read(historyProvider.notifier).clearAll();
      if (mounted) {
        showAppSnack(context, 'History cleared successfully!');
      }
    }
  }

  void _showEntryDetail(HistoryEntry entry) {
    showDialog(
      context: context,
      builder: (context) {
        final theme = Theme.of(context);
        return AlertDialog(
          title: Text(
            'Log Detail',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildDetailField('Action', entry.action.toUpperCase(), theme),
                _buildDetailField('Status', entry.success ? 'Success' : 'Failed', theme, isStatus: true, success: entry.success),
                _buildDetailField('Timestamp', DateFormat('yyyy-MM-dd HH:mm:ss').format(entry.timestamp), theme),
                _buildDetailField('Tag UID', entry.uid ?? 'N/A', theme),
                _buildDetailField('Details', entry.details ?? 'N/A', theme),
                const Divider(height: 24),
                Text(
                  'NDEF Records (${entry.records.length})',
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                if (entry.records.isEmpty)
                  const Text('No records', style: TextStyle(fontStyle: FontStyle.italic))
                else
                  ...entry.records.map((r) {
                    final content = r.payload.values.firstWhere((e) => e != null, orElse: () => '').toString();
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              r.type.toUpperCase(),
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: theme.colorScheme.primary,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              content,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildDetailField(String label, String value, ThemeData theme, {bool isStatus = false, bool success = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 2),
          isStatus
              ? Text(
                  value,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: success ? theme.colorScheme.tertiary : theme.colorScheme.error,
                  ),
                )
              : Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final history = ref.watch(historyProvider);

    final filteredHistory = history.where((e) {
      final query = _searchQuery.toLowerCase();
      final hasAction = e.action.toLowerCase().contains(query);
      final hasUid = (e.uid ?? '').toLowerCase().contains(query);
      final hasDetails = (e.details ?? '').toLowerCase().contains(query);
      return hasAction || hasUid || hasDetails;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('History Logs', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (history.isNotEmpty) ...[
            IconButton(
              icon: const Icon(Icons.share_outlined),
              tooltip: 'Export CSV',
              onPressed: _exportHistory,
            ),
            IconButton(
              icon: const Icon(Icons.delete_sweep_outlined),
              tooltip: 'Clear All',
              onPressed: _clearAllHistory,
            ),
          ]
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search history...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          setState(() {
                            _searchQuery = '';
                            _searchController.clear();
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onChanged: (val) {
                setState(() {
                  _searchQuery = val;
                });
              },
            ),
          ),
          Expanded(
            child: filteredHistory.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.history_outlined, size: 64, color: theme.colorScheme.primary.withValues(alpha: 0.3)),
                          const SizedBox(height: 16),
                          Text(
                            _searchQuery.isNotEmpty ? 'No logs match search' : 'No History Logs',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _searchQuery.isNotEmpty
                                ? 'Try searching different keywords'
                                : 'Any successful or failed NFC reads and writes will show up here.',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: filteredHistory.length,
                    itemBuilder: (context, index) {
                      final entry = filteredHistory[index];
                      final dateStr = DateFormat('MMM d, h:mm a').format(entry.timestamp);
                      
                      Color badgeColor = theme.colorScheme.outline;
                      if (entry.action == 'read') badgeColor = theme.colorScheme.primary;
                      if (entry.action == 'write') badgeColor = theme.colorScheme.tertiary;
                      if (entry.action == 'batch_write') badgeColor = theme.colorScheme.secondary;

                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        child: ListTile(
                          onTap: () => _showEntryDetail(entry),
                          title: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: badgeColor.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  entry.action.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: badgeColor,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  entry.uid != null ? 'UID: ${entry.uid}' : 'No UID',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    entry.details ?? 'NDEF Action',
                                    style: const TextStyle(fontSize: 12),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                Text(
                                  dateStr,
                                  style: TextStyle(fontSize: 11, color: theme.colorScheme.onSurfaceVariant),
                                ),
                              ],
                            ),
                          ),
                          trailing: Icon(
                            entry.success ? Icons.check_circle_outline : Icons.error_outline,
                            color: entry.success ? theme.colorScheme.tertiary : theme.colorScheme.error,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
