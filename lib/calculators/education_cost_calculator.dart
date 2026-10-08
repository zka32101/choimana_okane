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
/// 『子供の学習費調査』等を参考にした近似値」とされているが、**具体的な
/// 出典URL・調査年度が明記されていない**。他の Calculator と同様、
/// [Parameter] の `expiresAt` を過去日付にして配信不可を機械的に強制する。
class EducationCostCalculator extends Calculator {
  EducationCostCalculator()
      : super(
          calcId: 'education-cost',
          title: '教育費の目安',
          parameters: _parameters,
          sources: [
            Source(
              title: '子供の学習費調査（出典未確認。kinnyu移植時点のコメントに'
                  '「文部科学省『子供の学習費調査』等を参考」とあるのみで、'
                  '具体的な調査年度・URLの記載なし）',
              url: 'https://www.mext.go.jp/',
              publisher: '文部科学省（推定。要確認）',
              retrievedAt: DateTime(2026, 1, 1),
              category: SourceCategory.aux,
            ),
          ],
          reviewedAt: DateTime(2026, 1, 1),
        );

  static final _parameters = [
    for (final stage in EducationStage.values)
      for (final track in SchoolTrack.values)
        _param(stage, track, _legacyCostTable[stage]![track]!),
  ];

  static Parameter _param(EducationStage stage, SchoolTrack track, int value) => Parameter(
        paramId: 'education-cost-${stage.name}-${track.name}',
        value: value.toDouble(),
        unit: '円',
        basis: '${stage.name}（${track.name}）の教育費総額（出典未確認）',
        lawVersion: '出典未確認（調査年度不明）— 文部科学省の調査等で再確認が必要',
        retrievedAt: DateTime(2026, 1, 1),
        // 意図的に過去日付にして「このままでは配信できない」を機械的に強制する。
        expiresAt: DateTime(2026, 1, 1),
      );

  /// kinnyu から移植した近似値（出典未確認）。
  static const Map<EducationStage, Map<SchoolTrack, int>> _legacyCostTable = {
    EducationStage.kindergarten: {
      SchoolTrack.public: 700000,
      SchoolTrack.private: 1580000,
    },
    EducationStage.elementary: {
      SchoolTrack.public: 1920000,
      SchoolTrack.private: 9600000,
    },
    EducationStage.juniorHigh: {
      SchoolTrack.public: 1460000,
      SchoolTrack.private: 4050000,
    },
    EducationStage.highSchool: {
      SchoolTrack.public: 1370000,
      SchoolTrack.private: 2900000,
    },
    EducationStage.university: {
      SchoolTrack.public: 2550000,
      SchoolTrack.private: 4750000,
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
