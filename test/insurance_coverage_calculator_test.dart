import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = InsuranceCoverageCalculator();

  group('InsuranceCoverageCalculator', () {
    test('年度依存の制度定数がないため常に配信可能', () {
      expect(calc.parametersValidAt(DateTime(2026, 1, 1)), isTrue);
      expect(calc.parametersValidAt(DateTime(2099, 1, 1)), isTrue);
    });

    test('資産・遺族年金・配偶者収入がなければ生活費総額がそのまま必要保障額になる', () {
      final r = calc.computeDetail(
        monthlyLivingExpenseForFamily: 200000,
        yearsNeeded: 10,
        oneTimeCosts: 0,
      );
      expect(r.requiredCoverage, 200000 * 12 * 10);
    });

    test('資産・遺族年金・配偶者収入があれば必要保障額が減る', () {
      final withoutAssets = calc.computeDetail(
        monthlyLivingExpenseForFamily: 200000,
        yearsNeeded: 10,
      );
      final withAssets = calc.computeDetail(
        monthlyLivingExpenseForFamily: 200000,
        yearsNeeded: 10,
        currentSavings: 5000000,
        monthlySurvivorPension: 50000,
      );
      expect(withAssets.requiredCoverage, lessThan(withoutAssets.requiredCoverage));
    });

    test('必要保障額は0未満にならない', () {
      final r = calc.computeDetail(
        monthlyLivingExpenseForFamily: 100000,
        yearsNeeded: 5,
        oneTimeCosts: 0,
        currentSavings: 100000000,
      );
      expect(r.requiredCoverage, 0);
    });

    test('choimana_kit の Calculator 契約: compute() は必要保障額を返す', () {
      final result = calc.compute({
        'monthlyLivingExpenseForFamily': 200000,
        'yearsNeeded': 10,
      });
      final detail = calc.computeDetail(monthlyLivingExpenseForFamily: 200000, yearsNeeded: 10);
      expect(result.value, detail.requiredCoverage.toDouble());
      expect(result.note, '目安');
    });
  });
}
