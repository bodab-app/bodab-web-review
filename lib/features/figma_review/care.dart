import 'package:flutter/material.dart';

import 'care_handoff.dart';
import 'care_model.dart';
import 'core.dart';

const _services = ['생활 지원 상담', '방문 지원', '식사·외출 지원', '기타 돌봄 상담'];

Widget buildCareScreen(String key, ReviewController c) {
  final m = c.model(() => CareModel());
  switch (key) {
    case 'family':
      return _family(c, m);
    case 'invite':
      return _addContact(c, m);
    case 'share':
      return _selectRecords(c, m);
    case 'share_done':
      return _familyPreview(c, m);
    case 'revoke':
      return _deleteContact(c, m);
    case 'history':
      return _familyHistory(c, m);
    case 'care_select':
      return _selectCare(c, m);
    case 'care_review':
      return _carePreview(c, m);
    case 'care_pending':
      return _requestHistory(c, m);
    case 'care_accepted':
      return _reply(c, m);
    default:
      throw ArgumentError.value(key, 'key');
  }
}

Widget _family(ReviewController c, CareModel m) =>
    ReviewPage(title: '가족과 기록 나누기', backTo: 'profile', actions: [
      ReviewButton('가족 연락처 추가', () {
        m.beginContact();
        c.go('invite');
      }),
    ], children: [
      const Lead('누구에게 전할까요?', detail: '가족을 고른 뒤 오늘 전하고 싶은 기록을 선택하세요.'),
      if (m.contacts.isEmpty)
        const ReviewCard(
            child: Caption('아직 등록한 가족이 없어요. 먼저 이 기기에 가족의 이름을 추가해 주세요.')),
      for (final x in m.contacts.values)
        ReviewRow(
            title: x.name,
            detail: x.email.isEmpty ? '전달할 기록 선택' : x.email,
            icon: 'family',
            onTap: () {
              m.selectContact(x.id);
              c.go('share');
            }),
      ReviewRow(
          title: '가족에게 전달한 내역',
          detail: '이 기기에서 선택한 전달 방법과 일시',
          icon: 'records',
          onTap: () => c.go('history')),
    ]);

Widget _empty(ReviewController c, String title, String message, String action,
        String dest) =>
    ReviewPage(
        title: title,
        backTo: dest,
        actions: [ReviewButton(action, () => c.go(dest))],
        children: [Lead(message)]);

Widget _addContact(ReviewController c, CareModel m) =>
    ReviewPage(title: '가족 연락처 추가', backTo: 'family', actions: [
      ReviewButton(
          '이 기기에 추가하기',
          m.canAddContact
              ? () {
                  c.update(m.saveContact);
                  c.go('family');
                }
              : null),
      ReviewButton('취소하기', () => c.go('family'), secondary: true),
    ], children: [
      const Lead('가족 이름을 알려 주세요', detail: '연락처를 추가해도 기록은 전달되지 않아요.'),
      ReviewField(
          label: '이름 또는 별명',
          value: m.contactName,
          onChanged: (v) => c.update(() => m.contactName = v)),
      _emailField(m.contactEmail, (v) => c.update(() => m.contactEmail = v)),
    ]);

Widget _emailField(String value, ValueChanged<String> changed) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      ReviewField(
          label: '이메일 (선택)',
          value: value,
          keyboardType: TextInputType.emailAddress,
          hint: '메일로 전할 때 사용할 주소',
          onChanged: changed),
      if (!validCareEmail(value.trim()))
        const Caption('한 사람의 이메일 주소를 입력해 주세요.'),
    ]);

Widget _selectRecords(ReviewController c, CareModel m) {
  final person = m.contact;
  if (person == null) {
    return _empty(
        c, '공유할 기록 선택', '기록을 전할 가족을 먼저 선택해 주세요.', '가족 연락처로', 'family');
  }
  final records = c.records;
  final count = records.where((r) => m.selectedRecords.contains(r.id)).length;
  return ReviewPage(title: '공유할 기록 선택', backTo: 'family', actions: [
    ReviewButton(
        '전달 내용 확인하기',
        count == 0
            ? null
            : () {
                m.buildFamilyPreview(c.records);
                if (m.preview != null) c.go('share_done');
              }),
    ReviewButton('연락처 삭제', () => c.go('revoke'), secondary: true),
  ], children: [
    Lead('${person.name}님에게 전할 기록', detail: '직접 고른 항목의 제목과 내용만 한 번 전달해요.'),
    if (records.isEmpty) ...[
      const ReviewCard(child: Caption('아직 보낼 기록이 없어요. 건강 상태를 먼저 기록해 보세요.')),
      ReviewButton('오늘로 이동', () => c.resetTo('home'), secondary: true),
    ],
    for (final r in records)
      ReviewCard(
          child: Material(
              type: MaterialType.transparency,
              child: CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(r.title),
                subtitle: Text('${dateLabel(r.createdAt)}\n${r.detail}'),
                value: m.selectedRecords.contains(r.id),
                onChanged: (v) => c.update(() {
                  if (v == true) {
                    m.selectedRecords.add(r.id);
                  } else {
                    m.selectedRecords.remove(r.id);
                  }
                }),
              ))),
    if (records.isNotEmpty) Caption('선택한 기록 $count건'),
  ]);
}

Widget _familyPreview(ReviewController c, CareModel m) {
  final p = m.preview;
  if (p == null || !m.contacts.containsKey(p.ownerId)) {
    return _empty(c, '전달 전 확인', '선택한 가족과 전달할 기록이 없어요.', '가족 연락처로', 'family');
  }
  return ReviewPage(title: '전달 전 확인', backTo: 'share', actions: [
    ..._handoffButtons(c, m, p),
    ReviewButton('다시 선택하기', () => c.go('share'), secondary: true),
  ], children: [
    Lead('${p.label}님께 전할 내용', detail: '선택한 기록 ${p.count}건'),
    if (p.email.isNotEmpty) Caption('메일 작성 시 받는 주소 · ${p.email}'),
    _letter(p.body),
    const Caption('공유창에서 받을 사람을 직접 확인하세요. 보내거나 복사한 내용은 보답에서 회수할 수 없어요.'),
    if (m.completedChannel != null)
      Caption('이 기기의 처리 결과 · ${m.completedChannel!.historyLabel}'),
  ]);
}

Widget _letter(String text) => ReviewCard(
    tinted: true,
    child: Text(text,
        style: const TextStyle(
            fontFamily: 'NotoSansKRReview',
            fontSize: 20,
            height: 1.5,
            color: reviewInk)));

List<Widget> _handoffButtons(ReviewController c, CareModel m, CarePreview p,
    {CareRequest? request}) {
  final adapter = c.model<CareHandoff>(() => CareHandoff());
  return [
    for (final channel in CareChannel.values
        .where((v) => v != CareChannel.share || adapter.supportsShareSheet))
      Builder(
          builder: (context) => ReviewButton(
              channel.action,
              m.busy
                  ? null
                  : () async {
                      if (m.busy) return;
                      if (request == null &&
                          m.familyPreviewOf(c.records)?.body != p.body) {
                        m.preview = null;
                        c.go('share');
                        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                          const SnackBar(
                              content: Text('기록이 변경됐어요. 전달할 내용을 다시 확인해 주세요.')),
                        );
                        return;
                      }
                      c.update(() => m.busy = true);
                      bool ok = false;
                      try {
                        ok = await adapter.handoff(channel,
                            recipient: p.email, title: p.title, body: p.body);
                      } catch (_) {
                        ok = false;
                      }
                      m.busy = false;
                      if (c.isDisposed ||
                          !identical(
                              c.model<CareModel>(() => CareModel()), m)) {
                        return;
                      }
                      c.update(() {
                        if (ok) m.noteHandoff(p, channel, care: request);
                      });
                      if (!context.mounted) return;
                      if (!ok) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(switch (channel) {
                          CareChannel.share =>
                            '공유가 완료되지 않았어요. 다시 시도하거나 내용을 복사하세요.',
                          CareChannel.email =>
                            '메일 앱을 열지 못했어요. 내용을 복사해 원하는 앱에서 전하세요.',
                          CareChannel.copy =>
                            '복사하지 못했어요. 브라우저의 클립보드 권한을 확인하거나 메일로 작성해 주세요.',
                        })));
                        return;
                      }
                      if (request != null && c.baseKey == 'care_review') {
                        c.go('care_pending');
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(channel.historyLabel)));
                      }
                    },
              secondary: channel == CareChannel.copy)),
  ];
}

Widget _deleteContact(ReviewController c, CareModel m) {
  final person = m.contact;
  if (person == null) {
    return _empty(c, '연락처 삭제', '삭제할 연락처를 먼저 선택해 주세요.', '가족 연락처로', 'family');
  }
  return ReviewPage(title: '연락처 삭제', backTo: 'share', actions: [
    ReviewButton('이 기기에서 삭제', () {
      c.update(m.deleteContact);
      c.go('family');
    }, danger: true),
    ReviewButton('취소하기', () => c.go('share'), secondary: true),
  ], children: [
    Lead('${person.name}님의 연락처를 삭제할까요?',
        detail: '이 기기에 있는 연락처와 해당 전달 내역을 삭제해요. 이미 전한 내용은 받는 사람에게 남아요.'),
  ]);
}

Widget _familyHistory(ReviewController c, CareModel m) {
  final events =
      m.history().where((e) => m.contacts.containsKey(e.ownerId)).toList();
  return ReviewPage(title: '가족 전달 내역', backTo: 'family', actions: [
    ReviewButton('가족 연락처로', () => c.go('family'))
  ], children: [
    const Lead('무엇을 언제 전달했나요?', detail: '받는 사람의 수신·열람 여부는 직접 확인해 주세요.'),
    if (events.isEmpty)
      const ReviewCard(child: Caption('이 기기에서 가족에게 전달한 내역이 없어요.')),
    for (final e in events)
      ReviewRow(
          title: m.contacts[e.ownerId]!.name,
          detail:
              '${e.channel.historyLabel} · 기록 ${e.count}건\n${dateLabel(e.at)} ${timeLabel(TimeOfDay.fromDateTime(e.at))}',
          icon: 'records'),
  ]);
}

Widget _selectCare(ReviewController c, CareModel m) =>
    ReviewPage(title: '기관 돌봄 요청', backTo: 'profile', actions: [
      ReviewButton(
          '요청 조건 확인하기',
          m.canPrepareRequest
              ? () {
                  m.buildCarePreview();
                  c.go('care_review');
                }
              : null),
    ], children: [
      const Lead('어떤 돌봄이 필요하세요?', detail: '연락할 기관과 희망 일시를 적어 문의 내용을 준비하세요.'),
      ReviewField(
          label: '돌봄 기관 이름',
          value: m.institution,
          onChanged: (v) => c.update(() => m.institution = v)),
      _emailField(
          m.institutionEmail, (v) => c.update(() => m.institutionEmail = v)),
      _pick('서비스 선택', m.service, 'document', '희망 서비스', _services, m.service,
          (s) => c.update(() => m.service = s)),
      Builder(
          builder: (context) => ReviewRow(
              title: '희망 날짜',
              detail: dateLabel(m.date),
              icon: 'calendar',
              onTap: () async {
                final today = DateUtils.dateOnly(DateTime.now());
                final chosen = await showDatePicker(
                    context: context,
                    initialDate: m.date.isBefore(today) ? today : m.date,
                    firstDate: today,
                    lastDate: DateTime(today.year + 3, 12, 31));
                if (chosen != null && context.mounted) {
                  c.update(() => m.date = chosen);
                }
              })),
      Builder(
          builder: (context) => ReviewRow(
              title: '희망 시간',
              detail: timeLabel(m.time),
              icon: 'clock',
              onTap: () async {
                final chosen =
                    await showTimePicker(context: context, initialTime: m.time);
                if (chosen != null && context.mounted) {
                  c.update(() => m.time = chosen);
                }
              })),
      if (!m.futureRequestedTime) const Caption('현재 이후의 희망 날짜와 시간을 선택해 주세요.'),
      ReviewRow(
          title: '이전 문의 내역',
          detail: '기관별 문의와 직접 받은 답변',
          icon: 'records',
          onTap: () {
            m.requestId = null;
            c.go('care_pending');
          }),
    ]);

Widget _carePreview(ReviewController c, CareModel m) {
  final p = m.preview;
  if (p == null || p.ownerId != m.pendingRequestId || !m.canPrepareRequest) {
    return _empty(c, '요청 전 확인', '먼저 문의할 기관과 받고 싶은 서비스를 적어 주세요.', '문의 내용 작성',
        'care_select');
  }
  return ReviewPage(title: '요청 전 확인', backTo: 'care_select', actions: [
    ..._handoffButtons(c, m, p, request: m.snapshotRequest()),
    ReviewButton('조건 바꾸기', () => c.go('care_select'), secondary: true),
  ], children: [
    const Lead('이 내용으로 문의할까요?', detail: '기관과 주고받을 메시지의 내용을 확인하세요.'),
    if (p.email.isNotEmpty) Caption('메일 작성 시 받는 주소 · ${p.email}'),
    _letter(p.body),
    const Caption('기록·진단서·연락처는 첨부하지 않아요. 보낼 기관과 수신 주소를 확인한 뒤 직접 전하세요.'),
  ]);
}

Widget _requestHistory(ReviewController c, CareModel m) {
  final request = m.request;
  if (request == null) {
    return ReviewPage(title: '돌봄 문의 내역', backTo: 'care_select', actions: [
      ReviewButton('새 문의 준비', () {
        m.newRequest();
        c.go('care_select');
      }),
    ], children: [
      const Lead('돌봄 문의 내역'),
      if (m.requests.isEmpty)
        const ReviewCard(child: Caption('아직 작성한 문의를 전달한 내역이 없어요.')),
      for (final r in m.requests.values.toList().reversed)
        ReviewRow(
            title: r.institution,
            detail: '${r.service} · ${dateLabel(r.wanted)}',
            icon: 'institution',
            onTap: () {
              c.update(() => m.requestId = r.id);
            }),
    ]);
  }
  final events = m.history(request.id);
  return ReviewPage(title: '돌봄 문의 상세', backTo: 'care_select', actions: [
    ReviewButton(request.reply.isEmpty ? '받은 답변 기록하기' : '받은 답변 수정하기', () {
      m.replyDraft = request.reply;
      c.go('care_accepted');
    }),
    ReviewButton('문의 목록으로', () {
      c.update(() => m.requestId = null);
    }, secondary: true),
    ReviewButton('새 문의 준비', () {
      m.newRequest();
      c.go('care_select');
    }, secondary: true),
  ], children: [
    Lead(request.institution, detail: request.service),
    Caption(
        '희망 일시 · ${dateLabel(request.wanted)} ${timeLabel(TimeOfDay.fromDateTime(request.wanted))}'),
    for (final e in events)
      ReviewRow(
          title: e.channel.historyLabel,
          detail:
              '${dateLabel(e.at)} ${timeLabel(TimeOfDay.fromDateTime(e.at))}',
          icon: 'document'),
    if (request.reply.isNotEmpty)
      ReviewCard(
          tinted: true,
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const SectionLabel('직접 기록한 기관 답변'),
            Text(request.reply),
          ]))
    else
      const Caption('기관에서 실제로 받은 안내가 있다면 이곳에 기록하세요.'),
  ]);
}

Widget _reply(ReviewController c, CareModel m) {
  final r = m.request;
  if (r == null) {
    return _empty(c, '받은 답변 기록', '어느 기관의 문의에 대한 답변인지 선택해 주세요.', '문의 목록으로',
        'care_pending');
  }
  return ReviewPage(title: '받은 답변 기록', backTo: 'care_pending', actions: [
    ReviewButton(
        '내 기기에 기록하기',
        m.replyDraft.trim().isEmpty
            ? null
            : () {
                c.update(() {
                  r.reply = m.replyDraft.trim();
                  r.repliedAt = DateTime.now();
                });
                c.go('care_pending');
              }),
    ReviewButton('취소하기', () => c.go('care_pending'), secondary: true),
  ], children: [
    Lead('${r.institution}에서 어떤 안내를 받았나요?', detail: '직접 확인한 일정과 답변을 남겨 주세요.'),
    ReviewField(
        label: '기관에서 받은 답변',
        value: m.replyDraft,
        onChanged: (v) => c.update(() => m.replyDraft = v)),
  ]);
}

Widget _pick(String title, String detail, String icon, String sheetTitle,
    List<String> options, String value, ValueChanged<String> setValue) {
  return Builder(
      builder: (context) => ReviewRow(
          title: title,
          detail: detail,
          icon: icon,
          onTap: () async {
            final choice = await showModalBottomSheet<String>(
                context: context,
                sheetAnimationStyle: AnimationStyle.noAnimation,
                showDragHandle: true,
                builder: (sheet) => SafeArea(
                        child: SingleChildScrollView(
                            child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                          Padding(
                              padding: const EdgeInsets.all(14),
                              child: SectionLabel(sheetTitle)),
                          for (final item in options)
                            ListTile(
                                title: Text(item),
                                trailing: item == value
                                    ? const Icon(Icons.check,
                                        color: reviewGreen)
                                    : null,
                                onTap: () => Navigator.pop(sheet, item)),
                        ]))));
            if (context.mounted && choice != null) setValue(choice);
          }));
}
