import 'package:choimana_okane/choimana_okane.dart';

/// 額面年収から手取り額を試算する（型②「予測→実行」の土台）。
///
/// kinnyu（zka32101/kinnyu）の `TakeHomePayCalculator` から移植。
///
/// 2026年度の制度で出典を再確認済み（2026-10-13）:
/// - 健康保険料率・介護保険料率・厚生年金保険料率・雇用保険料率・標準報酬月額の
///   上限は全国平均/一律の値で検証し、`retrievedAt`/`expiresAt` を更新した
///   （次の料率改定時期である2027年4月を目安に `expiresAt` を設定）。
/// - 一方、所得税の基礎控除は令和8年度税制改正により**所得に応じた段階制
///   （本則62万円＋合計所得489万円以下は加算42万円で最大104万円等）**に
///   変わり、単一の [Parameter] 値では正しく表現できない。扶養控除も特定親族
///   特別控除の新設など要件が変わっている。これらは依然**出典未確認・
///   要再実装（速算表化が必要）**のため [expiresAt] を過去日付のままにして
///   [parametersValidAt] が false を返すようにしてある
///   （Lesson の鮮度チェックと同じ「安全側に倒す」考え方）。住民税の基礎控除
///   43万円は変更なしと確認できたが、連動する所得税側が未実装のため同様に
///   期限切れのままにしている。
class TakeHomePayCalculator extends Calculator {
  TakeHomePayCalculator()
      : super(
          calcId: 'take-home-pay',
          title: '手取りの目安',
          parameters: _parameters,
          sources: [
            Source(
              title: '令和8年度における協会けんぽの保険料率等について',
              url: 'https://www.kyoukaikenpo.or.jp/file/202510231821.pdf',
              publisher: '全国健康保険協会（協会けんぽ）',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.aux,
            ),
            Source(
              title: '厚生年金保険料率・標準報酬月額の上限（令和8年度）',
              url: 'https://www.mhlw.go.jp/stf/seisakunitsuite/bunya/0000147284_00024.html',
              publisher: '厚生労働省',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.aux,
            ),
            Source(
              title: '令和8年度の雇用保険料率',
              url: 'https://www.yayoi-kk.co.jp/lawinfo/detail.20260313/',
              publisher: '厚生労働省告示（令和8年3月12日付官報）',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.aux,
            ),
            Source(
              title: '所得税の仕組み（基礎控除・扶養控除は令和8年度改正で段階制に変更。未反映）',
              url: 'https://www.nta.go.jp/',
              publisher: '国税庁',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 10, 13),
        );

  static final _parameters = [
    // 全国健康保険協会の令和8年度全国平均9.90%の従業員負担分（折半）。
    // 都道府県ごとに料率が異なるため、全国平均を目安値として使用。
    _verifiedParam('health-insurance-rate', 0.0495, '割合', '健康保険料率（全国平均・従業員負担分・令和8年度）'),
    // 介護保険料率は全国一律1.62%の従業員負担分（折半）。
    _verifiedParam('ltc-insurance-rate', 0.0081, '割合', '介護保険料率（40歳以上・全国一律・令和8年度）'),
    // 18.3%の従業員負担分（折半）。令和7年年金制度改正法により上限額は
    // 2027年9月以降段階的に引き上げ予定（65万→68万→71万→75万）。
    _verifiedParam('pension-insurance-rate', 0.0915, '割合', '厚生年金保険料率（従業員負担分・令和8年度）'),
    // 一般の事業 13.5/1000 のうち労働者負担5/1000。
    _verifiedParam('employment-insurance-rate', 0.005, '割合', '雇用保険料率（一般の事業・従業員負担分・令和8年度）'),
    _verifiedParam('pensionable-income-cap', 7800000, '円', '標準報酬月額の上限（65万円・年額換算）。2027年9月以降68万円へ引き上げ予定'),
    _unverifiedParam('basic-deduction', 480000, '円', '基礎控除（所得税）。令和8年度改正で所得に応じた段階制（本則62万+加算最大42万=最大104万）に変更されたため未反映・要再実装'),
    _unverifiedParam('dependent-deduction-per-person', 380000, '円', '扶養控除（所得税・1人あたり概算）。特定親族特別控除の新設など要件変更が未反映'),
    _unverifiedParam('resident-tax-basic-deduction', 430000, '円', '基礎控除（住民税）。43万円で変更なしと確認済みだが、連動する所得税側が未実装のため暫定的に未検証扱い'),
    _unverifiedParam('resident-tax-dependent-deduction-per-person', 330000, '円', '扶養控除（住民税・一般・1人あたり）'),
    _unverifiedParam('resident-tax-rate', 0.10, '割合', '住民税所得割（標準税率）'),
    _unverifiedParam('resident-tax-per-capita', 5000, '円', '住民税均等割の概算（自治体により変動）'),
  ];

  /// 2026-10-13に出典を確認済みの定数。次回の料率改定（2027年4月想定）まで
  /// 配信可能とする。
  static Parameter _verifiedParam(String id, num value, String unit, String basis) => Parameter(
        paramId: id,
        value: value.toDouble(),
        unit: unit,
        basis: basis,
        lawVersion: '令和8年度（2026年度）',
        retrievedAt: DateTime(2026, 10, 13),
        expiresAt: DateTime(2027, 4, 1),
      );

  /// 出典未確認・制度変更未反映のため、意図的に過去日付にして
  /// 「このままでは配信できない」を機械的に強制する。
  static Parameter _unverifiedParam(String id, num value, String unit, String basis) => Parameter(
        paramId: id,
        value: value.toDouble(),
        unit: unit,
        basis: basis,
        lawVersion: '令和6年分（2024年度）の値のまま — 令和8年度税制改正の反映が必要',
        retrievedAt: DateTime(2026, 1, 1),
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
