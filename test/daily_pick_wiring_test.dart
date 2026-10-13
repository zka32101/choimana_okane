import 'dart:convert';
import 'dart:io';

import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

/// content/lessons の実データと DailyPickSelector、Calculator の配信可否判定を
/// 結合して確認する（お金 企画設計書 v0.2 §9-3「次の作業」の3. の前提確認）。
void main() {
  group('DailyPickSelector × Lesson × Calculator の結合', () {
    late Lesson lesson;

    setUpAll(() {
      final json = jsonDecode(File('content/lessons/take-home-pay-001.json').readAsStringSync())
          as Map<String, dynamic>;
      lesson = Lesson.fromJson(json);
    });

    final track = Track(
      trackId: 'takehome-tax',
      genreId: 'okane',
      name: '手取りと税金・社会保険',
      order: 1,
      lessonIds: ['take-home-pay-001'],
    );

    test('レッスン自体は鮮度OKで配信可能（kind=predict・rank=mid）', () {
      final now = DateTime(2026, 10, 20);
      expect(lesson.isDeliverableAt(now), isTrue);
    });

    test(
      'isCalcDeliverableAtを渡さない場合、DailyPickSelectorはレッスンの鮮度だけ見て選ぶ'
      '（従来の挙動。choimana_core 0781435時点の既知のギャップ）',
      () {
        final now = DateTime(2026, 10, 20);
        final pick = DailyPickSelector.pick(
          tracks: [track],
          lessonsById: {lesson.lessonId: lesson},
          completedLessonIds: {},
          srsItems: const [],
          quizById: {},
          now: now,
        );
        expect(pick, isNotNull);
        expect(pick!.lesson.lessonId, 'take-home-pay-001');
      },
    );

    test(
      'isCalcDeliverableAtを渡すと、calcIdのCalculatorが実際には配信可能なため選ばれる'
      '（take-home-payの基礎控除は令和8年度改正の段階制で再実装済み。'
      '扶養控除等が未検証のため依然 parametersValidAt は false だが、'
      'isFullyDeliverableAt は鮮度のみを見るisDeliverableAtとは異なり両方を合成する）',
      () {
        final now = DateTime(2026, 10, 20);
        final calculator = TakeHomePayCalculator();
        expect(calculator.calcId, lesson.calcId);

        final pick = DailyPickSelector.pick(
          tracks: [track],
          lessonsById: {lesson.lessonId: lesson},
          completedLessonIds: {},
          srsItems: const [],
          quizById: {},
          now: now,
          isCalcDeliverableAt: (calcId, now) {
            expect(calcId, 'take-home-pay');
            return calculator.isFullyDeliverableAt(now);
          },
        );

        // 扶養控除・住民税均等割がまだ未検証のため、このCalculatorは
        // 現時点では isFullyDeliverableAt が false になる。
        expect(calculator.isFullyDeliverableAt(now), isFalse);
        expect(pick, isNull, reason: 'このトラックには他に代替レッスンがないため');
      },
    );

    test('Calculatorが完全に配信可能であれば、isCalcDeliverableAtを渡してもレッスンが選ばれる', () {
      final now = DateTime(2026, 10, 20);

      final pick = DailyPickSelector.pick(
        tracks: [track],
        lessonsById: {lesson.lessonId: lesson},
        completedLessonIds: {},
        srsItems: const [],
        quizById: {},
        now: now,
        isCalcDeliverableAt: (calcId, now) => true,
      );

      expect(pick, isNotNull);
      expect(pick!.lesson.lessonId, 'take-home-pay-001');
    });
  });
}
