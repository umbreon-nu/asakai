import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import 'daily_tasks_store.dart';

class WidgetSyncService {
  static const appGroupId = 'group.com.asakai.asakai';
  static const _dateKey = 'asakai_widget_date';
  static const _linesKey = 'asakai_widget_lines';
  static const _titleKey = 'asakai_widget_title';
  static const _promptKey = 'asakai_widget_prompt';

  Future<void> initialize() async {
    if (Platform.isIOS) {
      await HomeWidget.setAppGroupId(appGroupId);
    }
  }

  Future<void> sync({
    required String text,
    required Locale locale,
    DateTime? now,
  }) async {
    final isJapanese = locale.languageCode.toLowerCase() == 'ja';
    final logicalLines = text.split(RegExp(r'\r?\n'));
    final visibleLines = logicalLines.take(6).toList();
    if (logicalLines.length > 6 && visibleLines.isNotEmpty) {
      visibleLines[visibleLines.length - 1] = '${visibleLines.last} …';
    }

    await Future.wait(<Future<dynamic>>[
      HomeWidget.saveWidgetData<String>(
        _dateKey,
        DailyTasksStore.dateKey(now ?? DateTime.now()),
      ),
      HomeWidget.saveWidgetData<String>(_linesKey, visibleLines.join('\n')),
      HomeWidget.saveWidgetData<String>(
        _titleKey,
        isJapanese ? '今日のタスク' : 'Today’s Tasks',
      ),
      HomeWidget.saveWidgetData<String>(
        _promptKey,
        isJapanese ? '今日は何をする？' : 'What are you planning today?',
      ),
    ]);

    if (Platform.isAndroid) {
      await HomeWidget.updateWidget(
        qualifiedAndroidName: 'com.asakai.asakai.AsakaiWidgetProvider',
      );
    } else if (Platform.isIOS) {
      await HomeWidget.updateWidget(iOSName: 'AsakaiWidget');
    }
  }
}
