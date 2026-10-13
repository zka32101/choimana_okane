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
/// 加入区分別の月額上限は制度上の数値。2026-10-13に出典確認した時点
/// （2026年11月まで）の値は kinnyu から移植した近似値のまま有効だが、
/// **2026年12月1日から拠出限度額の制度改正が施行される**ことが確認できた
/// （第1号: 6.8万→7.5万円、企業年金なしの会社員: 2.3万→6.2万円等）。
/// 改正後の値は加入先の企業年金の有無・金額によって個別に変わる複雑な
/// 計算式になるため、このバージョンでは「改正前（2026年11月まで）の値」を
/// 検証済みとして使い、`expiresAt` を施行日の直前に設定して配信停止を
/// 機械的に強制する。改正後の計算式は別途再実装が必要（次の作業）。
class IdecoCalculator extends Calculator {
  IdecoCalculator()
      : super(
          calcId: 'ideco',
          title: 'iDeCoの掛金上限・節税効果の目安',
          parameters: _parameters,
          sources: [
            Source(
              title: 'iDeCoの拠出限度額の見直し（2026年12月1日施行）',
              url: 'https://www.mhlw.go.jp/content/12500000/001739467.pdf',
              publisher: '厚生労働省',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.official,
            ),
          ],
          reviewedAt: DateTime(2026, 10, 13),
        );

  static final _parameters = [
    for (final type in IdecoOccupationType.values) _param(type, _monthlyLimitUntil202611[type]!),
  ];

  static Parameter _param(IdecoOccupationType type, int value) => Parameter(
        paramId: 'ideco-monthly-limit-${type.name}',
        value: value.toDouble(),
        unit: '円',
        basis: 'iDeCoの月額拠出限度額（${type.name}・2026年12月の制度改正前の値）',
        lawVersion: '2026年11月まで（2026年12月1日に拠出限度額の制度改正が施行される予定）',
        retrievedAt: DateTime(2026, 10, 13),
        // 2026年12月1日の制度改正施行日の直前で配信停止になるよう設定。
        expiresAt: DateTime(2026, 12, 1),
      );

  /// kinnyu から移植した、2026年12月の制度改正前の値（確認済み）。
  static const Map<IdecoOccupationType, int> _monthlyLimitUntil202611 = {
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
