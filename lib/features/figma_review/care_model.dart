import 'dart:math';
import 'package:flutter/material.dart';

import 'care_handoff.dart';
import 'core.dart';

final _random = Random.secure();
String _id() => List.generate(
    12, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

class CareContact {
  CareContact(this.id, this.name, this.email);
  final String id, name, email;
}

class CareRequest {
  CareRequest(this.id, this.institution, this.email, this.service, this.wanted);
  final String id, institution, email, service;
  final DateTime wanted;
  String reply = '';
  DateTime? repliedAt;
}

class CareEvent {
  CareEvent(this.id, this.ownerId, this.channel, this.at, this.count);
  final String id, ownerId;
  final CareChannel channel;
  final DateTime at;
  final int count;
}

class CarePreview {
  const CarePreview(
      this.ownerId, this.label, this.email, this.title, this.body, this.count);
  final String ownerId, label, email, title, body;
  final int count;
}

class CareModel implements ReviewSavedModel {
  final contacts = <String, CareContact>{};
  final requests = <String, CareRequest>{};
  final events = <String, CareEvent>{};
  String? contactId, requestId;
  String contactName = '',
      contactEmail = '',
      institution = '',
      institutionEmail = '',
      service = '생활 지원 상담';
  DateTime date =
      DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
  TimeOfDay time = const TimeOfDay(hour: 14, minute: 0);
  final selectedRecords = <String>{};
  CarePreview? preview;
  String pendingRequestId = '';
  String replyDraft = '';
  CareChannel? completedChannel;
  bool busy = false;

  CareContact? get contact => contacts[contactId];
  CareRequest? get request => requests[requestId];

  void beginContact() {
    contactName = '';
    contactEmail = '';
  }

  bool get canAddContact =>
      contactName.trim().isNotEmpty && validCareEmail(contactEmail.trim());
  void saveContact() {
    if (!canAddContact) return;
    final c = CareContact(_id(), contactName.trim(), contactEmail.trim());
    contacts[c.id] = c;
    selectContact(c.id);
    beginContact();
  }

  void selectContact(String id) {
    contactId = id;
    selectedRecords.clear();
    preview = null;
    completedChannel = null;
  }

  void deleteContact() {
    final id = contactId;
    if (id == null) return;
    contacts.remove(id);
    events.removeWhere((_, e) => e.ownerId == id);
    contactId = null;
    selectedRecords.clear();
    preview = null;
    completedChannel = null;
  }

  CarePreview? familyPreviewOf(List<ReviewRecord> records) {
    final who = contact;
    final chosen =
        records.where((r) => selectedRecords.contains(r.id)).toList();
    if (who == null || chosen.isEmpty) return null;
    final lines = chosen
        .map((r) => '• ${dateLabel(r.createdAt)}  ${r.title}\n${r.detail}');
    return CarePreview(who.id, who.name, who.email, '보답에서 고른 기록',
        '${who.name}님께 공유하는 보답 기록\n\n${lines.join('\n\n')}', chosen.length);
  }

  void buildFamilyPreview(List<ReviewRecord> records) {
    preview = familyPreviewOf(records);
    completedChannel = null;
  }

  DateTime get requestedTime =>
      DateTime(date.year, date.month, date.day, time.hour, time.minute);
  bool get futureRequestedTime => requestedTime.isAfter(DateTime.now());
  bool get canPrepareRequest =>
      futureRequestedTime &&
      institution.trim().isNotEmpty &&
      validCareEmail(institutionEmail.trim());
  void buildCarePreview() {
    if (!canPrepareRequest) return;
    if (pendingRequestId.isEmpty) pendingRequestId = _id();
    final to = institution.trim();
    final when =
        DateTime(date.year, date.month, date.day, time.hour, time.minute);
    preview = CarePreview(
        pendingRequestId,
        to,
        institutionEmail.trim(),
        '돌봄 상담 문의',
        '$to 담당자님, 안녕하세요.\n$service 관련 상담을 문의드립니다.\n희망 일시는 ${dateLabel(when)} ${timeLabel(TimeOfDay.fromDateTime(when))}입니다.\n가능한 일정과 이용 방법을 알려 주세요.',
        0);
    completedChannel = null;
  }

  CareRequest snapshotRequest() => CareRequest(
      pendingRequestId,
      institution.trim(),
      institutionEmail.trim(),
      service,
      DateTime(date.year, date.month, date.day, time.hour, time.minute));

  void noteHandoff(CarePreview payload, CareChannel channel,
      {CareRequest? care}) {
    if (care != null) {
      requests.putIfAbsent(care.id, () => care);
      requestId = care.id;
      if (pendingRequestId == care.id) pendingRequestId = '';
    }
    if (care == null && !contacts.containsKey(payload.ownerId)) return;
    final event = CareEvent(
        _id(), payload.ownerId, channel, DateTime.now(), payload.count);
    events[event.id] = event;
    completedChannel = channel;
  }

  void newRequest() {
    pendingRequestId = '';
    requestId = null;
    institution = '';
    institutionEmail = '';
    date = DateUtils.dateOnly(DateTime.now()).add(const Duration(days: 1));
    time = const TimeOfDay(hour: 14, minute: 0);
    service = '생활 지원 상담';
    preview = null;
    completedChannel = null;
    replyDraft = '';
  }

  List<CareEvent> history([String? id]) =>
      events.values.where((e) => id == null || e.ownerId == id).toList()
        ..sort((a, b) => b.at.compareTo(a.at));

  @override
  String get storageKey => 'care-v1';
  @override
  Map<String, Object?> exportSavedState() => {
        for (final x in contacts.values)
          'contact:${x.id}': {'name': x.name, 'email': x.email},
        for (final x in requests.values)
          'request:${x.id}': {
            'institution': x.institution,
            'email': x.email,
            'service': x.service,
            'wanted': x.wanted.toIso8601String(),
            'reply': x.reply,
            'repliedAt': x.repliedAt?.toIso8601String()
          },
        for (final x in events.values)
          'event:${x.id}': {
            'owner': x.ownerId,
            'channel': x.channel.name,
            'at': x.at.toIso8601String(),
            'count': x.count
          },
      };
  @override
  void restoreSavedState(Map<String, Object?> data) {
    contacts.clear();
    requests.clear();
    events.clear();
    for (final entry in data.entries) {
      final v = entry.value;
      if (v is! Map) continue;
      final parts = entry.key.split(':');
      if (parts.length != 2 || parts[1].isEmpty) continue;
      final id = parts[1];
      String str(String key) => v[key] is String ? v[key] as String : '';
      switch (parts[0]) {
        case 'contact':
          if (str('name').isNotEmpty && validCareEmail(str('email'))) {
            contacts[id] = CareContact(id, str('name'), str('email'));
          }
        case 'request':
          final when = DateTime.tryParse(str('wanted'));
          if (when != null &&
              str('institution').isNotEmpty &&
              validCareEmail(str('email'))) {
            requests[id] = CareRequest(
                id, str('institution'), str('email'), str('service'), when)
              ..reply = str('reply')
              ..repliedAt = DateTime.tryParse(str('repliedAt'));
          }
        case 'event':
          final at = DateTime.tryParse(str('at'));
          final ch = CareChannel.values
              .where((e) => e.name == str('channel'))
              .firstOrNull;
          if (at != null && ch != null && v['count'] is int) {
            events[id] = CareEvent(id, str('owner'), ch, at, v['count'] as int);
          }
      }
    }
    events.removeWhere((_, e) =>
        !contacts.containsKey(e.ownerId) && !requests.containsKey(e.ownerId));
    if (contactId != null && !contacts.containsKey(contactId)) {
      contactId = null;
      selectedRecords.clear();
      preview = null;
    }
    if (requestId != null && !requests.containsKey(requestId)) {
      requestId = null;
      replyDraft = '';
      preview = null;
    }
  }
}

String dateLabel(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일';
String timeLabel(TimeOfDay t) =>
    '${t.hour < 12 ? '오전' : '오후'} ${t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod}:${t.minute.toString().padLeft(2, '0')}';
