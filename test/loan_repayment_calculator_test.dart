import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = LoanRepaymentCalculator();

  group('LoanRepaymentCalculator', () {
    test('年度依存の制度定数がないため常に配信可能', () {
      expect(calc.parametersValidAt(DateTime(2026, 1, 1)), isTrue);
      expect(calc.parametersValidAt(DateTime(2099, 1, 1)), isTrue);
    });

    test('金利0%なら総返済額は元金と一致する', () {
      final r = LoanRepaymentCalculator.simulate(
        principal: 1200000,
        annualInterestRatePercent: 0,
        years: 10,
      );
      expect(r.totalPayment, 1200000);
      expect(r.totalInterest, 0);
    });

    test('元利均等返済: 毎月の返済額が一定', () {
      final r = LoanRepaymentCalculator.simulate(
        principal: 30000000,
        annualInterestRatePercent: 1.5,
        years: 35,
        repaymentType: RepaymentType.equalPayment,
      );
      final payments = r.months.map((m) => m.payment).toSet();
      // 最終回は端数調整で1円程度ずれることがあるため、最終回を除いて確認する。
      final withoutLast = r.months.sublist(0, r.months.length - 1).map((m) => m.payment).toSet();
      expect(withoutLast.length, 1);
      expect(payments.length, lessThanOrEqualTo(2));
    });

    test('元金均等返済: 返済額は徐々に減っていく', () {
      final r = LoanRepaymentCalculator.simulate(
        principal: 30000000,
        annualInterestRatePercent: 1.5,
        years: 35,
        repaymentType: RepaymentType.equalPrincipal,
      );
      expect(r.firstMonthPayment, greaterThan(r.lastMonthPayment));
    });

    test('最終回で残高はちょうど0になる', () {
      final r = LoanRepaymentCalculator.simulate(
        principal: 30000000,
        annualInterestRatePercent: 1.5,
        years: 35,
      );
      expect(r.months.last.remainingBalance, 0);
    });

    test('choimana_core の Calculator 契約: compute() は初回の返済額を返す', () {
      final result = calc.compute({
        'principal': 1200000,
        'annualInterestRatePercent': 2,
        'years': 5,
      });
      final detail = LoanRepaymentCalculator.simulate(
        principal: 1200000,
        annualInterestRatePercent: 2,
        years: 5,
      );
      expect(result.value, detail.firstMonthPayment.toDouble());
      expect(result.note, '目安');
    });
  });
}
