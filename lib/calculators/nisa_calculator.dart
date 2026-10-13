import 'package:choimana_okane/choimana_okane.dart';

class NisaResult {
  const NisaResult({
    required this.tsumitateRemaining,
    required this.growthRemaining,
    required this.annualRemaining,
    required this.lifetimeRemaining,
  });

  final int tsumitateRemaining;
  final int growthRemaining;
  final int annualRemaining;
  final int lifetimeRemaining;
}

/// NISAの非課税投資枠の消化状況の目安（型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `NisaIdecoCalculator.calculateNisa` から
/// 移植。**投資の基礎（NISA/iDeCo）はMVPから除外する方針**（お金 企画
/// 設計書 v0.2 §3-1。金融商品の勧誘と受け取られるリスクがあり、弁護士
/// 確認後の第2弾で扱う）。コードは先行して用意するが、Lesson化・UI公開
/// はMVPでは行わない。
///
/// 枠の金額は制度上の数値のため年度依存（2024年度時点の新NISA制度）。
/// 出典未確認のため、他の Calculator と同様に [Parameter] の
/// `expiresAt` を過去日付にしてある。
class NisaCalculator extends Calculator {
  NisaCalculator()
      : super(
          calcId: 'nisa',
          title: 'NISA枠の消化状況の目安',
          parameters: _parameters,
          sources: [
            Source(
              title: 'NISA制度の概要（出典未確認・kinnyu移植時点のコメントのみ）',
              url: 'https://www.fsa.go.jp/',
              publisher: '金融庁',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  static final _parameters = [
    _param('tsumitate-annual-limit', 1200000, '円', 'つみたて投資枠の年間上限'),
    _param('growth-annual-limit', 2400000, '円', '成長投資枠の年間上限'),
    _param('lifetime-limit', 18000000, '円', '生涯投資枠の上限（合計）'),
  ];

  static Parameter _param(String id, int value, String unit, String basis) => Parameter(
        paramId: id,
        value: value.toDouble(),
        unit: unit,
        basis: basis,
        lawVersion: '2024年度（新NISA制度）— 出典未確認。制度変更時・2026年度で再確認が必要',
        retrievedAt: DateTime(2026, 1, 1),
        // 意図的に過去日付にして「このままでは配信できない」を機械的に強制する。
        expiresAt: DateTime(2026, 1, 1),
      );

  int _limit(String id) => parameters.firstWhere((p) => p.paramId == id).value.round();

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final result = computeDetail(
      tsumitateInvestedThisYear: (inputs['tsumitateInvestedThisYear'] ?? 0).round(),
      growthInvestedThisYear: (inputs['growthInvestedThisYear'] ?? 0).round(),
      lifetimeInvestedTotal: (inputs['lifetimeInvestedTotal'] ?? 0).round(),
    );
    return CalculatorResult(value: result.annualRemaining.toDouble());
  }

  NisaResult computeDetail({
    int tsumitateInvestedThisYear = 0,
    int growthInvestedThisYear = 0,
    int lifetimeInvestedTotal = 0,
  }) {
    final tsumitateLimit = _limit('tsumitate-annual-limit');
    final growthLimit = _limit('growth-annual-limit');
    final lifetimeLimit = _limit('lifetime-limit');

    final tsumitateRemaining =
        (tsumitateLimit - tsumitateInvestedThisYear).clamp(0, tsumitateLimit);
    final growthRemaining = (growthLimit - growthInvestedThisYear).clamp(0, growthLimit);
    final lifetimeRemaining = (lifetimeLimit - lifetimeInvestedTotal).clamp(0, lifetimeLimit);

    return NisaResult(
      tsumitateRemaining: tsumitateRemaining,
      growthRemaining: growthRemaining,
      annualRemaining: tsumitateRemaining + growthRemaining,
      lifetimeRemaining: lifetimeRemaining,
    );
  }
}
