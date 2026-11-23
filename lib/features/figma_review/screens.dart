/// 보답 디자인 화면과 기능별 과업의 대응 관계.
typedef ReviewFrame = ({
  String name,
  String node,
  int group,
  String base,
  int width,
  bool large
});
const reviewGroups = <String>[
  "로그인·홈·공통 UI",
  "일정·루틴·알림",
  "건강 체크",
  "복약·처방전",
  "건강 기록·자료 등록",
  "활동·몸 상태 안내",
  "가족 연결·공유",
  "기관 돌봄 요청",
];
const reviewFrames = <String, ReviewFrame>{
  'home': (
    name: '오늘 홈',
    node: '3:2',
    group: 1,
    base: 'home',
    width: 390,
    large: false
  ),
  'login': (
    name: '로그인',
    node: '5:44',
    group: 1,
    base: 'login',
    width: 390,
    large: false
  ),
  'profile': (
    name: '내 정보',
    node: '5:81',
    group: 1,
    base: 'profile',
    width: 390,
    large: false
  ),
  'login_error': (
    name: '로그인 오류',
    node: '5:179',
    group: 1,
    base: 'login_error',
    width: 390,
    large: false
  ),
  'home_360px': (
    name: '360px · 오늘 홈',
    node: '51:79',
    group: 1,
    base: 'home',
    width: 360,
    large: false
  ),
  'home_200%': (
    name: '200% · 오늘 홈',
    node: '51:167',
    group: 1,
    base: 'home',
    width: 390,
    large: true
  ),
  'schedule': (
    name: '일정 목록',
    node: '5:218',
    group: 2,
    base: 'schedule',
    width: 390,
    large: false
  ),
  'routine': (
    name: '일정과 루틴 추가',
    node: '5:315',
    group: 2,
    base: 'routine',
    width: 390,
    large: false
  ),
  'notification': (
    name: '알림 권한',
    node: '5:375',
    group: 2,
    base: 'notification',
    width: 390,
    large: false
  ),
  'notification_done': (
    name: '알림 설정 후',
    node: '5:411',
    group: 2,
    base: 'notification_done',
    width: 390,
    large: false
  ),
  'checkin': (
    name: '건강 체크 질문',
    node: '5:445',
    group: 3,
    base: 'checkin',
    width: 390,
    large: false
  ),
  'checkin_review': (
    name: '건강 체크 확인',
    node: '5:498',
    group: 3,
    base: 'checkin_review',
    width: 390,
    large: false
  ),
  'checkin_done': (
    name: '건강 체크 완료',
    node: '5:543',
    group: 3,
    base: 'checkin_done',
    width: 390,
    large: false
  ),
  'prescription': (
    name: '처방 후보 검토',
    node: '3:98',
    group: 4,
    base: 'prescription',
    width: 390,
    large: false
  ),
  'medications': (
    name: '복약 목록',
    node: '5:581',
    group: 4,
    base: 'medications',
    width: 390,
    large: false
  ),
  'med_detail': (
    name: '복용 자기보고',
    node: '5:631',
    group: 4,
    base: 'med_detail',
    width: 390,
    large: false
  ),
  'med_done': (
    name: '복약 기록 완료',
    node: '5:675',
    group: 4,
    base: 'med_done',
    width: 390,
    large: false
  ),
  'prescription_360px': (
    name: '360px · 처방 후보 검토',
    node: '51:255',
    group: 4,
    base: 'prescription',
    width: 360,
    large: false
  ),
  'prescription_200%': (
    name: '200% · 처방 후보 검토',
    node: '51:313',
    group: 4,
    base: 'prescription',
    width: 390,
    large: true
  ),
  'records': (
    name: '건강 기록 목록',
    node: '5:713',
    group: 5,
    base: 'records',
    width: 390,
    large: false
  ),
  'upload': (
    name: '자료 등록',
    node: '5:802',
    group: 5,
    base: 'upload',
    width: 390,
    large: false
  ),
  'review': (
    name: '추출 항목 확인',
    node: '5:850',
    group: 5,
    base: 'review',
    width: 390,
    large: false
  ),
  'empty': (
    name: '아직 기록이 없어요',
    node: '5:913',
    group: 5,
    base: 'empty',
    width: 390,
    large: false
  ),
  'permission': (
    name: '사진 접근을 허용해 주세요',
    node: '5:942',
    group: 5,
    base: 'permission',
    width: 390,
    large: false
  ),
  'upload_error': (
    name: '자료를 등록하지 못했어요',
    node: '5:978',
    group: 5,
    base: 'upload_error',
    width: 390,
    large: false
  ),
  'upload_loading': (
    name: '자료를 읽고 있어요',
    node: '5:1014',
    group: 5,
    base: 'upload_loading',
    width: 390,
    large: false
  ),
  'activities': (
    name: '활동 목록',
    node: '5:1057',
    group: 6,
    base: 'activities',
    width: 390,
    large: false
  ),
  'activity_detail': (
    name: '활동 상세',
    node: '5:1139',
    group: 6,
    base: 'activity_detail',
    width: 390,
    large: false
  ),
  'body_status': (
    name: '몸 상태 안내',
    node: '5:1181',
    group: 6,
    base: 'body_status',
    width: 390,
    large: false
  ),
  'share': (
    name: '공유 범위와 기간',
    node: '3:164',
    group: 7,
    base: 'share',
    width: 390,
    large: false
  ),
  'family': (
    name: '가족 연결',
    node: '5:1226',
    group: 7,
    base: 'family',
    width: 390,
    large: false
  ),
  'invite': (
    name: '가족 초대',
    node: '5:1276',
    group: 7,
    base: 'invite',
    width: 390,
    large: false
  ),
  'share_done': (
    name: '공유 저장 결과',
    node: '5:1313',
    group: 7,
    base: 'share_done',
    width: 390,
    large: false
  ),
  'revoke': (
    name: '공유 중단 확인',
    node: '5:1355',
    group: 7,
    base: 'revoke',
    width: 390,
    large: false
  ),
  'history': (
    name: '공유 열람 이력',
    node: '5:1396',
    group: 7,
    base: 'history',
    width: 390,
    large: false
  ),
  'share_360px': (
    name: '360px · 공유 범위와 기간',
    node: '51:371',
    group: 7,
    base: 'share',
    width: 360,
    large: false
  ),
  'share_200%': (
    name: '200% · 공유 범위와 기간',
    node: '51:426',
    group: 7,
    base: 'share',
    width: 390,
    large: true
  ),
  'care_select': (
    name: '기관 돌봄 선택',
    node: '5:1433',
    group: 8,
    base: 'care_select',
    width: 390,
    large: false
  ),
  'care_review': (
    name: '돌봄 요청 확인',
    node: '5:1487',
    group: 8,
    base: 'care_review',
    width: 390,
    large: false
  ),
  'care_pending': (
    name: '기관 확인 대기',
    node: '5:1544',
    group: 8,
    base: 'care_pending',
    width: 390,
    large: false
  ),
  'care_accepted': (
    name: '기관 수락 예시',
    node: '5:1595',
    group: 8,
    base: 'care_accepted',
    width: 390,
    large: false
  ),
};

// Team-developed routes are separate from the delivered 41 Figma frames.
const healthChatRoute = 'health-chat';

bool isBodabRoute(String key) =>
    key == healthChatRoute || reviewFrames.containsKey(key);
