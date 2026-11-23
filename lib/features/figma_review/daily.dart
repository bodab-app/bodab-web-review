import 'dart:math';

import 'package:flutter/material.dart';

import '../../presentation/widgets/branding/funding_acknowledgement.dart';
import 'core.dart';
import 'petbot_card.dart';
import 'screens.dart' show healthChatRoute;
import 'device_settings.dart';
import 'calendar_export.dart';
import 'health.dart' show openHealthUpload, openAllHealthRecords;

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];
const _well = '괜찮아요';
const _unwell = '조금 불편해요';
DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
String _shortDate(DateTime d) => '${d.month}월 ${d.day}일';
String _longDate(DateTime d) =>
    '${_shortDate(d)} ${_weekdays[d.weekday - 1]}요일';

class ReviewRoutine {
  ReviewRoutine(this.name, this.time, this.date, this.weekdays, this.reminder,
      {String? id})
      : id = id ??
            '${DateTime.now().microsecondsSinceEpoch}-${Random.secure().nextInt(0x7fffffff)}';
  final String id, name;
  final TimeOfDay time;
  final DateTime date;
  final Set<int> weekdays;
  final bool reminder;
  bool occurs(DateTime day) =>
      !day.isBefore(date) && (day == date || weekdays.contains(day.weekday));
  Map<String, Object?> toJson() => {
        'name': name,
        'date': date.toIso8601String(),
        'minute': time.hour * 60 + time.minute,
        'days': weekdays.toList()..sort(),
        'showOnHome': reminder
      };

  static ReviewRoutine? read(String id, Object? value) {
    if (value is! Map ||
        value['name'] is! String ||
        value['date'] is! String ||
        value['minute'] is! int) {
      return null;
    }
    final minute = value['minute'] as int;
    final date = DateTime.tryParse(value['date'] as String);
    final name = (value['name'] as String).trim();
    if (id.isEmpty ||
        name.isEmpty ||
        date == null ||
        minute < 0 ||
        minute >= 1440) {
      return null;
    }
    final days = value['days'];
    return ReviewRoutine(
        name,
        TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
        _day(date),
        days is List
            ? days.whereType<int>().where((d) => d >= 1 && d <= 7).toSet()
            : {},
        value['showOnHome'] != false,
        id: id);
  }
}

class DailyModel implements ReviewSavedModel {
  DailyModel({DateTime Function()? clock}) : _clock = clock ?? DateTime.now {
    _selected = _lastToday = today;
    draftDate = today;
  }
  final DateTime Function() _clock;
  DateTime get today => _day(_clock().toLocal());
  late DateTime _selected, _lastToday, draftDate;
  DateTime get selected {
    final now = today;
    if (_lastToday != now && _selected == _lastToday) _selected = now;
    _lastToday = now;
    return _selected;
  }

  set selected(DateTime value) {
    _lastToday = today;
    _selected = _day(value);
  }

  final routines = <ReviewRoutine>[];
  String title = '';
  TimeOfDay time = const TimeOfDay(hour: 14, minute: 0);
  Set<int> weekdays = {};
  bool wantsReminder = true;
  ReviewRoutine? editing;
  int routineVisit = 0;
  bool localAlerts = true;
  String? choice;
  String memo = '';
  final checkinAnswers = <CheckinField, String>{};
  DateTime? savedDay, draftDay;

  @override
  String get storageKey => 'daily';
  @override
  Map<String, Object?> exportSavedState() => {
        'pref:showOnHome': localAlerts,
        for (final r in routines) 'routine:${r.id}': r.toJson(),
      };
  @override
  void restoreSavedState(Map<String, Object?> data) {
    localAlerts = data['pref:showOnHome'] != false;
    routines.clear();
    for (final e in data.entries.where((e) => e.key.startsWith('routine:'))) {
      final r = ReviewRoutine.read(e.key.substring(8), e.value);
      if (r != null) routines.add(r);
    }
  }

  List<ReviewRoutine> forDay(DateTime day) =>
      routines.where((r) => r.occurs(day)).toList()
        ..sort((a, b) => (a.time.hour * 60 + a.time.minute)
            .compareTo(b.time.hour * 60 + b.time.minute));

  void beginRoutine([ReviewRoutine? previous]) {
    routineVisit++;
    editing = previous;
    title = previous?.name ?? '';
    time = previous?.time ?? const TimeOfDay(hour: 14, minute: 0);
    weekdays = {...?previous?.weekdays};
    draftDate = previous?.date ?? selected;
    wantsReminder = previous?.reminder ?? true;
  }

  void saveRoutine() {
    final previous = editing;
    final next = ReviewRoutine(title.trim(), time, draftDate,
        Set.unmodifiable(weekdays), wantsReminder,
        id: previous?.id);
    if (previous == null) {
      routines.add(next);
    } else {
      final i = routines.indexWhere((r) => r.id == previous.id);
      if (i >= 0) routines[i] = next;
    }
    selected = draftDate;
    editing = null;
  }

  String get checkinMemoHint {
    final latest = checkinAnswers.entries.lastOrNull;
    return switch (latest?.key) {
      CheckinField.sleep => switch (latest!.value) {
          '자주 깼어요' => '예: 새벽 3시와 5시쯤 두 번 깼어요',
          '잠들기 어려웠어요' => '예: 밤 11시에 누워 한 시간쯤 뒤 잠들었어요',
          _ => '예: 밤 10시에 잠들어 아침 7시에 일어났어요',
        },
      CheckinField.meals => latest!.value == '끼니를 걸렀어요'
          ? '예: 외출하느라 점심을 걸렀어요'
          : '예: 아침에는 밥을 반 공기 먹었어요',
      CheckinField.activity => switch (latest!.value) {
          '가볍게 걸었어요' => '예: 점심 뒤 공원을 15분 걸었어요',
          '집안일을 했어요' => '예: 오전에 집을 20분 청소했어요',
          _ => '예: 오후에는 집에서 쉬었어요',
        },
      CheckinField.location ||
      CheckinField.onset =>
        '예: 아침에 일어날 때 불편했고 10분쯤 이어졌어요',
      null => '예: 오늘 평소와 달랐던 일이나 몸의 느낌',
    };
  }

  void beginCheckin(DateTime day, ReviewHealthCheck? record) {
    draftDay = day;
    choice = record?.condition;
    memo = record?.memo ?? '';
    checkinAnswers
      ..clear()
      ..addAll(record?.answers ?? const {});
  }
}

DailyModel _daily(ReviewController c) => c.model(() => DailyModel());

void openSavedCheckin(ReviewController c, ReviewHealthCheck record) {
  _daily(c).beginCheckin(record.day, record);
  c.go('checkin_review');
}

void startTodayCheckin(ReviewController c) {
  final m = _daily(c);
  final day = m.today;
  m.beginCheckin(day, c.checkinFor(day));
  c.go('checkin');
}

Widget buildDailyScreen(String key, ReviewController c) {
  final m = _daily(c);
  void startCheckin() => startTodayCheckin(c);

  switch (key) {
    case 'login':
      return ReviewPage(title: '보답', branded: true, actions: [
        ReviewButton('오늘 홈으로', () => c.resetTo('home')),
        ReviewButton('오류 화면 보기', () => c.go('login_error'), secondary: true),
      ], children: const [
        _DailyBadge('heart'),
        Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Lead('나를 챙기는\n작은 습관, 보답'),
              SizedBox(height: 20),
              Caption('일정부터 건강 기록까지\n편안하게 시작해요.'),
            ])),
        _DesignField('휴대전화 번호'),
        _DesignField('인증번호'),
      ]);
    case 'login_error':
      return ReviewPage(title: '인증번호 확인', actions: [
        ReviewButton('오늘 홈으로', () => c.resetTo('home')),
        ReviewButton('로그인 디자인 보기', () => c.go('login'), secondary: true),
      ], children: const [
        _DailyBadge('info', error: true),
        Lead('번호를 다시 확인해 주세요'),
        _DesignField('인증번호'),
      ]);
    case 'home':
      return ReviewPage(title: '보답', branded: true, tab: 'home', children: [
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Caption(c.isExampleAccount
              ? '${_longDate(m.today)} · 예시 계정'
              : _longDate(m.today)),
          const SizedBox(height: 6),
          const Lead('오늘도, 편안하게'),
        ]),
        Padding(
            padding: const EdgeInsets.only(top: 6, bottom: 8),
            child: _HomeHealthCard(
                record: c.checkinFor(m.today), onTap: startCheckin)),
        PetbotCard(onTap: () => c.go(healthChatRoute)),
        Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionLabel('오늘 챙길 일'),
          const SizedBox(height: 10),
          if (m.localAlerts)
            for (final r in m.forDay(m.today).where((r) => r.reminder))
              ReviewRow(
                  title: '${_timeLabel(r.time)} · ${r.name}',
                  icon: 'calendar',
                  onTap: () {
                    m.beginRoutine(r);
                    c.go('routine');
                  }),
          ReviewRow(
              title: '일정 보기',
              detail: '${m.forDay(m.today).length}개의 일정',
              icon: 'calendar',
              onTap: () {
                m.selected = m.today;
                c.go('schedule');
              }),
          ReviewRow(
              title: '나의 복약',
              detail: '등록한 약과 복용 기록 보기',
              icon: 'pill',
              onTap: () => c.go('medications')),
        ]),
        LayoutBuilder(builder: (context, box) {
          final actions = [
            _HomeAction('upload', '자료 올리기', () => openHealthUpload(c)),
            _HomeAction('family', '가족 공유', () => c.go('family')),
          ];
          final vertical = MediaQuery.textScalerOf(context).scale(20) >= 36 ||
              box.maxWidth < 250;
          return vertical
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                      actions[0],
                      const SizedBox(height: 12),
                      actions[1],
                    ])
              : Row(children: [
                  Expanded(child: actions[0]),
                  const SizedBox(width: 8),
                  Expanded(child: actions[1])
                ]);
        }),
      ]);
    case 'profile':
      return ReviewPage(title: '보답', branded: true, tab: 'profile', children: [
        const ReviewCard(
            tinted: true,
            child: Row(children: [
              ReviewIcon('profile'),
              SizedBox(width: 12),
              Expanded(child: Lead('나의 보답', detail: '내 정보와 연결을 관리해요.')),
            ])),
        const SectionLabel('연결과 공유'),
        ReviewRow(
            title: '가족 연결',
            detail: '가족에게 전달할 기록 준비',
            icon: 'family',
            onTap: () => c.go('family')),
        ReviewRow(
            title: '가족 전달 내역',
            detail: '이 기기에서 선택한 전달 방법과 일시',
            icon: 'shield',
            onTap: () => c.go('history')),
        const SectionLabel('도움이 필요할 때'),
        ReviewRow(
            title: '기관 돌봄 요청',
            detail: '돌봄 상담 내용을 정리해 기관에 전달',
            icon: 'institution',
            onTap: () => c.go('care_select')),
        ReviewRow(
            title: '일정 표시 설정',
            detail: '오늘 홈에 표시할 일정 관리',
            icon: 'bell',
            onTap: () => c.go('notification')),
        const BodabDeviceSettings(),
        const FundingAcknowledgement(),
      ]);
    case 'schedule':
      return _schedule(c, m);
    case 'routine':
      return _routine(c, m);
    case 'notification':
    case 'notification_done':
      return ReviewPage(title: '일정 표시 설정', backTo: 'schedule', actions: [
        ReviewButton('일정으로 돌아가기', () => c.go('schedule')),
      ], children: [
        const Lead('오늘 홈에서 일정 보기', detail: '홈에 표시하도록 선택한 일정을 시간순으로 보여줘요.'),
        SwitchListTile(
            title: const Text('오늘 홈에 일정 표시'),
            value: m.localAlerts,
            onChanged: (v) => c.update(() => m.localAlerts = v)),
        const Caption(
            '기기 알림이 필요하면 저장한 일정을 열고 캘린더로 가져오세요. 알림 시간은 캘린더 앱에서 확인할 수 있어요.'),
      ]);
    case 'checkin':
      void choose([String? condition]) {
        if (m.draftDay == null) {
          final today = m.today;
          m.beginCheckin(today, c.checkinFor(today));
        }
        m.choice = condition ?? m.choice ?? '';
        c.go('checkin_review');
      }
      return ReviewPage(title: '오늘의 건강 체크', backTo: 'home', actions: [
        ReviewButton('답하지 않고 돌아가기', () => c.go('home'), secondary: true),
      ], children: [
        const _Progress(false),
        const Lead('지금 몸 상태는\n어떠세요?',
            detail: '지금 느낌을 고르거나 수면·식사·활동부터 기록해 보세요.'),
        ReviewRow(
            title: _well,
            detail: '편안하게 지내고 있어요.',
            icon: 'smile',
            onTap: () => choose(_well)),
        ReviewRow(
            title: _unwell,
            detail: '지금 느끼는 상태를 남겨요.',
            icon: 'heart',
            onTap: () => choose(_unwell)),
        ReviewButton('생활 질문부터 보기', choose, secondary: true),
      ]);
    case 'checkin_review':
      final previous = m.draftDay == null ? null : c.checkinFor(m.draftDay!);
      final answer = m.choice;
      if (answer == null) {
        return ReviewPage(
            title: '건강 체크',
            actions: [ReviewButton('건강 체크 시작하기', startCheckin)],
            children: const [Lead('먼저 몸 상태를 선택해 주세요')]);
      }
      final canSave = answer.isNotEmpty ||
          m.memo.trim().isNotEmpty ||
          m.checkinAnswers.isNotEmpty;
      return ReviewPage(title: '기록 전 확인', backTo: 'checkin', actions: [
        ReviewButton(
            '이대로 기록하기',
            canSave
                ? () {
                    m.savedDay = m.draftDay ?? m.today;
                    c.saveCheckin(m.savedDay!, answer, m.memo,
                        answers: m.checkinAnswers);
                    c.go('checkin_done');
                  }
                : null),
        ReviewButton('답변 수정하기', () => c.go('checkin'), secondary: true),
        if (previous != null)
          Builder(
              builder: (context) => ReviewButton('체크인 삭제', () async {
                    if (await _confirmDelete(context, '이 날짜의 건강 체크를 삭제할까요?') &&
                        context.mounted) {
                      c.removeRecord(previous.id);
                      m.beginCheckin(m.today, null);
                      m.savedDay = null;
                      openAllHealthRecords(c);
                    }
                  }, secondary: true)),
      ], children: [
        const _Progress(true),
        SectionLabel(m.draftDay == null || m.draftDay == m.today
            ? '오늘의 상태를 확인해요'
            : '${_shortDate(m.draftDay!)}의 상태를 확인해요'),
        if (answer.isNotEmpty)
          ReviewCard(tinted: true, child: _DataLine('몸 상태', answer)),
        _DailyQuestions(
            key: ValueKey(m.draftDay),
            answers: m.checkinAnswers,
            onSelect: (field, value) => c.update(() {
                  if (m.checkinAnswers[field] == value) {
                    m.checkinAnswers.remove(field);
                  } else {
                    m.checkinAnswers.remove(field);
                    m.checkinAnswers[field] = value;
                  }
                })),
        ReviewField(
            label: '추가 메모',
            value: m.memo,
            hint: m.checkinMemoHint,
            onChanged: (v) {
              final wasEmpty = m.memo.trim().isEmpty;
              m.memo = v;
              if (wasEmpty != v.trim().isEmpty &&
                  answer.isEmpty &&
                  m.checkinAnswers.isEmpty) {
                c.update(() {});
              }
            }),
      ]);
    case 'checkin_done':
      final saved = m.savedDay == null ? null : c.checkinFor(m.savedDay!);
      if (saved == null) {
        return ReviewPage(
            title: '건강 체크',
            actions: [ReviewButton('건강 체크 시작하기', startCheckin)],
            children: const [Lead('저장한 체크인이 없어요')]);
      }
      return ReviewPage(title: '오늘의 건강 체크', backTo: 'home', actions: [
        ReviewButton('내 기록 확인하기', () => openAllHealthRecords(c)),
        ReviewButton('오늘로 돌아가기', () => c.go('home'), secondary: true),
      ], children: [
        const _DailyBadge('check'),
        Lead(
            saved.day == m.today
                ? '오늘의 상태를 남겼어요'
                : '${_shortDate(saved.day)}의 상태를 남겼어요',
            detail: '하루의 변화를 차근차근 돌아볼 수 있어요.'),
        ReviewCard(
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
              _DataLine('기록일', _shortDate(saved.day)),
              const Divider(),
              if (saved.condition.isNotEmpty) _DataLine('컨디션', saved.condition),
              for (final field in CheckinField.values)
                if (saved.answers.containsKey(field))
                  _DataLine(field.label, saved.answers[field]!),
              if (saved.memo.isNotEmpty) _DataLine('메모', saved.memo),
            ])),
      ]);
    default:
      throw ArgumentError.value(key, 'key', '지원하지 않는 보답 일상 화면');
  }
}

Future<DateTime?> _chooseDay(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(min(initial.year, 1900)),
      lastDate: DateTime(max(initial.year, DateTime.now().year + 10), 12, 31),
      helpText: '일정 날짜',
      cancelText: '취소',
      confirmText: '선택',
    );
Future<bool> _confirmDelete(BuildContext context, String prompt) async =>
    await showDialog<bool>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (dialog) => AlertDialog(title: Text(prompt), actions: [
              TextButton(
                  onPressed: () => Navigator.pop(dialog, false),
                  child: const Text('취소')),
              TextButton(
                  onPressed: () => Navigator.pop(dialog, true),
                  child: const Text('삭제')),
            ])) ??
    false;

String _timeLabel(TimeOfDay value) =>
    '${value.hour < 12 ? '오전' : '오후'} ${value.hourOfPeriod == 0 ? 12 : value.hourOfPeriod}:${value.minute.toString().padLeft(2, '0')}';

Widget _schedule(ReviewController c, DailyModel m) {
  final selected = m.selected;
  final monday = DateTime(
      selected.year, selected.month, selected.day - (selected.weekday - 1));
  final entries = m.forDay(selected);
  void routine([ReviewRoutine? previous]) {
    m.beginRoutine(previous);
    c.go('routine');
  }

  return ReviewPage(title: '보답', branded: true, tab: 'schedule', children: [
    Lead('나의 일정', detail: c.isExampleAccount ? '예시 계정' : null),
    Builder(
        builder: (context) => ReviewRow(
            title: '날짜 선택',
            detail: _longDate(selected),
            icon: 'calendar',
            onTap: () async {
              final value = await _chooseDay(context, selected);
              if (value != null && context.mounted) {
                c.update(() => m.selected = value);
              }
            })),
    SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(children: [
          for (int i = 0; i < 7; i++)
            Padding(
                padding: const EdgeInsets.only(right: 6),
                child: _DayButton(_weekdays[i],
                    DateTime(monday.year, monday.month, monday.day + i).day,
                    selected: m.selected.weekday == i + 1,
                    onTap: () => c.update(() => m.selected = _day(
                        DateTime(monday.year, monday.month, monday.day + i))))),
        ])),
    SectionLabel(_longDate(m.selected)),
    Caption(entries.isEmpty
        ? '등록한 일정이 없어요.'
        : '${m.selected == m.today ? '오늘' : '선택한 날'} 챙길 일정 ${entries.length}개'),
    for (final entry in entries)
      ReviewRow(
          title: '${_timeLabel(entry.time)} · ${entry.name}',
          detail: '내가 등록한 일정',
          icon: 'activity',
          onTap: () => routine(entry)),
    ReviewButton('새 일정 추가하기', () => routine()),
    ReviewRow(
        title: '일정 표시 설정',
        detail: '오늘 홈에 표시할 일정 관리',
        icon: 'bell',
        onTap: () => c.go('notification')),
  ]);
}

Widget _routine(ReviewController c, DailyModel m) => ReviewPage(
      key: PageStorageKey('routine-${m.routineVisit}'),
      title: m.editing == null ? '일정 추가' : '일정 수정',
      backTo: 'schedule',
      actions: [
        ReviewButton(
            '일정 저장하기',
            m.title.trim().isEmpty
                ? null
                : () {
                    m.saveRoutine();
                    c.go('schedule');
                  }),
        ReviewButton('취소하기', () => c.go('schedule'), secondary: true),
        if (m.editing != null)
          Builder(
              builder: (context) => ReviewButton('일정 삭제', () async {
                    final id = m.editing!.id;
                    if (await _confirmDelete(context, '이 일정과 반복을 삭제할까요?') &&
                        context.mounted) {
                      c.update(() {
                        m.routines.removeWhere((r) => r.id == id);
                        m.editing = null;
                      });
                      c.go('schedule');
                    }
                  }, secondary: true)),
      ],
      children: [
        const SectionLabel('잊지 않게 챙겨요'),
        const Caption('일정과 반복할 요일을 정해 주세요.'),
        ReviewField(
            label: '일정 이름',
            value: m.title,
            onChanged: (v) => c.update(() => m.title = v)),
        Builder(
            builder: (context) => ReviewRow(
                title: '시작 날짜',
                detail: _longDate(m.draftDate),
                icon: 'calendar',
                onTap: () async {
                  final d = await _chooseDay(context, m.draftDate);
                  if (d != null && context.mounted) {
                    c.update(() => m.draftDate = d);
                  }
                })),
        const Caption('시간'),
        Builder(
            builder: (context) => ReviewRow(
                title: _timeLabel(m.time),
                icon: 'clock',
                onTap: () async {
                  final value = await showTimePicker(
                      context: context,
                      initialTime: m.time,
                      helpText: '일정 시간',
                      cancelText: '취소',
                      confirmText: '확인');
                  if (context.mounted && value != null) {
                    c.update(() => m.time = value);
                  }
                })),
        if (m.editing case final saved?)
          BodabCalendarExport(
              id: saved.id,
              title: saved.name,
              startsAt: DateTime(saved.date.year, saved.date.month,
                  saved.date.day, saved.time.hour, saved.time.minute),
              weekdays: saved.weekdays),
        const SectionLabel('반복할 요일'),
        const Caption('요일을 고르지 않으면 시작 날짜에 한 번만 표시해요.'),
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (int i = 1; i <= 7; i++)
            _DayButton(_weekdays[i - 1], null,
                selected: m.weekdays.contains(i),
                onTap: () => c.update(() {
                      if (!m.weekdays.remove(i)) m.weekdays.add(i);
                    })),
        ]),
        ReviewCard(
            child: Material(
                type: MaterialType.transparency,
                child: SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('오늘 홈에 표시'),
                  subtitle: const Text('해당 날짜의 홈에 이 일정을 보여줘요.'),
                  value: m.wantsReminder,
                  onChanged: (v) => c.update(() => m.wantsReminder = v),
                ))),
      ],
    );

/// A static field illustration for the two original Figma designs.
class _DesignField extends StatelessWidget {
  const _DesignField(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Caption(label),
          const SizedBox(height: 8),
          const ReviewCard(child: SizedBox(height: 26)),
        ],
      );
}

class _DailyBadge extends StatelessWidget {
  const _DailyBadge(this.name, {this.error = false});
  final String name;
  final bool error;
  @override
  Widget build(BuildContext context) => Align(
      alignment: Alignment.centerLeft,
      child: Container(
        width: name == 'heart' ? 88 : 64,
        height: 64,
        decoration: BoxDecoration(
            color: error ? const Color(0xfffaead8) : reviewTint,
            borderRadius: BorderRadius.circular(16)),
        child: Center(child: ReviewIcon(name, size: name == 'heart' ? 48 : 36)),
      ));
}

class _DailyQuestions extends StatefulWidget {
  const _DailyQuestions(
      {super.key, required this.answers, required this.onSelect});
  final Map<CheckinField, String> answers;
  final void Function(CheckinField, String) onSelect;
  @override
  State<_DailyQuestions> createState() => _DailyQuestionsState();
}

class _DailyQuestionsState extends State<_DailyQuestions> {
  CheckinField? expanded;

  Widget choices(CheckinField field, List<String> values) =>
      Wrap(spacing: 8, runSpacing: 4, children: [
        for (final value in values)
          ChoiceChip(
              label: Text(value),
              selected: widget.answers[field] == value,
              onSelected: (_) => widget.onSelect(field, value)),
      ]);

  Widget question(CheckinField field, String title, List<String> options) {
    final isOpen = expanded == field;
    final selected = widget.answers[field];
    final onset = field == CheckinField.location
        ? widget.answers[CheckinField.onset]
        : null;
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Material(
          type: MaterialType.transparency,
          child: ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(title),
              subtitle: selected == null && onset == null
                  ? null
                  : Text([
                      if (selected != null) selected,
                      if (onset != null) onset
                    ].join(' · ')),
              trailing: Icon(isOpen ? Icons.expand_less : Icons.expand_more),
              onTap: () => setState(() => expanded = isOpen ? null : field))),
      if (isOpen) ...[
        if (field == CheckinField.location) const Caption('불편한 곳'),
        choices(field, options),
        if (field == CheckinField.location) ...[
          const Caption('언제부터 느꼈나요?'),
          choices(CheckinField.onset,
              const ['오늘 아침부터', '오늘 낮부터', '오늘 저녁부터', '어제부터', '며칠 전부터']),
          const Caption('다른 부위나 정확한 시각은 아래 메모에 적을 수 있어요.'),
        ],
      ],
    ]);
  }

  @override
  Widget build(BuildContext context) => ReviewCard(
          child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SectionLabel('기록하고 싶은 생활 질문'),
          const Caption('남기고 싶은 질문만 열어 답하세요. 선택한 답을 다시 누르면 지울 수 있어요.'),
          question(CheckinField.sleep, '어젯밤 잠은 어땠나요?',
              const ['푹 잤어요', '자주 깼어요', '잠들기 어려웠어요']),
          question(CheckinField.meals, '오늘 식사는 어땠나요?',
              const ['평소처럼 먹었어요', '평소보다 적게 먹었어요', '끼니를 걸렀어요']),
          question(CheckinField.activity, '오늘 어떻게 움직였나요?',
              const ['가볍게 걸었어요', '집안일을 했어요', '주로 쉬었어요']),
          question(CheckinField.location, '어디가 언제부터 불편했나요?',
              const ['머리', '목·어깨', '허리', '배', '무릎', '다리·발']),
        ],
      ));
}

class _HomeHealthCard extends StatelessWidget {
  const _HomeHealthCard({required this.record, required this.onTap});
  final ReviewHealthCheck? record;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
            color: reviewTint, borderRadius: BorderRadius.circular(24)),
        child: Stack(children: [
          Positioned(
              left: 0,
              top: 26,
              child: Container(
                  width: 4,
                  height: 40,
                  decoration: BoxDecoration(
                      color: reviewGreen,
                      borderRadius: BorderRadius.circular(4)))),
          Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 4),
                        child: Text('오늘의 건강 기록',
                            style: TextStyle(
                                fontFamily: 'NotoSansKRReview',
                                fontSize: 20,
                                height: 1.4,
                                fontWeight: FontWeight.w500,
                                color: reviewGreen))),
                    const SizedBox(height: 10),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                            record == null
                                ? '잠과 식사, 오늘은 어땠나요?'
                                : record!.condition.isEmpty
                                    ? '오늘 남긴 생활 기록'
                                    : record!.condition,
                            style: const TextStyle(
                                fontFamily: 'NotoSansKRReview',
                                fontSize: 28,
                                height: 1.4,
                                fontWeight: FontWeight.w700,
                                color: reviewInk))),
                    if (record == null) ...[
                      const SizedBox(height: 8),
                      const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4),
                          child: Caption('기억나는 것 하나만 남겨도 좋아요.')),
                    ],
                    const SizedBox(height: 24),
                    if (record?.answers.isNotEmpty == true)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Caption(ReviewHealthCheck.formatAnswers(
                              record!.answers))),
                    if (record?.memo.isNotEmpty == true)
                      Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Caption(record!.memo)),
                    ReviewButton(
                        record == null ? '건강 상태 남기기' : '건강 상태 수정하기', onTap),
                  ])),
        ]),
      );
}

class _HomeAction extends StatelessWidget {
  const _HomeAction(this.icon, this.text, this.onTap);
  final String icon, text;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      button: true,
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            side: const BorderSide(color: reviewLine),
            borderRadius: BorderRadius.circular(20)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 106),
              child: Padding(
                  padding: const EdgeInsets.fromLTRB(17, 15, 12, 15),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        ReviewIcon(icon, size: 26),
                        const SizedBox(height: 12),
                        Text(text,
                            style: const TextStyle(
                                fontFamily: 'NotoSansKRReview',
                                fontSize: 22,
                                height: 1.3,
                                color: reviewInk,
                                fontWeight: FontWeight.w500)),
                      ]))),
        ),
      ));
}

class _DayButton extends StatelessWidget {
  const _DayButton(this.label, this.day,
      {required this.selected, required this.onTap});
  final String label;
  final int? day;
  final bool selected;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    const green = Color(0xff285d4b);
    return Semantics(
        selected: selected,
        child: OutlinedButton(
          onPressed: onTap,
          style: OutlinedButton.styleFrom(
            textStyle: const TextStyle(
                fontFamily: 'NotoSansKRReview',
                fontSize: 18,
                fontWeight: FontWeight.w600),
            foregroundColor: selected ? Colors.white : green,
            backgroundColor: selected ? green : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
            minimumSize: Size(day == null ? 40 : 53, day == null ? 48 : 72),
            side: BorderSide(color: selected ? green : const Color(0xffd6ddd3)),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(label),
            if (day != null) Text('$day'),
          ]),
        ));
  }
}

class _Progress extends StatelessWidget {
  const _Progress(this.review);
  final bool review;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      for (final part in ['상태 선택', '내용 확인'])
        Expanded(
            child: Padding(
          padding: const EdgeInsets.only(right: 5),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(
                height: 3,
                color: part == '상태 선택' || review
                    ? const Color(0xff285d4b)
                    : const Color(0xffd6ddd3)),
            const SizedBox(height: 6),
            Text(part),
          ]),
        )),
    ]);
  }
}

class _DataLine extends StatelessWidget {
  const _DataLine(this.name, this.value);
  final String name, value;
  @override
  Widget build(BuildContext context) =>
      Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(width: 76, child: Text(name)),
        Expanded(child: Text(value)),
      ]);
}
