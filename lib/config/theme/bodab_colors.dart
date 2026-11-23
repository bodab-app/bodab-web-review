import 'package:flutter/material.dart';

/// 보답 앱 색상 — 온기 있는 신뢰.
///
/// 고령 사용자를 위한 대비는 유지하되, 의료 앱 템플릿처럼 보이던
/// 민트·쨍한 파랑·회청색 배경을 쓰지 않는다. 주조색은 짙은 솔잎색,
/// 강조색은 구리색, 바탕은 따뜻한 종이색으로 제한한다.
abstract final class BodabColors {
  static const Color gradientStart = Color(0xFF17483A);
  static const Color gradientEnd = Color(0xFF17483A);

  // Primary Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [gradientStart, gradientEnd],
  );

  // Primary — elder-first high-contrast evergreen.
  static const Color primary = Color(0xFF17483A);
  static const Color primaryLight = Color(0xFFE1ECE6);
  static const Color primaryDark = Color(0xFF0F3329); // pressed
  static const Color onPrimary = Color(0xFFFFFFFF);

  // Secondary — copper accent. Never use as a large text-button fill.
  static const Color secondary = Color(0xFFC76A3F);
  static const Color secondaryLight = Color(0xFFF3E5DD);
  static const Color secondaryDark = Color(0xFF8D4528);
  static const Color onSecondary = Color(0xFFFFFFFF);

  // Warm paper surfaces.
  static const Color background = Color(0xFFF7F5EF);
  static const Color surface = Color(0xFFFFFEFB);
  static const Color surfaceVariant = Color(0xFFEFEEE8);

  // Text — warm near-black with WCAG-grade secondary contrast.
  static const Color textPrimary = Color(0xFF18211D);
  static const Color textSecondary = Color(0xFF454E48);
  static const Color textTertiary = Color(0xFF5F6862);
  static const Color textHint = Color(0xFF68716B);
  static const Color textDisabled = Color(0xFF8A918C);
  static const Color textOnDark = Color(0xFFFFFFFF);

  // Status
  static const Color success = Color(0xFF176B4B);
  static const Color warning = Color(0xFF8A4B16);
  static const Color error = Color(0xFFA33A36);
  static const Color info = Color(0xFF355E78);

  // Divider & border — visible without turning every card into a gray box.
  static const Color divider = Color(0xFFD9D7D0);
  static const Color border = Color(0xFFD9D7D0);
  static const Color borderFocused = primary;

  // Overlay
  static const Color overlay = Color(0x80000000);
  static const Color scrim = Color(0x52000000);

  // Shadow
  static const Color shadow = Color(0x1418211D);
}

/// 앱 전역 스타일
abstract final class BodabStyles {
  /// 버튼 및 아이콘에 사용할 메인 그라데이션
  static const LinearGradient buttonGradient = BodabColors.primaryGradient;

  /// 부드러운 그림자
  static List<BoxShadow> softShadow = [
    const BoxShadow(
      color: BodabColors.shadow,
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];

  /// 카드 그림자
  static List<BoxShadow> cardShadow = [
    const BoxShadow(
      color: BodabColors.shadow,
      blurRadius: 12,
      offset: Offset(0, 3),
    ),
  ];
}
