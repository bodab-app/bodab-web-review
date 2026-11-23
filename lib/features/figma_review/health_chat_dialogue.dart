/// A reply shown inside a single, on-device conversation.
class HealthChatReply {
  const HealthChatReply(
    this.text, {
    this.suggestions = const [],
    this.appRoute,
    this.appActionLabel,
    this.sourceUrl,
    this.urgent = false,
  });

  final String text;
  final List<String> suggestions;
  final String? appRoute;
  final String? appActionLabel;
  final String? sourceUrl;
  final bool urgent;
}

const _healthPortal =
    'https://health.kdca.go.kr/healthinfo/biz/health/ntcnInfo/healthSourc/thtimtCntnts/thtimtCntntsView.do?thtimt_cntnts_sn=';
const _heart = '${_healthPortal}176';
const _sleep = '${_healthPortal}72';
const _medSafety = 'https://www.mfds.go.kr/brd/m_580/view.do?seq=75';
const _missedDose = 'https://health.dobong.go.kr/Contents.asp?code=10004964';
const _emergencyCall =
    'https://www.nfa.go.kr/nfa/safetyinfo/emergencyservice/119emergencydeclaration/';
const _highPressureSource =
    'https://www.heart.org/en/health-topics/high-blood-pressure/understanding-blood-pressure-readings/when-to-call-911-for-high-blood-pressure';
const _topics = ['약 복용', '진료 준비', '수면', '식사'];

enum _Topic {
  open,
  medicine,
  habits,
  sleep,
  meals,
  activity,
  pressure,
  highPressure,
  visit,
  emergency
}

class HealthChatDialogue {
  _Topic _topic = _Topic.open;
  final _visitNotes = <String>[];
  String _lastHabitNote = '';

  HealthChatReply replyTo(String message) {
    final original = message.trim();
    final words = original.toLowerCase().replaceAll(RegExp(r'\s+'), '');
    bool has(String pattern) => RegExp(pattern).hasMatch(words);

    // Check the entire message before continuing an existing conversation.
    if (RegExp(
            r'(지금|당장).{0,6}(자해|목숨을끊|죽으)(?:하려고|려하|려고|려고해|할거|할생각)|(?:죽으려|자해하려).{0,20}(?:삼켰|먹었|마셨)')
        .hasMatch(words)) {
      _topic = _Topic.emergency;
      return const HealthChatReply(
          '말씀해 주셔서 고마워요. 지금 119에 전화해 주세요. 혼자 계시면 가까운 사람에게 바로 와서 곁에 있어 달라고 부탁하세요. '
          '이미 약을 드셨거나 다치셨다면 신고할 때 그 사실과 현재 위치를 알려 주세요.',
          urgent: true,
          sourceUrl: _emergencyCall);
    }
    final describesCurrent = has('지금|현재|방금|갑자기|지속|여전히|계속|오늘도');
    final remoteHistory =
        has('예전에|과거에|지난달|지난해|작년|몇년전|어렸을때|어릴때|지난주') && !describesCurrent;
    final hypothetical = has('예를들어|가령|만약|일반적으로|뜻이|에대해알고|어떤경우|대처법') &&
        !has('지금제가|방금|지금.*(아파요|힘들어요|쉬어지지|있어요)');
    final pressureContext = has('혈압|수축기|이완기|mmhg') ||
        _topic == _Topic.pressure ||
        _topic == _Topic.highPressure;
    final severeReading = pressureContext && _veryHighPressure(words);
    final urgentSign = _hasUrgentSign(words) ||
        ((severeReading || _topic == _Topic.highPressure) &&
            _highPressureSymptom(words));
    if (urgentSign) {
      if (remoteHistory || hypothetical) {
        return const HealthChatReply(
            '그 증상이 실제로 지금 나타나거나 다시 생기면 즉시 119에 전화해 주세요. '
            '과거에 있었던 일이라면 당시 증상과 시각을 의료진에게 알려주세요.',
            sourceUrl: _emergencyCall);
      }
      _topic = _Topic.emergency;
      return const HealthChatReply(
        '지금 바로 119에 전화해 주세요. 주변 사람이 있다면 곁에서 신고를 도와 달라고 하세요. '
        '신고할 때 현재 위치와 어떤 일이 일어났는지 말씀하세요.',
        urgent: true,
        sourceUrl: _emergencyCall,
      );
    }
    if (pressureContext && has('임신|산후|출산후|출산직후')) {
      return const HealthChatReply(
          '임신 중이거나 출산 후라면 지금 잰 혈압과 증상을 산부인과나 분만실에 알려 상담하세요. '
          '새로 생긴 심한 두통이나 시야 변화, 숨쉬기 어려움, 가슴 통증이 있으면 119에 전화하세요.',
          sourceUrl:
              'https://www.cdc.gov/hearher/maternal-warning-signs/index.html');
    }
    if (severeReading) {
      final readingsByTime = words.split(RegExp('지금은|현재는|방금은|오늘은'));
      final latest = readingsByTime.last;
      final earlierReading = (has('어제|예전|지난|작년') && !describesCurrent) ||
          (readingsByTime.length > 1 &&
              _pressurePair.hasMatch(latest) &&
              !_veryHighPressure(latest));
      if (remoteHistory || hypothetical || earlierReading) {
        return const HealthChatReply(
            '예전 수치나 예시는 현재 상태를 알려주지 않아요. 실제로 지금 이 정도 혈압이면서 가슴 통증, 숨참, 시야나 말의 변화가 있으면 119에 전화하세요. '
            '그런 증상이 없어도 1분 이상 뒤 다시 쟀을 때 여전히 높으면 바로 의료진에게 연락하세요.',
            sourceUrl: _highPressureSource);
      }
      _topic = _Topic.highPressure;
      if (has('다시재|두번재|또재|재측정')) return _repeatHighPressure();
      return const HealthChatReply(
          '지금 잰 혈압이라면 가슴 통증, 숨참, 시야가 흐려짐, 갑자기 힘이 빠지거나 말하기 어려운 증상이 있는지 확인해 주세요. '
          '그중 하나라도 있다면 다시 재기를 기다리지 말고 바로 119에 전화하세요. '
          '이런 증상이 없다면 1분 이상 뒤 다시 재고 여전히 높으면 바로 의료진에게 연락하세요. 약을 임의로 더 드시지 마세요.',
          suggestions: ['다시 재도 비슷해요'],
          sourceUrl: _highPressureSource);
    }
    if (_topic == _Topic.highPressure &&
        has('다시재|또재|재측정|비슷|여전히|안내려|그대로|높아|증상은없')) {
      return _repeatHighPressure();
    }
    if (has(r'^(처음부터|새대화|다시시작|초기화|다른주제|그만)[.!?]*$')) {
      _topic = _Topic.open;
      _visitNotes.clear();
      _lastHabitNote = '';
      return const HealthChatReply('다시 시작할게요. 어떤 이야기를 나누고 싶으세요?',
          suggestions: _topics);
    }
    if (original.isEmpty) {
      return const HealthChatReply('궁금한 점을 한 문장으로 보내주세요.',
          suggestions: _topics);
    }
    if (has('응급증상|119.*(언제|신고방법)|뇌졸중|심근경색|응급실.*(가야|갈까|언제)')) {
      return const HealthChatReply(
        '갑자기 가슴이 심하게 조이거나 숨이 많이 찰 때, 한쪽 얼굴이나 팔에 힘이 빠지거나 '
        '말이 갑자기 어눌해질 때는 바로 119에 전화하세요. 채팅으로 응급 여부를 판단할 수는 없어요.',
        sourceUrl: _heart,
      );
    }
    if (_topic == _Topic.emergency &&
        has(r'^(네|예|응|그래|알겠|어떻게|전화|뭐라고|무슨말|도와)')) {
      return const HealthChatReply(
        '119에 현재 주소 또는 주변 건물 이름을 먼저 알려주세요. 지금 보이는 증상을 설명하고 '
        '구급대원의 안내를 따라주세요.',
        urgent: true,
        sourceUrl: _emergencyCall,
      );
    }
    if (has('메모다시보기|진료메모보기|다시보여|메모요약')) {
      return _visitNotes.isEmpty
          ? const HealthChatReply('이 대화에 정리한 진료 메모가 아직 없어요.',
              suggestions: ['진료 준비'])
          : _recap();
    }

    // Explicit topic choices also work in the middle of a note. Ordinary
    // answers may themselves mention a medication or a symptom.
    if (has(r'^(진료준비|진료를준비|진료메모|진료때물어볼내용|몸상태를정리|증상정리|메모다시작성)')) {
      _topic = _Topic.visit;
      _visitNotes.clear();
      return _askOnset();
    }
    if (has(r'^(약복용에대해|약복용[.!?]*$|복약상담|약에대해|다른주제.{0,4}약)')) {
      return _medicineMenu();
    }
    if (has(r'^(생활습관|수면[.!?]*$|식사[.!?]*$|활동[.!?]*$)')) {
      if (has('수면')) return _startHabit(_Topic.sleep);
      if (has('식사')) return _startHabit(_Topic.meals);
      if (has('활동')) return _startHabit(_Topic.activity);
      _topic = _Topic.habits;
      return const HealthChatReply('평소 생활 중 먼저 돌아보고 싶은 것을 골라 주세요.',
          suggestions: ['수면', '식사', '활동']);
    }
    if (has('사진.*(올리|올릴|첨부|등록)|결과표.*(올리|등록)|검사표.*사진')) {
      return const HealthChatReply(
          '자료 사진을 선택한 뒤 표시된 수치와 단위를 원문과 대조해 주세요. '
          '포함하고 싶은 항목만 골라 저장할 수 있어요.',
          appRoute: 'upload',
          appActionLabel: '건강 자료 등록');
    }
    if (_topic == _Topic.visit && _visitNotes.length < 3) {
      return _continueVisit(original);
    }

    if (has('복약|복용|약봉투|약을|약이|약은|약과|약먹|약물|처방|알먹|약효|약끊|약줄|약늘|약바꿔|약빼') ||
        (_topic == _Topic.medicine &&
            has('약|먹|드셨|깜빡|잊|기록|두알|몇알|빼먹|약국|병원|상담|건너|시간|빠뜨|빼도'))) {
      return _medicine(words);
    }
    if (has('혈압|수축기|이완기') ||
        (_topic == _Topic.pressure && has(r'\d|기록|재는|측정|시간|정상'))) {
      _topic = _Topic.pressure;
      final reading = RegExp(r'\b\d{2,3}\s*[/／]\s*\d{2,3}(?!\d)')
          .firstMatch(original)
          ?.group(0);
      return HealthChatReply(
        "${reading == null ? '혈압을 기록할 때는' : '말씀하신 혈압 $reading을 적을 때는'} "
        '측정한 시각과 당시 몸 상태도 함께 적어두세요. 한 번의 수치로 원인이나 정상 여부를 판단하기 어려워요. '
        '반복해 잰 수치와 불편한 점을 진료 때 보여주세요.',
        appRoute: 'checkin',
        appActionLabel: '오늘 건강 메모 쓰기',
        suggestions: const ['결과표 사진을 올릴게요', '진료 준비'],
        sourceUrl: _heart,
      );
    }

    if (_topic == _Topic.sleep ||
        _topic == _Topic.meals ||
        _topic == _Topic.activity) {
      final selected = _habitIn(words);
      if (selected != null && selected != _topic) return _startHabit(selected);
      if (has(r'^(진료|다른걸|다른이야기)')) {
        _topic = _Topic.open;
      } else if (!has('어디가아|아파요|아픕니다|갑자기|어지러|불편해요|진단|병인가|무슨병')) {
        return _habitFollowup(original);
      }
    }
    final habit = _habitIn(words);
    if (habit != null) return _startHabit(habit);
    if (has(
        '아파|아프|두통|어지러|어지럽|열이나|기침|피로|뻐근|불편|컨디션|몸상태|증상|통증|진단|병인가|무슨병|진료|병원')) {
      _topic = _Topic.visit;
      _visitNotes.clear();
      return HealthChatReply(
          '“$original”라고 하셨군요. 원인 판단은 의료진에게 맡기고, 진료 때 전할 내용을 함께 정리할게요. '
          '언제부터 어떤 불편이 있었나요? 시간이 정확하지 않아도 괜찮아요.');
    }
    if (has('메모|건강기록|기록.*(어디|보고|확인)|체크인')) {
      return const HealthChatReply(
          '오늘 몸 상태와 메모는 건강 체크에 적고, 저장된 내용은 기록 탭에서 다시 볼 수 있어요.',
          appRoute: 'checkin',
          appActionLabel: '건강 체크 열기',
          suggestions: ['진료 준비']);
    }
    return const HealthChatReply(
      '이 대화에서는 생활습관, 복약 기록, 진료 전에 전할 내용을 정리하는 일을 도울 수 있어요. '
      '원인을 진단하거나 치료법을 정할 때는 의료진에게 상담해 주세요. 어떤 점이 가장 궁금하세요?',
      suggestions: _topics,
    );
  }

  HealthChatReply _medicineMenu() {
    _topic = _Topic.medicine;
    return const HealthChatReply(
      '어떤 상황인가요? 약을 드셨는지와 보답에 기록하셨는지는 서로 다를 수 있어요.',
      suggestions: ['복용을 잊었어요', '먹었는지 모르겠어요', '복용 기록만 빠졌어요'],
    );
  }

  HealthChatReply _medicine(String words) {
    _topic = _Topic.medicine;
    if (RegExp('기록만|기록을깜빡|기록을빼먹|기록.*(확인|볼래|보고|어디)|체크만').hasMatch(words)) {
      return const HealthChatReply(
          '나의 복약에서 약 이름과 오늘의 기록을 확인해 보세요. '
          '실제로 드신 것이 확실할 때만 복용 기록을 남겨 주세요.',
          appRoute: 'medications',
          appActionLabel: '나의 복약 열기',
          suggestions: ['먹었는지 모르겠어요']);
    }
    if (RegExp('먹었는지|먹었나|복용했는지|드셨는지|기억이안|헷갈').hasMatch(words)) {
      return const HealthChatReply(
          '약 봉투와 남은 약, 오늘 남긴 복용 기록을 먼저 확인해 보세요. '
          '기록이 없어도 실제로 복용했는지는 알 수 없어요. 추가 복용 전에는 조제한 약국이나 처방한 병원에 확인하세요.',
          appRoute: 'medications',
          appActionLabel: '복용 기록 확인',
          suggestions: ['약사에게 뭐라고 물어볼까요?'],
          sourceUrl: _missedDose);
    }
    if (RegExp('잊|깜빡|걸렀|거른|놓쳤|빠뜨|빠트|빼먹|안먹|못먹|두알|두번|두배|2알|2배|한꺼번|건너뛰')
        .hasMatch(words)) {
      return const HealthChatReply(
        '임의로 두 번 분량을 한꺼번에 드시지 마세요. 다음 복용 방법은 약마다 다를 수 있어요. '
        '약 이름, 원래 복용 시각, 마지막으로 드신 시각을 확인해 약사나 처방한 병원에 물어보세요.',
        suggestions: ['약사에게 뭐라고 물어볼까요?', '복용 기록만 빠졌어요'],
        sourceUrl: _missedDose,
      );
    }
    if (RegExp('약사|약국|병원|뭐라고|무엇을|전화|물어').hasMatch(words)) {
      return const HealthChatReply(
        '약 봉투를 곁에 두고 “이 약을 마지막으로 먹은 시각은 ___이고, 오늘 복용 여부는 ___입니다. '
        '다음에는 어떻게 복용하면 될까요?”라고 물어보세요. 함께 먹는 다른 약도 알려주세요.',
        appRoute: 'medications',
        appActionLabel: '약 이름과 기록 확인',
        sourceUrl: _medSafety,
      );
    }
    if (RegExp(
            '끊|중단|그만|바꿔|바꾸|같이|함께|얼마|몇알|용량|늘려|줄여|더먹|많이먹|추가|부작용|먹어도|먹을까|먹어야|중복')
        .hasMatch(words)) {
      return const HealthChatReply(
          '약의 양이나 횟수를 스스로 바꾸기 전에 의사나 약사와 상의하세요. '
          '약 이름과 포장에 적힌 함량, 함께 드시는 약, 어떤 점이 걱정되는지를 알려주면 상담에 도움이 돼요.',
          suggestions: ['약사에게 뭐라고 물어볼까요?', '진료 준비'],
          sourceUrl: _medSafety);
    }
    return _medicineMenu();
  }

  HealthChatReply _askOnset() =>
      const HealthChatReply('진료 때 의료진에게 전할 메모를 함께 정리해요. 언제부터 어떤 점이 불편했나요?');

  HealthChatReply _continueVisit(String answer) {
    _visitNotes.add(answer);
    switch (_visitNotes.length) {
      case 1:
        return HealthChatReply(
            '“$answer”라고 적어둘게요. 처음과 비교해 어떻게 달라졌나요? '
            '어떤 때 더 불편한지도 말씀해 주세요.',
            suggestions: const ['큰 변화는 없어요', '아직 잘 모르겠어요']);
      case 2:
        return const HealthChatReply(
            '진료 때 꼭 물어보고 싶은 것은 무엇인가요? 평소 표현 그대로 적어 주세요.',
            suggestions: ['원인을 알고 싶어요', '생활하면서 무엇을 조심할까요?']);
      default:
        return _recap();
    }
  }

  HealthChatReply _recap() {
    const labels = ['시작과 불편한 점', '달라진 점', '물어볼 것'];
    final lines = [
      for (var i = 0; i < _visitNotes.length; i++)
        '• ${labels[i]} — ${_visitNotes[i]}'
    ];
    return HealthChatReply(
        '진료 때 이렇게 전해 보세요.\n${lines.join('\n')}\n\n이 메모는 현재 대화에서만 볼 수 있어요.',
        suggestions: const ['메모 다시 작성', '다른 주제']);
  }

  _Topic? _habitIn(String words) {
    if (RegExp('수면|잠이|잠을|잠들|숙면|불면|자꾸깨|새벽에깨').hasMatch(words)) {
      return _Topic.sleep;
    }
    if (RegExp('식사|식단|영양|끼니|음식|편식|입맛|밥을').hasMatch(words)) return _Topic.meals;
    if (RegExp('활동|걷기|걸을|산책|운동').hasMatch(words)) return _Topic.activity;
    return null;
  }

  HealthChatReply _startHabit(_Topic topic) {
    _topic = topic;
    _lastHabitNote = '';
    switch (topic) {
      case _Topic.sleep:
        return const HealthChatReply(
            '요즘 잠들기 어렵나요, 자다가 자주 깨나요? '
            '평소 잠자리에 드는 시각과 일어나는 시각을 알려 주세요.',
            suggestions: ['잠들기 어려워요', '새벽에 자꾸 깨요'],
            sourceUrl: _sleep);
      case _Topic.meals:
        return const HealthChatReply(
            '평소 식사에서 가장 신경 쓰이는 부분은 무엇인가요? '
            '끼니를 거르는 때나 자주 드시는 음식을 말씀해 주세요.',
            suggestions: ['아침을 자주 걸러요', '짜게 먹는 편이에요'],
            sourceUrl: _heart);
      case _Topic.activity:
        return const HealthChatReply(
            '평소 편안하게 할 수 있는 활동은 무엇인가요? '
            '보답에서 활동을 골라 끝난 뒤의 몸 상태를 남길 수도 있어요.',
            appRoute: 'activities',
            appActionLabel: '활동 목록 보기',
            suggestions: ['가볍게 걸어요', '진료 준비']);
      default:
        throw StateError('Unexpected habit topic');
    }
  }

  HealthChatReply _habitFollowup(String answer) {
    final previous = _lastHabitNote;
    _lastHabitNote = answer;
    final opening = previous.isEmpty
        ? '“$answer”라고 하셨군요.'
        : '앞서 “$previous”, 이번에는 “$answer”라고 하셨네요.';
    switch (_topic) {
      case _Topic.sleep:
        return HealthChatReply(
            '$opening 잠들고 깬 시각을 며칠 적어보면 본인의 수면 패턴을 돌아볼 수 있어요. '
            '비슷한 시각에 일어나는 습관부터 시도해 보세요. 계속 불편하면 그 기록을 가지고 진료 때 상의하세요.',
            appRoute: 'checkin',
            appActionLabel: '수면 메모 남기기',
            suggestions: const ['진료 준비', '다른 주제'],
            sourceUrl: _sleep);
      case _Topic.meals:
        return HealthChatReply(
            '$opening 오늘 식사 시각과 드신 음식을 적어보세요. '
            '평소에는 규칙적으로 다양한 식품을 골고루 먹는 것이 권장돼요. 의료진이 정해 준 식사 계획이 있으면 그 안내를 따르세요.',
            appRoute: 'checkin',
            appActionLabel: '식사 메모 남기기',
            suggestions: const ['진료 준비', '다른 주제'],
            sourceUrl: _heart);
      default:
        return HealthChatReply(
            '$opening 활동 후의 몸 상태도 함께 남겨두면 다음에 돌아볼 수 있어요. '
            '활동 중 평소와 다른 불편이 생기면 멈추고, 계속되면 의료진과 상의하세요.',
            appRoute: 'activities',
            appActionLabel: '활동 목록 보기',
            suggestions: const ['진료 준비', '다른 주제']);
    }
  }
}

// Either reading is relevant. A timestamp or an unlabelled number in an
// unrelated conversation is not itself a blood pressure measurement.
final _pressurePair = RegExp(r'(\d{2,3})(?:[/／]|에)(\d{2,3})(?!\d)');
final _otherUnit = RegExp(r'^(?:kg|mg|bpm|cm|mmol|kcal|년|월)');

bool _veryHighPressure(String words) {
  for (final pair in _pressurePair.allMatches(words)) {
    if (_otherUnit.hasMatch(words.substring(pair.end))) continue;
    if (int.parse(pair[1]!) >= 180 || int.parse(pair[2]!) >= 120) return true;
  }
  final labelled =
      RegExp(r'(수축기|이완기|최고혈압|최저혈압|혈압)[가-힣]{0,3}?(\d{2,3})(?![\d/／])');
  for (final reading in labelled.allMatches(words)) {
    if (_otherUnit.hasMatch(words.substring(reading.end))) continue;
    final diastolic = reading[1] == '이완기' || reading[1] == '최저혈압';
    if (int.parse(reading[2]!) >= (diastolic ? 120 : 180)) return true;
  }
  return false;
}

bool _highPressureSymptom(String words) {
  final symptom =
      RegExp('시야[가도]?(?:갑자기)?흐려|보는게흐려|눈앞[이도]?흐려|숨[이도]?(?:가빠|차)|한쪽.{0,4}저려');
  return symptom.allMatches(words).any((m) =>
      !RegExp(r'^(?:지|진|지는)?않|^(?:요)?가아니').hasMatch(words.substring(m.end)));
}

HealthChatReply _repeatHighPressure() => const HealthChatReply(
    '지금 의료진에게 연락해 측정한 수치와 시각을 알려주세요. 약은 임의로 조절하지 마세요. '
    '가슴 통증, 숨참, 갑작스러운 시야·말·팔다리 힘의 변화가 있으면 지금 119에 전화하세요.',
    sourceUrl: _highPressureSource);

// Signs can be reported about a family member. Evaluate each match separately
// so a negative about one symptom never cancels a different positive symptom.
bool _hasUrgentSign(String words) {
  final independentDanger = RegExp(
    r'숨[이가을은]?(?:전혀|제대로|잘|거의)?(?:안쉬어|못쉬|쉴수(?:가|도)?없|쉬기[가도]?(?:너무|매우)?힘|쉬지(?:도)?않|쉬어지지않|막혀)|'
    r'(?:의식|호흡|반응|맥박)[이가을은]?(?:전혀)?없|(?:불러도|깨워도)(?:대답|반응)[이은]?없|'
    r'의식[을이은]?(?:갑자기)?(?:잃|잃으|잃었|잃음)|(?:목|목구멍)[이가]?(?:갑자기)?(?:조여|닫히|막혀)|'
    r'(?:약물?|수면제|진통제).{0,6}(?:너무많이|너무많은|한꺼번에여러알)(?:삼켰|먹었|복용했)|'
    r'(?:갑자기)?쓰러져(?:서)?(?:일어나지못|못일어나)|심정지|'
    r'(?:약|수면제|진통제).{0,5}(?:한통|한병|한움큼|과다복용).{0,6}(?:먹|마셨|복용|삼)|'
    r'(?:약물?|수면제|진통제).{0,5}(?:과다복용(?:했|한것|한거)|(?:처방|정량)보다.{0,4}(?:많이|여러알)(?:먹었|먹엇|복용했))|'
    r'(?:죽으려|죽을려고|죽고싶어서|자해하려).{0,20}(?:마셨|삼켰|먹었|중이|하려고)|'
    r'(?:갑자기|난생처음|생애최악).{0,5}(?:극심한|극심하게|매우심한|너무심한)두통',
  );
  final signs = RegExp(
    r'가슴[이가을은]?(?:갑자기|너무|매우|심하게|몹시|꽉|심한|많이)*(?:조이|조여|짓눌|쥐어짜|통증|압박|아프|아파|답답)|흉통|'
    r'호흡곤란|(?:갑자기)?숨[이가은]?(?:갑자기|너무|매우|많이|심하게|몹시)+(?:차|가빠)|'
    r'(?:한쪽|오른쪽|왼쪽|오른|왼)(?:얼굴|팔|다리|팔다리)[이가에은는]?(?:갑자기)?(?:힘이?빠|힘이?없|마비|처져|처지)|'
    r'말[이을은]?(?:갑자기|잘)?(?:어눌|안나|못하)|발음[이은]?(?:갑자기)?어눌|'
    r'(?:갑자기)?(?:눈앞|한쪽눈)[이가은]?(?:갑자기)?(?:안보|보이지않)',
  );
  for (final clause in words.split(RegExp('[,.!?;\n]|그런데|하지만|반면'))) {
    for (final pattern in [independentDanger, signs]) {
      for (final match in pattern.allMatches(clause)) {
        final tail = clause.substring(match.end);
        if (RegExp(r'^(?:이|가|은|는)?(?:없어지|가라앉|사라지|멎)(?:지|질)?않').hasMatch(tail)) {
          return true;
        }
        if (RegExp(
                r'^(?:하|르|지|진|은|는|이|도|가|감|하지|하진|하다고|이라고|하다는|다고|다는){0,3}(?:않|없|아니)|^(?:은|는)?아닌')
            .hasMatch(tail)) {
          continue;
        }
        if (RegExp(r'^(?:이란|이무엇|이뭔|이뭐|의뜻|에대한정보)').hasMatch(tail)) continue;
        return true;
      }
    }
  }
  return false;
}
