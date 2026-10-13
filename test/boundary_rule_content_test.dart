import 'dart:convert';
import 'dart:io';

import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

/// content/boundary_rules/furusato-nozei-one-stop.json の実データを使い、
/// BoundaryRule.evaluate() が条件の組み合わせごとに正しい結論を返すことを確認する。
void main() {
  late BoundaryRule rule;

  setUpAll(() {
    final json =
        jsonDecode(File('content/boundary_rules/furusato-nozei-one-stop.json').readAsStringSync())
            as Map<String, dynamic>;
    rule = BoundaryRule.fromJson(json);
  });

  group('furusato-nozei-one-stop', () {
    test('寄付先5自治体以内・もともと確定申告不要ならワンストップ特例で申告不要', () {
      final outcome = rule.evaluate({
        'alreadyFilesTaxReturn': false,
        'donatesToFiveOrFewerMunicipalities': true,
      });
      expect(outcome, isNotNull);
      expect(outcome!.conclusion, contains('確定申告なしで控除を受けられる'));
    });

    test('寄付先6自治体以上なら確定申告が必要', () {
      final outcome = rule.evaluate({
        'alreadyFilesTaxReturn': false,
        'donatesToFiveOrFewerMunicipalities': false,
      });
      expect(outcome, isNotNull);
      expect(outcome!.conclusion, contains('6自治体以上'));
    });

    test('もともと確定申告が必要な人は、寄付先が5以内でも確定申告が必要', () {
      final outcome = rule.evaluate({
        'alreadyFilesTaxReturn': true,
        'donatesToFiveOrFewerMunicipalities': true,
      });
      expect(outcome, isNotNull);
      expect(outcome!.conclusion, contains('もともと確定申告が必要なため'));
    });

    test('出典・施行日があり、鮮度もOKなので配信可能', () {
      expect(rule.isDeliverableAt(DateTime(2026, 10, 20)), isTrue);
    });
  });
}
