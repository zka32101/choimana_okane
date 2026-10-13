import 'package:choimana_okane/choimana_okane.dart';

/// 教育段階。
enum EducationStage { kindergarten, elementary, juniorHigh, highSchool, university }

extension EducationStageInfo on EducationStage {
  /// 標準的な就学開始年齢。
  int get startAge => switch (this) {
        EducationStage.kindergarten => 3,
        EducationStage.elementary => 6,
        EducationStage.juniorHigh => 12,
        EducationStage.highSchool => 15,
        EducationStage.university => 18,
      };
}

/// 進路（公立/私立）。
enum SchoolTrack { public, private }

class EducationStageCost {
  const EducationStageCost({
    required this.stage,
    required this.track,
    required this.totalCost,
    required this.yearsUntilStart,
  });

  final EducationStage stage;
  final SchoolTrack track;
  final int totalCost;

  /// 現在からその段階が始まるまでの年数。
  final int yearsUntilStart;
}

class EducationCostResult {
  const EducationCostResult({
    required this.stageCosts,
    required this.totalCost,
    required this.remainingCost,
    required this.yearsUntilUniversity,
    required this.requiredMonthlySavings,
  });

  final List<EducationStageCost> stageCosts;

  /// 幼稚園〜大学の生涯教育費合計（参考表示用）。
  final int totalCost;

  /// 大学費用 − 既存の積立額（下限0）。幼稚園〜高校は都度の家計から支出
  /// される想定のため、事前にまとまった積立が必要な大学費用のみを対象とする。
  final int remainingCost;
  final int yearsUntilUniversity;

  /// 大学入学までに準備すべき月々の積立額の目安。
  final int requiredMonthlySavings;
}

/// 進学プランに応じた教育費の総額と必要な積立額の目安
/// （型②「予測→実行」）。
///
/// kinnyu（zka32101/kinnyu）の `EducationCostPlanner` から移植。
/// 段階別・進路別の費用テーブルは、kinnyu側のコメントで「文部科学省
/// 『子供の学習費調査』等を参考にした近似値」とされていたが、**具体的な
/// 出典URL・調査年度が明記されていなかった**ため、2026-10-13に文部科学省
/// 「令和5年度子供の学習費調査」（幼稚園〜高校）の公表データで実際の年間
/// 学習費総額×各段階の年数に置き換えて出典確認した。大学費用は文科省調査を
/// 基にした二次情報（出典明記あり・aux）で確認した。
class EducationCostCalculator extends Calculator {
  EducationCostCalculator()
      : super(
          calcId: 'education-cost',
          title: '教育費の目安',
          parameters: _parameters,
          sources: [
            Source(
              title: '令和5年度子供の学習費調査結果のポイント（幼稚園〜高校の学習費総額）',
              url: 'https://www.mext.go.jp/content/20260116-mxt_chousa01-000039333_1.pdf',
              publisher: '文部科学省',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.official,
            ),
            Source(
              title: '大学の学費ってどれぐらい？（文部科学省の調査を基にした4年間の学費総額の目安）',
              url: 'https://www.nomura.co.jp/fin-wing/column/study_expenses_for_university/',
              publisher: '野村の金融経済教育サイト「Fin Wing」（文科省調査の二次情報）',
              retrievedAt: DateTime(2026, 10, 13),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 10, 13),
        );

  static final _parameters = [
    for (final stage in EducationStage.values)
      for (final track in SchoolTrack.values)
        _param(stage, track, _costTable[stage]![track]!),
  ];

  static Parameter _param(EducationStage stage, SchoolTrack track, int value) => Parameter(
        paramId: 'education-cost-${stage.name}-${track.name}',
        value: value.toDouble(),
        unit: '円',
        basis: '${stage.name}（${track.name}）の教育費総額（令和5年度子供の学習費調査等に基づく）',
        lawVersion: '令和5年度子供の学習費調査（文部科学省。概ね2年おきに調査・公表）',
        retrievedAt: DateTime(2026, 10, 13),
        // 調査はおおむね2年に1度のペースのため、次回公表（2028年頃想定）を
        // 目安に expiresAt を設定する。
        expiresAt: DateTime(2028, 1, 1),
      );

  /// 文部科学省「令和5年度子供の学習費調査」の年間学習費総額×各段階の年数
  /// （幼稚園3年・小学校6年・中学校3年・高校3年）。大学は二次情報（Fin Wing）
  /// による4年間総額の目安。
  static const Map<EducationStage, Map<SchoolTrack, int>> _costTable = {
    EducationStage.kindergarten: {
      SchoolTrack.public: 555000, // 185,000円/年 × 3年
      SchoolTrack.private: 1041000, // 347,000円/年 × 3年
    },
    EducationStage.elementary: {
      SchoolTrack.public: 2202000, // 367,000円/年 × 6年
      SchoolTrack.private: 10452000, // 1,742,000円/年 × 6年
    },
    EducationStage.juniorHigh: {
      SchoolTrack.public: 1626000, // 542,000円/年 × 3年
      SchoolTrack.private: 4680000, // 1,560,000円/年 × 3年
    },
    EducationStage.highSchool: {
      SchoolTrack.public: 1791000, // 597,000円/年 × 3年
      SchoolTrack.private: 3537000, // 1,179,000円/年 × 3年
    },
    EducationStage.university: {
      SchoolTrack.public: 2420000, // 国公立4年間の目安（入学金含む）
      SchoolTrack.private: 5186942, // 私立4年間の目安（文系・理系等の平均）
    },
  };

  int _cost(EducationStage stage, SchoolTrack track) => parameters
      .firstWhere((p) => p.paramId == 'education-cost-${stage.name}-${track.name}')
      .value
      .round();

  @override
  CalculatorResult compute(Map<String, double> inputs) {
    final university = (inputs['universityPrivate'] ?? 0) != 0
        ? SchoolTrack.private
        : SchoolTrack.public;
    final result = computeDetail(
      childCurrentAge: inputs['childCurrentAge']!.round(),
      tracks: {EducationStage.university: university},
      currentSavings: (inputs['currentSavings'] ?? 0).round(),
    );
    return CalculatorResult(value: result.requiredMonthlySavings.toDouble());
  }

  EducationCostResult computeDetail({
    required int childCurrentAge,
    Map<EducationStage, SchoolTrack> tracks = const {},
    int currentSavings = 0,
  }) {
    final stageCosts = <EducationStageCost>[];
    var totalCost = 0;

    for (final stage in EducationStage.values) {
      final track = tracks[stage] ?? SchoolTrack.public;
      final cost = _cost(stage, track);
      totalCost += cost;

      stageCosts.add(EducationStageCost(
        stage: stage,
        track: track,
        totalCost: cost,
        yearsUntilStart: (stage.startAge - childCurrentAge).clamp(0, 100),
      ));
    }

    final universityTrack = tracks[EducationStage.university] ?? SchoolTrack.public;
    final universityCost = _cost(EducationStage.university, universityTrack);
    final remainingCost = (universityCost - currentSavings).clamp(0, universityCost);
    final yearsUntilUniversity =
        (EducationStage.university.startAge - childCurrentAge).clamp(0, 100);
    final monthsUntilUniversity = yearsUntilUniversity * 12;
    final requiredMonthlySavings =
        monthsUntilUniversity > 0 ? (remainingCost / monthsUntilUniversity).ceil() : remainingCost;

    return EducationCostResult(
      stageCosts: stageCosts,
      totalCost: totalCost,
      remainingCost: remainingCost,
      yearsUntilUniversity: yearsUntilUniversity,
      requiredMonthlySavings: requiredMonthlySavings,
    );
  }
}
