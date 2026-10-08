import 'package:choimana_okane/choimana_okane.dart';

/// 返済方式。
enum RepaymentType {
  /// 元利均等返済: 毎月の返済額（元金+利息）が一定。
  equalPayment,

  /// 元金均等返済: 毎月の元金部分が一定（返済額は徐々に減っていく）。
  equalPrincipal,
}

/// 1ヶ月分の返済内訳。
class LoanRepaymentMonthResult {
  const LoanRepaymentMonthResult({
    required this.month,
    required this.payment,
    required this.principalPaid,
    required this.interestPaid,
    required this.remainingBalance,
  });

  /// 1始まり。
  final int month;
  final int payment;
  final int principalPaid;
  final int interestPaid;
  final int remainingBalance;
}

/// 1年分の返済内訳（月次結果の集計）。
class LoanRepaymentYearResult {
  const LoanRepaymentYearResult({
    required this.year,
    required this.totalPayment,
    required this.totalPrincipal,
    required this.totalInterest,
    required this.remainingBalance,
  });

  final int year;
  final int totalPayment;
  final int totalPrincipal;
  final int totalInterest;
  final int remainingBalance;
}

class LoanRepaymentResult {
  const LoanRepaymentResult({required this.months, required this.years});

  final List<LoanRepaymentMonthResult> months;
  final List<LoanRepaymentYearResult> years;

  int get totalPayment => months.fold(0, (sum, m) => sum + m.payment);
  int get totalInterest => months.fold(0, (sum, m) => sum + m.interestPaid);
  int get totalPrincipal => months.fold(0, (sum, m) => sum + m.principalPaid);

  /// 元利均等返済なら全期間一定。元金均等返済なら初回の返済額。
  int get firstMonthPayment => months.isNotEmpty ? months.first.payment : 0;

  /// 元金均等返済の最終回の返済額（元利均等では同じ値になる）。
  int get lastMonthPayment => months.isNotEmpty ? months.last.payment : 0;
}

/// 借入金（住宅ローン・自動車ローン・奨学金など）の返済計画の目安
/// （型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `LoanRepaymentSimulator` から移植。
/// 金利計算は制度に依存しない純粋な数式のため、[Parameter] は空
/// （入力の金利はユーザー入力であり、制度の数値ではない）。
class LoanRepaymentCalculator extends Calculator {
  LoanRepaymentCalculator()
      : super(
          calcId: 'loan-repayment',
          title: 'ローン返済額の目安',
          parameters: const [],
          sources: [
            Source(
              title: '元利均等・元金均等返済の計算方法（一般的な金融知識）',
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
    final result = simulate(
      principal: inputs['principal']!.round(),
      annualInterestRatePercent: inputs['annualInterestRatePercent']!,
      years: inputs['years']!.round(),
      repaymentType: (inputs['equalPrincipal'] ?? 0) != 0
          ? RepaymentType.equalPrincipal
          : RepaymentType.equalPayment,
    );
    return CalculatorResult(value: result.firstMonthPayment.toDouble());
  }

  /// 月次・年次の内訳つき結果。
  static LoanRepaymentResult simulate({
    required int principal,
    required double annualInterestRatePercent,
    required int years,
    RepaymentType repaymentType = RepaymentType.equalPayment,
  }) {
    final totalMonths = years * 12;
    switch (repaymentType) {
      case RepaymentType.equalPayment:
        return _simulateEqualPayment(principal, annualInterestRatePercent, totalMonths);
      case RepaymentType.equalPrincipal:
        return _simulateEqualPrincipal(principal, annualInterestRatePercent, totalMonths);
    }
  }

  static LoanRepaymentResult _simulateEqualPayment(
    int principal,
    double annualInterestRatePercent,
    int totalMonths,
  ) {
    final monthlyRate = annualInterestRatePercent / 100 / 12;

    final int monthlyPayment;
    if (monthlyRate == 0) {
      monthlyPayment = (principal / totalMonths).round();
    } else {
      final factor = _pow(1 + monthlyRate, totalMonths);
      monthlyPayment = (principal * monthlyRate * factor / (factor - 1)).round();
    }

    final months = <LoanRepaymentMonthResult>[];
    double remaining = principal.toDouble();

    for (var m = 1; m <= totalMonths; m++) {
      final interestPaid = (remaining * monthlyRate).round();
      final isLastMonth = m == totalMonths;
      final rawPrincipalPaid = monthlyPayment - interestPaid;
      final principalPaid =
          isLastMonth ? remaining.round() : rawPrincipalPaid.clamp(0, remaining.round());
      final payment = isLastMonth ? principalPaid + interestPaid : monthlyPayment;

      remaining = (remaining - principalPaid).clamp(0, double.infinity);

      months.add(LoanRepaymentMonthResult(
        month: m,
        payment: payment,
        principalPaid: principalPaid,
        interestPaid: interestPaid,
        remainingBalance: remaining.round(),
      ));
    }

    return LoanRepaymentResult(months: months, years: _aggregateByYear(months));
  }

  static LoanRepaymentResult _simulateEqualPrincipal(
    int principal,
    double annualInterestRatePercent,
    int totalMonths,
  ) {
    final monthlyRate = annualInterestRatePercent / 100 / 12;
    final principalPerMonth = (principal / totalMonths).round();

    final months = <LoanRepaymentMonthResult>[];
    double remaining = principal.toDouble();

    for (var m = 1; m <= totalMonths; m++) {
      final isLastMonth = m == totalMonths;
      final principalPaid = isLastMonth ? remaining.round() : principalPerMonth;
      final interestPaid = (remaining * monthlyRate).round();
      final payment = principalPaid + interestPaid;

      remaining = (remaining - principalPaid).clamp(0, double.infinity);

      months.add(LoanRepaymentMonthResult(
        month: m,
        payment: payment,
        principalPaid: principalPaid,
        interestPaid: interestPaid,
        remainingBalance: remaining.round(),
      ));
    }

    return LoanRepaymentResult(months: months, years: _aggregateByYear(months));
  }

  static List<LoanRepaymentYearResult> _aggregateByYear(
    List<LoanRepaymentMonthResult> months,
  ) {
    final years = <LoanRepaymentYearResult>[];
    for (var i = 0; i < months.length; i += 12) {
      final yearMonths = months.skip(i).take(12).toList();
      if (yearMonths.isEmpty) continue;
      years.add(LoanRepaymentYearResult(
        year: (i ~/ 12) + 1,
        totalPayment: yearMonths.fold(0, (sum, m) => sum + m.payment),
        totalPrincipal: yearMonths.fold(0, (sum, m) => sum + m.principalPaid),
        totalInterest: yearMonths.fold(0, (sum, m) => sum + m.interestPaid),
        remainingBalance: yearMonths.last.remainingBalance,
      ));
    }
    return years;
  }

  static double _pow(double base, int exponent) {
    var result = 1.0;
    for (var i = 0; i < exponent; i++) {
      result *= base;
    }
    return result;
  }
}
