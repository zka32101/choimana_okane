import 'package:choimana_okane/choimana_okane.dart';

class InsuranceCoverageResult {
  const InsuranceCoverageResult({
    required this.totalLivingExpenseNeeded,
    required this.totalIncomeExpected,
    required this.requiredCoverage,
  });

  /// 必要な生活費総額。
  final int totalLivingExpenseNeeded;

  /// 遺族年金・配偶者収入の総見込み額。
  final int totalIncomeExpected;

  /// 必要保障額（不足分）。
  final int requiredCoverage;
}

/// 生命保険の必要保障額の目安（型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `InsuranceCoverageCalculator` から移植。
/// 必要保障額 = (生活費総額 + 一時費用) − (現在の金融資産 + 遺族年金等の
/// 総見込み額)。すべて入力値ベースの計算で、制度に基づく定数はないため
/// [Parameter] は空。
class InsuranceCoverageCalculator extends Calculator {
  InsuranceCoverageCalculator()
      : super(
          calcId: 'insurance-coverage',
          title: '必要な保険金額の目安',
          parameters: const [],
          sources: [
            Source(
              title: '必要保障額の考え方（一般的な金融知識）',
              url: 'https://www.fsa.go.jp/',
              publisher: '金融庁（一般的な考え方の参考。個別の計算式の出典ではない）',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final result = computeDetail(
      monthlyLivingExpenseForFamily: inputs['monthlyLivingExpenseForFamily']!.round(),
      yearsNeeded: inputs['yearsNeeded']!.round(),
      oneTimeCosts: (inputs['oneTimeCosts'] ?? 2000000).round(),
      currentSavings: (inputs['currentSavings'] ?? 0).round(),
      monthlySurvivorPension: (inputs['monthlySurvivorPension'] ?? 0).round(),
      spouseMonthlyIncome: (inputs['spouseMonthlyIncome'] ?? 0).round(),
    );
    return CalculatorResult(value: result.requiredCoverage.toDouble());
  }

  InsuranceCoverageResult computeDetail({
    required int monthlyLivingExpenseForFamily,
    required int yearsNeeded,
    int oneTimeCosts = 2000000,
    int currentSavings = 0,
    int monthlySurvivorPension = 0,
    int spouseMonthlyIncome = 0,
  }) {
    final totalLivingExpenseNeeded =
        monthlyLivingExpenseForFamily * 12 * yearsNeeded + oneTimeCosts;

    final totalIncomeExpected =
        (monthlySurvivorPension + spouseMonthlyIncome) * 12 * yearsNeeded + currentSavings;

    final requiredCoverage =
        (totalLivingExpenseNeeded - totalIncomeExpected).clamp(0, totalLivingExpenseNeeded);

    return InsuranceCoverageResult(
      totalLivingExpenseNeeded: totalLivingExpenseNeeded,
      totalIncomeExpected: totalIncomeExpected,
      requiredCoverage: requiredCoverage,
    );
  }
}
