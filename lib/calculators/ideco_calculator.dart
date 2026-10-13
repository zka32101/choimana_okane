import 'package:choimana_okane/choimana_okane.dart';

/// iDeCoの掛金上限は加入区分によって異なる。
enum IdecoOccupationType {
  /// 自営業者等（第1号被保険者）。
  selfEmployed,

  /// 会社員（企業年金なし）。
  employeeNoPension,

  /// 会社員（企業型DCのみ加入）。
  employeeWithDc,

  /// 会社員（DB・企業型DC併用等）。
  employeeWithDb,

  /// 公務員等。
  publicServant,

  /// 専業主婦(夫)（第3号被保険者）。
  dependentSpouse,
}

class IdecoResult {
  const IdecoResult({
    required this.monthlyLimit,
    required this.monthlyRemaining,
    required this.annualContribution,
    required this.estimatedAnnualTaxSaving,
  });

  final int monthlyLimit;
  final int monthlyRemaining;
  final int annualContribution;

  /// 掛金全額所得控除による概算節税額。
  final int estimatedAnnualTaxSaving;
}

/// iDeCoの掛金上限・節税効果の目安（型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `NisaIdecoCalculator.calculateIdeco` から
/// 移植。**投資の基礎（NISA/iDeCo）はMVPから除外する方針**（お金 企画
/// 設計書 v0.2 §3-1）。コードは先行して用意するが、Lesson化・UI公開は
/// MVPでは行わない。
///
/// 加入区分別の月額上限は制度上の数値のため年度依存（2024年度時点）。
/// 出典未確認のため [Parameter] の `expiresAt` を過去日付にしてある。
class IdecoCalculator extends Calculator {
  IdecoCalculator()
      : super(
          calcId: 'ideco',
          title: 'iDeCoの掛金上限・節税効果の目安',
          parameters: _parameters,
          sources: [
            Source(
              title: 'iDeCoの掛金上限（出典未確認・kinnyu移植時点のコメントのみ）',
              url: 'https://www.ideco-koushiki.jp/',
              publisher: '国民年金基金連合会',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  static final _parameters = [
    for (final type in IdecoOccupationType.values) _param(type, _legacyMonthlyLimit[type]!),
  ];

  static Parameter _param(IdecoOccupationType type, int value) => Parameter(
        paramId: 'ideco-monthly-limit-${type.name}',
        value: value.toDouble(),
        unit: '円',
        basis: 'iDeCoの月額拠出限度額（${type.name}・2024年度時点の目安）',
        lawVersion: '2024年度時点 — 出典未確認。制度変更時・2026年度で再確認が必要',
        retrievedAt: DateTime(2026, 1, 1),
        // 意図的に過去日付にして「このままでは配信できない」を機械的に強制する。
        expiresAt: DateTime(2026, 1, 1),
      );

  /// kinnyu から移植した近似値（出典未確認）。
  static const Map<IdecoOccupationType, int> _legacyMonthlyLimit = {
    IdecoOccupationType.selfEmployed: 68000,
    IdecoOccupationType.employeeNoPension: 23000,
    IdecoOccupationType.employeeWithDc: 20000,
    IdecoOccupationType.employeeWithDb: 12000,
    IdecoOccupationType.publicServant: 12000,
    IdecoOccupationType.dependentSpouse: 23000,
  };

  int _monthlyLimit(IdecoOccupationType type) => parameters
      .firstWhere((p) => p.paramId == 'ideco-monthly-limit-${type.name}')
      .value
      .round();

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final type = IdecoOccupationType.values[(inputs['occupationTypeIndex'] ?? 0).round()];
    final result = computeDetail(
      occupationType: type,
      monthlyContribution: inputs['monthlyContribution']!.round(),
      assumedTaxRatePercent: inputs['assumedTaxRatePercent'] ?? 20.0,
    );
    return CalculatorResult(value: result.estimatedAnnualTaxSaving.toDouble());
  }

  IdecoResult computeDetail({
    required IdecoOccupationType occupationType,
    required int monthlyContribution,
    double assumedTaxRatePercent = 20.0,
  }) {
    final monthlyLimit = _monthlyLimit(occupationType);
    final monthlyRemaining = (monthlyLimit - monthlyContribution).clamp(0, monthlyLimit);
    final annualContribution = monthlyContribution * 12;
    final estimatedAnnualTaxSaving =
        (annualContribution * assumedTaxRatePercent / 100).round();

    return IdecoResult(
      monthlyLimit: monthlyLimit,
      monthlyRemaining: monthlyRemaining,
      annualContribution: annualContribution,
      estimatedAnnualTaxSaving: estimatedAnnualTaxSaving,
    );
  }
}
