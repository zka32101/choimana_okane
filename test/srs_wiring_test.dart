import 'dart:convert';
import 'dart:io';

import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

/// content/lessons の実データ（Quiz）を使い、SRS（間隔反復）が
/// DailyPickSelector の復習枠（reviewQuiz）に実際に反映されるまでを
/// 結合して確認する。
void main() {
  group('Srs × content/lessons × DailyPickSelector の結合', () {
    late Lesson lesson;
    late Track track;
    late Map<String, Quiz> quizById;

    setUpAll(() {
      final json = jsonDecode(File('content/lessons/take-home-pay-001.json').readAsStringSync())
          as Map<String, dynamic>;
      lesson = Lesson.fromJson(json);
      quizById = {for (final q in lesson.quiz) q.qid: q};

      final trackJson =
          jsonDecode(File('content/tracks/takehome-tax.json').readAsStringSync())
              as Map<String, dynamic>;
      track = Track.fromJson(trackJson);
    });

    test('レッスンのquizは2問以上あり、qidで引き出せる', () {
      expect(lesson.quiz.length, greaterThanOrEqualTo(2));
      expect(quizById.keys, containsAll(lesson.quiz.map((q) => q.qid)));
    });

    test('不正解の直後は復習期日がすぐ来る（box=0・dueAt=now）', () {
      final now = DateTime(2026, 10, 20);
      final qid = lesson.quiz.first.qid;
      final item = Srs.review(null, qid: qid, correct: false, now: now);

      expect(item.box, 0);
      expect(item.dueAt, now);
      expect(Srs.due([item], now), [item]);
    });

    test(
      '選べる未完了レッスンが1つもない場合、復習期日が来た問題があってもDailyPickはnullになる'
      '（DailyPickSelector.pickは「今日の1レッスン」が見つからないと復習枠の判定自体を行わない、'
      'という既存の仕様の確認）',
      () {
        final now = DateTime(2026, 10, 20);
        final qid = lesson.quiz.first.qid;
        final srsItem = Srs.review(null, qid: qid, correct: false, now: now);

        final pick = DailyPickSelector.pick(
          tracks: [track],
          lessonsById: {lesson.lessonId: lesson},
          completedLessonIds: {lesson.lessonId},
          srsItems: [srsItem],
          quizById: quizById,
          now: now,
        );

        expect(pick, isNull);
      },
    );

    test(
      '未完了レッスンがあれば今日の1レッスンと復習問題が両方返る',
      () {
        final now = DateTime(2026, 10, 20);
        final qid = lesson.quiz.first.qid;
        final srsItem = Srs.review(null, qid: qid, correct: false, now: now);

        final pick = DailyPickSelector.pick(
          tracks: [track],
          lessonsById: {lesson.lessonId: lesson},
          completedLessonIds: {},
          srsItems: [srsItem],
          quizById: quizById,
          now: now,
        );

        expect(pick, isNotNull);
        expect(pick!.lesson.lessonId, lesson.lessonId);
        expect(pick.reviewQuiz, isNotNull);
        expect(pick.reviewQuiz!.qid, qid);
      },
    );

    test('複数回正解を積み重ねると復習間隔が延びていく（箱が上がる）', () {
      var now = DateTime(2026, 10, 20);
      final qid = lesson.quiz.first.qid;
      SrsItem? item;

      final boxesSeen = <int>[];
      for (var i = 0; i < 3; i++) {
        item = Srs.review(item, qid: qid, correct: true, now: now);
        boxesSeen.add(item.box);
        now = item.dueAt; // 次の復習期日ちょうどに正解し続けたと仮定する
      }

      expect(boxesSeen, [1, 2, 3]);
      // 箱が上がるほど次の復習までの間隔も長くなる。
      expect(Srs.intervals[3] > Srs.intervals[1], isTrue);
    });

    test('復習期日がまだ来ていない問題はDailyPickの復習枠に出てこない', () {
      final now = DateTime(2026, 10, 20);
      final qid = lesson.quiz.first.qid;
      // 正解直後（box=1・dueAt=1日後）なので、まだ復習期日ではない。
      final notYetDue = Srs.review(null, qid: qid, correct: true, now: now);

      final pick = DailyPickSelector.pick(
        tracks: [track],
        lessonsById: {lesson.lessonId: lesson},
        completedLessonIds: {},
        srsItems: [notYetDue],
        quizById: quizById,
        now: now,
      );

      expect(pick, isNotNull);
      expect(pick!.reviewQuiz, isNull);
    });
  });
}
