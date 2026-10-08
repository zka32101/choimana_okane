import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = CompoundCalculator();

  group('CompoundCalculator', () {
    test('年度依存の制度定数がないため常に配信可能', () {
      expect(calc.parametersValidAt(DateTime(2026, 1, 1)), isTrue);
      expect(calc.parametersValidAt(DateTime(2099, 1, 1)), isTrue);
    });

    test('元本のみ（利回り0%）なら評価額は積立額の合計と一致する', () {
      final years = CompoundCalculator.simulate(
        monthlyContribution: 10000,
        annualRatePercent: 0,
        years: 10,
      );
      expect(years.last.balance, closeTo(10000 * 12 * 10, 0.01));
      expect(years.last.profit, closeTo(0, 0.01));
    });

    test('利回りがプラスなら元本より評価額が増える', () {
      final years = CompoundCalculator.simulate(
        monthlyContribution: 30000,
        annualRatePercent: 5,
        years: 20,
      );
      expect(years.last.balance, greaterThan(years.last.principal.toDouble()));
    });

    test('年が進むごとに評価額は単調増加する', () {
      final years = CompoundCalculator.simulate(
        monthlyContribution: 20000,
        annualRatePercent: 3,
        years: 15,
      );
      for (var i = 1; i < years.length; i++) {
        expect(years[i].balance, greaterThan(years[i - 1].balance));
      }
    });

    test('インフレ率を入れると実質評価額は名目評価額より小さくなる', () {
      final years = CompoundCalculator.simulate(
        monthlyContribution: 20000,
        annualRatePercent: 3,
        years: 15,
        inflationRatePercent: 2,
      );
      expect(years.last.realBalance, lessThan(years.last.balance));
    });

    test('choimana_kit の Calculator 契約: compute() は最終年の実質評価額を返す', () {
      final result = calc.compute({
        'monthlyContribution': 10000,
        'annualRatePercent': 3,
        'years': 10,
      });
      final detail = CompoundCalculator.simulate(
        monthlyContribution: 10000,
        annualRatePercent: 3,
        years: 10,
      );
      expect(result.value, detail.last.realBalance);
      expect(result.note, '目安');
    });
  });
}
