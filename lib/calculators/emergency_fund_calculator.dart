import 'package:choimana_okane/choimana_okane.dart';

class EmergencyFundResult {
  const EmergencyFundResult({
    required this.targetAmount,
    required this.remainingAmount,
    required this.progressPercent,
    required this.monthsToGoal,
    required this.isGoalReached,
  });

  final int targetAmount;
  final int remainingAmount;
  final double progressPercent;

  /// 目標達成までの月数（積立額が0なら null）。
  final int? monthsToGoal;
  final bool isGoalReached;
}

/// 生活防衛資金（緊急予備資金）の目標額と達成時期の目安
/// （型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `EmergencyFundPlanner` から移植。
/// 「毎月の必要生活費の3〜6ヶ月分（会社員）〜12ヶ月分（自営業）」という
/// 月数はユーザーが選ぶ入力（[coverageMonths]）であり、コードに固定値
/// として埋め込まれた制度定数はないため [Parameter] は空。
class EmergencyFundCalculator extends Calculator {
  EmergencyFundCalculator()
      : super(
          calcId: 'emergency-fund',
          title: '生活防衛資金の目標額の目安',
          parameters: const [],
          sources: [
            Source(
              title: '生活防衛資金の考え方（一般的な金融知識。3〜6ヶ月／12ヶ月分は目安）',
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
      monthlyEssentialExpense: inputs['monthlyEssentialExpense']!.round(),
      coverageMonths: inputs['coverageMonths']!.round(),
      currentSavings: inputs['currentSavings']!.round(),
      monthlyContribution: inputs['monthlyContribution']!.round(),
    );
    return CalculatorResult(value: result.remainingAmount.toDouble());
  }

  EmergencyFundResult computeDetail({
    required int monthlyEssentialExpense,
    required int coverageMonths,
    required int currentSavings,
    required int monthlyContribution,
  }) {
    final targetAmount = monthlyEssentialExpense * coverageMonths;
    final remainingAmount = (targetAmount - currentSavings).clamp(0, targetAmount);
    final isGoalReached = remainingAmount == 0 && targetAmount > 0;
    final progressPercent =
        targetAmount > 0 ? (currentSavings / targetAmount * 100).clamp(0.0, 100.0) : 0.0;

    int? monthsToGoal;
    if (!isGoalReached && monthlyContribution > 0) {
      monthsToGoal = (remainingAmount / monthlyContribution).ceil();
    }

    return EmergencyFundResult(
      targetAmount: targetAmount,
      remainingAmount: remainingAmount,
      progressPercent: progressPercent,
      monthsToGoal: monthsToGoal,
      isGoalReached: isGoalReached,
    );
  }
}
