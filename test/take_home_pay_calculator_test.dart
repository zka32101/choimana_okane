import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = TakeHomePayCalculator();

  group('TakeHomePayCalculator', () {
    test('年収500万円・扶養なし・40歳未満の目安', () {
      final r = calc.computeDetail(grossAnnualIncome: 5000000);

      // kinnyu の元実装と同じ式で、手計算せず「大きく外れていないか」の帯で確認する。
      expect(r.socialInsurance.total, closeTo(5000000 * (0.0495 + 0.0915 + 0.005), 1));
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

    test('choimana_core の Calculator 契約: compute() は月額の目安を返す', () {
      final result = calc.compute({'grossAnnualIncome': 5000000});
      final detail = calc.computeDetail(grossAnnualIncome: 5000000);
      expect(result.value, detail.takeHomeMonthly.toDouble());
      expect(result.note, '目安');
    });

    test('全定数が出典確認済みのため配信可能（2027-04の次回料率改定まで）', () {
      expect(calc.parametersValidAt(DateTime(2026, 10, 8)), isTrue);
      expect(calc.parametersValidAt(DateTime(2027, 5, 1)), isFalse);
    });
  });

  group('扶養控除の区分別の金額', () {
    test('一般の扶養親族は所得税38万円・住民税33万円', () {
      final withGeneral = calc.computeDetail(
        grossAnnualIncome: 5000000,
        dependentsByCategory: {DependentCategory.general: 1},
      );
      final without = calc.computeDetail(grossAnnualIncome: 5000000);
      expect(withGeneral.dependentDeduction, 380000);
      expect(withGeneral.takeHomeAnnual, greaterThan(without.takeHomeAnnual));
    });

    test('特定扶養親族（19〜22歳）は一般より控除額が大きい', () {
      final general = calc.computeDetail(
        grossAnnualIncome: 5000000,
        dependentsByCategory: {DependentCategory.general: 1},
      );
      final specific = calc.computeDetail(
        grossAnnualIncome: 5000000,
        dependentsByCategory: {DependentCategory.specific: 1},
      );
      expect(specific.dependentDeduction, 630000);
      expect(specific.takeHomeAnnual, greaterThan(general.takeHomeAnnual));
    });

    test('同居老親等は同居以外の老人扶養親族より控除額が大きい', () {
      final other = calc.computeDetail(
        grossAnnualIncome: 5000000,
        dependentsByCategory: {DependentCategory.elderlyOther: 1},
      );
      final cohabiting = calc.computeDetail(
        grossAnnualIncome: 5000000,
        dependentsByCategory: {DependentCategory.elderlyCohabiting: 1},
      );
      expect(other.dependentDeduction, 480000);
      expect(cohabiting.dependentDeduction, 580000);
      expect(cohabiting.takeHomeAnnual, greaterThan(other.takeHomeAnnual));
    });

    test('複数区分を組み合わせた場合、各区分の控除額が合算される', () {
      final r = calc.computeDetail(
        grossAnnualIncome: 8000000,
        dependentsByCategory: {
          DependentCategory.general: 1,
          DependentCategory.specific: 1,
        },
      );
      expect(r.dependentDeduction, 380000 + 630000);
    });

    test('dependentsByCategoryを指定しない場合、dependentsは一般区分として扱われる', () {
      final viaDependents = calc.computeDetail(grossAnnualIncome: 5000000, dependents: 2);
      final viaCategory = calc.computeDetail(
        grossAnnualIncome: 5000000,
        dependentsByCategory: {DependentCategory.general: 2},
      );
      expect(viaDependents.dependentDeduction, viaCategory.dependentDeduction);
      expect(viaDependents.takeHomeAnnual, viaCategory.takeHomeAnnual);
    });
  });

  group('基礎控除（所得税）の段階制（令和8年度税制改正）', () {
    test('合計所得489万円以下は104万円', () {
      // 給与所得489万円になるよう、給与所得控除込みで額面を逆算する必要はなく、
      // ここでは給与所得そのものが低めになる年収で確認する。
      final r = calc.computeDetail(grossAnnualIncome: 3000000);
      expect(r.employmentIncome, lessThanOrEqualTo(4890000));
      expect(r.basicDeduction, 1040000);
    });

    test('合計所得489万円超655万円以下は67万円', () {
      final r = calc.computeDetail(grossAnnualIncome: 7500000);
      expect(r.employmentIncome, inInclusiveRange(4890001, 6550000));
      expect(r.basicDeduction, 670000);
    });

    test('合計所得655万円超2,350万円以下は62万円', () {
      final r = calc.computeDetail(grossAnnualIncome: 10000000);
      expect(r.employmentIncome, greaterThan(6550000));
      expect(r.basicDeduction, 620000);
    });
  });
}
