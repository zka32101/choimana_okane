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
/// 枠の金額は2026-10-13に出典確認済み。2026年度も2024年度の新NISA制度の
/// 枠（つみたて120万円・成長240万円・生涯1,800万円）から変更がないことを
/// 確認した。ただし2027年1月から18歳未満向けの枠が新設される見込みのため
/// （18歳以上の枠自体は変更なしだが、制度の前提が変わる節目のため）、
/// `expiresAt` をその直前に設定し再確認を促す。
class NisaCalculator extends Calculator {
  NisaCalculator()
      : super(
          calcId: 'nisa',
          title: 'NISA枠の消化状況の目安',
          parameters: _parameters,
          sources: [
            Source(
              title: '令和8年度税制改正大綱（NISA制度・18歳未満向け枠の新設等）',
              url: 'https://www.fsa.go.jp/news/r7/sonota/20251226-2/01.pdf',
              publisher: '金融庁',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.official,
            ),
          ],
          reviewedAt: DateTime(2026, 10, 13),
        );

  static final _parameters = [
    _param('tsumitate-annual-limit', 1200000, '円', 'つみたて投資枠の年間上限（18歳以上・2026年度も変更なし）'),
    _param('growth-annual-limit', 2400000, '円', '成長投資枠の年間上限（2026年度も変更なし）'),
    _param('lifetime-limit', 18000000, '円', '生涯投資枠の上限（合計・2026年度も変更なし）'),
  ];

  static Parameter _param(String id, int value, String unit, String basis) => Parameter(
        paramId: id,
        value: value.toDouble(),
        unit: unit,
        basis: basis,
        lawVersion: '新NISA制度（2024年度〜。2026年度も変更なしを確認済み）',
        retrievedAt: DateTime(2026, 10, 13),
        // 2027年1月に18歳未満向け枠が新設される見込みのため、その直前で
        // 再確認を促す。
        expiresAt: DateTime(2027, 1, 1),
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
