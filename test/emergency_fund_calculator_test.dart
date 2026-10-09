import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = EmergencyFundCalculator();

  group('EmergencyFundCalculator', () {
    test('年度依存の制度定数がないため常に配信可能', () {
      expect(calc.parametersValidAt(DateTime(2026, 1, 1)), isTrue);
      expect(calc.parametersValidAt(DateTime(2099, 1, 1)), isTrue);
    });

    test('目標金額は月額支出×カバー月数', () {
      final r = calc.computeDetail(
        monthlyEssentialExpense: 200000,
        coverageMonths: 6,
        currentSavings: 0,
        monthlyContribution: 0,
      );
      expect(r.targetAmount, 1200000);
    });

    test('既に目標額を貯めていれば達成済みになる', () {
      final r = calc.computeDetail(
        monthlyEssentialExpense: 200000,
        coverageMonths: 6,
        currentSavings: 1200000,
        monthlyContribution: 0,
      );
      expect(r.isGoalReached, isTrue);
      expect(r.remainingAmount, 0);
      expect(r.progressPercent, 100.0);
    });

    test('積立額から目標達成までの月数を計算する', () {
      final r = calc.computeDetail(
        monthlyEssentialExpense: 200000,
        coverageMonths: 6,
        currentSavings: 0,
        monthlyContribution: 100000,
      );
      expect(r.monthsToGoal, 12);
    });

    test('積立額が0なら目標達成月数はnull', () {
      final r = calc.computeDetail(
        monthlyEssentialExpense: 200000,
        coverageMonths: 6,
        currentSavings: 0,
        monthlyContribution: 0,
      );
      expect(r.monthsToGoal, isNull);
    });

    test('choimana_core の Calculator 契約: compute() は不足額を返す', () {
      final result = calc.compute({
        'monthlyEssentialExpense': 200000,
        'coverageMonths': 6,
        'currentSavings': 300000,
        'monthlyContribution': 50000,
      });
      final detail = calc.computeDetail(
        monthlyEssentialExpense: 200000,
        coverageMonths: 6,
        currentSavings: 300000,
        monthlyContribution: 50000,
      );
      expect(result.value, detail.remainingAmount.toDouble());
      expect(result.note, '目安');
    });
  });
}
