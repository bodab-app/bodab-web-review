import 'package:flutter/material.dart';

import 'core.dart';
import 'daily.dart';
import 'health_chat_sessions.dart';

/// Local, editable starting contents for an otherwise unused public profile.
void openExampleAccount(ReviewController controller, DateTime now) {
  final local = now.toLocal();
  DateTime day(int offset, [int hour = 0]) =>
      DateTime(local.year, local.month, local.day + offset, hour);

  final daily = DailyModel()
    ..routines.addAll([
      ReviewRoutine('아침 스트레칭', const TimeOfDay(hour: 9, minute: 30), day(-3),
          {1, 2, 3, 4, 5, 6, 7}, true,
          id: 'example-stretch'),
      ReviewRoutine('공원 산책', const TimeOfDay(hour: 14, minute: 0), day(0),
          {1, 3, 5}, true,
          id: 'example-walk'),
      ReviewRoutine('가족과 안부 나누기', const TimeOfDay(hour: 18, minute: 30), day(1),
          {day(1).weekday}, true,
          id: 'example-call'),
    ]);
  final chat = HealthChatSessions.example(day(-1, 16));
  controller.loadExampleAccount([
    ReviewHealthCheck(day(-1), '괜찮아요', '점심을 먹고 공원을 천천히 걸었어요.',
        answers: {CheckinField.activity: '가볍게 걸었어요'}, createdAt: day(-1, 15)),
    ReviewHealthCheck(day(-2), '괜찮아요', '저녁에는 평소보다 일찍 잠들었어요.',
        answers: {CheckinField.meals: '평소처럼 먹었어요'}, createdAt: day(-2, 20)),
  ], [
    daily,
    chat
  ]);
  chat.dispose();
}
