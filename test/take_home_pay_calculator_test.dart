import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = TakeHomePayCalculator();

  group('TakeHomePayCalculator', () {
    test('年収500万円・扶養なし・40歳未満の目安', () {
      final r = calc.computeDetail(grossAnnualIncome: 5000000);

      // kinnyu の元実装と同じ式で、手計算せず「大きく外れていないか」の帯で確認する。
      expect(r.socialInsurance.total, closeTo(5000000 * (0.0499 + 0.0915 + 0.006), 1));
      expect(r.socialInsurance.longTermCareInsurance, 0);
      expect(r.takeHomeAnnual, lessThan(r.grossAnnualIncome));
      expect(r.takeHomeRate, inInclusiveRange(0.7, 0.9));
    });

    test('40歳以上は介護保険料が加算される', () {
      final under40 = calc.computeDetail(grossAnnualIncome: 5000000, isOver40: false);
      final over40 = calc.computeDetail(grossAnnualIncome: 5000000, isOver40: true);

      expect(over40.socialInsurance.longTermCareInsurance, greaterThan(0));
      expect(over40.takeHomeAnnual, lessThan(under40.takeHomeAnnual));
    });

    test('扶養人数が増えると手取りが増える（控除が増えるため）', () {
      final noDependents = calc.computeDetail(grossAnnualIncome: 5000000, dependents: 0);
      final withDependents = calc.computeDetail(grossAnnualIncome: 5000000, dependents: 2);

      expect(withDependents.takeHomeAnnual, greaterThan(noDependents.takeHomeAnnual));
    });

    test('年収0円で例外にならない', () {
      final r = calc.computeDetail(grossAnnualIncome: 0);
      expect(r.takeHomeAnnual, 0);
      expect(r.takeHomeRate, 0.0);
    });

    test('choimana_kit の Calculator 契約: compute() は月額の目安を返す', () {
      final result = calc.compute({'grossAnnualIncome': 5000000});
      final detail = calc.computeDetail(grossAnnualIncome: 5000000);
      expect(result.value, detail.takeHomeMonthly.toDouble());
      expect(result.note, '目安');
    });

    test('定数は出典未確認のため、意図的に期限切れ（配信不可）になっている', () {
      expect(calc.parametersValidAt(DateTime(2026, 10, 8)), isFalse);
    });
  });
}
