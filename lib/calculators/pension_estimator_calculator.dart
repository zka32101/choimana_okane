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
/// 日本年金機構の制度に基づくが2024年度時点のまま出典未確認。他の
/// Calculator と同じく [Parameter] の `expiresAt` を過去日付にしてある。
class PensionEstimatorCalculator extends Calculator {
  PensionEstimatorCalculator()
      : super(
          calcId: 'pension-estimator',
          title: '年金額の目安',
          parameters: _parameters,
          sources: [
            Source(
              title: '老齢年金の受給額（出典未確認・kinnyu移植時点のコメントのみ）',
              url: 'https://www.nenkin.go.jp/',
              publisher: '日本年金機構',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  static final _parameters = [
    _param('full-basic-pension-annual', 816000, '円',
        '老齢基礎年金の満額（40年=480ヶ月納付時・2024年度）'),
    _param('full-basic-pension-months', 480, 'ヶ月', '満額となる納付月数'),
    _param('employee-pension-rate', 5.481 / 1000, '乗率',
        '老齢厚生年金の報酬比例部分（2003年4月以降の簡易乗率）'),
    _param('early-claim-reduction-per-month', 0.004, '割合',
        '繰り上げ受給: 1ヶ月あたりの減額率（標準受給開始65歳・2022年4月以降の制度）'),
    _param('delayed-claim-increase-per-month', 0.007, '割合',
        '繰り下げ受給: 1ヶ月あたりの増額率'),
  ];

  static Parameter _param(String id, num value, String unit, String basis) => Parameter(
        paramId: id,
        value: value.toDouble(),
        unit: unit,
        basis: basis,
        lawVersion: '2024年度（基礎年金満額）／2022年4月以降（繰上げ繰下げ率）'
            ' — 出典未確認。2026年度で再確認が必要',
        retrievedAt: DateTime(2026, 1, 1),
        // 意図的に過去日付にして「このままでは配信できない」を機械的に強制する。
        expiresAt: DateTime(2026, 1, 1),
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
