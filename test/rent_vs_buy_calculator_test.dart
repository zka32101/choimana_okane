import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = RentVsBuyCalculator();

  group('RentVsBuyCalculator', () {
    test('年度依存の制度定数がないため、鮮度ポリシーの範囲内なら配信可能', () {
      // Calculator自体の reviewedAt による通常の鮮度判定は別途かかるが、
      // 依存先（LoanRepaymentCalculator）の Parameter が空のため、
      // それが原因で配信不可になることはない。
      expect(calc.isDeliverableAt(DateTime(2026, 1, 1)), isTrue);
    });

    test('賃貸コストは家賃×12×年数で積み上がる（上昇率0%）', () {
      final r = calc.computeDetail(
        monthlyRent: 100000,
        purchasePrice: 30000000,
        downPayment: 3000000,
        loanInterestRatePercent: 1.0,
        loanYears: 35,
        comparisonYears: 10,
      );
      expect(r.finalRentCost, 100000 * 12 * 10);
    });

    test('購入コストには頭金・ローン返済・税・維持費が含まれる', () {
      final r = calc.computeDetail(
        monthlyRent: 100000,
        purchasePrice: 30000000,
        downPayment: 3000000,
        loanInterestRatePercent: 1.0,
        loanYears: 35,
        comparisonYears: 10,
        annualPropertyTax: 100000,
        annualMaintenanceCost: 50000,
      );
      expect(r.finalBuyCost, greaterThan(3000000));
    });

    test('ローン完済前に比較期間が終わればローン残高が残る', () {
      final r = calc.computeDetail(
        monthlyRent: 100000,
        purchasePrice: 30000000,
        downPayment: 3000000,
        loanInterestRatePercent: 1.0,
        loanYears: 35,
        comparisonYears: 10,
      );
      expect(r.remainingLoanBalance, greaterThan(0));
    });

    test('choimana_kit の Calculator 契約: compute() はコスト差を返す', () {
      final result = calc.compute({
        'monthlyRent': 100000,
        'purchasePrice': 30000000,
        'downPayment': 3000000,
        'loanInterestRatePercent': 1.0,
        'loanYears': 35,
        'comparisonYears': 10,
      });
      expect(result.note, '目安');
    });
  });
}
