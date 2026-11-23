import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import 'care_share_stub.dart' if (dart.library.js_interop) 'care_share_web.dart'
    as platform;

enum CareChannel {
  share('기기 공유창 열기', '기기 공유창 사용'),
  email('메일 작성하기', '메일 작성창 열기 요청'),
  copy('내용 복사하기', '클립보드에 복사');

  const CareChannel(this.action, this.historyLabel);
  final String action;
  final String historyLabel;
}

bool validCareEmail(String email) =>
    email.isEmpty ||
    (email.length <= 254 &&
        RegExp(
          r'^[A-Za-z0-9_+.-]+@[A-Za-z0-9-]+(?:\.[A-Za-z0-9-]+)+$',
        ).hasMatch(email) &&
        !email.contains('..'));

Uri careMailUri(String recipient, String title, String body) {
  if (!validCareEmail(recipient)) {
    throw const FormatException('메일 주소를 확인해 주세요.');
  }
  final query = {'subject': title, 'body': body}
      .entries
      .map((e) =>
          '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
      .join('&');
  return Uri(scheme: 'mailto', path: recipient, query: query);
}

class CareHandoff {
  bool get supportsShareSheet => platform.canUseShareSheet;

  /// Called exclusively after the user previews the content and picks a channel.
  Future<bool> handoff(CareChannel channel,
      {required String recipient,
      required String title,
      required String body}) async {
    switch (channel) {
      case CareChannel.share:
        return platform.openShareSheet(title, body);
      case CareChannel.email:
        return launchUrl(careMailUri(recipient, title, body),
            mode: LaunchMode.externalApplication);
      case CareChannel.copy:
        await Clipboard.setData(ClipboardData(text: body));
        return true;
    }
  }
}
