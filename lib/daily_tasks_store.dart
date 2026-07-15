import 'dart:convert';

import 'package:home_widget/home_widget.dart';

class DailyTaskEntry {
  const DailyTaskEntry({required this.dateKey, required this.text});

  final String dateKey;
  final String text;
}

/// Stores the complete, local-only history in the same shared container used by
/// the native home-screen widgets.
class DailyTasksStore {
  static const _entriesKey = 'asakai_entries';

  Future<List<DailyTaskEntry>> loadHistory({DateTime? now}) async {
    final entries = await _readEntries();
    final changed = _purgeExpired(entries, now ?? DateTime.now());
    if (changed) {
      await _writeEntries(entries);
    }
    return _asEntries(entries);
  }

  Future<String> loadToday({DateTime? now}) async {
    final date = now ?? DateTime.now();
    final entries = await _readEntries();
    final changed = _purgeExpired(entries, date);
    if (changed) {
      await _writeEntries(entries);
    }
    return entries[_dateKey(date)] ?? '';
  }

  Future<List<DailyTaskEntry>> saveToday(String text, {DateTime? now}) async {
    final date = now ?? DateTime.now();
    final entries = await _readEntries();
    _purgeExpired(entries, date);

    final key = _dateKey(date);
    if (text.trim().isEmpty) {
      entries.remove(key);
    } else {
      entries[key] = text;
    }

    await _writeEntries(entries);
    return _asEntries(entries);
  }

  Future<List<DailyTaskEntry>> purgeExpired({DateTime? now}) async {
    final entries = await _readEntries();
    if (_purgeExpired(entries, now ?? DateTime.now())) {
      await _writeEntries(entries);
    }
    return _asEntries(entries);
  }

  Future<Map<String, String>> _readEntries() async {
    final raw = await HomeWidget.getWidgetData<String>(
      _entriesKey,
      defaultValue: '{}',
    );
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }

    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return <String, String>{};
      }
      return decoded.map(
        (key, value) =>
            MapEntry(key, value is String ? value : value.toString()),
      );
    } on FormatException {
      return <String, String>{};
    }
  }

  Future<void> _writeEntries(Map<String, String> entries) async {
    await HomeWidget.saveWidgetData<String>(_entriesKey, jsonEncode(entries));
  }

  static List<DailyTaskEntry> _asEntries(Map<String, String> entries) {
    final result =
        entries.entries
            .where((entry) => entry.value.trim().isNotEmpty)
            .map(
              (entry) => DailyTaskEntry(dateKey: entry.key, text: entry.value),
            )
            .toList()
          ..sort((a, b) => b.dateKey.compareTo(a.dateKey));
    return result;
  }

  static bool _purgeExpired(Map<String, String> entries, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    final expired =
        entries.keys.where((key) {
          final date = _parseDateKey(key);
          return date == null || today.difference(date).inDays >= 30;
        }).toList();
    for (final key in expired) {
      entries.remove(key);
    }
    return expired.isNotEmpty;
  }

  static String dateKey(DateTime date) => _dateKey(date);

  static String _dateKey(DateTime date) {
    return '${date.year.toString().padLeft(4, '0')}-'
        '${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }

  static DateTime? _parseDateKey(String key) {
    final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(key);
    if (match == null) {
      return null;
    }
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }
}
