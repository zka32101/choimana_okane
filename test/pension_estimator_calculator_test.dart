import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = PensionEstimatorCalculator();

  group('PensionEstimatorCalculator', () {
    test('40年（480ヶ月）納付で基礎年金は満額になる', () {
      final r = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 40,
        companySize: CompanySize.employee,
      );
      expect(r.annualBasicPension, 816000);
    });

    test('納付期間が短いと基礎年金は満額に届かない', () {
      final r = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 20,
        companySize: CompanySize.employee,
      );
      expect(r.annualBasicPension, closeTo(816000 / 2, 1));
    });

    test('自営業は厚生年金部分が0円', () {
      final r = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 40,
        companySize: CompanySize.selfEmployed,
      );
      expect(r.annualEmployeePension, 0);
    });

    test('会社員は厚生年金部分が加算される', () {
      final r = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 40,
        companySize: CompanySize.employee,
      );
      expect(r.annualEmployeePension, greaterThan(0));
      expect(r.annualTotalPension, r.annualBasicPension + r.annualEmployeePension);
    });

    test('繰り上げ受給（60歳）は標準より年金額が減る', () {
      final standard = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 40,
        companySize: CompanySize.employee,
      );
      final early = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 40,
        companySize: CompanySize.employee,
        retirementAge: 60,
      );
      expect(early.annualTotalPension, lessThan(standard.annualTotalPension));
    });

    test('繰り下げ受給（70歳）は標準より年金額が増える', () {
      final standard = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 40,
        companySize: CompanySize.employee,
      );
      final delayed = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 40,
        companySize: CompanySize.employee,
        retirementAge: 70,
      );
      expect(delayed.annualTotalPension, greaterThan(standard.annualTotalPension));
    });

    test('定数は出典未確認のため、意図的に期限切れ（配信不可）になっている', () {
      expect(calc.parametersValidAt(DateTime(2026, 10, 8)), isFalse);
    });

    test('choimana_core の Calculator 契約: compute() は月額の目安を返す', () {
      final result = calc.compute({
        'averageAnnualIncome': 4000000,
        'pensionEnrollmentYears': 40,
      });
      final detail = calc.computeDetail(
        averageAnnualIncome: 4000000,
        pensionEnrollmentYears: 40,
        companySize: CompanySize.employee,
      );
      expect(result.value, detail.monthlyTotalPension.toDouble());
      expect(result.note, '目安');
    });
  });
}
