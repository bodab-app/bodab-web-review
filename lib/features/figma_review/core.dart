import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'device_store_api.dart';
import 'screens.dart';

export 'device_store_api.dart' show ReviewSavedModel, ReviewDeviceStore;
part 'device_controller.dart';

const reviewInk = Color(0xff223d33);
const reviewGreen = Color(0xff285d4b);
const reviewBackground = Color(0xfff8f6f0);
const reviewLine = Color(0xffd6ddd3);
const reviewTint = Color(0xffe7eee5);

class ReviewRecord {
  const ReviewRecord(
      this.id, this.title, this.detail, this.category, this.createdAt);
  final String id, title, detail, category;
  final DateTime createdAt;
}

enum CheckinField {
  sleep('수면'),
  meals('식사'),
  activity('활동'),
  location('불편한 곳'),
  onset('시작');

  const CheckinField(this.label);
  final String label;
}

class ReviewHealthCheck extends ReviewRecord {
  ReviewHealthCheck(this.day, this.condition, this.memo,
      {Map<CheckinField, String> answers = const {}, DateTime? createdAt})
      : answers = Map.unmodifiable(answers),
        super(
            idFor(day),
            '오늘의 건강 체크',
            [
              if (condition.isNotEmpty) condition,
              if (answers.isNotEmpty) formatAnswers(answers),
              if (memo.isNotEmpty) memo
            ].join(' · '),
            '건강',
            createdAt ?? DateTime.now());

  final DateTime day;
  final String condition, memo;
  final Map<CheckinField, String> answers;

  static String formatAnswers(Map<CheckinField, String> answers) => [
        for (final field in CheckinField.values)
          if (answers.containsKey(field)) '${field.label}: ${answers[field]}'
      ].join(' · ');

  static String idFor(DateTime day) =>
      'checkin-${day.year}-${day.month}-${day.day}';
}

/// Each app instance owns its own navigation, feature models and records.
class ReviewController extends _DeviceController {
  ReviewController({String initial = 'home', ReviewDeviceStore? deviceStore})
      : _path = [isBodabRoute(initial) ? initial : 'home'],
        super(deviceStore);
  final List<String> _path;
  @override
  void _homeAfterClear() {
    _path
      ..clear()
      ..add('home');
  }

  String get current => _path.last;
  String get baseKey => reviewFrames[current]?.base ?? current;
  void update(VoidCallback change) {
    change();
    _changed();
  }

  void go(String key) {
    if (!isBodabRoute(key) || key == current) return;
    _path.add(key);
    _changed();
  }

  void resetTo(String key) {
    if (!isBodabRoute(key)) return;
    _path
      ..clear()
      ..add(key);
    _changed();
  }

  bool get canGoBack => _path.length > 1;
  void back([String fallback = 'home']) {
    if (!canGoBack) {
      resetTo(fallback);
      return;
    }
    _path.removeLast();
    _changed();
  }

  void addRecord(String title, String detail,
      {String category = '건강', String? id}) {
    final now = DateTime.now();
    final recordId = id ?? _uniqueId();
    final createdAt =
        _records.where((r) => r.id == recordId).firstOrNull?.createdAt ?? now;
    _save(ReviewRecord(recordId, title, detail, category, createdAt));
  }

  ReviewHealthCheck? checkinFor(DateTime day) {
    final id = ReviewHealthCheck.idFor(day);
    return _records
        .whereType<ReviewHealthCheck>()
        .where((r) => r.id == id)
        .firstOrNull;
  }

  void saveCheckin(DateTime day, String condition, String memo,
      {Map<CheckinField, String>? answers}) {
    final previous = checkinFor(day);
    _save(ReviewHealthCheck(day, condition, memo.trim(),
        answers: answers ?? previous?.answers ?? const {},
        createdAt: previous?.createdAt));
  }

  void _save(ReviewRecord record) {
    _records.removeWhere((r) => r.id == record.id);
    _records.insert(0, record);
    _changed(record: record);
  }

  void removeRecord(String id) {
    _records.removeWhere((record) => record.id == id);
    _changed(removedRecord: id);
  }
}

class ReviewScope extends InheritedNotifier<ReviewController> {
  const ReviewScope(
      {super.key, required ReviewController controller, required super.child})
      : super(notifier: controller);
  static ReviewController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ReviewScope>()!.notifier!;
}

class ReviewIcon extends StatelessWidget {
  const ReviewIcon(this.name, {super.key, this.size = 24});
  final String name;
  final double size;
  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: SvgPicture.asset('assets/figma_review/$name.svg',
            width: size, height: size, fit: BoxFit.contain),
      );
}

class Lead extends StatelessWidget {
  const Lead(this.text, {super.key, this.detail});
  final String text;
  final String? detail;
  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(text,
            style: const TextStyle(
                fontFamily: 'NotoSansKRReview',
                fontSize: 32,
                height: 1.35,
                fontWeight: FontWeight.w700,
                color: reviewInk)),
        if (detail != null)
          Padding(
              padding: const EdgeInsets.only(top: 8), child: Caption(detail!)),
      ]);
}

class Caption extends StatelessWidget {
  const Caption(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontFamily: 'NotoSansKRReview',
          fontSize: 20,
          height: 1.45,
          color: Color(0xff47584d)));
}

class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});
  final String text;
  @override
  Widget build(BuildContext context) => Text(text,
      style: const TextStyle(
          fontFamily: 'NotoSansKRReview',
          fontSize: 22,
          height: 1.35,
          fontWeight: FontWeight.w700,
          color: reviewInk));
}

class ReviewCard extends StatelessWidget {
  const ReviewCard({super.key, required this.child, this.tinted = false});
  final Widget child;
  final bool tinted;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
          color: tinted ? reviewTint : Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: tinted ? reviewTint : reviewLine)),
      child: child);
}

class ReviewRow extends StatelessWidget {
  const ReviewRow(
      {super.key, required this.title, this.detail, this.icon, this.onTap});
  final String title;
  final String? detail, icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    final content = Row(children: [
      if (icon != null) ...[
        ReviewIcon(icon!, size: 28),
        const SizedBox(width: 14)
      ],
      Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionLabel(title),
        if (detail != null) Caption(detail!),
      ])),
      if (onTap != null) ...[
        const SizedBox(width: 6),
        const ReviewIcon('chevron', size: 20)
      ],
    ]);
    final radius = BorderRadius.circular(16);
    return Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
            borderRadius: radius, side: const BorderSide(color: reviewLine)),
        child: InkWell(
            onTap: onTap,
            borderRadius: radius,
            child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
                child: content)));
  }
}

class ReviewButton extends StatelessWidget {
  const ReviewButton(this.label, this.onPressed,
      {super.key, this.secondary = false, this.danger = false});
  final String label;
  final VoidCallback? onPressed;
  final bool secondary, danger;
  @override
  Widget build(BuildContext context) {
    final ink = danger ? const Color(0xff8c3932) : reviewGreen;
    return SizedBox(
        width: double.infinity,
        child: FilledButton(
            style: FilledButton.styleFrom(
                minimumSize: Size(0, secondary ? 66 : 80),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
                backgroundColor: secondary ? Colors.white : ink,
                foregroundColor: secondary ? ink : Colors.white,
                side: secondary ? const BorderSide(color: reviewLine) : null,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
                textStyle: const TextStyle(
                    fontFamily: 'NotoSansKRReview',
                    fontSize: 24,
                    height: 1.3,
                    fontWeight: FontWeight.w700)),
            onPressed: onPressed,
            child: Text(label, textAlign: TextAlign.center)));
  }
}

class ReviewField extends StatefulWidget {
  const ReviewField(
      {super.key,
      required this.label,
      required this.value,
      required this.onChanged,
      this.keyboardType,
      this.hint});
  final String label, value;
  final String? hint;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;
  @override
  State<ReviewField> createState() => _ReviewFieldState();
}

class _ReviewFieldState extends State<ReviewField> {
  late final _text = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(ReviewField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_text.text != widget.value && oldWidget.value != widget.value) {
      _text.value = TextEditingValue(
          text: widget.value,
          selection: TextSelection.collapsed(offset: widget.value.length));
    }
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Caption(widget.label),
        const SizedBox(height: 8),
        TextField(
            controller: _text,
            keyboardType: widget.keyboardType,
            onChanged: widget.onChanged,
            style: const TextStyle(
                fontFamily: 'NotoSansKRReview',
                fontSize: 22,
                height: 1.4,
                color: reviewInk),
            decoration: InputDecoration(
                hintText: widget.hint,
                filled: true,
                fillColor: Colors.white,
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: reviewLine)),
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16))))
      ]);
}

class ReviewPage extends StatelessWidget {
  const ReviewPage(
      {super.key,
      required this.title,
      required this.children,
      this.actions = const [],
      this.tab,
      this.branded = false,
      this.backTo = 'home'});
  final String title, backTo;
  final List<Widget> children, actions;
  final String? tab;
  final bool branded;
  @override
  Widget build(BuildContext context) {
    final c = ReviewScope.of(context);
    final headerButton = TextButton.styleFrom(
      minimumSize: const Size(48, 48),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      backgroundColor: Colors.white,
      foregroundColor: reviewGreen,
      side: const BorderSide(color: reviewLine),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      textStyle: const TextStyle(
          fontFamily: 'NotoSansKRReview',
          fontSize: 20,
          fontWeight: FontWeight.w700),
    );
    final previous = TextButton.icon(
        style: headerButton,
        onPressed: () => c.back(backTo),
        icon: const ReviewIcon('back', size: 19),
        label: const Text('이전'));
    final alert = TextButton.icon(
        style: headerButton,
        onPressed: () => c.go('notification'),
        icon: const ReviewIcon('bell', size: 22),
        label: const Text('알림'));
    final header =
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      if (!branded) ...[previous, const SizedBox(width: 10)],
      Expanded(
          child: Text(title,
              style: TextStyle(
                  fontFamily: 'NotoSansKRReview',
                  fontSize: branded ? 30 : 24,
                  height: 1.3,
                  fontWeight: FontWeight.w700,
                  color: reviewInk))),
      if (branded) alert,
    ]);
    return Scaffold(
        backgroundColor: reviewBackground,
        body: SafeArea(
            child: CustomScrollView(key: PageStorageKey(c.current), slivers: [
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              sliver: SliverToBoxAdapter(child: header)),
          SliverPadding(
              padding: const EdgeInsets.fromLTRB(24, 25, 24, 16),
              sliver: SliverList.list(children: [
                for (var i = 0; i < children.length; i++) ...[
                  if (i > 0) const SizedBox(height: 14),
                  children[i]
                ],
              ])),
          if (actions.isNotEmpty)
            SliverFillRemaining(
                hasScrollBody: false,
                child: Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                        child:
                            Column(mainAxisSize: MainAxisSize.min, children: [
                          for (var i = 0; i < actions.length; i++) ...[
                            if (i > 0) const SizedBox(height: 10),
                            actions[i]
                          ],
                        ])))),
          if (tab != null && reviewFrames[c.current]!.large)
            SliverToBoxAdapter(child: _ReviewTabs(tab: tab!, vertical: true))
        ])),
        bottomNavigationBar: tab != null && !reviewFrames[c.current]!.large
            ? SafeArea(
                top: false, child: _ReviewTabs(tab: tab!, vertical: false))
            : null);
  }
}

class _ReviewTabs extends StatelessWidget {
  const _ReviewTabs({required this.tab, required this.vertical});
  final String tab;
  final bool vertical;
  @override
  Widget build(BuildContext context) {
    final c = ReviewScope.of(context);
    const tabs = [
      ('home', '오늘', 'home'),
      ('schedule', '일정', 'calendar'),
      ('records', '기록', 'records'),
      ('activities', '활동', 'activity'),
      ('profile', '설정', 'profile')
    ];
    final items = <Widget>[
      for (final t in tabs)
        Semantics(
            selected: tab == t.$1,
            button: true,
            child: InkWell(
                onTap: () => c.resetTo(t.$1),
                child: Container(
                    decoration: BoxDecoration(
                        color: tab == t.$1 ? reviewTint : Colors.transparent,
                        borderRadius: BorderRadius.circular(10)),
                    padding:
                        const EdgeInsets.symmetric(vertical: 13, horizontal: 2),
                    child: vertical
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                                ReviewIcon(t.$3),
                                const SizedBox(width: 12),
                                Text(t.$2)
                              ])
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            ReviewIcon(t.$3, size: 27),
                            Text(t.$2,
                                style: const TextStyle(
                                    fontFamily: 'NotoSansKRReview',
                                    fontSize: 16))
                          ]))))
    ];
    return DecoratedBox(
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: reviewLine))),
        child: Padding(
            padding: const EdgeInsets.all(4),
            child: vertical
                ? Column(children: items)
                : Row(children: [for (final i in items) Expanded(child: i)])));
  }
}
