import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = NisaCalculator();

  group('NisaCalculator', () {
    test('定数は2026年度も変更なしと確認済み（2027年1月の制度変更まで配信可）', () {
      expect(calc.parametersValidAt(DateTime(2026, 10, 8)), isTrue);
      expect(calc.parametersValidAt(DateTime(2027, 2, 1)), isFalse);
    });

    test('未投資ならすべて上限額が残っている', () {
      final r = calc.computeDetail();
      expect(r.tsumitateRemaining, 1200000);
      expect(r.growthRemaining, 2400000);
      expect(r.lifetimeRemaining, 18000000);
    });

    test('投資済み額を差し引いた残り枠を計算する', () {
      final r = calc.computeDetail(
        tsumitateInvestedThisYear: 500000,
        growthInvestedThisYear: 1000000,
        lifetimeInvestedTotal: 3000000,
      );
      expect(r.tsumitateRemaining, 700000);
      expect(r.growthRemaining, 1400000);
      expect(r.annualRemaining, 700000 + 1400000);
      expect(r.lifetimeRemaining, 15000000);
    });

    test('残り枠は0未満にならない', () {
      final r = calc.computeDetail(tsumitateInvestedThisYear: 9999999);
      expect(r.tsumitateRemaining, 0);
    });

    test('choimana_kit の Calculator 契約: compute() は年間残り枠を返す', () {
      final result = calc.compute({});
      final detail = calc.computeDetail();
      expect(result.value, detail.annualRemaining.toDouble());
      expect(result.note, '目安');
    });
  });
}
