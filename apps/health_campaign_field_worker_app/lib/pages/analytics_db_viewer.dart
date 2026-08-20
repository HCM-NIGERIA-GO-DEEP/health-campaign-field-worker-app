import 'dart:convert';

import 'package:digit_analytics/digit_analytics.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

/// Local inspector for the `AnalyticsEvent` Isar collection. `digit_analytics`
/// persists events in its own Isar store, separate from the app's Drift
/// database, so they never show up in the `DriftDbViewer` ("DB" home tile) —
/// this screen fills that gap for analytics events specifically.
class AnalyticsDbViewer extends StatefulWidget {
  const AnalyticsDbViewer({super.key});

  @override
  State<AnalyticsDbViewer> createState() => _AnalyticsDbViewerState();
}

class _AnalyticsDbViewerState extends State<AnalyticsDbViewer> {
  late Future<List<AnalyticsEvent>> _eventsFuture;

  @override
  void initState() {
    super.initState();
    _eventsFuture = _loadEvents();
  }

  Future<List<AnalyticsEvent>> _loadEvents() {
    final isar = AnalyticsSingleton().queueManager?.isar;
    if (isar == null) return Future.value(const []);

    return isar.analyticsEvents.where().sortByCreatedAtDesc().findAll();
  }

  Future<void> _refresh() async {
    final events = await _loadEvents();
    if (!mounted) return;
    setState(() {
      _eventsFuture = Future.value(events);
    });
  }

  Future<void> _deleteEvent(AnalyticsEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteEventDialog(event: event),
    );
    if (confirmed != true) return;

    await AnalyticsSingleton().queueManager?.deleteEvent(event.id);
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted "${event.name}"')),
    );
  }

  Future<void> _deleteAll(List<AnalyticsEvent> events) async {
    if (events.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _DeleteAllDialog(events: events),
    );
    if (confirmed != true) return;

    await AnalyticsSingleton().queueManager?.deleteAll();
    if (!mounted) return;
    await _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Deleted ${events.length} events')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F5),
      appBar: AppBar(
        title: const Text('Analytics Events'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
          ),
          FutureBuilder<List<AnalyticsEvent>>(
            future: _eventsFuture,
            builder: (context, snapshot) {
              final count = snapshot.data?.length ?? 0;
              return IconButton(
                tooltip: 'Clear all',
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed:
                    count == 0 ? null : () => _deleteAll(snapshot.data!),
              );
            },
          ),
        ],
      ),
      body: FutureBuilder<List<AnalyticsEvent>>(
        future: _eventsFuture,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final events = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: Column(
              children: [
                _SummaryBar(events: events),
                Expanded(
                  child: events.isEmpty
                      ? ListView(
                          children: const [
                            Padding(
                              padding: EdgeInsets.only(top: 120),
                              child: Center(
                                child: Text('No analytics events queued yet.'),
                              ),
                            ),
                          ],
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                          itemCount: events.length,
                          itemBuilder: (context, index) => _AnalyticsEventTile(
                            event: events[index],
                            onDelete: () => _deleteEvent(events[index]),
                          ),
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.events});

  final List<AnalyticsEvent> events;

  @override
  Widget build(BuildContext context) {
    final pending =
        events.where((e) => !e.syncedUp && !e.nonRecoverableError).length;
    final synced = events.where((e) => e.syncedUp).length;
    final failed = events.where((e) => e.nonRecoverableError).length;

    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          _StatChip(label: 'Total', count: events.length, color: Colors.blueGrey),
          _StatChip(label: 'Pending', count: pending, color: Colors.orange),
          _StatChip(label: 'Synced', count: synced, color: Colors.green),
          _StatChip(label: 'Failed', count: failed, color: Colors.red),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.label,
    required this.count,
    required this.color,
  });

  final String label;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Chip(
      backgroundColor: color.withOpacity(0.12),
      side: BorderSide(color: color.withOpacity(0.4)),
      label: Text(
        '$label: $count',
        style: TextStyle(color: color, fontWeight: FontWeight.w600),
      ),
      visualDensity: VisualDensity.compact,
    );
  }
}

class _AnalyticsEventTile extends StatefulWidget {
  const _AnalyticsEventTile({required this.event, required this.onDelete});

  final AnalyticsEvent event;
  final VoidCallback onDelete;

  @override
  State<_AnalyticsEventTile> createState() => _AnalyticsEventTileState();
}

class _AnalyticsEventTileState extends State<_AnalyticsEventTile> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final event = widget.event;
    final statusLabel = event.nonRecoverableError
        ? 'failed'
        : event.syncedUp
            ? 'synced'
            : 'pending';
    final statusColor = event.nonRecoverableError
        ? Colors.red
        : event.syncedUp
            ? Colors.green
            : Colors.orange;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      child: Column(
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          event.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${event.occurredAt} • $statusLabel'
                          '${event.retryCount > 0 ? ' • retries: ${event.retryCount}' : ''}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: widget.onDelete,
                  ),
                  Icon(_expanded ? Icons.expand_less : Icons.expand_more),
                ],
              ),
            ),
          ),
          if (_expanded) _AnalyticsEventDetails(event: event),
        ],
      ),
    );
  }
}

class _AnalyticsEventDetails extends StatelessWidget {
  const _AnalyticsEventDetails({required this.event});

  final AnalyticsEvent event;

  @override
  Widget build(BuildContext context) {
    final params = jsonDecode(event.paramsJson) as Map<String, dynamic>;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          _row('id', event.id.toString()),
          _row('userId', event.userId ?? '-'),
          _row('createdAt', event.createdAt.toString()),
          _row('syncedUpOn', event.syncedUpOn?.toString() ?? '-'),
          const SizedBox(height: 8),
          const Text('params', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(6),
            ),
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(params),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Text('$label: $value'),
      );
}

/// Icon-in-circle + bold title row shared by both delete dialogs.
class _DialogHeader extends StatelessWidget {
  const _DialogHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.delete_outline, color: Colors.red),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 17),
          ),
        ),
      ],
    );
  }
}

class _WarningCallout extends StatelessWidget {
  const _WarningCallout({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.orange.withOpacity(0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Colors.orange, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, style: const TextStyle(fontSize: 12.5)),
          ),
        ],
      ),
    );
  }
}

class _DeleteEventDialog extends StatelessWidget {
  const _DeleteEventDialog({required this.event});

  final AnalyticsEvent event;

  @override
  Widget build(BuildContext context) {
    final isPending = !event.syncedUp && !event.nonRecoverableError;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const _DialogHeader(title: 'Delete this event?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              style: DefaultTextStyle.of(context).style,
              children: [
                const TextSpan(text: 'This removes '),
                TextSpan(
                  text: '"${event.name}"',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(
                  text: ' from the local queue. This cannot be undone.',
                ),
              ],
            ),
          ),
          if (isPending) ...[
            const SizedBox(height: 12),
            const _WarningCallout(
              text: 'This event has not synced to the analytics backend '
                  'yet — deleting it now means it will never be sent.',
            ),
          ],
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Delete'),
        ),
      ],
    );
  }
}

class _DeleteAllDialog extends StatefulWidget {
  const _DeleteAllDialog({required this.events});

  final List<AnalyticsEvent> events;

  @override
  State<_DeleteAllDialog> createState() => _DeleteAllDialogState();
}

class _DeleteAllDialogState extends State<_DeleteAllDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    final events = widget.events;
    final pending =
        events.where((e) => !e.syncedUp && !e.nonRecoverableError).length;
    final synced = events.where((e) => e.syncedUp).length;
    final failed = events.where((e) => e.nonRecoverableError).length;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: _DialogHeader(title: 'Clear all ${events.length} events?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'This permanently deletes every queued analytics event on '
            'this device. This cannot be undone.',
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatChip(label: 'Pending', count: pending, color: Colors.orange),
              _StatChip(label: 'Synced', count: synced, color: Colors.green),
              _StatChip(label: 'Failed', count: failed, color: Colors.red),
            ],
          ),
          if (pending > 0) ...[
            const SizedBox(height: 12),
            _WarningCallout(
              text: '$pending event${pending == 1 ? '' : 's'} '
                  '${pending == 1 ? 'has' : 'have'} not synced to the '
                  'analytics backend yet. Deleting now means '
                  '${pending == 1 ? 'it' : 'they'} will never be sent.',
            ),
          ],
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _acknowledged,
            onChanged: (value) =>
                setState(() => _acknowledged = value ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            dense: true,
            title: const Text(
              'I understand this action is permanent',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ],
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed:
              _acknowledged ? () => Navigator.of(context).pop(true) : null,
          child: const Text('Delete all'),
        ),
      ],
    );
  }
}
