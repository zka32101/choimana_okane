import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = IdecoCalculator();

  group('IdecoCalculator', () {
    test('定数は出典未確認のため、意図的に期限切れ（配信不可）になっている', () {
      expect(calc.parametersValidAt(DateTime(2026, 10, 8)), isFalse);
    });

    test('加入区分ごとに月額上限が異なる', () {
      final selfEmployed = calc.computeDetail(
        occupationType: IdecoOccupationType.selfEmployed,
        monthlyContribution: 0,
      );
      final publicServant = calc.computeDetail(
        occupationType: IdecoOccupationType.publicServant,
        monthlyContribution: 0,
      );
      expect(selfEmployed.monthlyLimit, 68000);
      expect(publicServant.monthlyLimit, 12000);
    });

    test('年間拠出額は月額×12', () {
      final r = calc.computeDetail(
        occupationType: IdecoOccupationType.employeeNoPension,
        monthlyContribution: 20000,
      );
      expect(r.annualContribution, 240000);
    });

    test('節税額は年間拠出額×想定税率', () {
      final r = calc.computeDetail(
        occupationType: IdecoOccupationType.employeeNoPension,
        monthlyContribution: 20000,
        assumedTaxRatePercent: 20.0,
      );
      expect(r.estimatedAnnualTaxSaving, (240000 * 0.2).round());
    });

    test('choimana_kit の Calculator 契約: compute() は節税額を返す', () {
      final result = calc.compute({
        'occupationTypeIndex': IdecoOccupationType.employeeNoPension.index.toDouble(),
        'monthlyContribution': 20000,
      });
      final detail = calc.computeDetail(
        occupationType: IdecoOccupationType.employeeNoPension,
        monthlyContribution: 20000,
      );
      expect(result.value, detail.estimatedAnnualTaxSaving.toDouble());
      expect(result.note, '目安');
    });
  });
}
