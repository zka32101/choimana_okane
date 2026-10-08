import 'dart:math';

import 'package:choimana_okane/choimana_okane.dart';

/// 積立複利シミュレーションの1年分のスナップショット。
class CompoundYearResult {
  const CompoundYearResult({
    required this.year,
    required this.principal,
    required this.balance,
    required this.realBalance,
  });

  final int year;

  /// 累計元本（初期投資額＋積立額の合計）。
  final int principal;

  /// その年末時点の評価額。
  final double balance;

  /// 物価上昇分を割り引いた、現在の購買力での評価額。
  final double realBalance;

  double get profit => balance - principal;
  double get realProfit => realBalance - principal;
}

/// 積立複利の目安計算（型②「予測→実行」の土台）。
///
/// kinnyu（zka32101/kinnyu）の `CompoundSimulator` から移植。年度依存の
/// 制度定数を持たない純粋な数式のため、[Parameter] は空（鮮度の制約を
/// 受けない。入力の利回り等はユーザー入力であり、制度の数値ではない）。
class CompoundCalculator extends Calculator {
  CompoundCalculator()
      : super(
          calcId: 'compound',
          title: '複利の目安',
          parameters: const [],
          sources: [
            Source(
              title: '複利計算の定義（教育目的の近似式。月初積立→月利運用のモデル）',
              url: 'https://www.fsa.go.jp/',
              publisher: '金融庁（一般的な複利の考え方の参考。個別の計算式の出典ではない）',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final years = simulate(
      initial: (inputs['initial'] ?? 0).round(),
      monthlyContribution: inputs['monthlyContribution']!.round(),
      annualRatePercent: inputs['annualRatePercent']!,
      years: inputs['years']!.round(),
      inflationRatePercent: inputs['inflationRatePercent'] ?? 0,
      contributionIncreasePercent: inputs['contributionIncreasePercent'] ?? 0,
    );
    return CalculatorResult(value: years.last.realBalance);
  }

  /// 年ごとの評価額の推移（グラフ表示用）。
  static List<CompoundYearResult> simulate({
    int initial = 0,
    required int monthlyContribution,
    required double annualRatePercent,
    required int years,
    double inflationRatePercent = 0.0,
    double contributionIncreasePercent = 0.0,
  }) {
    assert(years > 0, 'years must be positive');
    final monthlyRate = annualRatePercent / 100 / 12;

    double balance = initial.toDouble();
    int principal = initial;
    double currentContribution = monthlyContribution.toDouble();
    final results = <CompoundYearResult>[];

    for (var year = 1; year <= years; year++) {
      if (year > 1 && contributionIncreasePercent != 0) {
        currentContribution *= (1 + contributionIncreasePercent / 100);
      }
      for (var m = 0; m < 12; m++) {
        balance += currentContribution;
        principal += currentContribution.round();
        balance *= (1 + monthlyRate);
      }
      final inflationFactor = pow(1 + inflationRatePercent / 100, year);
      final realBalance = balance / inflationFactor;
      results.add(CompoundYearResult(
        year: year,
        principal: principal,
        balance: balance,
        realBalance: realBalance,
      ));
    }
    return results;
  }
}
