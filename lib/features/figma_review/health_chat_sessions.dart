import 'dart:math';

import 'package:flutter/foundation.dart';
import 'device_store_api.dart';
import 'health_chat_dialogue.dart';

final _random = Random.secure();
String _id() => List.generate(
    16, (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0')).join();

class HealthChatTurn {
  HealthChatTurn(this.id, this.at, this.question, this.reply);
  final String id, question;
  final DateTime at;
  final HealthChatReply reply;

  Map<String, Object?> toJson() => {
        'at': at.toUtc().toIso8601String(),
        'question': question,
        'text': reply.text,
        'suggestions': reply.suggestions,
        'urgent': reply.urgent,
        if (reply.appRoute != null) 'route': reply.appRoute,
        if (reply.appActionLabel != null) 'action': reply.appActionLabel,
        if (reply.sourceUrl != null) 'source': reply.sourceUrl,
      };

  static HealthChatTurn? read(String id, Object? raw) {
    if (raw is! Map ||
        raw['at'] is! String ||
        raw['question'] is! String ||
        raw['text'] is! String) {
      return null;
    }
    final at = DateTime.tryParse(raw['at'] as String)?.toLocal();
    if (at == null) return null;
    String? field(String key) => raw[key] is String ? raw[key] as String : null;
    final suggestions = raw['suggestions'];
    return HealthChatTurn(
        id,
        at,
        raw['question'] as String,
        HealthChatReply(raw['text'] as String,
            suggestions: suggestions is List
                ? suggestions.whereType<String>().toList()
                : const [],
            urgent: raw['urgent'] == true,
            appRoute: field('route'),
            appActionLabel: field('action'),
            sourceUrl: field('source')));
  }
}

class HealthChatSession {
  HealthChatSession._(this.id, this.title, this.createdAt);
  final String id;
  String title;
  final DateTime createdAt;
  bool retained = false;
  final List<HealthChatTurn> _turns = [];
  final _dialogue = HealthChatDialogue();
  List<HealthChatTurn> get turns => List.unmodifiable(_turns);
  DateTime get updatedAt => _turns.isEmpty ? createdAt : _turns.last.at;
}

class HealthChatSessions extends ChangeNotifier implements ReviewSavedModel {
  HealthChatSessions({this.onChanged});
  HealthChatSessions.example(DateTime at) : onChanged = null {
    _restoreExample(at);
  }
  final VoidCallback? onChanged;
  static const _exampleId = 'example-walk';
  DateTime? _exampleAt;

  void _restoreExample(DateTime? at) {
    if (_exampleAt == at) return;
    _exampleAt = at;
    if (_sessions[_exampleId]?.retained == true) return;
    _sessions.remove(_exampleId);
    if (at == null) return;
    final thread = HealthChatSession._(_exampleId, '산책과 몸 상태', at);
    const opening = '산책한 날의 몸 상태를 기록하고 싶어요.';
    const detail = '점심 뒤 공원을 천천히 걸었어요.';
    thread._turns.add(HealthChatTurn('example-walk-opening', at, opening,
        thread._dialogue.replyTo(opening)));
    thread._turns.add(HealthChatTurn(
        'example-walk-detail',
        at.add(const Duration(minutes: 1)),
        detail,
        thread._dialogue.replyTo(detail)));
    _sessions[_exampleId] = thread;
    activeId ??= _exampleId;
  }

  String? activeId;
  final Map<String, HealthChatSession> _sessions = {};

  @override
  String get storageKey => 'healthChat';
  List<HealthChatSession> get sessions => _sessions.values.toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  HealthChatSession? byId(String id) => _sessions[id];

  String _title(String input) {
    final text = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    return text.isEmpty ? '새 상담' : String.fromCharCodes(text.runes.take(60));
  }

  String create(String firstQuestion) {
    final id = _id();
    _sessions[id] =
        HealthChatSession._(id, _title(firstQuestion), DateTime.now());
    notifyListeners();
    return id;
  }

  HealthChatReply send(String id, String question) {
    final thread = _sessions[id];
    final input = question.trim();
    if (thread == null || input.isEmpty) {
      return const HealthChatReply('새 상담에서 질문을 입력해 주세요.');
    }
    final reply = thread._dialogue.replyTo(input);
    final now = DateTime.now();
    final at = now.isAfter(thread.updatedAt)
        ? now
        : thread.updatedAt.add(const Duration(microseconds: 1));
    thread._turns.add(HealthChatTurn(_id(), at, input, reply));
    _changed(thread.retained);
    return reply;
  }

  void rename(String id, String title) {
    final thread = _sessions[id];
    if (thread == null || title.trim().isEmpty) return;
    thread.title = _title(title);
    _changed(thread.retained);
  }

  void setRetained(String id, bool value) {
    final thread = _sessions[id];
    if (thread == null || thread.retained == value) return;
    thread.retained = value;
    if (id == _exampleId && value) _exampleAt = null;
    _changed(true);
  }

  void remove(String id) {
    final removed = _sessions.remove(id);
    if (activeId == id) activeId = null;
    final example = id == _exampleId && _exampleAt != null;
    if (example) _exampleAt = null;
    if (removed != null) _changed(removed.retained || example);
  }

  void _changed(bool affectsStorage) {
    if (affectsStorage) onChanged?.call();
    notifyListeners();
  }

  // The vault merges per key. Storing each turn independently preserves two
  // different messages appended in parallel by two tabs of the same browser.
  @override
  Map<String, Object?> exportSavedState() => {
        if (_exampleAt != null)
          'exampleCreated': _exampleAt!.toUtc().toIso8601String(),
        for (final s in _sessions.values.where((s) => s.retained)) ...{
          'thread/${s.id}': {
            'title': s.title,
            'created': s.createdAt.toUtc().toIso8601String()
          },
          for (final t in s._turns) 'turn/${s.id}/${t.id}': t.toJson(),
        }
      };

  @override
  void restoreSavedState(Map<String, Object?> data) {
    final restored = <String, HealthChatSession>{};
    for (final e in data.entries) {
      final raw = e.value;
      if (!e.key.startsWith('thread/') ||
          raw is! Map ||
          raw['title'] is! String ||
          raw['created'] is! String) {
        continue;
      }
      final at = DateTime.tryParse(raw['created'] as String)?.toLocal();
      if (at == null) continue;
      final id = e.key.substring('thread/'.length);
      restored[id] = HealthChatSession._(id, _title(raw['title'] as String), at)
        ..retained = true;
    }
    for (final e in data.entries) {
      final key = e.key.split('/');
      if (key.length != 3 || key.first != 'turn') continue;
      final thread = restored[key[1]];
      final t = HealthChatTurn.read(key.last, e.value);
      if (thread != null && t != null) thread._turns.add(t);
    }
    for (final thread in restored.values) {
      thread._turns.sort((a, b) {
        final order = a.at.compareTo(b.at);
        return order == 0 ? a.id.compareTo(b.id) : order;
      });
      // Reconstruct follow-up context while keeping the exact replies originally shown.
      for (final turn in thread._turns) {
        thread._dialogue.replyTo(turn.question);
      }
    }
    _sessions.removeWhere((_, thread) => thread.retained);
    _sessions.addAll(restored);
    final exampleDate = data['exampleCreated'];
    _restoreExample(exampleDate is String
        ? DateTime.tryParse(exampleDate)?.toLocal()
        : null);
    if (!_sessions.containsKey(activeId)) activeId = null;
    notifyListeners();
  }
}
