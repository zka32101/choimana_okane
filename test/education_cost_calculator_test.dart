import 'package:choimana_okane/choimana_okane.dart';
import 'package:test/test.dart';

void main() {
  final calc = EducationCostCalculator();

  group('EducationCostCalculator', () {
    test('定数は出典未確認のため、意図的に期限切れ（配信不可）になっている', () {
      expect(calc.parametersValidAt(DateTime(2026, 10, 8)), isFalse);
    });

    test('私立の方が公立より費用が高い（大学）', () {
      final public = calc.computeDetail(
        childCurrentAge: 0,
        tracks: {EducationStage.university: SchoolTrack.public},
      );
      final private = calc.computeDetail(
        childCurrentAge: 0,
        tracks: {EducationStage.university: SchoolTrack.private},
      );
      expect(private.remainingCost, greaterThan(public.remainingCost));
    });

    test('既に積立があれば必要な残り費用が減る', () {
      final r = calc.computeDetail(childCurrentAge: 0, currentSavings: 1000000);
      final rWithoutSavings = calc.computeDetail(childCurrentAge: 0);
      expect(r.remainingCost, lessThan(rWithoutSavings.remainingCost));
    });

    test('大学入学年齢に近いほど月々の積立額は大きくなる', () {
      final young = calc.computeDetail(childCurrentAge: 0);
      final old = calc.computeDetail(childCurrentAge: 15);
      expect(old.requiredMonthlySavings, greaterThan(young.requiredMonthlySavings));
    });

    test('choimana_core の Calculator 契約: compute() は月々の積立額を返す', () {
      final result = calc.compute({'childCurrentAge': 0});
      final detail = calc.computeDetail(childCurrentAge: 0);
      expect(result.value, detail.requiredMonthlySavings.toDouble());
      expect(result.note, '目安');
    });
  });
}
