import 'package:choimana_okane/choimana_okane.dart';

/// 企業規模（自営業かどうかで厚生年金の有無を判定する）。
enum CompanySize { employee, selfEmployed }

class PensionEstimatorResult {
  const PensionEstimatorResult({
    required this.annualBasicPension,
    required this.annualEmployeePension,
    required this.annualTotalPension,
    required this.monthlyTotalPension,
  });

  /// 老齢基礎年金（国民年金）年額。
  final int annualBasicPension;

  /// 老齢厚生年金 年額。
  final int annualEmployeePension;
  final int annualTotalPension;
  final int monthlyTotalPension;
}

/// 年金受給見込み額の目安（型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `PensionEstimator` から移植。**退職金の概算
/// 部分は移植していない**（企業規模別の支給率係数が公的出典を持たない
/// 独自の仮定値だったため。お金 企画設計書 v0.2 §6「出典のない数値は
/// 載せない」方針に従う）。
///
/// 年金の数値自体（基礎年金満額・報酬比例の乗率・繰上げ繰下げ率）は
/// 日本年金機構の制度に基づき、2026-10-13に令和8年度の実データで出典確認済み。
/// 基礎年金満額は毎年度の改定率に応じて変わるため、次回改定（2027年4月想定）
/// を目安に `expiresAt` を設定している。報酬比例の乗率・繰上げ繰下げ率は
/// 制度変更がない限り変わらない安定した値として扱う。
class PensionEstimatorCalculator extends Calculator {
  PensionEstimatorCalculator()
      : super(
          calcId: 'pension-estimator',
          title: '年金額の目安',
          parameters: _parameters,
          sources: [
            Source(
              title: '令和8年4月分からの年金額等について',
              url: 'https://www.nenkin.go.jp/oshirase/taisetu/kojin/2026/202604/0401.html',
              publisher: '日本年金機構',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.official,
            ),
            Source(
              title: '報酬比例部分の計算式（乗率5.481/1000・平成15年4月以降）',
              url: 'https://www.nenkin.go.jp/service/yougo/hagyo/hoshuhirei.html',
              publisher: '日本年金機構',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.official,
            ),
          ],
          reviewedAt: DateTime(2026, 10, 13),
        );

  static final _parameters = [
    // 令和8年度（昭和31年4月2日以後生まれ）の満額年額。
    _param('full-basic-pension-annual', 847296, '円',
        '老齢基礎年金の満額（40年=480ヶ月納付時・令和8年度）'),
    _param('full-basic-pension-months', 480, 'ヶ月', '満額となる納付月数（制度上安定）'),
    _param('employee-pension-rate', 5.481 / 1000, '乗率',
        '老齢厚生年金の報酬比例部分（平成15年4月以降の乗率・制度上安定）'),
    _param('early-claim-reduction-per-month', 0.004, '割合',
        '繰り上げ受給: 1ヶ月あたりの減額率（標準受給開始65歳・令和4年4月以降の制度・昭和37年4月2日以降生まれ対象）'),
    _param('delayed-claim-increase-per-month', 0.007, '割合',
        '繰り下げ受給: 1ヶ月あたりの増額率（制度上安定）'),
  ];

  static Parameter _param(String id, num value, String unit, String basis) => Parameter(
        paramId: id,
        value: value.toDouble(),
        unit: unit,
        basis: basis,
        lawVersion: '令和8年度（基礎年金満額）／令和4年4月以降（繰上げ繰下げ率）',
        retrievedAt: DateTime(2026, 10, 13),
        // 基礎年金満額は毎年度改定されるため、次回改定時期（2027年4月想定）で
        // 配信不可になるよう設定。乗率・繰上げ繰下げ率は制度変更がなければ
        // 変わらないが、同じ期限で一括管理する。
        expiresAt: DateTime(2027, 4, 1),
      );

  double _rate(String id) => parameters.firstWhere((p) => p.paramId == id).value;

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final detail = computeDetail(
      averageAnnualIncome: inputs['averageAnnualIncome']!.round(),
      pensionEnrollmentYears: inputs['pensionEnrollmentYears']!.round(),
      companySize: (inputs['selfEmployed'] ?? 0) != 0
          ? CompanySize.selfEmployed
          : CompanySize.employee,
      retirementAge: (inputs['retirementAge'] ?? 65).round(),
    );
    return CalculatorResult(value: detail.monthlyTotalPension.toDouble());
  }

  /// UI表示用の詳細結果。
  PensionEstimatorResult computeDetail({
    required int averageAnnualIncome,
    required int pensionEnrollmentYears,
    required CompanySize companySize,
    int retirementAge = 65,
  }) {
    final enrollmentMonths = pensionEnrollmentYears * 12;
    final fullBasicPensionMonths = _rate('full-basic-pension-months').round();

    final basicPensionMonths = enrollmentMonths.clamp(0, fullBasicPensionMonths);
    final baseAnnualBasicPension =
        (_rate('full-basic-pension-annual') * basicPensionMonths / fullBasicPensionMonths)
            .round();

    final avgMonthlyIncome = averageAnnualIncome / 12;
    final baseAnnualEmployeePension = companySize == CompanySize.selfEmployed
        ? 0
        : (avgMonthlyIncome * _rate('employee-pension-rate') * enrollmentMonths).round();

    final claimAgeAdjustment = _claimAgeAdjustmentFactor(retirementAge);
    final annualBasicPension = (baseAnnualBasicPension * claimAgeAdjustment).round();
    final annualEmployeePension = (baseAnnualEmployeePension * claimAgeAdjustment).round();

    final annualTotalPension = annualBasicPension + annualEmployeePension;
    final monthlyTotalPension = (annualTotalPension / 12).round();

    return PensionEstimatorResult(
      annualBasicPension: annualBasicPension,
      annualEmployeePension: annualEmployeePension,
      annualTotalPension: annualTotalPension,
      monthlyTotalPension: monthlyTotalPension,
    );
  }

  /// 受給開始年齢による年金額の調整率（標準受給開始年齢65歳を基準とする）。
  double _claimAgeAdjustmentFactor(int retirementAge) {
    final monthsDiff = (retirementAge - 65) * 12;
    return monthsDiff >= 0
        ? 1 + monthsDiff * _rate('delayed-claim-increase-per-month')
        : 1 + monthsDiff * _rate('early-claim-reduction-per-month');
  }
}
