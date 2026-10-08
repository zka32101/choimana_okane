import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = FurusatoNozeiCalculator();

  group('FurusatoNozeiCalculator', () {
    test('年収が高いほど控除上限額は大きくなる', () {
      final low = calc.computeDetail(grossAnnualIncome: 3000000);
      final high = calc.computeDetail(grossAnnualIncome: 8000000);
      expect(high.donationLimit, greaterThan(low.donationLimit));
    });

    test('控除上限額は常に実質負担2,000円分を含む（0円未満にならない）', () {
      final r = calc.computeDetail(grossAnnualIncome: 2000000);
      expect(r.donationLimit, greaterThanOrEqualTo(2000));
    });

    test('依存先（TakeHomePayCalculator）の定数が期限切れのため配信不可', () {
      expect(calc.isDeliverableAt(DateTime(2026, 10, 8)), isFalse);
    });

    test('choimana_kit の Calculator 契約: compute() は控除上限額を返す', () {
      final result = calc.compute({'grossAnnualIncome': 5000000});
      final detail = calc.computeDetail(grossAnnualIncome: 5000000);
      expect(result.value, detail.donationLimit.toDouble());
      expect(result.note, '目安');
    });
  });
}
