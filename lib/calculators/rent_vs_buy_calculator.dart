import 'package:choimana_okane/choimana_okane.dart';

class RentVsBuyYearResult {
  const RentVsBuyYearResult({
    required this.year,
    required this.cumulativeRentCost,
    required this.cumulativeBuyCost,
  });

  final int year;
  final int cumulativeRentCost;
  final int cumulativeBuyCost;
}

class RentVsBuyResult {
  const RentVsBuyResult({
    required this.years,
    required this.finalRentCost,
    required this.finalBuyCost,
    required this.breakEvenYear,
    required this.remainingLoanBalance,
    required this.totalInterestPaid,
  });

  final List<RentVsBuyYearResult> years;

  /// 比較期間終了時点の賃貸累計コスト。
  final int finalRentCost;

  /// 比較期間終了時点の購入累計コスト（頭金・ローン返済・税・維持費）。
  final int finalBuyCost;

  /// 購入コストが賃貸コストを下回り始める最初の年（期間内に無ければnull）。
  final int? breakEvenYear;
  final int remainingLoanBalance;
  final int totalInterestPaid;
}

/// 住宅購入 vs 賃貸の支払い総額比較の目安（型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `RentVsBuyCalculator` から移植。
/// [LoanRepaymentCalculator] の上に構築し、年度依存の制度定数を持たない
/// （[Parameter] は空。家賃・金利・税・維持費はすべてユーザー入力）。
///
/// 購入した場合に手元に残る不動産という資産の価値（値上がり・値下がり）は
/// 考慮せず、あくまで支払い総額の比較である点に注意（kinnyu時点の注記）。
class RentVsBuyCalculator extends Calculator {
  RentVsBuyCalculator({LoanRepaymentCalculator? loanRepayment})
      : _loanRepayment = loanRepayment ?? LoanRepaymentCalculator(),
        super(
          calcId: 'rent-vs-buy',
          title: '住宅購入と賃貸の比較の目安',
          parameters: const [],
          sources: [
            Source(
              title: '住宅購入・賃貸の比較の考え方（一般的な金融知識）',
              url: 'https://www.fsa.go.jp/',
              publisher: '金融庁（一般的な考え方の参考。個別の計算式の出典ではない）',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  final LoanRepaymentCalculator _loanRepayment;

  @override
  bool isDeliverableAt(DateTime now) =>
      super.isDeliverableAt(now) && _loanRepayment.isDeliverableAt(now);

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final result = computeDetail(
      monthlyRent: inputs['monthlyRent']!.round(),
      purchasePrice: inputs['purchasePrice']!.round(),
      downPayment: inputs['downPayment']!.round(),
      loanInterestRatePercent: inputs['loanInterestRatePercent']!,
      loanYears: inputs['loanYears']!.round(),
      comparisonYears: inputs['comparisonYears']!.round(),
      annualRentIncreaseRatePercent: inputs['annualRentIncreaseRatePercent'] ?? 0,
      annualPropertyTax: (inputs['annualPropertyTax'] ?? 0).round(),
      annualMaintenanceCost: (inputs['annualMaintenanceCost'] ?? 0).round(),
    );
    return CalculatorResult(value: (result.finalBuyCost - result.finalRentCost).toDouble());
  }

  RentVsBuyResult computeDetail({
    required int monthlyRent,
    required int purchasePrice,
    required int downPayment,
    required double loanInterestRatePercent,
    required int loanYears,
    required int comparisonYears,
    double annualRentIncreaseRatePercent = 0.0,
    int annualPropertyTax = 0,
    int annualMaintenanceCost = 0,
  }) {
    final loanPrincipal = (purchasePrice - downPayment).clamp(0, purchasePrice);
    final loanResult = LoanRepaymentCalculator.simulate(
      principal: loanPrincipal,
      annualInterestRatePercent: loanInterestRatePercent,
      years: loanYears,
    );

    final years = <RentVsBuyYearResult>[];
    var cumulativeRent = 0;
    var cumulativeBuy = downPayment;
    int? breakEvenYear;
    var currentMonthlyRent = monthlyRent.toDouble();

    for (var y = 1; y <= comparisonYears; y++) {
      final annualRent = (currentMonthlyRent * 12).round();
      cumulativeRent += annualRent;
      currentMonthlyRent *= (1 + annualRentIncreaseRatePercent / 100);

      final loanPaymentThisYear =
          y <= loanResult.years.length ? loanResult.years[y - 1].totalPayment : 0;
      cumulativeBuy += loanPaymentThisYear + annualPropertyTax + annualMaintenanceCost;

      years.add(RentVsBuyYearResult(
        year: y,
        cumulativeRentCost: cumulativeRent,
        cumulativeBuyCost: cumulativeBuy,
      ));

      breakEvenYear ??= cumulativeBuy <= cumulativeRent ? y : null;
    }

    final remainingBalance = comparisonYears < loanYears
        ? loanResult.years[comparisonYears - 1].remainingBalance
        : 0;

    return RentVsBuyResult(
      years: years,
      finalRentCost: cumulativeRent,
      finalBuyCost: cumulativeBuy,
      breakEvenYear: breakEvenYear,
      remainingLoanBalance: remainingBalance,
      totalInterestPaid: loanResult.totalInterest,
    );
  }
}
