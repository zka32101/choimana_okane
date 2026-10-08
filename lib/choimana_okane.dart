/// ちょいまな お金（choimana_okane）。
///
/// v0.1時点ではまだ固有コンテンツ・計算ロジックを実装していない
/// （kinnyu の既存計算の出典確認・移植が先行作業のため）。
/// choimana_kit の型をそのまま re-export し、依存の配線だけを確認する。
library;

export 'package:choimana_kit/choimana_kit.dart';

export 'calculators/compound_calculator.dart';
export 'calculators/furusato_nozei_calculator.dart';
export 'calculators/loan_repayment_calculator.dart';
export 'calculators/take_home_pay_calculator.dart';
