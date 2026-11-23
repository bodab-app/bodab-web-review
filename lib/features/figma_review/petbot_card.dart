import 'package:flutter/material.dart';

import 'core.dart' show reviewInk;

class PetbotPortrait extends StatelessWidget {
  const PetbotPortrait({super.key, required this.size});

  final double size;

  @override
  Widget build(BuildContext context) => Image.asset(
        'assets/images/ai.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        excludeFromSemantics: true,
      );
}

class PetbotCard extends StatelessWidget {
  const PetbotCard({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xff214e68);
    final largeText = MediaQuery.textScalerOf(context).scale(18) >= 30;
    return Semantics(
      button: true,
      child: Material(
        color: const Color(0xffe5f1f7),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xffb8d2dd)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
            child: Row(children: [
              PetbotPortrait(size: largeText ? 46 : 64),
              const SizedBox(width: 14),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('팻봇 건강상담',
                        style: TextStyle(
                            color: reviewInk,
                            fontWeight: FontWeight.w700,
                            fontSize: 23,
                            height: 1.35)),
                    SizedBox(height: 4),
                    Row(children: [
                      Flexible(
                          child: Text('대화 열기',
                              style: TextStyle(
                                  color: accent,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4))),
                      SizedBox(width: 5),
                      Icon(Icons.arrow_forward_rounded,
                          size: 19, color: accent),
                    ]),
                  ],
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }
}
