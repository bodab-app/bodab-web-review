import 'dart:convert';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'core.dart';

String _stamp(DateTime date) =>
    date.toIso8601String().split('.').first.replaceAll(RegExp('[-:]'), '');

String _text(String text) => text
    .replaceAll(r'\', r'\\')
    .replaceAll(RegExp(r'\r\n|\r|\n'), r'\n')
    .replaceAll(RegExp(r'[\x00-\x08\x0b\x0c\x0e-\x1f\x7f]'), '')
    .replaceAll(';', r'\;')
    .replaceAll(',', r'\,');

String _fold(String line) {
  final result = StringBuffer();
  var bytes = 0;
  for (final rune in line.runes) {
    final char = String.fromCharCode(rune);
    final length = utf8.encode(char).length;
    if (bytes + length > 75) {
      result.write('\r\n ');
      bytes = 1;
    }
    result.write(char);
    bytes += length;
  }
  return result.toString();
}

String bodabCalendarFile(
    {required String id,
    required String title,
    required DateTime startsAt,
    required Set<int> weekdays,
    DateTime? generatedAt}) {
  const names = ['MO', 'TU', 'WE', 'TH', 'FR', 'SA', 'SU'];
  final days = weekdays.where((day) => day >= 1 && day <= 7).toList()..sort();
  final uid = base64Url.encode(utf8.encode(id)).replaceAll('=', '');
  final stamp = '${_stamp((generatedAt ?? DateTime.now()).toUtc())}Z';
  final lines = [
    'BEGIN:VCALENDAR',
    'VERSION:2.0',
    'PRODID:-//Bodab//Calendar//KO',
    'CALSCALE:GREGORIAN'
  ];
  void event(DateTime start, {required bool repeat}) {
    lines.addAll([
      'BEGIN:VEVENT',
      'UID:$uid-${repeat ? "weekly" : "once"}@bodab.invalid',
      'DTSTAMP:$stamp',
      'DTSTART:${_stamp(start)}',
      'SUMMARY:${_text(title)}',
      if (repeat)
        'RRULE:FREQ=WEEKLY;BYDAY=${days.map((day) => names[day - 1]).join(",")}',
      'BEGIN:VALARM',
      'ACTION:DISPLAY',
      'TRIGGER:PT0M',
      'DESCRIPTION:보답 일정',
      'END:VALARM',
      'END:VEVENT',
    ]);
  }

  final start = startsAt.toLocal();
  if (!days.contains(start.weekday)) event(start, repeat: false);
  if (days.isNotEmpty) {
    final offset = List.generate(7, (i) => i)
        .firstWhere((i) => days.contains((start.weekday - 1 + i) % 7 + 1));
    event(
        DateTime(start.year, start.month, start.day + offset, start.hour,
            start.minute),
        repeat: true);
  }
  lines.add('END:VCALENDAR');
  return '${lines.map(_fold).join("\r\n")}\r\n';
}

class BodabCalendarExport extends StatelessWidget {
  const BodabCalendarExport(
      {super.key,
      required this.id,
      required this.title,
      required this.startsAt,
      required this.weekdays});
  final String id, title;
  final DateTime startsAt;
  final Set<int> weekdays;

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb) return const SizedBox.shrink();
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const Caption(
          '저장된 일정의 이름·시간·반복 요일을 캘린더 파일로 받아요. 내 캘린더에서 열어 추가하고 알림을 확인하세요.'),
      const SizedBox(height: 8),
      ReviewButton('캘린더 파일 받기', () async {
        final contents = bodabCalendarFile(
            id: id, title: title, startsAt: startsAt, weekdays: weekdays);
        try {
          const name = '보답-일정.ics';
          await XFile.fromData(Uint8List.fromList(utf8.encode(contents)),
                  name: name, mimeType: 'text/calendar')
              .saveTo(name);
        } catch (_) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('캘린더 파일을 저장하지 못했어요. 다시 시도해 주세요.')));
          }
        }
      }, secondary: true),
    ]);
  }
}
