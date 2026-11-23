import 'package:flutter/material.dart';

import '../../../config/theme/bodab_colors.dart';
import '../../../config/theme/bodab_typography.dart';
import '../../../l10n/app_localizations.dart';

/// 호서대학교 앵커사업단 지원 사사 문구.
///
/// 로그인 화면과 내 정보 화면 하단에 작은 보조 글씨로 보여 준다. 어르신이
/// 읽을 수 있도록 bodySmall(16) 이상을 유지하고, 화면 낭독기가 읽도록
/// Semantics 로 감싼다. 한국어 문구는 낱말 중간에서 줄이 갈리지 않도록
/// 번역 문자열에 줄바꿈을 직접 넣는다.
class FundingAcknowledgement extends StatelessWidget {
  const FundingAcknowledgement({super.key});

  @override
  Widget build(BuildContext context) {
    final text = AppLocalizations.of(context).fundingAcknowledgement;
    return Semantics(
      container: true,
      // 화면 줄바꿈은 낭독에 필요 없으므로 한 문장으로 읽힌다.
      label: text.replaceAll('\n', ' '),
      excludeSemantics: true,
      child: Text(
        text,
        key: const ValueKey('funding-acknowledgement'),
        textAlign: TextAlign.center,
        style: BodabTypography.bodySmall.copyWith(
          color: BodabColors.textSecondary,
        ),
      ),
    );
  }
}
