import 'package:choimana_okane/choimana_okane.dart';

/// 額面年収から手取り額を試算する（型②「予測→実行」の土台）。
///
/// kinnyu（zka32101/kinnyu）の `TakeHomePayCalculator` から移植。
/// 計算式自体はそのまま使えるが、**定数は2024年度（協会けんぽ東京都の目安・
/// 所得税速算表 令和6年分）のまま未検証**。お金 企画設計書 v0.2 §9-3の通り、
/// 2026年度の制度で出典を再確認してから [Parameter] の `retrievedAt`/`expiresAt`
/// を更新する。それまでは [parametersValidAt] が常に false を返すよう
/// [expiresAt] を過去日付にしてあり、このままでは配信できない
/// （Lesson の鮮度チェックと同じ「安全側に倒す」考え方）。
class TakeHomePayCalculator extends Calculator {
  TakeHomePayCalculator()
      : super(
          calcId: 'take-home-pay',
          title: '手取りの目安',
          parameters: _parameters,
          sources: [
            Source(
              title: '所得税の仕組み（出典未確認・kinnyu移植時点のコメントのみ）',
              url: 'https://www.nta.go.jp/',
              publisher: '国税庁',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  static final _parameters = [
    _param('health-insurance-rate', 0.0499, '割合', '協会けんぽ東京都の目安料率（従業員負担分・2024年度）'),
    _param('ltc-insurance-rate', 0.0080, '割合', '介護保険料率（40歳以上・2024年度）'),
    _param('pension-insurance-rate', 0.0915, '割合', '厚生年金保険料率（従業員負担分・2024年度）'),
    _param('employment-insurance-rate', 0.006, '割合', '雇用保険料率（一般の事業・2024年度）'),
    _param('pensionable-income-cap', 7800000, '円', '標準報酬月額の上限相当（年額）'),
    _param('basic-deduction', 480000, '円', '基礎控除（所得税・合計所得2,400万円以下）'),
    _param('dependent-deduction-per-person', 380000, '円', '扶養控除（所得税・1人あたり概算）'),
    _param('resident-tax-basic-deduction', 430000, '円', '基礎控除（住民税）'),
    _param('resident-tax-dependent-deduction-per-person', 330000, '円', '扶養控除（住民税・1人あたり概算）'),
    _param('resident-tax-rate', 0.10, '割合', '住民税所得割（標準税率）'),
    _param('resident-tax-per-capita', 5000, '円', '住民税均等割の概算（自治体により変動）'),
  ];

  static Parameter _param(String id, num value, String unit, String basis) => Parameter(
        paramId: id,
        value: value.toDouble(),
        unit: unit,
        basis: basis,
        lawVersion: '令和6年分（2024年度）— 出典未確認。2026年度の制度で再確認が必要',
        retrievedAt: DateTime(2026, 1, 1),
        // 意図的に過去日付にして「このままでは配信できない」を機械的に強制する。
        expiresAt: DateTime(2026, 1, 1),
      );

  double _rate(String id) => parameters.firstWhere((p) => p.paramId == id).value;

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final detail = computeDetail(
      grossAnnualIncome: inputs['grossAnnualIncome']!.round(),
      isOver40: (inputs['isOver40'] ?? 0) != 0,
      dependents: (inputs['dependents'] ?? 0).round(),
    );
    return CalculatorResult(value: detail.takeHomeMonthly.toDouble());
  }

  /// UI表示用の内訳つき結果。[compute] は choimana_core の Calculator 契約
  /// （単一の目安値）を満たすための簡略版で、実際の画面にはこちらを使う。
  TakeHomePayResult computeDetail({
    required int grossAnnualIncome,
    bool isOver40 = false,
    int dependents = 0,
  }) {
    final gross = grossAnnualIncome;

    final socialInsurance = _socialInsurance(gross, isOver40);

    final employmentIncomeDeduction = _employmentIncomeDeduction(gross);
    final employmentIncome = (gross - employmentIncomeDeduction).clamp(0, gross);

    final dependentDeduction = dependents * _rate('dependent-deduction-per-person').round();

    final taxableForIncomeTax = (employmentIncome -
            _rate('basic-deduction').round() -
            dependentDeduction -
            socialInsurance.total)
        .clamp(0, employmentIncome);
    final incomeTax = _incomeTax(taxableForIncomeTax);

    final residentDependentDeduction =
        dependents * _rate('resident-tax-dependent-deduction-per-person').round();
    final taxableForResidentTax = (employmentIncome -
            _rate('resident-tax-basic-deduction').round() -
            residentDependentDeduction -
            socialInsurance.total)
        .clamp(0, employmentIncome);
    final residentTax = taxableForResidentTax > 0
        ? (taxableForResidentTax * _rate('resident-tax-rate')).round() +
            _rate('resident-tax-per-capita').round()
        : 0;

    return TakeHomePayResult(
      grossAnnualIncome: gross,
      socialInsurance: socialInsurance,
      employmentIncomeDeduction: employmentIncomeDeduction,
      employmentIncome: employmentIncome,
      basicDeduction: _rate('basic-deduction').round(),
      dependentDeduction: dependentDeduction,
      taxableIncomeForIncomeTax: taxableForIncomeTax,
      incomeTax: incomeTax,
      taxableIncomeForResidentTax: taxableForResidentTax,
      residentTax: residentTax,
    );
  }

  SocialInsurancePremiums _socialInsurance(int grossAnnualIncome, bool isOver40) {
    final pensionableIncome = grossAnnualIncome.clamp(0, _rate('pensionable-income-cap').round());
    return SocialInsurancePremiums(
      healthInsurance: (grossAnnualIncome * _rate('health-insurance-rate')).round(),
      longTermCareInsurance:
          isOver40 ? (grossAnnualIncome * _rate('ltc-insurance-rate')).round() : 0,
      pensionInsurance: (pensionableIncome * _rate('pension-insurance-rate')).round(),
      employmentInsurance: (grossAnnualIncome * _rate('employment-insurance-rate')).round(),
    );
  }

  /// 給与所得控除（令和2年分以降の速算表。所得税法の速算表そのものを使うため
  /// Parameter 化していない）。
  int _employmentIncomeDeduction(int grossAnnualIncome) {
    final g = grossAnnualIncome;
    if (g <= 1625000) return 550000;
    if (g <= 1800000) return (g * 0.4 - 100000).round();
    if (g <= 3600000) return (g * 0.3 + 80000).round();
    if (g <= 6600000) return (g * 0.2 + 440000).round();
    if (g <= 8500000) return (g * 0.1 + 1100000).round();
    return 1950000;
  }

  /// 所得税額（復興特別所得税2.1%込み）。国税庁の速算表（令和6年分）。
  int _incomeTax(int taxableIncome) {
    final t = taxableIncome;
    double rate;
    int deduction;
    if (t <= 1949000) {
      rate = 0.05;
      deduction = 0;
    } else if (t <= 3299000) {
      rate = 0.10;
      deduction = 97500;
    } else if (t <= 6949000) {
      rate = 0.20;
      deduction = 427500;
    } else if (t <= 8999000) {
      rate = 0.23;
      deduction = 636000;
    } else if (t <= 17999000) {
      rate = 0.33;
      deduction = 1536000;
    } else if (t <= 39999000) {
      rate = 0.40;
      deduction = 2796000;
    } else {
      rate = 0.45;
      deduction = 4796000;
    }
    final baseIncomeTax = (t * rate - deduction).clamp(0, double.infinity);
    final reconstructionTax = baseIncomeTax * 0.021;
    return (baseIncomeTax + reconstructionTax).round();
  }
}

class SocialInsurancePremiums {
  const SocialInsurancePremiums({
    required this.healthInsurance,
    required this.longTermCareInsurance,
    required this.pensionInsurance,
    required this.employmentInsurance,
  });

  final int healthInsurance;
  final int longTermCareInsurance;
  final int pensionInsurance;
  final int employmentInsurance;

  int get total =>
      healthInsurance + longTermCareInsurance + pensionInsurance + employmentInsurance;
}

class TakeHomePayResult {
  const TakeHomePayResult({
    required this.grossAnnualIncome,
    required this.socialInsurance,
    required this.employmentIncomeDeduction,
    required this.employmentIncome,
    required this.basicDeduction,
    required this.dependentDeduction,
    required this.taxableIncomeForIncomeTax,
    required this.incomeTax,
    required this.taxableIncomeForResidentTax,
    required this.residentTax,
  });

  final int grossAnnualIncome;
  final SocialInsurancePremiums socialInsurance;
  final int employmentIncomeDeduction;
  final int employmentIncome;
  final int basicDeduction;
  final int dependentDeduction;
  final int taxableIncomeForIncomeTax;
  final int incomeTax;
  final int taxableIncomeForResidentTax;
  final int residentTax;

  int get totalDeductions => socialInsurance.total + incomeTax + residentTax;
  int get takeHomeAnnual => grossAnnualIncome - totalDeductions;
  int get takeHomeMonthly => (takeHomeAnnual / 12).round();
  double get takeHomeRate => grossAnnualIncome > 0 ? takeHomeAnnual / grossAnnualIncome : 0.0;
}
