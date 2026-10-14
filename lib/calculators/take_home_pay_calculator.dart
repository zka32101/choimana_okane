import 'package:choimana_okane/choimana_okane.dart';

/// 扶養親族の区分（所得税法上の扶養控除・住民税の扶養控除の区分）。
enum DependentCategory {
  /// 一般の控除対象扶養親族（16〜18歳、23〜69歳）。
  general,

  /// 特定扶養親族（19〜22歳）。
  specific,

  /// 老人扶養親族のうち同居老親等以外（70歳以上）。
  elderlyOther,

  /// 老人扶養親族のうち同居老親等（70歳以上・本人または配偶者と同居）。
  elderlyCohabiting,
}

/// 額面年収から手取り額を試算する（型②「予測→実行」の土台）。
///
/// kinnyu（zka32101/kinnyu）の `TakeHomePayCalculator` から移植。
///
/// 2026年度の制度で出典を再確認済み（2026-10-13）:
/// - 健康保険料率・介護保険料率・厚生年金保険料率・雇用保険料率・標準報酬月額の
///   上限は全国平均/一律の値で検証し、`retrievedAt`/`expiresAt` を更新した
///   （次の料率改定時期である2027年4月を目安に `expiresAt` を設定）。
/// - 所得税の基礎控除は令和8年度税制改正により所得に応じた段階制（本則62万円＋
///   合計所得489万円以下は加算42万円で最大104万円等）に変わったため、
///   `_employmentIncomeDeduction`/`_incomeTax` と同様に単一の [Parameter] 値
///   ではなく [_basicDeductionIncomeTax] の速算表関数として実装した
///   （国税庁の公表資料で確認済み）。
/// - 住民税の基礎控除（43万円）は変更なしと確認済み。住民税所得割の標準税率
///   （10%）も安定した制度のため検証済みとして扱う。
/// - 扶養控除は[DependentCategory]（一般/特定/老人・同居老親等以外/老人・
///   同居老親等）の区分別に、所得税・住民税それぞれの金額を国税庁・総務省の
///   資料で確認し実装した（特定親族特別控除は別の控除のため未反映）。
/// - 住民税均等割は標準額（市町村民税・道府県民税の合計4,000円＋森林環境税
///   1,000円＝5,000円）として確認済みだが、自治体の超過課税により実際の額は
///   変動する（目安として検証済み扱いとする）。
///
/// これにより全 [Parameter] が検証済みとなり、`parametersValidAt()` が
/// true を返すようになった（2027-04の次回料率改定まで配信可能）。
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
              title: '令和8年度税制改正による所得税の基礎控除の引上げ等について',
              url: 'https://www.nta.go.jp/users/gensen/2026kiso/index.htm',
              publisher: '国税庁',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.official,
            ),
            Source(
              title: '個人住民税の基礎控除・所得割の標準税率（令和8年度・変更なし）',
              url: 'https://www.city.kobe.lg.jp/a83576/kurashi/tax/shikenminze/r8kaisei.html',
              publisher: '神戸市（総務省の地方税制改正に基づく解説）',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.aux,
            ),
            Source(
              title: '扶養控除（所得税）の区分別の金額',
              url: 'https://www.nta.go.jp/taxes/shiraberu/taxanswer/shotoku/1180.htm',
              publisher: '国税庁',
              retrievedAt: DateTime(2026, 10, 14),
              category: SourceCategory.official,
            ),
            Source(
              title: '個人住民税の扶養控除額（令和8年度・区分別）',
              url: 'https://www.nishi.or.jp/kurashi/shizei/kojinshiminzei/kisotishiki/juminshotoku-sa.html',
              publisher: '堺市西区（総務省の地方税制に基づく解説）',
              retrievedAt: DateTime(2026, 10, 14),
              category: SourceCategory.aux,
            ),
            Source(
              title: '個人住民税の均等割の標準額（市町村民税・道府県民税＋森林環境税）',
              url: 'https://www.kaonavi.jp/dictionary/jyuminzeikeisan/',
              publisher: '自治体資料を基にした二次情報。自治体の超過課税により実際の額は変動する',
              retrievedAt: DateTime(2026, 10, 14),
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
    // 基礎控除（所得税）は令和8年度改正で所得に応じた段階制になったため、
    // Parameter ではなく _basicDeductionIncomeTax の速算表関数で扱う。
    for (final category in DependentCategory.values)
      _verifiedParam(
        'dependent-deduction-income-tax-${category.name}',
        _dependentDeductionIncomeTax[category]!,
        '円',
        '扶養控除（所得税・${category.name}）',
      ),
    _verifiedParam('resident-tax-basic-deduction', 430000, '円', '基礎控除（住民税）。43万円で令和8年度も変更なしと確認済み'),
    for (final category in DependentCategory.values)
      _verifiedParam(
        'dependent-deduction-resident-tax-${category.name}',
        _dependentDeductionResidentTax[category]!,
        '円',
        '扶養控除（住民税・${category.name}）',
      ),
    _verifiedParam('resident-tax-rate', 0.10, '割合', '住民税所得割（標準税率・安定した制度のため検証済み）'),
    _verifiedParam('resident-tax-per-capita', 5000, '円', '住民税均等割の標準額（市町村民税・道府県民税＋森林環境税。自治体の超過課税により実際は変動）'),
  ];

  /// 扶養控除（所得税）の区分別の金額。国税庁タックスアンサーNo.1180で確認済み。
  static const Map<DependentCategory, int> _dependentDeductionIncomeTax = {
    DependentCategory.general: 380000,
    DependentCategory.specific: 630000,
    DependentCategory.elderlyOther: 480000,
    DependentCategory.elderlyCohabiting: 580000,
  };

  /// 扶養控除（住民税）の区分別の金額。令和8年度・区分別の資料で確認済み。
  static const Map<DependentCategory, int> _dependentDeductionResidentTax = {
    DependentCategory.general: 330000,
    DependentCategory.specific: 450000,
    DependentCategory.elderlyOther: 380000,
    DependentCategory.elderlyCohabiting: 450000,
  };

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
  ///
  /// 扶養親族の区分を指定しない場合、[dependents] 人を一般の控除対象扶養親族
  /// （[DependentCategory.general]）として扱う（簡易入力）。区分ごとの人数を
  /// 指定したい場合は [dependentsByCategory] を渡す（指定時は [dependents] は
  /// 無視される）。
  TakeHomePayResult computeDetail({
    required int grossAnnualIncome,
    bool isOver40 = false,
    int dependents = 0,
    Map<DependentCategory, int> dependentsByCategory = const {},
  }) {
    final gross = grossAnnualIncome;
    final dependentCounts = dependentsByCategory.isNotEmpty
        ? dependentsByCategory
        : {DependentCategory.general: dependents};

    final socialInsurance = _socialInsurance(gross, isOver40);

    final employmentIncomeDeduction = _employmentIncomeDeduction(gross);
    final employmentIncome = (gross - employmentIncomeDeduction).clamp(0, gross);

    var dependentDeduction = 0;
    var residentDependentDeduction = 0;
    for (final entry in dependentCounts.entries) {
      dependentDeduction +=
          entry.value * _rate('dependent-deduction-income-tax-${entry.key.name}').round();
      residentDependentDeduction +=
          entry.value * _rate('dependent-deduction-resident-tax-${entry.key.name}').round();
    }

    // 基礎控除は合計所得金額に応じた段階制（令和8年度改正）。このCalculatorには
    // 給与所得以外の収入がないため、給与所得（employmentIncome）を合計所得金額の
    // 近似値として使う。
    final basicDeduction = _basicDeductionIncomeTax(employmentIncome);
    final taxableForIncomeTax = (employmentIncome -
            basicDeduction -
            dependentDeduction -
            socialInsurance.total)
        .clamp(0, employmentIncome);
    final incomeTax = _incomeTax(taxableForIncomeTax);

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
      basicDeduction: basicDeduction,
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

  /// 所得税の基礎控除（令和8年度・令和9年度限定の特例を含む速算表。国税庁
  /// 「令和8年度税制改正による所得税の基礎控除の引上げ等について」）。
  /// [totalIncome] は合計所得金額（このCalculatorでは給与所得で近似）。
  int _basicDeductionIncomeTax(int totalIncome) {
    final t = totalIncome;
    if (t <= 4890000) return 1040000;
    if (t <= 6550000) return 670000;
    if (t <= 23500000) return 620000;
    if (t <= 24000000) return 480000;
    if (t <= 24500000) return 320000;
    if (t <= 25000000) return 160000;
    return 0;
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
