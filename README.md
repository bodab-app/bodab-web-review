# 보답 웹앱 구현 소스

보답 창업동아리가 개발한 어르신 건강 기록·가족 돌봄 웹앱의 검수용 소스입니다. 로로프론트는 UI/UX 디자인과 자문을 맡았습니다. 보답팀은 전달받은 화면 디자인을 바탕으로 앱을 구현했습니다.

[설치 없이 보답 예시 계정 열기](https://bodab-app.pages.dev/?account=sample)

## 시연 영상과 코드 대조

영상의 시간은 학교에 제출할 4분 30초 시연본 기준입니다. 예시 계정에는 오늘 일정과 지난 건강 기록, 이어서 열 수 있는 팻봇 대화가 들어 있습니다.

| 영상 | 확인할 동작 | 관련 소스 |
|---|---|---|
| 00:00 | 수면·식사를 기록하고 수면 답만 수정합니다. | [데일리큐](lib/features/figma_review/daily.dart) · [예시 계정 초기값](lib/features/figma_review/example_account.dart) |
| 00:36 | 산책 상담을 이어 쓰고 복약 상담과 오갑니다. | [팻봇 카드](lib/features/figma_review/petbot_card.dart) · [대화 보관과 복원](lib/features/figma_review/health_chat_sessions.dart) · [대화 응답](lib/features/figma_review/health_chat_dialogue.dart) |
| 01:12–01:59 | 기존 산책 일정을 변경하고, 복용 여부를 기록하고, 건강 자료 PDF를 엽니다. | [일정과 캘린더](lib/features/figma_review/calendar_export.dart) · [복약·건강 자료·활동](lib/features/figma_review/health.dart) |
| 02:13 | 가족에게 전달할 기록을 선택하고 기관 문의를 남깁니다. | [가족·기관 화면](lib/features/figma_review/care.dart) · [전달할 내용 구성](lib/features/figma_review/care_handoff.dart) |
| 02:49 | 처방 사진과 측정표를 읽고, 인식한 값 중 확인한 항목만 저장합니다. | [브라우저 사진 인식](tool/ocr/photo_ocr.mjs) · [처방 항목](lib/features/figma_review/prescription_photo_fields.dart) · [측정값](lib/features/figma_review/health_photo_fields.dart) |
| 04:04 | 브라우저를 다시 열어 저장한 기록을 확인하고 디자인 화면 목록을 살펴봅니다. | [기기 저장·삭제](lib/features/figma_review/device_store_web.dart) · [8개 과업과 41개 화면의 대응표](lib/features/figma_review/screens.dart) |

팻봇은 기기 안에서 대화의 앞선 내용과 정해진 건강정보 안내를 바탕으로 답합니다. 사진의 글자 인식도 브라우저에서 실행됩니다. 기록 보관을 선택하면 해당 브라우저에 저장됩니다.

## 내 컴퓨터에서 실행

빌드에는 Flutter 3.44.8, Node.js 22와 npm, Python 3을 사용했습니다. 처음에는 공개 패키지와 한글·영문 글자 인식 모델을 내려받을 인터넷 연결이 필요합니다. 저장소 루트에서 아래 두 명령을 실행합니다.

```sh
sh tool/build_web.sh
python3 -m http.server 8080 --bind 127.0.0.1 --directory build/web
```

[내 컴퓨터에서 예시 계정 열기](http://127.0.0.1:8080/?account=sample) · [디자인 화면 목록 열기](http://127.0.0.1:8080/review/)

이 버전은 시연에 쓰인 보답 웹 기능을 검토자가 독립적으로 빌드하도록 구성했습니다. 웹 시작 파일과 의존성을 정리했고, 내보내는 캘린더 일정의 식별자에는 검수본 전용 접미사를 사용합니다. 브라우저 시간대에 따라 오늘 일정의 날짜가 정해집니다.

글꼴 이용 조건은 [Noto Sans KR 고지](assets/fonts/NotoSansKR_OFL.txt)에, 사진 인식 모델과 엔진의 출처는 [모델 고지](tool/ocr/NOTICE-models.txt)와 [공개 패키지 목록](tool/ocr/package.json)에 있습니다. 빌드 시 인식 엔진·모델과 함께 해당 라이선스 파일도 복사합니다.
