import 'dart:convert';
import 'dart:io';

import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

/// content/lessons の実データと DailyPickSelector、Calculator の配信可否判定を
/// 結合して確認する（お金 企画設計書 v0.2 §9-3「次の作業」の3. の前提確認）。
void main() {
  group('DailyPickSelector × Lesson × Calculator の結合', () {
    late Lesson lesson;
    late Track track;

    T loadJson<T>(String path, T Function(Map<String, dynamic>) parse) {
      final json = jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;
      return parse(json);
    }

    setUpAll(() {
      lesson = loadJson('content/lessons/take-home-pay-001.json', Lesson.fromJson);
      // 実際の content/tracks/takehome-tax.json を読み込む。このテストは
      // take-home-pay-001 だけを見るため、他のレッスンは完了済みとして扱う
      // （下記 completedLessonIds 参照）。
      track = loadJson('content/tracks/takehome-tax.json', Track.fromJson);
    });

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
      'isCalcDeliverableAtを渡すと、calcIdのCalculatorの実際の配信可否で判定される'
      '（take-home-payは基礎控除・扶養控除の区分別実装により全Parameterが'
      '検証済みになったため、isFullyDeliverableAtもtrueになり選ばれる）',
      () {
        final now = DateTime(2026, 10, 20);
        final calculator = TakeHomePayCalculator();
        expect(calculator.calcId, lesson.calcId);
        expect(calculator.isFullyDeliverableAt(now), isTrue);

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

        expect(pick, isNotNull);
        expect(pick!.lesson.lessonId, 'take-home-pay-001');
      },
    );

    test(
      'Calculatorが配信不可であればisCalcDeliverableAtを渡すとそのレッスンはスキップされる'
      '（このトラックには他に代替レッスンがないためpickはnullになる、という'
      '合成ロジック自体の確認）',
      () {
        final now = DateTime(2026, 10, 20);

        final pick = DailyPickSelector.pick(
          tracks: [track],
          lessonsById: {lesson.lessonId: lesson},
          completedLessonIds: {},
          srsItems: const [],
          quizById: {},
          now: now,
          isCalcDeliverableAt: (calcId, now) => false,
        );

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
