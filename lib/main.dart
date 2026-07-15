import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'daily_tasks_store.dart';
import 'widget_sync_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const AsakaiApp());
}

class AsakaiApp extends StatelessWidget {
  const AsakaiApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ASAKAI',
      debugShowCheckedModeBanner: false,
      theme: _theme(Brightness.light),
      darkTheme: _theme(Brightness.dark),
      themeMode: ThemeMode.system,
      home: const TodayTasksPage(),
    );
  }

  ThemeData _theme(Brightness brightness) {
    const sage = Color(0xFF6E8570);
    final isDark = brightness == Brightness.dark;
    final scheme = ColorScheme(
      brightness: brightness,
      primary: isDark ? const Color(0xFFAABDA8) : sage,
      onPrimary: isDark ? const Color(0xFF172018) : Colors.white,
      secondary: isDark ? const Color(0xFFCFD8C9) : const Color(0xFF566458),
      onSecondary: isDark ? const Color(0xFF1B241C) : Colors.white,
      error: isDark ? const Color(0xFFFFB4AB) : const Color(0xFFBA1A1A),
      onError: isDark ? const Color(0xFF690005) : Colors.white,
      surface: isDark ? const Color(0xFF111410) : const Color(0xFFF9F8F3),
      onSurface: isDark ? const Color(0xFFE4E4DC) : const Color(0xFF1A1C18),
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      textSelectionTheme: TextSelectionThemeData(cursorColor: scheme.primary),
    );
  }
}

class TodayTasksPage extends StatefulWidget {
  const TodayTasksPage({super.key});

  @override
  State<TodayTasksPage> createState() => _TodayTasksPageState();
}

class _TodayTasksPageState extends State<TodayTasksPage>
    with WidgetsBindingObserver {
  final _store = DailyTasksStore();
  final _widgetSync = WidgetSyncService();
  final _controller = TextEditingController();
  Timer? _saveTimer;
  bool _loading = true;
  bool _privacyCover = false;
  bool _saving = false;

  bool get _isJapanese => Localizations.localeOf(context).languageCode == 'ja';
  String get _todayTitle => _isJapanese ? '今日のタスク' : 'Today’s Tasks';
  String get _pastTitle => _isJapanese ? '過去のタスク' : 'Past Tasks';
  String get _prompt =>
      _isJapanese ? '今日は何をする？' : 'What are you planning today?';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  Future<void> _initialize() async {
    await _widgetSync.initialize();
    final today = await _store.loadToday();
    if (!mounted) return;
    _controller.text = today;
    await _syncWidget(today);
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final covered =
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused;
    if (mounted && _privacyCover != covered) {
      setState(() => _privacyCover = covered);
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _saveNow();
    }
    if (state == AppLifecycleState.resumed) {
      _reloadForCurrentDay();
    }
  }

  Future<void> _reloadForCurrentDay() async {
    final today = await _store.loadToday();
    if (!mounted || _saving) return;
    if (today != _controller.text) {
      _controller.value = TextEditingValue(
        text: today,
        selection: TextSelection.collapsed(offset: today.length),
      );
    }
    await _syncWidget(today);
  }

  void _scheduleSave(String _) {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), _saveNow);
  }

  Future<void> _saveNow() async {
    _saveTimer?.cancel();
    if (_saving || _loading) return;
    _saving = true;
    try {
      await _store.saveToday(_controller.text);
      await _syncWidget(_controller.text);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _isJapanese ? '保存できませんでした。' : 'Couldn’t save your tasks.',
            ),
            action: SnackBarAction(
              label: _isJapanese ? '再試行' : 'Retry',
              onPressed: _saveNow,
            ),
          ),
        );
      }
    } finally {
      _saving = false;
    }
  }

  Future<void> _syncWidget(String text) {
    return _widgetSync.sync(
      text: text,
      locale: Localizations.localeOf(context),
    );
  }

  Future<void> _openPastTasks() async {
    await _saveNow();
    if (!mounted) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => PastTasksPage(store: _store)),
    );
    await _reloadForCurrentDay();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    _controller.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: SizedBox.expand());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_todayTitle),
        actions: [
          Semantics(
            button: true,
            label: _pastTitle,
            child: TextButton(
              onPressed: _openPastTasks,
              child: Text(_pastTitle),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
                child: Semantics(
                  textField: true,
                  label: _prompt,
                  child: TextField(
                    controller: _controller,
                    onChanged: _scheduleSave,
                    autofocus: false,
                    expands: true,
                    maxLines: null,
                    minLines: null,
                    keyboardType: TextInputType.multiline,
                    textAlignVertical: TextAlignVertical.top,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyLarge?.copyWith(height: 1.6),
                    decoration: InputDecoration(
                      hintText: _prompt,
                      hintStyle: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_privacyCover)
            Positioned.fill(
              child: ColoredBox(color: Theme.of(context).colorScheme.surface),
            ),
        ],
      ),
    );
  }
}

class PastTasksPage extends StatefulWidget {
  const PastTasksPage({required this.store, super.key});

  final DailyTasksStore store;

  @override
  State<PastTasksPage> createState() => _PastTasksPageState();
}

class _PastTasksPageState extends State<PastTasksPage> {
  late Future<List<DailyTaskEntry>> _entries;

  @override
  void initState() {
    super.initState();
    _entries = widget.store.loadHistory();
  }

  @override
  Widget build(BuildContext context) {
    final isJapanese = Localizations.localeOf(context).languageCode == 'ja';
    final locale = isJapanese ? 'ja_JP' : 'en_US';
    final todayKey = DailyTasksStore.dateKey(DateTime.now());
    return Scaffold(
      appBar: AppBar(title: Text(isJapanese ? '過去のタスク' : 'Past Tasks')),
      body: FutureBuilder<List<DailyTaskEntry>>(
        future: _entries,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const SizedBox.expand();
          final entries =
              snapshot.data!
                  .where((entry) => entry.dateKey != todayKey)
                  .toList();
          if (entries.isEmpty) {
            return Center(
              child: Text(isJapanese ? 'まだ過去のタスクはありません' : 'No past tasks yet.'),
            );
          }
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 720),
              child: ListView.separated(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                itemCount: entries.length,
                separatorBuilder: (_, __) => const SizedBox(height: 28),
                itemBuilder: (context, index) {
                  final entry = entries[index];
                  final date = DateTime.parse(entry.dateKey);
                  final label = DateFormat.yMMMMd(locale).format(date);
                  return Semantics(
                    header: true,
                    label: label,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          label,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        SelectableText(
                          entry.text,
                          style: Theme.of(
                            context,
                          ).textTheme.bodyLarge?.copyWith(height: 1.6),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          );
        },
      ),
    );
  }
}
