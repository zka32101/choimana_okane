import 'package:choimana_okane/choimana_okane.dart';

class FurusatoNozeiResult {
  const FurusatoNozeiResult({
    required this.residentTaxIncomeLevy,
    required this.marginalIncomeTaxRate,
    required this.donationLimit,
  });

  /// 住民税所得割額（概算）。
  final int residentTaxIncomeLevy;

  /// 適用される所得税の限界税率。
  final double marginalIncomeTaxRate;

  /// 控除上限額（実質負担2,000円で寄付できる上限・目安）。
  final int donationLimit;
}

/// ふるさと納税の控除上限額の目安（型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `FurusatoNozeiCalculator` から移植。
/// 総務省が公表する近似式を使うため年度依存の制度定数は持たないが、
/// [TakeHomePayCalculator] に依存しており、そちらの定数が出典未確認
/// （期限切れ）である限り、この計算機も「目安」として配信できない。
class FurusatoNozeiCalculator extends Calculator {
  FurusatoNozeiCalculator({TakeHomePayCalculator? takeHomePay})
      : _takeHomePay = takeHomePay ?? TakeHomePayCalculator(),
        super(
          calcId: 'furusato-nozei',
          title: 'ふるさと納税の控除上限の目安',
          parameters: const [],
          sources: [
            Source(
              title: 'ふるさと納税のしくみ（控除上限額の近似式）',
              url: 'https://www.soumu.go.jp/',
              publisher: '総務省',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  final TakeHomePayCalculator _takeHomePay;

  /// この計算機自身に年度依存の定数はないが、依存先（[TakeHomePayCalculator]）
  /// の定数が有効でなければ配信できない。
  @override
  bool isDeliverableAt(DateTime now) =>
      super.isDeliverableAt(now) && _takeHomePay.isDeliverableAt(now);

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final result = computeDetail(
      grossAnnualIncome: inputs['grossAnnualIncome']!.round(),
      isOver40: (inputs['isOver40'] ?? 0) != 0,
      dependents: (inputs['dependents'] ?? 0).round(),
    );
    return CalculatorResult(value: result.donationLimit.toDouble());
  }

  /// 総務省の近似式: 控除上限額 ≒ 住民税所得割額 × 20% ÷ (90% − 所得税率 × 1.021) + 2,000円
  FurusatoNozeiResult computeDetail({
    required int grossAnnualIncome,
    bool isOver40 = false,
    int dependents = 0,
  }) {
    final payResult = _takeHomePay.computeDetail(
      grossAnnualIncome: grossAnnualIncome,
      isOver40: isOver40,
      dependents: dependents,
    );

    const residentTaxRate = 0.10;
    final residentTaxIncomeLevy =
        (payResult.taxableIncomeForResidentTax * residentTaxRate).round();

    final marginalRate = _marginalIncomeTaxRate(payResult.taxableIncomeForIncomeTax);

    final denominator = 0.90 - (marginalRate * 1.021);
    final donationLimit = denominator > 0
        ? ((residentTaxIncomeLevy * 0.20) / denominator + 2000).round()
        : 2000;

    return FurusatoNozeiResult(
      residentTaxIncomeLevy: residentTaxIncomeLevy,
      marginalIncomeTaxRate: marginalRate,
      donationLimit: donationLimit,
    );
  }

  /// 所得税の限界税率（速算表の税率。復興特別所得税は式側で加味）。
  double _marginalIncomeTaxRate(int taxableIncome) {
    final t = taxableIncome;
    if (t <= 1949000) return 0.05;
    if (t <= 3299000) return 0.10;
    if (t <= 6949000) return 0.20;
    if (t <= 8999000) return 0.23;
    if (t <= 17999000) return 0.33;
    if (t <= 39999000) return 0.40;
    return 0.45;
  }
}
