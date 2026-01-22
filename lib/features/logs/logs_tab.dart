import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/logging/log_service.dart';
import '../../models/log_entry.dart';

class LogsTab extends StatefulWidget {
  const LogsTab({super.key});

  @override
  State<LogsTab> createState() => _LogsTabState();
}

class _LogsTabState extends State<LogsTab> {
  LogLevel _selectedFilter = LogLevel.debug;
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();

  List<LogEntry> _getFilteredLogs(LogService logService) {
    var logs = logService.logs;

    // Filter by log level
    if (_selectedFilter != LogLevel.debug) {
      logs = logs.where((log) => log.level.index >= _selectedFilter.index).toList();
    }

    // Filter by search query
    if (_searchQuery.isNotEmpty) {
      logs = logs.where((log) {
        return log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               log.module.toLowerCase().contains(_searchQuery.toLowerCase());
      }).toList();
    }

    // Return in reverse order (newest first)
    return logs.reversed.toList();
  }

  void _copyLogToClipboard(LogEntry log) {
    Clipboard.setData(ClipboardData(text: log.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Log entry copied to clipboard'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  void _copyAllLogs(List<LogEntry> logs) {
    final logText = logs.map((log) => log.toString()).join('\n');
    Clipboard.setData(ClipboardData(text: logText));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${logs.length} log entries copied to clipboard'),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<LogService>(
      builder: (context, logService, _) {
        final filteredLogs = _getFilteredLogs(logService);

        return Scaffold(
          appBar: AppBar(
            title: const Text('Application Logs'),
            actions: [
              PopupMenuButton<LogLevel>(
                icon: Icon(
                  Icons.filter_list,
                  color: _selectedFilter != LogLevel.debug ? _selectedFilter.color : null,
                ),
                tooltip: 'Filter by log level',
                initialValue: _selectedFilter,
                onSelected: (level) => setState(() => _selectedFilter = level),
                itemBuilder: (context) => LogLevel.values.map((level) {
                  return PopupMenuItem(
                    value: level,
                    child: Row(
                      children: [
                        Container(
                          width: 16,
                          height: 16,
                          decoration: BoxDecoration(
                            color: level.color,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(level.name.toUpperCase()),
                      ],
                    ),
                  );
                }).toList(),
              ),
              if (filteredLogs.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.copy_all),
                  onPressed: () => _copyAllLogs(filteredLogs),
                  tooltip: 'Copy all logs',
                ),
              IconButton(
                icon: const Icon(Icons.clear_all),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('Clear Logs'),
                      content: const Text('Are you sure you want to clear all logs?'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        TextButton(
                          onPressed: () {
                            logService.clear();
                            Navigator.pop(context);
                          },
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                  );
                },
                tooltip: 'Clear all logs',
              ),
            ],
          ),
          body: Column(
            children: [
              // Search bar
              Padding(
                padding: const EdgeInsets.all(16),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search logs...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    border: const OutlineInputBorder(),
                  ),
                  onChanged: (value) => setState(() => _searchQuery = value),
                ),
              ),
              
              // Log statistics
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Showing ${filteredLogs.length} of ${logService.logs.length} logs',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (logService.logs.isNotEmpty)
                      Text(
                        'Latest: ${logService.logs.last.timestamp.toLocal().toString().substring(11, 23)}',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              
              const SizedBox(height: 8),
              
              // Logs list
              Expanded(
                child: filteredLogs.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.assignment,
                              size: 64,
                              color: Colors.grey.withOpacity(0.5),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              logService.logs.isEmpty 
                                  ? 'No logs yet'
                                  : 'No logs match your filter',
                              style: const TextStyle(
                                fontSize: 18,
                                color: Colors.grey,
                              ),
                            ),
                            if (logService.logs.isEmpty)
                              const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'App activities will be logged here',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: filteredLogs.length,
                        itemBuilder: (context, index) {
                          final log = filteredLogs[index];
                          final isLatest = index == 0;

                          return Card(
                            elevation: isLatest ? 3 : 1,
                            margin: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onLongPress: () => _copyLogToClipboard(log),
                              onTap: () => _showLogDetails(context, log),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Log level indicator
                                    Container(
                                      width: 4,
                                      height: 40,
                                      decoration: BoxDecoration(
                                        color: log.level.color,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                    
                                    const SizedBox(width: 12),
                                    
                                    // Log content
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Header: timestamp, module, level
                                          Row(
                                            children: [
                                              Text(
                                                log.timestamp.toLocal().toString().substring(11, 23),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontFamily: 'monospace',
                                                  color: Colors.grey,
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 6,
                                                  vertical: 2,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: log.level.color.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  log.module,
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                    color: log.level.color,
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                log.level.name.toUpperCase(),
                                                style: TextStyle(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.bold,
                                                  color: log.level.color,
                                                ),
                                              ),
                                            ],
                                          ),
                                          
                                          const SizedBox(height: 4),
                                          
                                          // Message
                                          Text(
                                            log.message,
                                            style: const TextStyle(fontSize: 14),
                                          ),
                                        ],
                                      ),
                                    ),
                                    
                                    // Copy button
                                    IconButton(
                                      icon: const Icon(Icons.copy, size: 16),
                                      onPressed: () => _copyLogToClipboard(log),
                                      tooltip: 'Copy log entry',
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showLogDetails(BuildContext context, LogEntry log) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: log.level.color,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            const SizedBox(width: 8),
            Text('${log.module} - ${log.level.name.toUpperCase()}'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Timestamp:',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              Text(log.timestamp.toLocal().toString()),
              const SizedBox(height: 16),
              Text(
                'Message:',
                style: Theme.of(context).textTheme.labelSmall,
              ),
              SelectableText(
                log.message,
                style: const TextStyle(fontFamily: 'monospace'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => _copyLogToClipboard(log),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
}
