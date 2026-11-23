import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'core.dart'
    show
        ReviewIcon,
        reviewBackground,
        reviewGreen,
        reviewInk,
        reviewLine,
        reviewTint;
import 'health_chat_sessions.dart';
import 'petbot_card.dart';

const _body = TextStyle(fontSize: 18, height: 1.55, color: reviewInk);
const _small = TextStyle(fontSize: 15, height: 1.4, color: Color(0xff485b50));
const _title = TextStyle(
    fontSize: 22, height: 1.35, fontWeight: FontWeight.w700, color: reviewInk);
const _danger = Color(0xff922a24);
const _starters = [
  ('pill', '약 복용', '약 복용에 대해 물어볼게요'),
  ('heart', '몸 상태', '몸 상태를 정리하고 싶어요'),
  ('document', '진료 준비', '진료를 준비하고 싶어요'),
  ('activity', '생활습관', '생활습관을 돌아보고 싶어요'),
];

class HealthChatView extends StatefulWidget {
  const HealthChatView(
      {super.key,
      required this.onBack,
      required this.onOpenAppRoute,
      this.sessions,
      this.onSaveToDevice,
      this.deviceSavingEnabled = false});

  final VoidCallback onBack;
  final ValueChanged<String> onOpenAppRoute;
  final HealthChatSessions? sessions;
  final Future<void> Function(String id)? onSaveToDevice;
  final bool deviceSavingEnabled;

  @override
  State<HealthChatView> createState() => _HealthChatViewState();
}

class _HealthChatViewState extends State<HealthChatView> {
  final _draft = TextEditingController();
  final _focus = FocusNode();
  final _scroll = ScrollController();
  final _replyAnchor = GlobalKey();
  late HealthChatSessions _sessions;
  String? get _active => _sessions.activeId;
  bool _showList = false;
  String? _savingId;
  final _drafts = <String?, String>{};

  @override
  void initState() {
    super.initState();
    _sessions = widget.sessions ?? HealthChatSessions();
    if (_active != null) _showLastReply();
  }

  @override
  void didUpdateWidget(HealthChatView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.sessions == widget.sessions) return;
    if (oldWidget.sessions == null) _sessions.dispose();
    _sessions = widget.sessions ?? HealthChatSessions();
    if (_active != null) _showLastReply();
    _drafts.clear();
    _draft.clear();
    _showList = false;
  }

  @override
  void dispose() {
    if (widget.sessions == null) _sessions.dispose();
    _draft.dispose();
    _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _showLastReply() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final anchor = _replyAnchor.currentContext;
      if (mounted && anchor != null) {
        Scrollable.ensureVisible(anchor, alignment: 0.04);
      }
    });
  }

  void _ask(String input) {
    final question = input.trim();
    if (question.isEmpty) return;
    _focus.unfocus();
    final current = _active;
    final id = current != null && _sessions.byId(current) != null
        ? current
        : _sessions.create(question);
    _sessions.send(id, question);
    _drafts.remove(current);
    _draft.clear();
    setState(() => _sessions.activeId = id);
    _showLastReply();
  }

  void _list() {
    _focus.unfocus();
    _drafts[_active] = _draft.text;
    setState(() => _showList = true);
  }

  void _open(String? id, {bool fresh = false}) {
    _focus.unfocus();
    setState(() {
      _showList = false;
      _sessions.activeId = id;
      _draft.text = fresh ? '' : _drafts[id] ?? '';
      _draft.selection = TextSelection.collapsed(offset: _draft.text.length);
    });
    if (id != null) _showLastReply();
    if (id == null && _scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _link(Uri uri) async {
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      // A browser or dialler may be unavailable on this device.
    }
    if (!mounted || opened) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
      uri.scheme == 'tel'
          ? '전화 앱을 열 수 없어요. 전화에서 119를 누르세요.'
          : '이 기기에서 출처를 열 수 없어요.',
    )));
  }

  Future<void> _save(String id) async {
    final save = widget.onSaveToDevice;
    if (save == null || _savingId != null) return;
    setState(() => _savingId = id);
    try {
      await save(id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('이 상담을 보관하지 못했어요. 다시 시도해 주세요.')));
      }
    } finally {
      if (mounted) setState(() => _savingId = null);
    }
  }

  Widget _saveAction(HealthChatSession session) {
    if (session.retained &&
        widget.deviceSavingEnabled &&
        _savingId != session.id) {
      return const Row(children: [
        Icon(Icons.bookmark, color: reviewGreen, size: 18),
        SizedBox(width: 6),
        Expanded(child: Text('이 기기에 보관 중', style: _small)),
      ]);
    }
    return Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _savingId == null ? () => _save(session.id) : null,
          icon: const Icon(Icons.bookmark_add_outlined, size: 20),
          label: Text(_savingId == session.id ? '보관 중…' : '이 상담 기기에 보관'),
          style: TextButton.styleFrom(
              minimumSize: const Size(48, 48), foregroundColor: reviewGreen),
        ));
  }

  Future<void> _manage(HealthChatSession session, String action) async {
    if (action == 'save') {
      await _save(session.id);
      return;
    }
    if (action == 'rename') {
      final name = await showDialog<String>(
        context: context,
        animationStyle: AnimationStyle.noAnimation,
        builder: (_) => _RenameDialog(initial: session.title),
      );
      if (mounted && name != null && _sessions.byId(session.id) != null) {
        _sessions.rename(session.id, name);
      }
      return;
    }
    final remove = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (dialog) => AlertDialog(
        scrollable: true,
        title: const Text('상담을 삭제할까요?'),
        content: Text('‘${session.title}’의 질문과 답변이 지워져요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialog, false),
              child: const Text('취소')),
          TextButton(
              onPressed: () => Navigator.pop(dialog, true),
              child: const Text('삭제하기', style: TextStyle(color: _danger))),
        ],
      ),
    );
    if (!mounted || remove != true) return;
    _drafts.remove(session.id);
    if (_active == session.id) {
      _sessions.activeId = null;
      _draft.clear();
    }
    _sessions.remove(session.id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: reviewBackground,
      body: SafeArea(
          child: Center(
              child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 680),
        child: AnimatedBuilder(
            animation: _sessions,
            builder: (context, _) {
              if (_showList) {
                return Column(children: [
                  Expanded(child: _sessionList()),
                  _emergencyAction()
                ]);
              }
              final session = _active == null ? null : _sessions.byId(_active!);
              final turns = session?.turns ?? const <HealthChatTurn>[];
              return LayoutBuilder(builder: (context, bounds) {
                final short = bounds.maxHeight <
                    MediaQuery.textScalerOf(context).scale(200);
                final header = _header(session?.title);
                return Column(children: [
                  if (!short) header,
                  Expanded(
                      child: SingleChildScrollView(
                    controller: _scroll,
                    child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (short) header,
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 18, 16, 22),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (turns.isEmpty) _welcome(),
                                  for (var i = 0; i < turns.length; i++)
                                    _turn(turns[i], i, i == turns.length - 1),
                                  if (session != null &&
                                      widget.onSaveToDevice != null)
                                    _saveAction(session),
                                ]),
                          ),
                        ]),
                  )),
                  _emergencyAction(),
                  ConstrainedBox(
                      constraints: BoxConstraints(
                          maxHeight: bounds.maxHeight * (short ? .55 : .4)),
                      child: SingleChildScrollView(child: _composer())),
                ]);
              });
            }),
      ))),
    );
  }

  Widget _header(String? name) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
        decoration: const BoxDecoration(
            color: reviewBackground,
            border: Border(bottom: BorderSide(color: reviewLine))),
        child: Row(children: [
          IconButton(
              tooltip: '이전',
              icon: const ReviewIcon('back'),
              onPressed: widget.onBack),
          if (MediaQuery.textScalerOf(context).scale(18) < 30)
            const PetbotPortrait(size: 30),
          const SizedBox(width: 6),
          Expanded(
              child: Semantics(
                  header: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name ?? '팻봇 건강상담',
                          style: _title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis),
                      Text(name == null ? '기기 안 안내' : '팻봇 · 기기 안 안내',
                          style: _small),
                    ],
                  ))),
          const SizedBox(width: 4),
          _listButton(),
        ]),
      );

  Widget _listButton() {
    // Large text keeps all of the header width available to the heading.
    if (MediaQuery.textScalerOf(context).scale(18) > 24) {
      return IconButton(
          tooltip: '상담 목록',
          icon: const Icon(Icons.forum_outlined),
          onPressed: _list);
    }
    return TextButton.icon(
        onPressed: _list,
        icon: const Icon(Icons.forum_outlined, size: 20),
        label: const Text('상담 목록'),
        style: TextButton.styleFrom(
            foregroundColor: reviewGreen, minimumSize: const Size(48, 48)));
  }

  Widget _welcome() =>
      Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Semantics(
            header: true,
            child: const Text('어떤 점이 궁금하세요?',
                style: TextStyle(
                  fontSize: 27,
                  height: 1.4,
                  fontWeight: FontWeight.w700,
                  color: reviewInk,
                ))),
        const SizedBox(height: 6),
        const Text('주제를 고르거나 아래에 질문을 적어 주세요.', style: _body),
        const SizedBox(height: 20),
        for (final starter in _starters)
          Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Material(
                color: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: const BorderSide(color: reviewLine)),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _ask(starter.$3),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 14),
                    child: Row(children: [
                      ReviewIcon(starter.$1),
                      const SizedBox(width: 14),
                      Expanded(
                          child: Text(starter.$2,
                              style:
                                  _body.copyWith(fontWeight: FontWeight.w600))),
                      const ReviewIcon('chevron', size: 20),
                    ]),
                  ),
                ),
              )),
      ]);

  Widget _turn(HealthChatTurn turn, int index, bool last) {
    final reply = turn.reply;
    final source = Uri.tryParse(reply.sourceUrl ?? '');
    final route = reply.appRoute;
    final action = reply.appActionLabel;
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Align(
            alignment: Alignment.centerRight,
            child: Padding(
              padding: const EdgeInsets.only(left: 28),
              child: DecoratedBox(
                  decoration: BoxDecoration(
                      color: reviewGreen,
                      borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      child: Semantics(
                          label: '내 질문',
                          child: Text(turn.question,
                              style: _body.copyWith(color: Colors.white))))),
            )),
        const SizedBox(height: 8),
        Container(
          key: ValueKey('health-chat-answer-$index'),
          decoration: BoxDecoration(
              color: reply.urgent ? const Color(0xfffff1ee) : Colors.white,
              border: Border.all(color: reply.urgent ? _danger : reviewLine),
              borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.all(16),
          child: Column(
              key: last ? _replyAnchor : null,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (reply.urgent)
                  const Text('긴급 안내',
                      style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: _danger)),
                Semantics(
                    liveRegion: last, child: Text(reply.text, style: _body)),
                if (reply.urgent)
                  _action(
                      '119 전화하기', () => _link(Uri(scheme: 'tel', path: '119')),
                      color: _danger),
                if (route != null && action != null)
                  _action(action, () => widget.onOpenAppRoute(route)),
                if (source != null &&
                    source.isScheme('https') &&
                    source.host.isNotEmpty &&
                    source.userInfo.isEmpty)
                  _action('자료 출처 보기', () => _link(source)),
              ]),
        ),
        if (last && reply.suggestions.isNotEmpty)
          Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 6, runSpacing: 6, children: [
                for (final item in reply.suggestions)
                  OutlinedButton(
                      onPressed: () => _ask(item),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: reviewGreen,
                        minimumSize: const Size(48, 48),
                        side: const BorderSide(color: reviewGreen),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 6),
                      ),
                      child: Text(item, style: const TextStyle(fontSize: 16))),
              ])),
      ]),
    );
  }

  Widget _action(String label, VoidCallback onTap,
          {Color color = reviewGreen}) =>
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton(
            onPressed: onTap,
            style: TextButton.styleFrom(
                foregroundColor: color, minimumSize: const Size(48, 48)),
            child: Text(label,
                style: const TextStyle(
                    fontSize: 17, fontWeight: FontWeight.w700))),
      );

  Widget _emergencyAction() => Align(
        alignment: Alignment.centerRight,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: TextButton.icon(
            onPressed: () => _link(Uri(scheme: 'tel', path: '119')),
            icon: const Icon(Icons.phone_outlined, size: 18),
            label: const Text('응급 시 119', style: TextStyle(fontSize: 16)),
            style: TextButton.styleFrom(
                foregroundColor: _danger, minimumSize: const Size(48, 48)),
          ),
        ),
      );

  Widget _composer() => DecoratedBox(
        decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: reviewLine))),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
            Expanded(
                child: TextField(
              key: const ValueKey('health-chat-input'),
              controller: _draft,
              focusNode: _focus,
              minLines: 1,
              maxLines: 3,
              textInputAction: TextInputAction.send,
              onSubmitted: _ask,
              style: _body,
              autocorrect: false,
              enableSuggestions: false,
              enableIMEPersonalizedLearning: false,
              decoration: InputDecoration(
                labelText: '질문 입력',
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
            )),
            const SizedBox(width: 8),
            ValueListenableBuilder(
                valueListenable: _draft,
                builder: (context, value, _) => IconButton.filled(
                      key: const ValueKey('health-chat-send'),
                      tooltip: '보내기',
                      onPressed: value.text.trim().isEmpty
                          ? null
                          : () => _ask(_draft.text),
                      icon: const Icon(Icons.arrow_upward_rounded),
                      style: IconButton.styleFrom(
                        minimumSize: const Size(48, 48),
                        backgroundColor: reviewGreen,
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: reviewTint,
                        disabledForegroundColor: const Color(0xff637467),
                      ),
                    )),
          ]),
        ),
      );

  Widget _sessionList() =>
      ListView(padding: const EdgeInsets.fromLTRB(16, 10, 16, 24), children: [
        Row(children: [
          IconButton(
              tooltip: '이전',
              icon: const ReviewIcon('back'),
              onPressed: () => _open(_active)),
          const SizedBox(width: 6),
          Expanded(
              child: Semantics(
                  header: true, child: const Text('상담 목록', style: _title))),
        ]),
        const SizedBox(height: 16),
        FilledButton.icon(
            onPressed: () => _open(null, fresh: true),
            icon: const Icon(Icons.add),
            style: FilledButton.styleFrom(
                backgroundColor: reviewGreen, minimumSize: const Size(48, 52)),
            label: const Text('새 상담', style: TextStyle(fontSize: 18))),
        const SizedBox(height: 16),
        if (widget.onSaveToDevice != null)
          const Text('다음 방문에도 볼 상담은 ‘이 상담 기기에 보관’을 눌러 주세요.', style: _small),
        const SizedBox(height: 12),
        if (_sessions.sessions.isEmpty)
          const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text('아직 상담이 없어요. 새 상담에서 첫 질문을 적어 보세요.', style: _body)),
        for (final session in _sessions.sessions)
          Padding(
            key: ValueKey('session-${session.id}'),
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: Colors.white,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: reviewLine)),
              child: Row(children: [
                Expanded(
                    child: InkWell(
                  onTap: () => _open(session.id),
                  borderRadius: BorderRadius.circular(16),
                  child: Padding(
                      padding: const EdgeInsets.all(15),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(session.title,
                                style: _body.copyWith(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(height: 4),
                            if (session.retained && widget.deviceSavingEnabled)
                              const Text('이 기기에 보관 중', style: _small),
                            Text(_date(session.updatedAt.toLocal()),
                                style: _small),
                          ])),
                )),
                PopupMenuButton<String>(
                    popUpAnimationStyle: AnimationStyle.noAnimation,
                    tooltip: '상담 관리',
                    onSelected: (v) => _manage(session, v),
                    itemBuilder: (_) => [
                          if (widget.onSaveToDevice != null &&
                              !(session.retained && widget.deviceSavingEnabled))
                            const PopupMenuItem(
                                value: 'save', child: Text('이 상담 기기에 보관')),
                          const PopupMenuItem(
                              value: 'rename', child: Text('이름 변경')),
                          const PopupMenuItem(
                              value: 'delete', child: Text('상담 삭제')),
                        ]),
              ]),
            ),
          ),
      ]);

  String _date(DateTime date) =>
      '${date.year}년 ${date.month}월 ${date.day}일 ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});
  final String initial;
  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _input = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
        scrollable: true,
        title: const Text('상담 이름 변경'),
        content: TextField(
            controller: _input,
            autofocus: true,
            enableIMEPersonalizedLearning: false,
            autocorrect: false,
            enableSuggestions: false,
            maxLines: 2,
            minLines: 1,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(labelText: '상담 이름'),
            onSubmitted: (v) {
              if (v.trim().isNotEmpty) Navigator.pop(context, v.trim());
            }),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context), child: const Text('취소')),
          ValueListenableBuilder(
              valueListenable: _input,
              builder: (_, value, child) => TextButton(
                  onPressed: value.text.trim().isEmpty
                      ? null
                      : () => Navigator.pop(context, _input.text.trim()),
                  child: const Text('변경하기'))),
        ],
      );
}
