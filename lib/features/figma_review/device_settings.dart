import 'package:flutter/material.dart';

import 'core.dart';

Future<bool> chooseDeviceSaving(
    BuildContext context, ReviewController controller) async {
  final enable = await showDialog<bool>(
    context: context,
    animationStyle: AnimationStyle.noAnimation,
    builder: (context) => AlertDialog(
      scrollable: true,
      title: const Text('다음 방문에도 기록을 볼까요?'),
      content: const Text(
          '내 기기에 저장하면 다음에 이 브라우저로 보답을 열었을 때 기록과 일정을 이어서 볼 수 있어요. 함께 쓰는 기기에서는 다른 사람도 볼 수 있어요.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('이번에만 사용'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('내 기기에 저장'),
        ),
      ],
    ),
  );
  if (enable == true && context.mounted) {
    return controller.enableDeviceSaving();
  }
  return false;
}

class BodabDeviceSettings extends StatelessWidget {
  const BodabDeviceSettings({super.key});

  Future<void> _clear(BuildContext context, ReviewController controller) async {
    final clear = await showDialog<bool>(
      context: context,
      animationStyle: AnimationStyle.noAnimation,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: const Text('이 기기의 보답 기록을 지울까요?'),
        content: const Text(
            '이 브라우저의 보답 기록, 일정, 보관한 상담, 연락처와 돌봄 요청을 모두 지워요. 지운 기록은 복구할 수 없어요.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xff8c3932)),
            child: const Text('모두 지우기'),
          ),
        ],
      ),
    );
    if (clear == true && context.mounted) {
      await controller.clearDeviceData();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = ReviewScope.of(context);
    final enabled = controller.deviceSavingEnabled;
    return ReviewCard(
        child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionLabel('내 기기의 기록'),
        const SizedBox(height: 8),
        Caption(enabled
            ? '이 브라우저에 저장 중이에요. 브라우저 데이터를 지우면 기록도 삭제돼요.'
            : '지금은 새로고침하면 기록이 사라져요. 내 기기에 저장하면 다음에도 볼 수 있어요.'),
        const SizedBox(height: 12),
        if (!enabled)
          ReviewButton(
              '내 기기에 저장',
              controller.storageBusy
                  ? null
                  : () => chooseDeviceSaving(context, controller)),
        TextButton(
          onPressed:
              controller.storageBusy ? null : () => _clear(context, controller),
          child: const Text('이 기기의 기록 모두 지우기'),
        ),
      ],
    ));
  }
}

class BodabStorageNotice extends StatelessWidget {
  const BodabStorageNotice({super.key, required this.controller});
  final ReviewController controller;

  @override
  Widget build(BuildContext context) => Semantics(
        liveRegion: true,
        child: Material(
          color: const Color(0xfffff0db),
          child: Padding(
            padding: const EdgeInsets.only(left: 16, right: 4),
            child: Row(children: [
              Expanded(
                  child: Text(controller.storageError ?? '',
                      style: const TextStyle(fontSize: 16))),
              TextButton(
                  onPressed: controller.storageBusy
                      ? null
                      : controller.retryDeviceStorage,
                  child: const Text('다시 시도')),
            ]),
          ),
        ),
      );
}
