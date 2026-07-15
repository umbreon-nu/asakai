import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:asakai/daily_tasks_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  late Map<String, dynamic> values;

  setUp(() {
    values = <String, dynamic>{};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          final arguments = Map<String, dynamic>.from(call.arguments as Map);
          switch (call.method) {
            case 'getWidgetData':
              return values[arguments['id']] ?? arguments['defaultValue'];
            case 'saveWidgetData':
              values[arguments['id'] as String] = arguments['data'];
              return true;
            case 'updateWidget':
              return true;
            default:
              return null;
          }
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('saves plain multiline text for the local day', () async {
    final store = DailyTasksStore();
    final now = DateTime(2026, 7, 15, 9);

    await store.saveToday('Write proposal\nCall Aya', now: now);

    expect(await store.loadToday(now: now), 'Write proposal\nCall Aya');
  });

  test('does not keep whitespace-only days', () async {
    final store = DailyTasksStore();
    final now = DateTime(2026, 7, 15, 9);

    await store.saveToday('One task', now: now);
    await store.saveToday('  \n ', now: now);

    expect(await store.loadToday(now: now), isEmpty);
    expect(await store.loadHistory(now: now), isEmpty);
  });

  test('keeps the newest 30 calendar days only', () async {
    final store = DailyTasksStore();
    final today = DateTime(2026, 7, 31, 9);

    await store.saveToday('Keep me', now: DateTime(2026, 7, 2, 9));
    await store.saveToday('Delete me', now: DateTime(2026, 7, 1, 9));

    final history = await store.loadHistory(now: today);

    expect(history.map((entry) => entry.dateKey), ['2026-07-02']);
  });
}
