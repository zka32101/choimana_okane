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

    test('DailyPickSelector はレッスンの鮮度だけ見るため選ばれる', () {
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
    });

    test(
      'しかし kind=predict のレッスンが参照する calcId の Calculator は、'
      '基礎控除・扶養控除が未検証のため配信不可のままである'
      '（DailyPickSelector はレッスンの鮮度（Lesson.isDeliverableAt）しか見ないため、'
      'predict系レッスンを実際に表示する側は lesson.calcId の Calculator の '
      'isFullyDeliverableAt（choimana_core 0781435 以降で追加）も別途チェックする'
      '必要がある、という既知のギャップを明示するテスト）',
      () {
        final now = DateTime(2026, 10, 20);
        expect(lesson.kind, LessonKind.predict);
        expect(lesson.calcId, 'take-home-pay');

        final calculator = TakeHomePayCalculator();
        expect(calculator.calcId, lesson.calcId);
        expect(calculator.isDeliverableAt(now), isTrue, reason: '鮮度自体はまだOK');
        expect(calculator.isFullyDeliverableAt(now), isFalse, reason: '基礎控除等が未検証のため');
      },
    );
  });
}
